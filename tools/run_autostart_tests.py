#!/usr/bin/env python3
# ============================================================================
#
#  JR100_MiSTer: autostart acceptance tests.
#
#  With the OSD Autostart option on, the core types RUN after a BASIC
#  load and A=USR($hhhh) when a v2 comment carries "USR=$hhhh"; with no
#  hint (v1 machine-code container), nothing is typed.
#
#  The BASIC ROM does all the work: the tests only inspect memory/VRAM
#  after letting the auto-typer and the program run.
#
#  Copyright (C) 2026 Zabaglione
#  SPDX-License-Identifier: GPL-2.0-or-later
#
# ============================================================================
"""Acceptance for the autostart feature (RUN / USR=$hhhh)."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORK = REPO / "sim" / "work"
SIM = REPO / "sim" / "obj_dir" / "Vjr100_top"
EMU_DATAS = REPO.parent / "jr100emu" / "datas"


def run_sim(args: list[str], dump: Path, ranges: list[str],
            boot_cycles: int = 600000) -> dict[int, int]:
    cmd = [str(SIM), "--image", str(WORK / "boot.img"),
           "--cycles", str(boot_cycles),
           "--autostart", "--dump", str(dump)]
    for r in ranges:
        cmd += ["--dump-range", r]
    subprocess.run(cmd + args, check=True, capture_output=True)
    mem: dict[int, int] = {}
    for line in dump.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^([0-9A-F]{4})((?: [0-9A-F]{2}){16})$", line)
        if m:
            base = int(m.group(1), 16)
            for i, tok in enumerate(m.group(2).split()):
                mem[base + i] = int(tok, 16)
    return mem


def vram_text(mem: dict[int, int]) -> str:
    rows = []
    for r in range(24):
        row = "".join(
            chr((mem.get(0xC100 + r * 32 + c, 0) & 0x7F) + 0x20)
            for c in range(32))
        rows.append(row)
    return "\n".join(rows)


def test_run() -> bool:
    mem = run_sim(
        ["--bas", str(EMU_DATAS / "doremi_scale.bas"), "--cycles2", "3000000"],
        WORK / "as_run.dump", ["C100:C3FF"])
    screen = vram_text(mem)
    if "C MAJOR SCALE" in screen:
        print("PASS autostart RUN (doremi_scale is running)")
        return True
    print("FAIL autostart RUN: screen:\n" + screen)
    return False


def make_usr_prg() -> Path:
    routine = WORK / "as_routine.bin"
    routine.write_bytes(bytes([0x86, 0x2A, 0xB7, 0x07, 0x00, 0x39]))
    bas = WORK / "as_stub.bas"
    bas.write_text("10 END\n", encoding="utf-8")
    prg = WORK / "as_usr.prg"
    subprocess.run(
        [sys.executable, str(REPO / "tools" / "bas2prg.py"), str(bas),
         str(prg), "--bin", f"1000:{routine}", "--autostart", "1000"],
        check=True, capture_output=True)
    return prg


def test_usr() -> bool:
    prg = make_usr_prg()
    mem = run_sim(["--prg", str(prg), "--cycles2", "4500000"],
                  WORK / "as_usr.dump", ["0700:070F"])
    if mem.get(0x0700) == 0x2A:
        print("PASS autostart USR=$1000 (routine executed)")
        return True
    print(f"FAIL autostart USR: mem[0700]={mem.get(0x0700)}")
    return False


def test_usr_before_ready() -> bool:
    prg = make_usr_prg()
    mem = run_sim(
        ["--prg", str(prg), "--cycles2", "4500000"],
        WORK / "as_usr_before_ready.dump", ["0700:070F", "C100:C3FF"],
        boot_cycles=0)
    if mem.get(0x0700) == 0x2A:
        print("PASS autostart USR waits for BASIC input")
        return True
    print("FAIL autostart USR started before BASIC input: screen:\n" +
          vram_text(mem))
    return False


def test_none() -> bool:
    # v1 machine-code container: no autostart hint -> nothing typed
    mem = run_sim(
        ["--prg", str(EMU_DATAS / "maze_init_test.prg"),
         "--cycles2", "1500000"],
        WORK / "as_none.dump", ["C100:C3FF"])
    screen = vram_text(mem)
    if "READY" in screen and "SYNTAX" not in screen:
        print("PASS autostart none (v1 machine code: nothing typed)")
        return True
    print("FAIL autostart none: screen:\n" + screen)
    return False


def main() -> int:
    ok = test_run()
    ok &= test_usr()
    ok &= test_usr_before_ready()
    ok &= test_none()
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
