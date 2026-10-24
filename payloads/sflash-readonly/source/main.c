#include "ps4.h"

#ifndef LOG_PATH
#define LOG_PATH "/data/payloads/sflash-dumper-readonly.log"
#endif
#ifndef INPUT_PATH
#define INPUT_PATH "/dev/sflash0"
#endif
#define USB_ROOT "/mnt/usb0"
#define OUTPUT_DIR "/mnt/usb0/PS4"
#define OUTPUT_FW_DIR "/mnt/usb0/PS4/13.50"
#ifndef OUTPUT_PATH
#define OUTPUT_PATH "/mnt/usb0/PS4/13.50/sflash0.bin"
#endif
#ifndef COMPLETE_PATH
#define COMPLETE_PATH "/mnt/usb0/PS4/13.50/sflash0.complete"
#endif
#ifndef LOG_HEADER
#define LOG_HEADER "PS4 13.50 read-only sflash dumper v1\n"
#endif
#ifndef COMPLETE_TEXT
#define COMPLETE_TEXT "sflash0 read-only dump complete\n"
#endif
#define CHUNK_SIZE 0x4000ULL
#define MIN_MEDIA_SIZE 0x00100000ULL
#define MAX_MEDIA_SIZE 0x08000000ULL

/* FreeBSD DIOCGMEDIASIZE = _IOR('d', 129, off_t). */
#define DIOCGMEDIASIZE 0x40086481UL
/* FreeBSD DIOCGSECTORSIZE = _IOR('d', 128, unsigned int). */
#define DIOCGSECTORSIZE 0x40046480UL

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
    line[cursor++] = digits[(value >> shift) & 0xF];
  }
  line[cursor++] = '\n';
  line[cursor] = '\0';
  append_text(line);
}

static void reset_log(void) {
  int fd = open(LOG_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (fd >= 0) {
    static const char header[] = LOG_HEADER;
    write(fd, header, sizeof(header) - 1);
    close(fd);
  }
}

static int write_all(int fd, const uint8_t *buffer, size_t amount) {
  size_t done = 0;
  while (done < amount) {
    ssize_t result = write(fd, buffer + done, amount - done);
    if (result <= 0) {
      return -1;
    }
    done += (size_t)result;
  }
  return 0;
}

static int read_all(int fd, uint8_t *buffer, size_t amount) {
  size_t done = 0;
  while (done < amount) {
    ssize_t result = read(fd, buffer + done, amount - done);
    if (result <= 0) {
      return -1;
    }
    done += (size_t)result;
  }
  return 0;
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

  int input = open(INPUT_PATH, O_RDONLY, 0);
  append_hex("07 input_fd=", (uint64_t)(int64_t)input);
  if (input < 0) {
    append_text("STOP cannot open /dev/sflash0 read-only\n");
    return 0;
  }

  off_t media_size = 0;
  int media_result = ioctl(input, DIOCGMEDIASIZE, &media_size);
  append_hex("08 media_ioctl_result=", (uint64_t)(int64_t)media_result);
  append_hex("09 media_size=", (uint64_t)media_size);
  if (media_result != 0 || media_size < (off_t)MIN_MEDIA_SIZE ||
      media_size > (off_t)MAX_MEDIA_SIZE || ((uint64_t)media_size & 0x1FF) != 0) {
    append_text("STOP invalid serial-flash media size\n");
    close(input);
    return 0;
  }

  unsigned int sector_size = 0;
  int sector_result = ioctl(input, DIOCGSECTORSIZE, &sector_size);
  append_hex("10 sector_ioctl_result=", (uint64_t)(int64_t)sector_result);
  append_hex("11 sector_size=", sector_size);
  if (sector_result != 0 || sector_size == 0 || sector_size > CHUNK_SIZE ||
      (CHUNK_SIZE % sector_size) != 0) {
    append_text("STOP invalid serial-flash sector size\n");
    close(input);
    return 0;
  }

  int probe = open(USB_ROOT "/.sflash-dumper-probe",
                   O_WRONLY | O_CREAT | O_TRUNC, 0777);
  append_hex("12 usb_probe_fd=", (uint64_t)(int64_t)probe);
  if (probe < 0) {
    append_text("STOP usb0 is not writable\n");
    close(input);
    return 0;
  }
  static const char probe_data[] = "ok\n";
  write(probe, probe_data, sizeof(probe_data) - 1);
  close(probe);
  unlink(USB_ROOT "/.sflash-dumper-probe");

  mkdir(OUTPUT_DIR, 0777);
  mkdir(OUTPUT_FW_DIR, 0777);
  unlink(COMPLETE_PATH);

  /*
   * Payload Guest may impose a runtime limit.  Preserve any complete chunks
   * already copied and continue from the exact existing output length.
   */
  int output = open(OUTPUT_PATH, O_WRONLY | O_CREAT | O_APPEND, 0777);
  append_hex("13 output_fd=", (uint64_t)(int64_t)output);
  if (output < 0) {
    append_text("STOP output file open failed\n");
    close(input);
    return 0;
  }

  uint8_t *buffer = mmap(NULL, CHUNK_SIZE, PROT_READ | PROT_WRITE,
                         MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
  if (buffer == MAP_FAILED) {
    append_text("STOP memory allocation failed\n");
    close(output);
    close(input);
    return 0;
  }

  off_t output_size = lseek(output, 0, SEEK_END);
  append_hex("14 resume_offset=", (uint64_t)output_size);
  if (output_size < 0 || (uint64_t)output_size > (uint64_t)media_size ||
      ((uint64_t)output_size % CHUNK_SIZE) != 0) {
    append_text("STOP existing output size is invalid for safe resume\n");
    munmap(buffer, CHUNK_SIZE);
    close(output);
    close(input);
    return 0;
  }

  if (lseek(input, output_size, SEEK_SET) != output_size) {
    append_text("STOP could not seek serial flash to resume offset\n");
    munmap(buffer, CHUNK_SIZE);
    close(output);
    close(input);
    return 0;
  }

  uint64_t position = (uint64_t)output_size;
  uint64_t chunk_index = 0;
  while (position < (uint64_t)media_size) {
    uint64_t remaining = (uint64_t)media_size - position;
    size_t amount = remaining < CHUNK_SIZE ? (size_t)remaining : (size_t)CHUNK_SIZE;
    if (read_all(input, buffer, amount) != 0) {
      append_hex("STOP serial-flash read offset=", position);
      munmap(buffer, CHUNK_SIZE);
      close(output);
      close(input);
      return 0;
    }
    if (write_all(output, buffer, amount) != 0) {
      append_hex("STOP usb write offset=", position);
      munmap(buffer, CHUNK_SIZE);
      close(output);
      close(input);
      return 0;
    }
    position += amount;
    chunk_index++;
    if ((chunk_index & 0xFF) == 0) {
      append_hex("progress_bytes=", position);
    }
  }

  munmap(buffer, CHUNK_SIZE);
  close(output);
  close(input);

  int complete = open(COMPLETE_PATH, O_WRONLY | O_CREAT | O_TRUNC, 0777);
  if (complete >= 0) {
    static const char complete_data[] = COMPLETE_TEXT;
    write(complete, complete_data, sizeof(complete_data) - 1);
    close(complete);
  }
  append_hex("15 bytes_written=", position);
  append_text("PASS sflash0 read-only dump complete\n");
  return 0;
}
