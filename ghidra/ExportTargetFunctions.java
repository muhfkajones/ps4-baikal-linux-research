// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

import java.io.File;
import java.io.PrintWriter;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Exports the containing function, callers, disassembly, and decompilation for
 * a small set of addresses. Addresses may be function entries or hook sites.
 *
 * Script arguments:
 *   output-file address [address ...]
 */
public class ExportTargetFunctions extends GhidraScript {
    private Address parseTargetAddress(String value) {
        String normalized = value.trim().toLowerCase();
        if (normalized.startsWith("0x")) {
            normalized = normalized.substring(2);
        }
        return currentProgram.getAddressFactory().getDefaultAddressSpace()
            .getAddress(Long.parseUnsignedLong(normalized, 16));
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            throw new IllegalArgumentException(
                "Expected output-file followed by one or more hexadecimal addresses");
        }

        File output = new File(args[0]);
        File parent = output.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("Could not create output directory: " + parent);
        }

        Map<Address, Function> functions = new LinkedHashMap<>();
        Map<Address, Address> requested = new LinkedHashMap<>();
        for (int i = 1; i < args.length; i++) {
            Address address = parseTargetAddress(args[i]);
            Function function = currentProgram.getFunctionManager().getFunctionContaining(address);
            if (function == null) {
                disassemble(address);
                function = currentProgram.getFunctionManager().getFunctionAt(address);
                if (function == null) {
                    function = createFunction(address, null);
                }
            }
            if (function == null) {
                throw new IllegalStateException("No function at or containing " + address);
            }
            functions.put(function.getEntryPoint(), function);
            requested.put(address, function.getEntryPoint());
        }

        DecompInterface decompiler = new DecompInterface();
        decompiler.toggleCCode(true);
        decompiler.toggleSyntaxTree(true);
        if (!decompiler.openProgram(currentProgram)) {
            throw new IllegalStateException("Decompiler could not open program");
        }

        try (PrintWriter out = new PrintWriter(output, "UTF-8")) {
            out.println("Program: " + currentProgram.getName());
            out.println("Image base: " + currentProgram.getImageBase());
            out.println();
            out.println("== Requested addresses ==");
            for (Map.Entry<Address, Address> entry : requested.entrySet()) {
                out.println(entry.getKey() + " -> function " + entry.getValue());
            }

            for (Function function : functions.values()) {
                if (monitor.isCancelled()) {
                    break;
                }
                out.println();
                out.println("============================================================");
                out.println("FUNCTION " + function.getEntryPoint() + " " + function.getName(true));
                out.println("BODY " + function.getBody());
                out.println();
                out.println("CALLERS/REFERENCES");
                ReferenceIterator refs = currentProgram.getReferenceManager()
                    .getReferencesTo(function.getEntryPoint());
                while (refs.hasNext()) {
                    Reference ref = refs.next();
                    Function caller = currentProgram.getFunctionManager()
                        .getFunctionContaining(ref.getFromAddress());
                    out.println(ref.getFromAddress() + " " + ref.getReferenceType() + " "
                        + (caller == null ? "<no function>" : caller.getName(true) + " @ "
                            + caller.getEntryPoint()));
                }

                out.println();
                out.println("DISASSEMBLY");
                Instruction instruction = currentProgram.getListing()
                    .getInstructionAt(function.getEntryPoint());
                while (instruction != null && function.getBody().contains(instruction.getAddress())) {
                    out.println(instruction.getAddress() + "  " + instruction);
                    instruction = instruction.getNext();
                }

                out.println();
                out.println("DECOMPILATION");
                DecompileResults result = decompiler.decompileFunction(function, 120, monitor);
                if (result != null && result.decompileCompleted()
                    && result.getDecompiledFunction() != null) {
                    out.println(result.getDecompiledFunction().getC());
                } else {
                    out.println("/* DECOMPILATION FAILED */");
                }
            }
        } finally {
            decompiler.dispose();
        }

        println("Wrote " + output.getAbsolutePath());
    }
}
