#!/usr/bin/env python3
"""Bounded one-shot listener and strict parser for the EXP-014 trace."""

from __future__ import annotations

import argparse
import socket
from pathlib import Path

MAX_CAPTURE = 8192
FIELDS = [
    "00 readback_result",
    "01 magic",
    "02 version",
    "03 triggered",
    "04 original_result",
    "05 app_handle",
    "06 bootloader_result",
    "07 bootloader_handle",
    "08 init_env_result",
    "09 init_env_present",
    "10 plugin_load_result",
    "11 plugin_load_present",
    "12 patch_jmp_result",
    "13 patch_target_result",
    "14 complete",
]
PASS_LINE = "[EXP014] 15 PASS bounded trace complete"


def parse_capture(data: bytes) -> dict[str, int]:
    text = data.decode("ascii", "strict")
    if "\r" in text or "\x00" in text or not text.endswith("\n"):
        raise ValueError("capture is not canonical newline-terminated ASCII")
    lines = text.splitlines()
    if len(lines) != len(FIELDS) + 1 or lines[-1] != PASS_LINE:
        raise ValueError("capture is incomplete or contains unexpected lines")

    values: dict[str, int] = {}
    for expected, line in zip(FIELDS, lines[:-1], strict=True):
        prefix = f"[EXP014] {expected}=0x"
        if not line.startswith(prefix):
            raise ValueError(f"expected {expected}")
        digits = line[len(prefix) :]
        if len(digits) != 16 or any(c not in "0123456789abcdef" for c in digits):
            raise ValueError(f"invalid hexadecimal value for {expected}")
        values[expected] = int(digits, 16)

    required = {
        "00 readback_result": 0,
        "01 magic": 0x34313045,
        "02 version": 1,
        "03 triggered": 1,
        "14 complete": 1,
    }
    for name, expected in required.items():
        if values[name] != expected:
            raise ValueError(f"{name} failed validation")
    for name in ("09 init_env_present", "11 plugin_load_present"):
        if values[name] not in (0, 1):
            raise ValueError(f"{name} is not Boolean")
    return values


def receive_once(bind: str, port: int) -> bytes:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((bind, port))
        listener.listen(1)
        connection, _ = listener.accept()
        with connection:
            chunks: list[bytes] = []
            size = 0
            while True:
                chunk = connection.recv(2048)
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_CAPTURE:
                    raise ValueError("capture exceeds the 8192-byte bound")
                chunks.append(chunk)
    return b"".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9024)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    data = receive_once(args.bind, args.port)
    values = parse_capture(data)
    args.output.write_bytes(data)
    print(f"PASS: {len(data)} bytes, {len(values)} validated fields")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
