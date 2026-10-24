import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;

import java.io.File;
import java.io.PrintWriter;

public class ExportAnalysis extends GhidraScript {
    private static String safeName(String value) {
        return value.replaceAll("[^A-Za-z0-9._-]", "_");
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1 || args.length > 2) {
            throw new IllegalArgumentException("Expected output-directory and optional report-prefix arguments");
        }

        File outputDirectory = new File(args[0]);
        if (!outputDirectory.exists() && !outputDirectory.mkdirs()) {
            throw new IllegalStateException("Could not create output directory: " + outputDirectory);
        }

        String baseName = args.length == 2
            ? safeName(args[1]) + "__" + safeName(currentProgram.getName())
            : safeName(currentProgram.getName());
        File reportFile = new File(outputDirectory, baseName + "-analysis.txt");
        File decompileFile = new File(outputDirectory, baseName + "-decompiled.c");

        try (PrintWriter report = new PrintWriter(reportFile, "UTF-8");
             PrintWriter decompiled = new PrintWriter(decompileFile, "UTF-8")) {
            report.println("Program: " + currentProgram.getName());
            report.println("Executable format: " + currentProgram.getExecutableFormat());
            report.println("Language: " + currentProgram.getLanguageID());
            report.println("Compiler: " + currentProgram.getCompilerSpec().getCompilerSpecID());
            report.println("Image base: " + currentProgram.getImageBase());
            report.println();

            report.println("== External/imported symbols ==");
            SymbolIterator symbols = currentProgram.getSymbolTable().getExternalSymbols();
            while (symbols.hasNext() && !monitor.isCancelled()) {
                Symbol symbol = symbols.next();
                report.println(symbol.getName(true));
            }
            report.println();

            report.println("== Defined strings ==");
            DataIterator dataIterator = currentProgram.getListing().getDefinedData(true);
            while (dataIterator.hasNext() && !monitor.isCancelled()) {
                Data data = dataIterator.next();
                Object value = data.getValue();
                if (value instanceof String) {
                    report.println(data.getAddress() + " | " + value.toString().replace("\n", "\\n"));
                }
            }
            report.println();

            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            if (!decompiler.openProgram(currentProgram)) {
                throw new IllegalStateException("Decompiler could not open program");
            }

            report.println("== Functions ==");
            FunctionIterator functions = currentProgram.getFunctionManager().getFunctions(true);
            int functionCount = 0;
            int decompiledCount = 0;
            while (functions.hasNext() && !monitor.isCancelled()) {
                Function function = functions.next();
                functionCount++;
                report.print(function.getEntryPoint() + " | " + function.getName(true));
                report.print(" | size=" + function.getBody().getNumAddresses());

                int callers = 0;
                ReferenceIterator refs = currentProgram.getReferenceManager()
                    .getReferencesTo(function.getEntryPoint());
                while (refs.hasNext()) {
                    Reference ref = refs.next();
                    if (ref.getReferenceType().isCall()) {
                        callers++;
                    }
                }
                report.println(" | callers=" + callers);

                DecompileResults result = decompiler.decompileFunction(function, 20, monitor);
                if (result != null && result.decompileCompleted() &&
                    result.getDecompiledFunction() != null) {
                    decompiled.println("\n/* " + function.getEntryPoint() + " " +
                        function.getName(true) + " */");
                    decompiled.println(result.getDecompiledFunction().getC());
                    decompiledCount++;
                } else {
                    decompiled.println("\n/* DECOMPILATION FAILED: " + function.getEntryPoint() +
                        " " + function.getName(true) + " */");
                }
            }

            report.println();
            report.println("Function count: " + functionCount);
            report.println("Successfully decompiled: " + decompiledCount);
            decompiler.dispose();
        }

        println("Wrote " + reportFile.getAbsolutePath());
        println("Wrote " + decompileFile.getAbsolutePath());
    }
}
