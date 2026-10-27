// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors
// EXP-013 revision 7: revision-6 user-mode inventory with direct host capture.
// No kernel memory reads, file I/O, custom PRX loading, or kernel patching.

#include "ps4.h"

#ifndef EXP013_DEBUG_HOST
#error "EXP013_DEBUG_HOST must be supplied by the private local build"
#endif

#ifndef EXP013_DEBUG_PORT
#define EXP013_DEBUG_PORT 9023
#endif

#define MODULE_CAPACITY 256

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

static void log_hex(const char *label, uint64_t val) {
  static const char hexdigits[] = "0123456789abcdef";
  char line[104];
  size_t pos = 0;
  while (*label && pos < sizeof(line) - 20) line[pos++] = *label++;
  line[pos++] = '0'; line[pos++] = 'x';
  for (int shift = 60; shift >= 0; shift -= 4)
    line[pos++] = hexdigits[(val >> shift) & 0xF];
  line[pos++] = '\n'; line[pos] = 0;
  trace(line);
}

static void log_module(unsigned index, unsigned id, const char name[32]) {
  static const char hexdigits[] = "0123456789abcdef";
  static const char prefix[] = "[EXP013-V7] module[";
  static const char middle[] = "] id=0x";
  static const char suffix[] = " name=";
  char line[128];
  size_t pos = 0;
  for (size_t i = 0; i < sizeof(prefix) - 1; ++i) line[pos++] = prefix[i];
  line[pos++] = hexdigits[(index >> 4) & 0xF];
  line[pos++] = hexdigits[index & 0xF];
  for (size_t i = 0; i < sizeof(middle) - 1; ++i) line[pos++] = middle[i];
  for (int shift = 28; shift >= 0; shift -= 4)
    line[pos++] = hexdigits[(id >> shift) & 0xF];
  for (size_t i = 0; i < sizeof(suffix) - 1; ++i) line[pos++] = suffix[i];
  for (size_t i = 0; i < 32 && name[i]; ++i) {
    unsigned char c = (unsigned char)name[i];
    line[pos++] = (c >= 32 && c <= 126) ? (char)c : '?';
  }
  line[pos++] = '\n';
  line[pos] = 0;
  trace(line);
}

int _main(struct thread *td) {
  UNUSED(td);
  initKernel();
  initLibc();
  initNetwork();
  capture_socket = SckConnect(EXP013_DEBUG_HOST, EXP013_DEBUG_PORT);
  if (capture_socket < 0) {
    trace("[EXP013-V7] STOP host capture connection failed\n");
    return 0;
  }

  trace("[EXP013-V7] 00 capture connected\n");
  log_hex("[EXP013-V7] 01 uid=", (uint64_t)(int64_t)getuid());
  log_hex("[EXP013-V7] 02 sandbox=", (uint64_t)(int64_t)is_in_sandbox());

  int handles[MODULE_CAPACITY];
  int count = 0;
  memset(handles, 0, sizeof(handles));
  int r = getLoadedModules(handles, MODULE_CAPACITY, &count);
  log_hex("[EXP013-V7] 03 enumeration_result=", (uint64_t)(int64_t)r);
  log_hex("[EXP013-V7] 04 module_count=", (uint64_t)(int64_t)count);
  if (r != 0 || count < 0 || count > MODULE_CAPACITY) {
    trace("[EXP013-V7] STOP enumeration failed/truncated\n");
    SckClose(capture_socket);
    return 0;
  }

  unsigned failures = 0;
  for (int i = 0; i < count; ++i) {
    struct moduleInfo info;
    memset(&info, 0, sizeof(info));
    int result = getModuleInfo(handles[i], &info);
    if (result == 0) log_module((unsigned)i, (unsigned)handles[i], info.name);
    else {
      failures++;
      log_hex("[EXP013-V7] module_info_failed_id=", (uint64_t)(uint32_t)handles[i]);
    }
  }
  log_hex("[EXP013-V7] 05 module_info_failures=", failures);
  trace("[EXP013-V7] 06 complete; no kernel reads or file writes attempted\n");
  SckClose(capture_socket);
  return 0;
}
