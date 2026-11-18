"""Instruction-level source harness; peripherals are stubs, not a hardware simulator.

Uses AVRA's symbol map and executes the foreground/sensor/math instructions under
test. This deliberately does not model cycles, interrupts or electrical behavior.
"""
from collections import defaultdict
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Controller:
    def __init__(self):
        self.symbols = {}
        for line in (ROOT / "build/pinball.map").read_text().splitlines():
            fields = line.split()
            if len(fields) == 4:
                self.symbols[fields[0].lower()] = int(fields[2], 16)
        self.code, self.labels = [], {}
        for name in ["Mainloop.asm", "Helper.asm", "sensor_routine(with full comment).asm",
                     "sound.asm", "util.asm"]:
            for line in (ROOT / "src" / name).read_text().splitlines():
                line = line.split(";")[0].strip().lower()
                if not line or line.startswith("."):
                    continue
                if ":" in line:
                    label, line = line.split(":", 1)
                    self.labels[label] = len(self.code)
                    line = line.strip()
                if line and not line.startswith("."):
                    self.code.append(line)
        self.r = [0] * 32
        self.mem = defaultdict(int)
        self.io = defaultdict(int)
        self.stack, self.calls = [], []
        self.c = self.z = self.n = False
        self.stubs = {name: lambda: None for name in
                      ["displayhex", "updatedisplay", "updatedledpattern", "updateledpattern",
                       "initdisplay", "dispenseball", "showattractmode"]}
        self.stored = 0
        self.writes = []
        self.stubs["readeerom"] = lambda: self.word("highscore_l", self.stored)
        self.stubs["writeeerom"] = lambda: self.writes.append(self.word("highscore_l"))
        self.flash = {}
        data = (ROOT / "src/SystemTables.asm").read_text().split("ScoreTable:")[1]
        address = self.symbols["scoretable"] * 2
        for value in re.findall(r"\b\d+\b", "\n".join(
                line.split(";")[0].replace(".dw", "") for line in data.splitlines())):
            value = int(value)
            self.flash[address], self.flash[address + 1] = value & 255, value >> 8
            address += 2

    def reg(self, name):
        return {"xl": 26, "xh": 27, "yl": 28, "yh": 29, "zl": 30, "zh": 31}.get(
            name, int(name[1:]) if name.startswith("r") else -1)

    def val(self, expr):
        expr = re.sub(r"\b[a-z_]\w*\b", lambda m: str(self.symbols[m[0]])
                      if m[0] in self.symbols else m[0], expr)
        return eval(expr, {"__builtins__": {}},
                    {"low": lambda v: v & 255, "high": lambda v: (v >> 8) & 255,
                     "byte3": lambda v: (v >> 16) & 255})

    def word(self, name, value=None):
        address = self.symbols[name]
        if value is not None:
            self.mem[address], self.mem[address + 1] = value & 255, value >> 8
        return self.mem[address] | self.mem[address + 1] << 8

    def set(self, name, value):
        self.mem[self.symbols[name]] = value

    def get(self, name):
        return self.mem[self.symbols[name]]

    def run(self, label, stop=(), limit=10000):
        pc, returns = self.labels[label.lower()], []
        for step in range(limit):
            if step and any(pc == self.labels[s.lower()] for s in stop):
                return next(s for s in stop if pc == self.labels[s.lower()])
            line = self.code[pc]
            if hasattr(self, "hook"):
                self.hook(line)
            pc += 1
            op, _, args = line.partition(" ")
            args = [a.strip() for a in args.split(",")]
            a = args[0]
            if op in ("cli", "sei"):
                continue
            if op in ("call", "rcall"):
                self.calls.append(a)
                if a in self.stubs:
                    self.stubs[a]()
                else:
                    returns.append(pc)
                    pc = self.labels[a]
            elif op == "ret":
                if not returns:
                    return
                pc = returns.pop()
            elif op in ("rjmp", "jmp"):
                pc = self.labels[a]
            elif op.startswith("br"):
                condition = {"breq": self.z, "brne": not self.z,
                             "brlo": self.c, "brcs": self.c, "brsh": not self.c,
                             "brlt": self.n, "brtc": not self.t}[op]
                if condition:
                    pc = self.labels[a]
            elif op in ("push", "pop"):
                if op == "push":
                    self.stack.append(self.r[self.reg(a)])
                else:
                    self.r[self.reg(a)] = self.stack.pop()
            elif op in ("ldi", "lds", "mov", "in"):
                b = args[1]
                self.r[self.reg(a)] = (self.val(b) if op == "ldi" else
                                      self.mem[self.val(b)] if op == "lds" else
                                      self.io[self.val(b)] if op == "in" else self.r[self.reg(b)])
            elif op in ("sts", "out"):
                (self.mem if op == "sts" else self.io)[self.val(a)] = self.r[self.reg(args[1])]
            elif op == "lpm":
                address = self.r[30] | self.r[31] << 8
                self.r[self.reg(a)] = self.flash[address]
                if args[1] == "z+":
                    address += 1
                    self.r[30], self.r[31] = address & 255, address >> 8
            elif op in ("ld", "ldd", "st", "std"):
                pointer = args[1] if op in ("ld", "ldd") else a
                index = self.reg(pointer[0] + "l")
                address = self.r[index] | self.r[index + 1] << 8
                if "+" in pointer and not pointer.endswith("+"):
                    address += int(pointer.split("+")[1])
                if op in ("ld", "ldd"):
                    self.r[self.reg(a)] = self.mem[address]
                else:
                    self.mem[address] = self.r[self.reg(args[1])]
            elif op == "adiw":
                index = self.reg(a)
                value = (self.r[index] | self.r[index + 1] << 8) + self.val(args[1])
                self.r[index], self.r[index + 1] = value & 255, value >> 8
            elif op in ("sbi", "cbi"):
                address, mask = self.val(a), 1 << self.val(args[1])
                self.io[address] = (self.io[address] | mask if op == "sbi" else
                                    self.io[address] & ~mask)
            elif op == "mul":
                value = self.r[self.reg(a)] * self.r[self.reg(args[1])]
                self.r[0], self.r[1] = value & 255, value >> 8
            elif op == "bst":
                self.t = bool(self.r[self.reg(a)] & (1 << self.val(args[1])))
            elif op in ("sec", "clc"):
                self.c = op == "sec"
            else:
                index = self.reg(a)
                x = self.r[index]
                b = args[1] if len(args) > 1 else "0"
                y = self.val(b) if op in ("cpi", "subi", "sbci") else (
                    self.r[self.reg(b)] if len(args) > 1 else 0)
                carry = int(self.c)
                if op in ("cp", "cpi", "cpc", "sub", "subi", "sbc", "sbci"):
                    result = x - y - (carry if op in ("cpc", "sbc", "sbci") else 0)
                    self.c = result < 0
                elif op in ("add", "adc", "lsl", "rol"):
                    result = x + (x if op in ("lsl", "rol") else y) + (
                        carry if op in ("adc", "rol") else 0)
                    self.c = result > 255
                elif op == "lsr":
                    result, self.c = x >> 1, bool(x & 1)
                elif op == "clr": result = 0
                elif op == "inc": result = x + 1
                elif op == "dec": result = x - 1
                elif op == "tst": result = x
                elif op == "or": result = x | y
                elif op == "eor": result = x ^ y
                elif op == "com": result, self.c = x ^ 255, True
                else: raise AssertionError(f"Unsupported instruction: {line}")
                self.z, self.n = (result & 255) == 0, bool(result & 128)
                if op not in ("cp", "cpi", "cpc", "tst"):
                    self.r[index] = result & 255
        raise AssertionError(f"Instruction limit at {self.code[pc]}")


class GameFlowTests(unittest.TestCase):
    def controller(self):
        c = Controller()
        c.t = False
        return c

    def event(self, c, index):
        c.set("sensor_available", 1)
        c.set("debounced_sensor_code", index + 9)
        # Skip the real display formatter but execute game arithmetic and lookup.
        return c.run("InPlayLoop", stop=("StartPlaying", "MainLoop", "InPlayLoop"))

    def test_new_game_selection_and_reset(self):
        for players in (1, 2):
            c = self.controller()
            c.stubs["waitforstartbutton"] = lambda: c.r.__setitem__(16, players)
            c.word("score_p1_l", 999)
            c.run("MainLoop", stop=("StartPlaying",))
            self.assertEqual((c.get("numplayers"), c.get("currentplayer")), (players, 0))
            self.assertEqual((c.get("ballcount_p1"), c.get("ballcount_p2")),
                             (3, 3 if players == 2 else 0))
            self.assertEqual(c.word("score_p1_l"), 0)

    def test_high_score_max_and_strict_improvement(self):
        for p1, p2, stored, expected in [(50, 90, 40, [90]), (90, 50, 40, [90]),
                                         (40, 40, 40, []), (0, 0, 0, []),
                                         (5, 6, 100, []), (255, 256, 254, [256]),
                                         (65535, 3, 65534, [65535])]:
            c = self.controller()
            c.word("score_p1_l", p1)
            c.word("score_p2_l", p2)
            c.stored = stored
            c.run("CheckHighScore")
            self.assertEqual(c.writes, expected)

    def test_scoring_stays_with_player_and_plays_frequency(self):
        c = self.controller()
        c.set("numplayers", 2)
        c.set("currentplayer", 1)
        c.word("score_p2_l", 250)
        self.assertEqual(self.event(c, 8), "InPlayLoop")
        self.assertEqual(c.word("score_p2_l"), 350)
        self.assertEqual(c.get("currentplayer"), 1)
        self.assertIn("playnote", c.calls)
        self.assertEqual(c.r[16] | c.r[17] << 8, 880)

    def test_empty_start_and_invalid_events_do_not_score(self):
        for raw in (None, 0, 8, 9, 49, 255):
            c = self.controller()
            if raw is not None:
                c.set("sensor_available", 1)
                c.set("debounced_sensor_code", raw)
            c.run("InPlayLoop", stop=("InPlayLoop",))
            self.assertEqual(c.word("score_p1_l"), 0)
            self.assertNotIn("updatescore", c.calls)

    def test_all_balls_then_attract(self):
        for players in (1, 2):
            c = self.controller()
            c.set("numplayers", players)
            c.set("ballcount_p1", 3)
            c.set("ballcount_p2", 3 if players == 2 else 0)
            for ball in range(3 * players):
                result = self.event(c, 39)
                self.assertEqual(result, "MainLoop" if ball == 3 * players - 1 else "StartPlaying")
                self.assertEqual(c.get("currentplayer"), (ball + 1) % players)
            self.assertEqual((c.get("ballcount_p1"), c.get("ballcount_p2")), (0, 0))
            self.assertIn("checkhighscore", c.calls)

    def test_tilt_ends_current_ball(self):
        c = self.controller()
        c.set("numplayers", 2)
        c.set("ballcount_p1", 3)
        c.set("ballcount_p2", 3)
        self.assertEqual(self.event(c, 38), "StartPlaying")
        self.assertEqual((c.get("ballcount_p1"), c.get("currentplayer")), (2, 1))
        self.assertIn("playnote", c.calls)

    def test_start_selector_normalizes_both_presses(self):
        for players in (1, 2):
            c = self.controller()
            c.symbols.update(start_delay_outer=1, start_delay_inner=1)
            c.set("sensor_available", 1)
            c.set("debounced_sensor_code", 9)
            def hook(line):
                if players == 2 and line == "lds r17, sensor_available":
                    c.set("sensor_available", 1)
                    c.set("debounced_sensor_code", 9)
            c.hook = hook
            c.run("WaitForStartButton")
            self.assertEqual(c.r[16], players)

    def test_sensor_column_eight_hold_release(self):
        c = self.controller()
        c.set("rowcount", 5)
        c.set("debounce_counter", 10)
        c.io[c.symbols["pine"]] = 0x7f
        for _ in range(11): c.run("SensorDebounceMatrix")
        self.assertEqual(c.get("debounced_sensor_code"), 48)
        self.assertEqual(c.get("sensor_available"), 1)
        for _ in range(20): c.run("SensorDebounceMatrix")
        self.assertEqual(c.get("sensor_available"), 1)
        c.set("sensor_available", 0)
        for _ in range(20): c.run("SensorDebounceMatrix")
        self.assertEqual(c.get("sensor_available"), 0)
        c.io[c.symbols["pine"]] = 255
        c.run("SensorDebounceMatrix")
        c.io[c.symbols["pine"]] = 0x7f
        for _ in range(11): c.run("SensorDebounceMatrix")
        self.assertEqual(c.get("sensor_available"), 1)

    def test_sound_compare_and_silence(self):
        for frequency in (100, 261, 440, 2400):
            c = self.controller()
            c.r[16], c.r[17] = frequency & 255, frequency >> 8
            c.run("PlayNote")
            compare = c.io[c.symbols["ocr1al"]] | c.io[c.symbols["ocr1ah"]] << 8
            self.assertEqual(compare, 500000 // frequency - 1)
            self.assertEqual(c.io[c.symbols["tccr1a"]], 64)
            c.r[16] = c.r[17] = 0
            c.run("PlayNote")
            self.assertEqual(c.io[c.symbols["tccr1a"]], 0)


if __name__ == "__main__":
    unittest.main()
