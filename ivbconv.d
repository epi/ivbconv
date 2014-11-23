/*
	Convert images to .xex files suitable for viewing on
	VBXE-equipped Atari XL/XE machines

	Author: Adrian Matoga

	Poetic License:

	This work 'as-is' we provide.
	No warranty express or implied.
	We've done our best,
	to debug and test.
	Liability for damages denied.

	Permission is granted hereby,
	to copy, share, and modify.
	Use as is fit,
	free or for profit.
	These rights, on this notice, rely.
*/

import std.algorithm;
import std.array;
import std.ascii;
import std.getopt;
import std.path;
import std.parallelism;
import std.stdio;
import std.string;

import freeimage;
import outputformat;

ubyte[] toAnticChars(string str, uint limit = 40)
{
	auto app = appender!(ubyte[]);
	while (str.length && app.data.length < limit)
	{
		auto c = str[0];
		if (c >= 32 && c < 96)
			app.put(cast(ubyte) (c - 32));
		else if (c >= 96 && c < 128)
			app.put(c);
		else
			app.put('T');
		str = str[1 .. $];
	}
	if (app.data.length < limit)
		foreach (i; 0 .. limit - app.data.length)
			app.put(cast(ubyte) (' ' - 32));
	return app.data;
}

int main(string[] args)
{
	if (args.length <= 1)
	{
		stderr.writefln("%s: no input files", args[0]);
		return 2;
	}

	bool help;
	bool verbose;
	string destDir;
	string caption;
	string outputFormatName;
	bool forceOverwrite;
	bool dither;

	try
	{
		getopt(args,
			config.caseSensitive,
			config.bundling,
			config.passThrough,
			"h|help",      &help,
			"O|output-format", &outputFormatName,
			"t|dither",    &dither,
			"d",           &destDir,
			"v|verbose",   &verbose,
			"f|overwrite", &forceOverwrite,
			"c|caption",   &caption);

		if (help)
		{
			writeln("Convert pictures to Atari XL/XE executables for viewing on VBXE");
			writeln("Usage:");
			writefln(" %s [-d output_directory] [-O format] [-t] [-f] [-v] [-c caption] input_file...", args[0]);
			writeln("Output files have their extension replaced according to the output format.");
			writeln("Available output formats:");
			foreach (info; OutputFormat.getAllFormats())
				writefln("%-8s%-8s%-8s", info.name, info.extension, info.description);
			return 0;
		}

		auto of = OutputFormat.create(outputFormatName);
		of.parseOptions(args);
		getopt(args); // throw on any option-like argument that were not recognized

		foreach (arg; taskPool.parallel(args[1 .. $], 1))
		{
			auto destName = setExtension(arg, ".xex");
			if (destDir.length)
				destName = buildNormalizedPath(destDir, destName.baseName());
			if (std.file.exists(destName) && !forceOverwrite)
			{
				stderr.writeln("File `", destName, "' already exists, skipping");
				continue;
			}
			if (verbose)
			{
				writeln(arg, " -> ", destName);
				stdout.flush();
			}
			auto anticCaption = toAnticChars(caption !is null ? caption : arg.baseName());
			auto result = of.convert(arg, anticCaption, dither);
			std.file.write(destName, result);
		}
	}
	catch (Exception e)
	{
		stderr.writefln("%s: %s", args[0], e.msg);
		return 1;
	}

	return 0;
}
