import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;

import java.io.File;
import java.io.PrintWriter;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

public class ExportBootXrefs extends GhidraScript {
    private static final String[] TERMS = {
        "sflash", "slb2", "secure loader", "secure_loader", "samu",
        "baikal", "boot control", "bootparam", "boot parameter",
        "emc", "syscon", "snvs", "authmgr", "signature"
    };

    private static boolean matches(String value) {
        String lower = value.toLowerCase(Locale.ROOT);
        for (String term : TERMS) {
            if (lower.contains(term)) {
                return true;
            }
        }
        return false;
    }

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

        Map<Address, Function> targetFunctions = new LinkedHashMap<>();
        try (PrintWriter out = new PrintWriter(output, "UTF-8")) {
            out.println("== Boot-chain keyword string references ==");
            DataIterator data = currentProgram.getListing().getDefinedData(true);
            while (data.hasNext() && !monitor.isCancelled()) {
                Data item = data.next();
                Object value = item.getValue();
                if (!(value instanceof String) || !matches(value.toString())) {
                    continue;
                }

                out.println();
                out.println("STRING " + item.getAddress() + " | " + value.toString()
                    .replace("\r", "\\r").replace("\n", "\\n"));
                ReferenceIterator refs = currentProgram.getReferenceManager()
                    .getReferencesTo(item.getAddress());
                int refCount = 0;
                while (refs.hasNext()) {
                    Reference ref = refs.next();
                    refCount++;
                    Function function = currentProgram.getFunctionManager()
                        .getFunctionContaining(ref.getFromAddress());
                    out.println("  XREF " + ref.getFromAddress() + " | "
                        + (function == null ? "<no function>" : function.getName(true)
                            + " @ " + function.getEntryPoint()));
                    if (function != null) {
                        targetFunctions.put(function.getEntryPoint(), function);
                    }
                }
                if (refCount == 0) {
                    out.println("  XREF <none>");
                }
            }

            out.println();
            out.println("== Decompiled referencing functions ==");
            out.println("Target function count: " + targetFunctions.size());
            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            if (!decompiler.openProgram(currentProgram)) {
                throw new IllegalStateException("Decompiler could not open program");
            }

            for (Function function : targetFunctions.values()) {
                if (monitor.isCancelled()) {
                    break;
                }
                out.println();
                out.println("/* " + function.getEntryPoint() + " " + function.getName(true) + " */");
                DecompileResults result = decompiler.decompileFunction(function, 60, monitor);
                if (result != null && result.decompileCompleted()
                    && result.getDecompiledFunction() != null) {
                    out.println(result.getDecompiledFunction().getC());
                } else {
                    out.println("/* DECOMPILATION FAILED */");
                }
            }
            decompiler.dispose();
        }

        println("Wrote " + output.getAbsolutePath());
    }
}
