/* SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2026 PS4 Baikal Linux Research contributors
 *
 * Builds against Scene-Collective/ps4-payload-sdk. See CREDITS.md.
 *
 * This payload reads four specifically named signed SELF files from USB and
 * asks the running 13.50 AuthMgr path to return their decrypted ELF32
 * segments. It never opens an internal storage device and never writes
 * outside /mnt/usb0/ps4-re-output.
 */
#include "ps4.h"

#define INPUT_ROOT "/mnt/usb0/ps4-re-input"
#define OUTPUT_ROOT "/mnt/usb0/ps4-re-output"
#define LOG_PATH OUTPUT_ROOT "/secure-module-decrypt.log"
#define COMPLETE_PATH OUTPUT_ROOT "/.complete"

#define SELF32_MACHINE 0x0667U
#define MAX_HEADER_BYTES 0x1000U
#define MAX_SEGMENTS 16U
#define MAX_SEGMENT_BYTES 0x02000000U

extern bool read_decrypt_segment(int fd, uint64_t index, uint64_t offset,
                                 size_t size, uint8_t *out);

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
  char line[112];
  size_t cursor = 0;
  while (label[cursor] != '\0' && cursor < sizeof(line) - 20) {
    line[cursor] = label[cursor];
    cursor++;
  }
  line[cursor++] = '0';
  line[cursor++] = 'x';
  for (int shift = 60; shift >= 0; shift -= 4) {
    line[cursor++] = digits[(value >> shift) & 0x0fU];
  }
  line[cursor++] = '\n';
  line[cursor] = '\0';
  append_text(line);
}

static uint16_t load16(const uint8_t *p) {
  return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t load32(const uint8_t *p) {
  return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
         ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint64_t load64(const uint8_t *p) {
  return (uint64_t)load32(p) | ((uint64_t)load32(p + 4) << 32);
}

static void store32(uint8_t *p, uint32_t value) {
  p[0] = (uint8_t)value;
  p[1] = (uint8_t)(value >> 8);
  p[2] = (uint8_t)(value >> 16);
  p[3] = (uint8_t)(value >> 24);
}

static void store16(uint8_t *p, uint16_t value) {
  p[0] = (uint8_t)value;
  p[1] = (uint8_t)(value >> 8);
}

static int write_all(int fd, const uint8_t *buffer, size_t length) {
  size_t done = 0;
  while (done < length) {
    ssize_t amount = write(fd, buffer + done, length - done);
    if (amount <= 0) {
      return -1;
    }
    done += (size_t)amount;
  }
  return 0;
}

static int read_header(int fd, uint8_t *header, size_t length) {
  if (lseek(fd, 0, SEEK_SET) < 0) {
    return -1;
  }
  size_t done = 0;
  while (done < length) {
    ssize_t amount = read(fd, header + done, length - done);
    if (amount <= 0) {
      return -1;
    }
    done += (size_t)amount;
  }
  return 0;
}

static int decrypt_self32(const char *input_path, const char *output_path,
                          uint64_t expected_size) {
  uint8_t header[MAX_HEADER_BYTES];
  int input = -1;
  int output = -1;
  int result = -1;

  append_text("INPUT ");
  append_text(input_path);
  append_text("\n");

  input = open(input_path, O_RDONLY, 0);
  append_hex(" input_fd=", (uint64_t)(int64_t)input);
  if (input < 0) {
    append_text(" result=input-open-failed\n");
    return -1;
  }

  off_t actual_size = lseek(input, 0, SEEK_END);
  append_hex(" input_size=", (uint64_t)actual_size);
  if (actual_size < 0 || (uint64_t)actual_size != expected_size ||
      expected_size > MAX_SEGMENT_BYTES) {
    append_text(" result=unexpected-input-size\n");
    goto cleanup;
  }

  size_t header_read = actual_size < (off_t)sizeof(header)
                           ? (size_t)actual_size
                           : sizeof(header);
  if (read_header(input, header, header_read) != 0 || header_read < 0x80U) {
    append_text(" result=header-read-failed\n");
    goto cleanup;
  }

  uint16_t self_entries = load16(header + 0x18);
  uint16_t self_header_size = load16(header + 0x0c);
  uint16_t self_meta_size = load16(header + 0x0e);
  uint64_t self_file_size = load64(header + 0x10);
  uint64_t elf_offset = 0x20ULL + (uint64_t)self_entries * 0x20ULL;
  append_hex(" self_entries=", self_entries);
  append_hex(" self_header_size=", self_header_size);
  append_hex(" self_meta_size=", self_meta_size);
  append_hex(" elf_offset=", elf_offset);

  if (load32(header) != SELF_MAGIC || self_entries == 0 ||
      self_entries > MAX_SEGMENTS || self_file_size != expected_size ||
      elf_offset + 0x34U > header_read ||
      (uint64_t)self_header_size + self_meta_size > header_read) {
    append_text(" result=invalid-self-header\n");
    goto cleanup;
  }

  uint8_t *elf = header + (size_t)elf_offset;
  if (load32(elf) != ELF_MAGIC || elf[4] != ELFCLASS32 ||
      elf[5] != ELFDATA2LSB || load16(elf + 0x12) != SELF32_MACHINE) {
    append_text(" result=not-supported-elf32\n");
    goto cleanup;
  }

  uint32_t phoff = load32(elf + 0x1c);
  uint16_t ehsize = load16(elf + 0x28);
  uint16_t phentsize = load16(elf + 0x2a);
  uint16_t phnum = load16(elf + 0x2c);
  uint64_t phend = (uint64_t)phoff + (uint64_t)phentsize * phnum;
  append_hex(" elf_phoff=", phoff);
  append_hex(" elf_phentsize=", phentsize);
  append_hex(" elf_phnum=", phnum);

  if (ehsize != 0x34U || phentsize != 0x20U || phnum == 0 ||
      phnum > MAX_SEGMENTS || elf_offset + phend > header_read) {
    append_text(" result=invalid-program-headers\n");
    goto cleanup;
  }

  output = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  append_hex(" output_fd=", (uint64_t)(int64_t)output);
  if (output < 0) {
    append_text(" result=output-open-failed\n");
    goto cleanup;
  }

  /* Remove section-table references; only authenticated program segments are
   * reconstructed. The original signed input remains untouched on USB. */
  store32(elf + 0x20, 0);
  store16(elf + 0x2e, 0);
  store16(elf + 0x30, 0);
  store16(elf + 0x32, 0);
  if (write_all(output, elf, (size_t)phend) != 0) {
    append_text(" result=elf-header-write-failed\n");
    goto cleanup;
  }

  for (uint16_t index = 0; index < phnum; index++) {
    uint8_t *ph = elf + phoff + (size_t)index * phentsize;
    uint32_t file_offset = load32(ph + 0x04);
    uint32_t file_size = load32(ph + 0x10);
    append_hex(" segment_index=", index);
    append_hex(" segment_file_offset=", file_offset);
    append_hex(" segment_file_size=", file_size);

    if (file_size == 0) {
      continue;
    }
    if (file_size > MAX_SEGMENT_BYTES ||
        (uint64_t)file_offset + file_size > MAX_SEGMENT_BYTES) {
      append_text(" result=segment-bounds-rejected\n");
      goto cleanup;
    }

    uint8_t *segment = (uint8_t *)malloc(file_size);
    if (segment == NULL) {
      append_text(" result=segment-allocation-failed\n");
      goto cleanup;
    }
    memset(segment, 0, file_size);
    bool decrypted = read_decrypt_segment(input, index, 0, file_size, segment);
    append_hex(" segment_decrypt_ok=", decrypted ? 1U : 0U);
    if (!decrypted || lseek(output, file_offset, SEEK_SET) < 0 ||
        write_all(output, segment, file_size) != 0) {
      free(segment);
      append_text(" result=segment-decrypt-or-write-failed\n");
      goto cleanup;
    }
    free(segment);
  }

  append_text(" result=pass\n");
  result = 0;

cleanup:
  if (output >= 0) {
    close(output);
  }
  if (input >= 0) {
    close(input);
  }
  return result;
}

static void reset_log(void) {
  mkdir(OUTPUT_ROOT, 0755);
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd >= 0) {
    static const char header[] =
        "PS4 13.50 targeted secure-module decrypt v1\n";
    write(fd, header, sizeof(header) - 1);
    close(fd);
  }
  unlink(COMPLETE_PATH);
}

int _main(struct thread *td) {
  UNUSED(td);

  initKernel();
  initLibc();
  initPthread();

  mkdir(OUTPUT_ROOT, 0755);
  reset_log();
  append_text("01 runtime initialized\n");

  int jail_state = is_jailbroken();
  append_hex("02 is_jailbroken=", (uint64_t)jail_state);
  if (!jail_state) {
    int jail_result = jailbreak();
    append_hex("03 jailbreak_result=", (uint64_t)(int64_t)jail_result);
    if (jail_result < 0) {
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

  int patch_result = mmap_patch();
  append_hex("05 mmap_patch_result=", (uint64_t)(int64_t)patch_result);
  if (patch_result < 0) {
    append_text("STOP mmap SELF patch failed\n");
    return 0;
  }

  int failures = 0;
  failures += decrypt_self32(INPUT_ROOT "/bank-a-80010001.self",
                             OUTPUT_ROOT "/bank-a-80010001.elf", 98676U) != 0;
  failures += decrypt_self32(INPUT_ROOT "/bank-b-80010001.self",
                             OUTPUT_ROOT "/bank-b-80010001.elf", 98676U) != 0;
  failures += decrypt_self32(INPUT_ROOT "/bank-a-80010008.self",
                             OUTPUT_ROOT "/bank-a-80010008.elf", 88304U) != 0;
  failures += decrypt_self32(INPUT_ROOT "/bank-b-80010008.self",
                             OUTPUT_ROOT "/bank-b-80010008.elf", 88304U) != 0;
  append_hex("06 failures=", (uint64_t)failures);

  if (failures == 0) {
    int complete = open(COMPLETE_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (complete >= 0) {
      static const char marker[] = "PASS\n";
      write(complete, marker, sizeof(marker) - 1);
      close(complete);
    }
    append_text("PASS all four secure-module inputs decrypted\n");
  } else {
    append_text("FAIL one or more inputs were not decrypted\n");
  }
  return 0;
}
