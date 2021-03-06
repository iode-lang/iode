module iode.main;

import std.stdio;
import std.file;
import std.string;
import std.datetime;
import std.datetime.stopwatch : benchmark, StopWatch;
import std.conv;
import core.stdc.stdlib;
import std.process;
import iode.gen.codeGen;
import iode.gen.stash;
import iode.vm.vm;
import iode.vm.codes;
import colorize;

/* Example of bytecode exec
void main(string[] args) {
	int[] program = [
		to!int(ByteCode.PUSH), 3,
		to!int(ByteCode.PUSH), 4,
		to!int(ByteCode.ADD),
		to!int(ByteCode.PUSH), 5,
		to!int(ByteCode.SUB)
	];

	VM.vm(program);
}
*/

void main(string[] args) {
	string[] files;
	bool help = false;
	bool vrsn = false;
	bool output = false;

	foreach (string arg; args) {
		if (arg == "-h" || arg == "--help") {
			help = true;
		} else if (arg == "-v" || arg == "--version") {
			vrsn = true;
		} else {
			if (arg == "-o") {
				output = true;
			} else {
				files ~= arg;
			}
		}
	}

	if (help) {
		getHelp();
	}

	if (vrsn) {
		getVersion();
	}

	if (!help && !vrsn && files.length <= 1) {
		getHelp();
		exit(0);
	}

	if (files.length > 0) {
		removeAt(files, 0);
	}

	foreach (string filePath; files) {
		if (exists(filePath) != 0) {
			if (endsWith(filePath, ".iode")) {
				auto f = File(filePath);
			    scope(exit) f.close();
				string code = "";

			    foreach (str; f.byLine) {
					code ~= str;
					code ~= "\n";
				}

				if (code != "") {
					Stash.currentCode = code;
					Stash.currentFile = filePath;
					StopWatch sw;
					sw.start();
					string outCode = CodeGenerator.run(code);
					sw.stop();
					long msecs = sw.peek.total!"msecs";
					writeln("Execution: " ~ to!string(msecs) ~ "ms");

					if (output) {
						File js = File(filePath.replace(".iode", ".js"), "w");
						js.write(outCode);
						js.close();
					} else {
						File js = File(filePath.replace(".iode", ".js"), "w");
						js.write(outCode);
						js.close();
						writeln();
						auto nr = executeShell("node " ~ filePath.replace(".iode", ".js"));
						if (nr.status != 0) writeln("Failed to execute. Make sure node.js is properly installed.");
						else writeln(nr.output);
						remove(filePath.replace(".iode", ".js"));
					}
				}
			} else {
				writeln("File is not an .iode file.");
				exit(-1);
			}
		} else {
		  writeln("File not found.");
		  exit(-1);
		}
	}
}

void getHelp() {
	writeln();
	writeln(style(color("The Iode Programming Language", fg.cyan), mode.bold));
	writeln();
	writeln(color("Usage:", fg.yellow) ~ " iode <options> [files]");
	writeln();
	writeln(color("Options:", fg.yellow));
	writeln("\t-v, --version         returns Iode version");
	writeln("\t-h, --help            returns usage info");
	writeln("\t-o                    outputs javascript file");
	writeln();
	writeln(color("Examples:", fg.yellow));
	writeln("\tiode -v");
	writeln("\tiode test.iode test2.iode tests/test3.iode");
	writeln();
}

void getVersion() {
	writeln();
	writeln("Iode v1.0.0");
	writeln();
}

static void removeAt(T)(ref T[] arr, size_t index) {
    foreach (i, ref item; arr[index .. $ - 1]) {
        item = arr[i + 1];
	}

    arr = arr[0 .. $ - 1];
    arr.assumeSafeAppend();
}
