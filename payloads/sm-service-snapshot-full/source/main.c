// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors

#include "ps4.h"

#define OUTPUT_ROOT "/mnt/usb0/ps4-re-output"
#define OUTPUT_PATH OUTPUT_ROOT "/sm-service-state-full-1350.bin"
#define LOG_PATH OUTPUT_ROOT "/sm-service-state-full-1350.log"
#define COMPLETE_PATH OUTPUT_ROOT "/sm-service-state-full-1350.complete"

/*
 * Firmware 13.50 only. This bounded range contains the sm_service control and
 * request records (0x3a0 bytes) followed by the complete 0xfe0-byte staging
 * area identified from the owned console's kernel dump.
 */
#define SM_SERVICE_STATE_OFFSET 0x02680800ULL
#define SM_SERVICE_STATE_SIZE 0x00001380ULL

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

static void reset_log(void) {
  mkdir(OUTPUT_ROOT, 0777);
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (fd >= 0) {
    static const char header[] = "PS4 13.50 sm_service full state snapshot v2\n";
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

int _main(struct thread *td) {
  UNUSED(td);

  initKernel();
  initLibc();
  reset_log();
  append_text("01 init ok\n");

  int jail_state = is_jailbroken();
  append_hex("02 is_jailbroken=", (uint64_t)(int64_t)jail_state);
  if (!jail_state) {
    int result = jailbreak();
    append_hex("03 jailbreak_result=", (uint64_t)(int64_t)result);
    if (result < 0) {
      append_text("STOP jailbreak failed\n");
      return 0;
    }
  } else {
    append_text("03 jailbreak skipped\n");
  }

  uint16_t firmware = get_firmware();
  append_hex("04 firmware=", firmware);
  if (firmware != 1350) {
    append_text("STOP firmware is not 13.50\n");
    return 0;
  }

  uint64_t kernel_base = get_kernel_base();
  append_hex("05 kernel_base=", kernel_base);
  if (kernel_base == UINT64_MAX || (kernel_base >> 48) != 0xffff) {
    append_text("STOP invalid kernel base\n");
    return 0;
  }

  uint8_t *snapshot = mmap(NULL, SM_SERVICE_STATE_SIZE,
                           PROT_READ | PROT_WRITE,
                           MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
  if (snapshot == MAP_FAILED) {
    append_text("STOP snapshot allocation failed\n");
    return 0;
  }

  uint64_t source = kernel_base + SM_SERVICE_STATE_OFFSET;
  append_hex("06 source=", source);
  append_hex("07 bytes=", SM_SERVICE_STATE_SIZE);
  int read_result = get_memory_dump(source, (uint64_t *)snapshot,
                                    SM_SERVICE_STATE_SIZE);
  append_hex("08 get_memory_dump_result=", (uint64_t)(int64_t)read_result);
  if (read_result != 0) {
    append_text("STOP bounded kernel read failed\n");
    munmap(snapshot, SM_SERVICE_STATE_SIZE);
    return 0;
  }

  unlink(OUTPUT_PATH);
  unlink(COMPLETE_PATH);
  int output = open(OUTPUT_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  append_hex("09 output_fd=", (uint64_t)(int64_t)output);
  if (output < 0) {
    append_text("STOP output open failed\n");
    munmap(snapshot, SM_SERVICE_STATE_SIZE);
    return 0;
  }

  int write_result = write_all(output, snapshot, SM_SERVICE_STATE_SIZE);
  close(output);
  munmap(snapshot, SM_SERVICE_STATE_SIZE);
  append_hex("10 write_result=", (uint64_t)(int64_t)write_result);
  if (write_result != 0) {
    unlink(OUTPUT_PATH);
    append_text("STOP output write failed\n");
    return 0;
  }

  int marker = open(COMPLETE_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (marker < 0) {
    append_text("STOP completion marker failed\n");
    unlink(OUTPUT_PATH);
    return 0;
  }
  static const char marker_text[] = "complete\n";
  write(marker, marker_text, sizeof(marker_text) - 1);
  close(marker);

  append_text("PASS full bounded sm_service state snapshot complete\n");
  printf_notification("sm_service full snapshot complete");
  return 0;
}
