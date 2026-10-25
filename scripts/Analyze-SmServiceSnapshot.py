#!/usr/bin/env python3
"""Compare a bounded PS4 sm_service snapshot with privately held bank entries."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path


STAGING_OFFSET = 0x3A0
EXPECTED_STAGING_SIZE = 0xFE0
WINDOW_SIZES = (0xC00, 0x800, 0x400, 0x200, 0x100, 0x80, 0x40, 0x20)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def entropy(data: bytes) -> float:
    if not data:
        return 0.0
    total = len(data)
    return -sum((count / total) * math.log2(count / total) for count in Counter(data).values())


def region_summary(data: bytes) -> dict[str, int | float | str]:
    return {
        "bytes": len(data),
        "sha256": sha256(data),
        "entropyBitsPerByte": round(entropy(data), 6),
        "zeroBytes": data.count(0),
        "uniqueByteValues": len(set(data)),
    }


def meaningful(data: bytes) -> bool:
    return entropy(data) >= 2.5 and len(set(data)) >= 8


def extend_match(
    staging: bytes,
    candidate: bytes,
    staging_offset: int,
    candidate_offset: int,
    seed_size: int,
) -> dict[str, int]:
    left = 0
    while (
        staging_offset - left > 0
        and candidate_offset - left > 0
        and staging[staging_offset - left - 1] == candidate[candidate_offset - left - 1]
    ):
        left += 1

    right = seed_size
    while (
        staging_offset + right < len(staging)
        and candidate_offset + right < len(candidate)
        and staging[staging_offset + right] == candidate[candidate_offset + right]
    ):
        right += 1

    staging_start = staging_offset - left
    candidate_start = candidate_offset - left
    return {
        "bytes": left + right,
        "snapshotOffset": STAGING_OFFSET + staging_start,
        "stagingOffset": staging_start,
        "candidateOffset": candidate_start,
        "seedBytes": seed_size,
    }


def first_meaningful_match(staging: bytes, candidate: bytes) -> dict[str, int] | None:
    for size in WINDOW_SIZES:
        if size > len(staging):
            continue
        for staging_offset in range(0, len(staging) - size + 1, 0x10):
            window = staging[staging_offset : staging_offset + size]
            if not meaningful(window):
                continue
            candidate_offset = candidate.find(window)
            if candidate_offset >= 0:
                return extend_match(
                    staging, candidate, staging_offset, candidate_offset, size
                )
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", required=True, type=Path)
    parser.add_argument("--entries", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    snapshot = args.snapshot.read_bytes()
    if len(snapshot) != 0x1000:
        raise SystemExit(f"snapshot must be exactly 0x1000 bytes, got 0x{len(snapshot):x}")

    staging = snapshot[STAGING_OFFSET:]
    results = {
        "snapshot": region_summary(snapshot),
        "controlRegion": region_summary(snapshot[:STAGING_OFFSET]),
        "capturedStagingRegion": region_summary(staging),
        "stagingOffset": STAGING_OFFSET,
        "expectedStagingBytes": EXPECTED_STAGING_SIZE,
        "capturedStagingBytes": len(staging),
        "missingStagingBytes": EXPECTED_STAGING_SIZE - len(staging),
        "entries": [],
    }

    for entry_path in sorted(args.entries.glob("*.bin")):
        candidate = entry_path.read_bytes()
        results["entries"].append(
            {
                "name": entry_path.name,
                "bytes": len(candidate),
                "sha256": sha256(candidate),
                "entireCapturedStagingOffset": candidate.find(staging),
                "meaningfulMatch": first_meaningful_match(staging, candidate),
            }
        )

    rendered = json.dumps(results, indent=2)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
