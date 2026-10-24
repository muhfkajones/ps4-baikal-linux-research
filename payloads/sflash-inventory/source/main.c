/* SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2026 PS4 Baikal Linux Research contributors
 *
 * Builds against Scene-Collective/ps4-payload-sdk. See CREDITS.md.
 */
#include "ps4.h"

#define LOG_PATH "/data/payloads/sflash-provider-inventory-readonly.log"
#define SAMPLE_SIZE 0x200U
#define MIN_MEDIA_SIZE 0x200ULL
#define MAX_MEDIA_SIZE 0x08000000ULL

/* FreeBSD DIOCGMEDIASIZE = _IOR('d', 129, off_t). */
#define DIOCGMEDIASIZE 0x40086481UL
/* FreeBSD DIOCGSECTORSIZE = _IOR('d', 128, unsigned int). */
#define DIOCGSECTORSIZE 0x40046480UL

static const char *const device_paths[] = {
  "/dev/sflash0s1",
  "/dev/sflash0s1.crypt",
  "/dev/sflash0s1.cryptx1",
  "/dev/sflash0s1.cryptx2",
  "/dev/sflash0s1.cryptx3",
  "/dev/sflash0s1.cryptx2b",
  "/dev/sflash0s1.cryptx3b",
  "/dev/sflash0s1.cryptx39",
  "/dev/sflash0s1.cryptx40"
};

static size_t text_length(const char *text) {
  size_t length = 0;
  while (text[length] != '\0') {
    length++;
  }
  return length;
}

static void append_text(const char *text) {
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_APPEND, 0644);
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
    line[cursor++] = digits[(value >> shift) & 0xF];
  }
  line[cursor++] = '\n';
  line[cursor] = '\0';
  append_text(line);
}

static void reset_log(void) {
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd >= 0) {
    static const char header[] =
        "PS4 13.50 read-only SFLASH provider inventory v1\n";
    write(fd, header, sizeof(header) - 1);
    close(fd);
  }
}

static int starts_with(const uint8_t *sample, size_t sample_length,
                       const uint8_t *expected, size_t expected_length) {
  if (sample_length < expected_length) {
    return 0;
  }
  for (size_t index = 0; index < expected_length; index++) {
    if (sample[index] != expected[index]) {
      return 0;
    }
  }
  return 1;
}

static uint64_t fnv1a64(const uint8_t *sample, size_t sample_length) {
  uint64_t hash = 0xcbf29ce484222325ULL;
  for (size_t index = 0; index < sample_length; index++) {
    hash ^= sample[index];
    hash *= 0x100000001b3ULL;
  }
  return hash;
}

static void probe_device(const char *path) {
  static const uint8_t sony_header[] = "SONY COMPUTER ENTERTAINMENT INC.";
  static const uint8_t slb2[] = "SLB2";
  static const uint8_t elf[] = {0x7f, 0x45, 0x4c, 0x46};
  uint8_t sample[SAMPLE_SIZE];

  append_text("DEVICE ");
  append_text(path);
  append_text("\n");

  int input = open(path, O_RDONLY, 0);
  append_hex(" open_fd=", (uint64_t)(int64_t)input);
  if (input < 0) {
    append_text(" result=unavailable\n");
    return;
  }

  off_t media_size = 0;
  int media_result = ioctl(input, DIOCGMEDIASIZE, &media_size);
  append_hex(" media_ioctl=", (uint64_t)(int64_t)media_result);
  append_hex(" media_size=", (uint64_t)media_size);

  unsigned int sector_size = 0;
  int sector_result = ioctl(input, DIOCGSECTORSIZE, &sector_size);
  append_hex(" sector_ioctl=", (uint64_t)(int64_t)sector_result);
  append_hex(" sector_size=", sector_size);

  if (media_result != 0 || sector_result != 0 ||
      media_size < (off_t)MIN_MEDIA_SIZE ||
      media_size > (off_t)MAX_MEDIA_SIZE ||
      sector_size == 0 || sector_size > SAMPLE_SIZE) {
    append_text(" result=invalid-geometry-no-read\n");
    close(input);
    return;
  }

  ssize_t amount = read(input, sample, sizeof(sample));
  append_hex(" sample_read=", (uint64_t)(int64_t)amount);
  if (amount <= 0) {
    append_text(" result=sample-read-failed\n");
    close(input);
    return;
  }

  size_t sample_length = (size_t)amount;
  append_hex(" sample_fnv1a64=", fnv1a64(sample, sample_length));
  append_hex(" marker_sony=", starts_with(sample, sample_length, sony_header,
                                           sizeof(sony_header) - 1));
  append_hex(" marker_slb2=", starts_with(sample, sample_length, slb2,
                                          sizeof(slb2) - 1));
  append_hex(" marker_elf=", starts_with(sample, sample_length, elf,
                                         sizeof(elf)));
  append_hex(" marker_mbr55aa=",
             sample_length >= 0x200 && sample[0x1fe] == 0x55 &&
                 sample[0x1ff] == 0xaa);
  append_text(" result=read-only-probe-complete\n");
  close(input);
}

int _main(struct thread *td) {
  UNUSED(td);

  initKernel();
  reset_log();
  append_text("01 initKernel ok\n");
  initLibc();
  append_text("02 initLibc ok\n");
  initPthread();
  append_text("03 initPthread ok\n");

  int jail_state = is_jailbroken();
  append_hex("04 is_jailbroken=", (uint64_t)jail_state);
  if (!jail_state) {
    int result = jailbreak();
    append_hex("05 jailbreak_result=", (uint64_t)(int64_t)result);
    if (result < 0) {
      append_text("STOP jailbreak failed\n");
      return 0;
    }
  } else {
    append_text("05 jailbreak skipped\n");
  }

  uint16_t firmware = get_firmware();
  append_hex("06 firmware=", firmware);
  if (firmware != 1350) {
    append_text("STOP firmware is not 13.50\n");
    return 0;
  }

  for (size_t index = 0;
       index < sizeof(device_paths) / sizeof(device_paths[0]); index++) {
    probe_device(device_paths[index]);
  }
  append_text("PASS provider inventory complete\n");
  return 0;
}
