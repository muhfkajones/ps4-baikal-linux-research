#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

set -u

if [[ $# -ne 2 ]]; then
  echo "usage: $0 HEN_SOURCE_ROOT REPORT_DIRECTORY" >&2
  exit 64
fi

hen_root=$(realpath "$1")
report_root=$(realpath -m "$2")
kpayload="$hen_root/kpayload"
mkdir -p "$report_root"

for required in gcc ld objcopy readelf make git sha256sum stat; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "required tool not found: $required" >&2
    exit 69
  fi
done

if [[ ! -f "$kpayload/Makefile" || ! -f "$kpayload/linker.x" ]]; then
  echo "HEN kpayload build inputs not found under $hen_root" >&2
  exit 66
fi

{
  echo "source_revision=$(git -C "$hen_root" rev-parse HEAD)"
  echo "source_status_before_build<<EOF"
  git -C "$hen_root" status --short
  echo "EOF"
  echo "gcc=$(gcc --version | head -n 1)"
  echo "ld=$(ld --version | head -n 1)"
  echo "objcopy=$(objcopy --version | head -n 1)"
  echo "make=$(make --version | head -n 1)"
  echo "linker_sha256=$(sha256sum "$kpayload/linker.x" | cut -d' ' -f1)"
} >"$report_root/provenance.txt"

make -C "$kpayload" info >"$report_root/make-info.txt" 2>&1

set +e
make -C "$kpayload" payload RM=true >"$report_root/build.log" 2>&1
build_status=$?
set -e
printf '%s\n' "$build_status" >"$report_root/build-status.txt"

if [[ $build_status -ne 0 ]]; then
  exit "$build_status"
fi

for artifact in temp.t temp.u kpayload.bin kpayload.map; do
  if [[ ! -f "$kpayload/$artifact" ]]; then
    echo "successful make did not produce $artifact" >&2
    exit 65
  fi
done

(
  cd "$kpayload"
  stat -c '%n %s' temp.t temp.u kpayload.bin kpayload.map >"$report_root/sizes.txt"
  sha256sum temp.t temp.u kpayload.bin kpayload.map >"$report_root/sha256sums.txt"
  readelf --file-header --sections --segments --relocs temp.t >"$report_root/elf-layout.txt"
)
