// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors

// Marks the first byte of a raw x86-64 payload as executable code so Ghidra's
// normal analyzers can follow control flow and discover additional functions.

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class PrepareRawX64 extends GhidraScript {
    @Override
    public void run() throws Exception {
        Address entry = currentProgram.getMinAddress();
        if (entry == null) {
            throw new IllegalStateException("Raw program has no mapped memory");
        }

        disassemble(entry);
        Function function = getFunctionAt(entry);
        if (function == null) {
            function = createFunction(entry, "payload_entry");
        }
        if (function != null) {
            addEntryPoint(entry);
            println("Marked raw payload entry at " + entry);
        }
    }
}
