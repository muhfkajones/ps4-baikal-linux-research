// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors
// EXP-014 initial-load-only installer. Never run after HEN is active.

#error "Rejected after EXP-015 initial-load hardware shutdown; do not rebuild or execute"

#include <ps4.h>

#include "common.h"
#include "config_struct.h"
#include "kpayloads.h"
#include "path.h"

int _main(struct thread *td) {
  UNUSED(td);
  initKernel();
  initLibc();

  if (get_firmware() != 1350) {
    printf_notification("EXP-014 stopped: firmware is not 13.50");
    return -1;
  }

  jailbreak();

  if (file_exists(IS_INSTALLED_PATH)) {
    printf_notification("EXP-014 stopped: HEN is already active");
    return -1;
  }

  int patch_result = install_patches();
  if (patch_result != 0) {
    printf_notification("EXP-014 stopped: pre-install result 0x%08x", patch_result);
    return patch_result;
  }

  struct configuration config;
  memset(&config, 0, sizeof(config));
  config.skip_patches = 0;
  config.enable_plugins = 1;

  int result = install_payload(&config);
  printf_notification("EXP-014 initial hook install result: 0x%08x", result);
  return result;
}
