// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors
// EXP-014 bounded user-mode readback of the firmware/title-locked HEN trace.

#include "ps4.h"

#ifndef EXP014_DEBUG_HOST
#error "EXP014_DEBUG_HOST must be supplied by the private local build"
#endif

#ifndef EXP014_DEBUG_PORT
#define EXP014_DEBUG_PORT 9024
#endif

#define EXP014_TRACE_MAGIC 0x34313045u
#define SYS_PROC_EXP014_TRACE 10UL

struct exp014_trace {
  uint32_t magic;
  uint32_t version;
  uint32_t triggered;
  int32_t original_result;
  int32_t app_handle;
  int32_t bootloader_result;
  int32_t bootloader_handle;
  int32_t init_env_result;
  uint32_t init_env_present;
  int32_t plugin_load_result;
  uint32_t plugin_load_present;
  int32_t patch_jmp_result;
  int32_t patch_target_result;
  uint32_t complete;
} __attribute__((packed));

static int capture_socket = -1;

static int send_all(const char *msg) {
  int remaining = (int)strlen(msg);
  while (remaining > 0) {
    int sent = sceNetSend(capture_socket, msg, (size_t)remaining, 0);
    if (sent <= 0) return -1;
    msg += sent;
    remaining -= sent;
  }
  return 0;
}

static void trace(const char *msg) {
  (void)syscall(601UL, 7UL, (unsigned long)msg, 0UL);
  if (capture_socket >= 0) (void)send_all(msg);
}

static void log_hex(const char *label, uint64_t value) {
  static const char digits[] = "0123456789abcdef";
  char line[112];
  size_t pos = 0;
  while (*label && pos < sizeof(line) - 20) line[pos++] = *label++;
  line[pos++] = '0';
  line[pos++] = 'x';
  for (int shift = 60; shift >= 0; shift -= 4)
    line[pos++] = digits[(value >> shift) & 0xf];
  line[pos++] = '\n';
  line[pos] = 0;
  trace(line);
}

int _main(struct thread *td) {
  UNUSED(td);
  initKernel();
  initLibc();
  initNetwork();

  capture_socket = SckConnect(EXP014_DEBUG_HOST, EXP014_DEBUG_PORT);
  if (capture_socket < 0) {
    trace("[EXP014] STOP host capture connection failed\n");
    return 0;
  }

  struct exp014_trace result;
  memset(&result, 0, sizeof(result));
  int r = (int)syscall(109UL, (unsigned long)getpid(),
                       SYS_PROC_EXP014_TRACE, (unsigned long)&result);
  log_hex("[EXP014] 00 readback_result=", (uint64_t)(int64_t)r);
  log_hex("[EXP014] 01 magic=", result.magic);
  log_hex("[EXP014] 02 version=", result.version);
  log_hex("[EXP014] 03 triggered=", result.triggered);
  log_hex("[EXP014] 04 original_result=", (uint64_t)(int64_t)result.original_result);
  log_hex("[EXP014] 05 app_handle=", (uint32_t)result.app_handle);
  log_hex("[EXP014] 06 bootloader_result=", (uint64_t)(int64_t)result.bootloader_result);
  log_hex("[EXP014] 07 bootloader_handle=", (uint32_t)result.bootloader_handle);
  log_hex("[EXP014] 08 init_env_result=", (uint64_t)(int64_t)result.init_env_result);
  log_hex("[EXP014] 09 init_env_present=", result.init_env_present);
  log_hex("[EXP014] 10 plugin_load_result=", (uint64_t)(int64_t)result.plugin_load_result);
  log_hex("[EXP014] 11 plugin_load_present=", result.plugin_load_present);
  log_hex("[EXP014] 12 patch_jmp_result=", (uint64_t)(int64_t)result.patch_jmp_result);
  log_hex("[EXP014] 13 patch_target_result=", (uint64_t)(int64_t)result.patch_target_result);
  log_hex("[EXP014] 14 complete=", result.complete);

  if (r == 0 && result.magic == EXP014_TRACE_MAGIC && result.version == 1 &&
      result.triggered == 1 && result.complete == 1)
    trace("[EXP014] 15 PASS bounded trace complete\n");
  else
    trace("[EXP014] STOP trace absent or incomplete\n");

  SckClose(capture_socket);
  return 0;
}
