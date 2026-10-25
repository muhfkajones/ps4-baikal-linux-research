// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors

#include <orbis/libkernel.h>

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define ATTR_PUBLIC __attribute__((visibility("default")))

#define OUTPUT_ROOT "/mnt/usb0/ps4-re-output"
#define OUTPUT_PATH OUTPUT_ROOT "/authmgr-early-state-1350.bin"
#define LOG_PATH OUTPUT_ROOT "/authmgr-early-state-1350.log"
#define COMPLETE_PATH OUTPUT_ROOT "/authmgr-early-state-1350.complete"

#define TARGET_FIRMWARE_WORD 0x1350u
#define XFAST_SYSCALL_OFFSET_1350 0x000001c0ULL
#define COPYOUT_OFFSET_1350 0x002bd600ULL
#define SM_SERVICE_STATE_OFFSET 0x02680800ULL
#define SM_SERVICE_STATE_SIZE 0x00001380ULL

struct SceEntry {
  int argc;
  int pad;
  const char *argv[];
};

struct snapshot_request {
  uint64_t user_buffer;
  uint64_t size;
  uint64_t kernel_base;
};

struct kexec_call_args {
  void *syscall_handler;
  struct snapshot_request *request;
};

static uint8_t g_snapshot[SM_SERVICE_STATE_SIZE] __attribute__((aligned(16)));

ATTR_PUBLIC const char *g_pluginName = "authmgr_early_snapshot";
ATTR_PUBLIC const char *g_pluginDesc =
    "Firmware-locked early passive sm_service snapshot for Payload Guest";
ATTR_PUBLIC const char *g_pluginAuth = "PS4 Baikal Linux Research contributors";
ATTR_PUBLIC const char *g_pluginVersion = "EXP-012 source revision 1";

static inline uint64_t __attribute__((always_inline)) read_msr(uint32_t msr) {
  uint32_t low;
  uint32_t high;
  __asm__ volatile("rdmsr" : "=a"(low), "=d"(high) : "c"(msr));
  return ((uint64_t)high << 32) | low;
}

/* Invoked by HEN syscall 11. It performs one copyout, never a kernel write. */
static int __attribute__((used, noinline, no_stack_protector))
kernel_snapshot(void *thread, struct kexec_call_args *args) {
  (void)thread;

  struct snapshot_request *request = args->request;
  if (request->size != SM_SERVICE_STATE_SIZE) {
    return -1;
  }

  uint8_t *kernel_base =
      (uint8_t *)(read_msr(0xc0000082u) - XFAST_SYSCALL_OFFSET_1350);
  int (*copyout)(const void *, void *, size_t) =
      (void *)(kernel_base + COPYOUT_OFFSET_1350);

  int result = copyout(kernel_base + SM_SERVICE_STATE_OFFSET,
                       (void *)request->user_buffer, request->size);
  if (result != 0) {
    return result;
  }

  return copyout(&kernel_base, &request->kernel_base,
                 sizeof(request->kernel_base));
}

/*
 * Fixed-arity form of the MIT-licensed syscall pattern used by
 * Scene-Collective/ps4-hen-plugins. All six argument registers are defined.
 */
static long call_kexec(void *callback, void *user_argument) {
  unsigned long result;
  char carry;
  register long r10 __asm__("r10") = 0;
  register long r8 __asm__("r8") = 0;
  register long r9 __asm__("r9") = 0;

  __asm__ volatile("syscall"
                   : "=a"(result), "=@ccc"(carry), "+r"(r10), "+r"(r8),
                     "+r"(r9)
                   : "a"(11L), "D"((long)callback), "S"((long)user_argument),
                     "d"(0L)
                   : "rcx", "r11", "memory");

  return carry ? -(long)result : (long)result;
}

static size_t text_length(const char *text) {
  size_t length = 0;
  while (text[length] != '\0') {
    length++;
  }
  return length;
}

static void append_text(const char *text) {
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0777);
  if (fd >= 0) {
    write(fd, text, text_length(text));
    close(fd);
  }
}

static void append_hex(const char *label, uint64_t value) {
  static const char digits[] = "0123456789abcdef";
  char line[96];
  size_t cursor = 0;
  while (label[cursor] != '\0' && cursor < sizeof(line) - 20) {
    line[cursor] = label[cursor];
    cursor++;
  }
  line[cursor++] = '0';
  line[cursor++] = 'x';
  for (int shift = 60; shift >= 0; shift -= 4) {
    line[cursor++] = digits[(value >> shift) & 0xf];
  }
  line[cursor++] = '\n';
  line[cursor] = '\0';
  append_text(line);
}

static void reset_outputs(void) {
  mkdir(OUTPUT_ROOT, 0777);
  unlink(OUTPUT_PATH);
  unlink(LOG_PATH);
  unlink(COMPLETE_PATH);

  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (fd >= 0) {
    static const char header[] =
        "PS4 13.50 AuthMgr early-load snapshot plugin EXP-012\n";
    write(fd, header, sizeof(header) - 1);
    close(fd);
  }
}

static int write_all(int fd, const uint8_t *data, size_t size) {
  size_t written = 0;
  while (written < size) {
    ssize_t result = write(fd, data + written, size - written);
    if (result <= 0) {
      return -1;
    }
    written += (size_t)result;
  }
  return 0;
}

ATTR_PUBLIC int plugin_load(struct SceEntry *args,
                            const void *atexit_handler) {
  (void)args;
  (void)atexit_handler;

  reset_outputs();
  append_text("01 plugin_load entered\n");

  OrbisKernelSwVersion version;
  memset(&version, 0, sizeof(version));
  version.Size = sizeof(version);
  int version_result = sceKernelGetSystemSwVersion(&version);
  append_hex("02 firmware_query_result=", (uint64_t)(int64_t)version_result);
  append_hex("03 firmware_raw=", version.Version);
  if (version_result != 0 ||
      ((version.Version >> 16) & 0xffffu) != TARGET_FIRMWARE_WORD) {
    append_text("STOP firmware is not exactly 13.50\n");
    return 1;
  }

  memset(g_snapshot, 0, sizeof(g_snapshot));
  struct snapshot_request request;
  memset(&request, 0, sizeof(request));
  request.user_buffer = (uint64_t)g_snapshot;
  request.size = sizeof(g_snapshot);

  append_hex("04 requested_bytes=", request.size);
  long kexec_result = call_kexec((void *)kernel_snapshot, &request);
  append_hex("05 kexec_result=", (uint64_t)kexec_result);
  append_hex("06 kernel_base=", request.kernel_base);
  if (kexec_result != 0 || (request.kernel_base >> 48) != 0xffffu) {
    append_text("STOP bounded kernel snapshot failed\n");
    return 1;
  }

  int output = open(OUTPUT_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  append_hex("07 output_fd=", (uint64_t)(int64_t)output);
  if (output < 0) {
    append_text("STOP output open failed\n");
    return 1;
  }

  int write_result = write_all(output, g_snapshot, sizeof(g_snapshot));
  close(output);
  append_hex("08 write_result=", (uint64_t)(int64_t)write_result);
  if (write_result != 0) {
    unlink(OUTPUT_PATH);
    append_text("STOP output write failed\n");
    return 1;
  }

  int marker = open(COMPLETE_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (marker < 0) {
    unlink(OUTPUT_PATH);
    append_text("STOP completion marker failed\n");
    return 1;
  }
  static const char marker_text[] = "complete\n";
  write(marker, marker_text, sizeof(marker_text) - 1);
  close(marker);

  append_text("PASS early bounded sm_service state snapshot complete\n");
  return 1;
}

ATTR_PUBLIC int plugin_unload(struct SceEntry *args,
                              const void *atexit_handler) {
  (void)args;
  (void)atexit_handler;
  return 0;
}
