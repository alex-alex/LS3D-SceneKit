// Exports Ghidra decompiler output for selected addresses.
// Usage: analyzeHeadless <project_dir> <project> -process Game.exe \
//   -scriptPath tools/ghidra -postScript ExportFunctions.java <output> <addr>...

import java.io.File;
import java.io.PrintWriter;

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class ExportFunctions extends GhidraScript {
	@Override
	public void run() throws Exception {
		String[] args = getScriptArgs();
		if (args.length < 2) {
			printerr("Usage: ExportFunctions.java <output> <addr>...");
			return;
		}

		DecompInterface decompiler = new DecompInterface();
		decompiler.setOptions(new DecompileOptions());
		decompiler.openProgram(currentProgram);

		try (PrintWriter writer = new PrintWriter(new File(args[0]))) {
			for (int i = 1; i < args.length; i++) {
				Address address = toAddr(args[i]);
				Function function = getFunctionContaining(address);
				if (function == null) {
					writer.printf("## %s%nNo function found.%n%n", args[i]);
					continue;
				}

				writer.printf("## %s %s %s%n", args[i], function.getName(), function.getEntryPoint());
				DecompileResults results = decompiler.decompileFunction(function, 60, monitor);
				if (results.decompileCompleted()) {
					writer.println(results.getDecompiledFunction().getC());
				} else {
					writer.println(results.getErrorMessage());
				}
				writer.println();
			}
		}

		decompiler.dispose();
	}
}
