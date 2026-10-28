// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors
// EXP-014 volatile installer: replaces only the in-memory HEN kernel payload.

#error "REJECTED: live HEN payload replacement powered off the reference console; do not rebuild or execute"

#include <ps4.h>

#include "config_struct.h"
#include "kpayloads.h"

int _main(struct thread *td) {
  UNUSED(td);
  initKernel();
  initLibc();

  if (get_firmware() != 1350) {
    printf_notification("EXP-014 stopped: firmware is not 13.50");
    return -1;
  }

  jailbreak();

  struct configuration config;
  memset(&config, 0, sizeof(config));
  config.skip_patches = 1;
  config.enable_plugins = 1;

  int result = install_payload(&config);
  printf_notification("EXP-014 volatile hook install result: 0x%08x", result);
  return result;
}
