// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PS4 Baikal Linux Research contributors

import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;

import java.io.File;
import java.io.PrintWriter;

public class ExportKernelInventory extends GhidraScript {
    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected one output-file argument");
        }

        File output = new File(args[0]);
        File parent = output.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) {
            throw new IllegalStateException("Could not create output directory: " + parent);
        }

        try (PrintWriter out = new PrintWriter(output, "UTF-8")) {
            out.println("Program: " + currentProgram.getName());
            out.println("Format: " + currentProgram.getExecutableFormat());
            out.println("Language: " + currentProgram.getLanguageID());
            out.println("Compiler: " + currentProgram.getCompilerSpec().getCompilerSpecID());
            out.println("Image base: " + currentProgram.getImageBase());
            out.println("Min address: " + currentProgram.getMinAddress());
            out.println("Max address: " + currentProgram.getMaxAddress());
            out.println("MD5: " + currentProgram.getExecutableMD5());
            out.println("SHA256: " + currentProgram.getExecutableSHA256());
            out.println();

            out.println("== Memory blocks ==");
            for (MemoryBlock block : currentProgram.getMemory().getBlocks()) {
                out.println(block.getName() + " | " + block.getStart() + "-" + block.getEnd()
                    + " | size=" + block.getSize()
                    + " | R=" + block.isRead() + " W=" + block.isWrite() + " X=" + block.isExecute());
            }
            out.println();

            out.println("== External symbols ==");
            SymbolIterator symbols = currentProgram.getSymbolTable().getExternalSymbols();
            while (symbols.hasNext() && !monitor.isCancelled()) {
                Symbol symbol = symbols.next();
                out.println(symbol.getName(true));
            }
            out.println();

            int functionCount = 0;
            long functionBytes = 0;
            out.println("== Functions ==");
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            while (functions.hasNext() && !monitor.isCancelled()) {
                Function function = functions.next();
                long size = function.getBody().getNumAddresses();
                functionCount++;
                functionBytes += size;
                out.println(function.getEntryPoint() + " | " + function.getName(true) + " | size=" + size);
            }
            out.println();
            out.println("Function count: " + functionCount);
            out.println("Function bytes: " + functionBytes);
            out.println();

            int stringCount = 0;
            out.println("== Defined strings ==");
            DataIterator data = currentProgram.getListing().getDefinedData(true);
            while (data.hasNext() && !monitor.isCancelled()) {
                Data item = data.next();
                Object value = item.getValue();
                if (value instanceof String) {
                    stringCount++;
                    out.println(item.getAddress() + " | " + value.toString()
                        .replace("\r", "\\r").replace("\n", "\\n"));
                }
            }
            out.println();
            out.println("String count: " + stringCount);
        }

        println("Wrote " + output.getAbsolutePath());
    }
}
