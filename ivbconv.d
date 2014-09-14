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

private void appendBlock(ref Appender!(ubyte[]) app, uint address, ubyte[] data)
{
	assert(address + data.length < 0x10000);
	app.put(cast(ubyte) address);
	app.put(cast(ubyte) (address >> 8));
	app.put(cast(ubyte) (address + data.length - 1));
	app.put(cast(ubyte) ((address + data.length - 1) >> 8));
	app.put(data);
}

private void appendIniBlock(ref Appender!(ubyte[]) app, uint address)
{
	appendBlock(app, 0x2e2, [ cast(ubyte) address, (address >> 8) & 0xff ]);
}

private void appendRunBlock(ref Appender!(ubyte[]) app, uint address)
{
	appendBlock(app, 0x2e0, [ cast(ubyte) address, (address >> 8) & 0xff ]);
}

private struct Item
{
	bool special;
	ubyte[] data;
}

private Item[] toItems(uint addr, ubyte[] data)
{
	auto app = appender!(Item[]);

	void addItem(bool special, ubyte[] bytes ...)
	{
		app.put(Item(special, bytes.dup));
	}

	void addRaw(ubyte b)					{ addItem(false, b); }
	void setAddr(uint addr, ubyte first)	{ addItem(true, 0, (addr - 0x80) & 0xff, ((addr - 0x80) >>> 8) & 0xff, first); }
	void addDup(uint count)					{ addItem(true, 1, cast(ubyte) (count - 2)); }
	void addCopy(uint dist, bool three)		{ addItem(true, cast(ubyte) ((0x80 - dist) << 1) | three); }

	setAddr(addr, data[0]);

	int[uint] seqs;
	uint srcLength = cast(uint) data.length;
	
	struct SeqSearchResult { int dist; bool three; }

	SeqSearchResult sequencesAt(int i)
	{
		if (i <= srcLength - 2)
		{
			uint duple = data[i] | (data[i + 1] << 8);
			int dist;
			bool three;
			if (i <= srcLength - 3)
			{
				uint triple = 0x10000000U | duple | (data[i + 2] << 16);
				dist = i - seqs.get(triple, i);
				seqs[triple] = i;
			}
			if (!dist || dist > 127)
				dist = i - seqs.get(duple, i);
			else
				three = true;
			seqs[duple]	= i;
			assert(dist >= 0, "WTF?");
			return SeqSearchResult(dist, three);
		}
		return SeqSearchResult(0, false);
	}

	sequencesAt(0);
	for (int i = 1; i < srcLength; ++i)
	{
		// >=3 duplicate bytes
		uint cnt = min(256, srcLength - i);
		ubyte prevb = data[i - 1];
		foreach (int j; i .. i + cnt)
		{
			if (data[j] != prevb)
			{
				cnt = j - i;
				break;
			}
		}
		if (cnt > 3)
		{
			addDup(cnt);
			i += cnt - 1;
			sequencesAt(i - 3);
			sequencesAt(i - 2);
			sequencesAt(i - 1);
			sequencesAt(i);
			continue;
		}

		// repeated sequence of 2 or 3 bytes
		auto s = sequencesAt(i);
		if (s.dist && s.dist <= 127)
		{
			addCopy(s.dist, s.three);
			sequencesAt(++i);
			if (s.three)
				sequencesAt(++i);
			continue;
		}
	
		// nothing to squeeze
		addRaw(data[i]);
	}

	// mark end of packed data
	addItem(true, 1, 0);

	return app.data;
}

private ubyte[] toBytes(Item[] items)
{
	auto app = appender!(ubyte[]);
	immutable itemsLength = items.length;
	for (size_t i = 0; i < itemsLength; i += 64)
	{
		ubyte outerFlags;
		auto appOuter = appender!(ubyte[]);
		auto outerChunk = items[i .. min(i + 64, itemsLength)];
		immutable outerChunkLength = outerChunk.length;
		for (size_t j = 0; j < outerChunkLength; j += 8)
		{
			ubyte innerFlags;
			auto innerChunk = outerChunk[j .. min(j + 8, outerChunkLength)];
			foreach (k; 0 .. innerChunk.length)
				if (innerChunk[k].special)
					innerFlags |= (0x80 >>> k);
			if (innerFlags)
			{
				appOuter.put(innerFlags);
				outerFlags |= (0x80 >>> (j / 8));
			}
			foreach (k; 0 .. innerChunk.length)
				appOuter.put(innerChunk[k].data);
		}
		app.put(outerFlags);
		app.put(appOuter.data);
	}
	return app.data;
}

private ubyte[] pack(uint addr, ubyte[] data)
{
	return toItems(addr, data).toBytes();
}

private Image preprocess(Image image)
{
	if (image.bpp != 24)
		image = image.convertTo24Bits();

	uint newWidth;
	uint newHeight;
	if (image.height * 640 < image.width * 480)
	{
		newWidth = 320;
		newHeight = image.height * 640 / image.width;
	}
	else
	{
		newHeight = 480;
		newWidth = image.width * 240 / image.height;
	}
	image = image.rescale(newWidth, newHeight, Image.Filter.bicubic);

	// position the image in the center of the screen. the image will be compressed,
	// so the black border will not occupy much additional space.
	enum black = 0;
	int left = (320 - image.width) / 2;
	int top = (480 - image.height) / 2;
	image = image.enlargeCanvas(left, top, 320 - left - image.width, 0, black);

	// convert to 256 colors, make sure color #0 is black
	auto reservePalette = [ RGBQuad(0, 0, 0, 0) ];
	image = image.colorQuantize(Image.Quantize.neuQuant, 256, reservePalette);

	image.flipVertical();

	return image;
}

private ubyte[] convertImage(string filename, string caption = null)
{
	auto image = Image(filename).preprocess();

	auto app = Appender!(ubyte[])();

	enum Addr
	{
		displayer = 0x3800,
		displayer_init1 = displayer,
		displayer_init_palette = displayer + 3,
		displayer_unpack_inc_bank = displayer + 6,
		displayer_inc_bank = displayer + 9,
		displayer_setup_interlace = displayer + 12,
		displayer_display_pic = displayer + 15,
		caption = 0x3cd8,
		palette = 0x3d00,
		pixels = 0x8000,
		packedPixels = 0x9000,
	}
	enum chunkSize = 0x1000;

	static ivb2 = cast(immutable(ubyte)[]) import("ivb2.obx");
	app.put(ivb2);

	app.appendBlock(Addr.caption,
		toAnticChars(caption !is null ? caption : filename.baseName()));

	assert(image.palette.length == 256);
	auto palette = new ubyte[3 * 256];
	foreach (i, rgb; image.palette)
	{
		palette[i * 3 + 0] = rgb.red;
		palette[i * 3 + 1] = rgb.green;
		palette[i * 3 + 2] = rgb.blue;
	}
	app.appendBlock(Addr.palette, palette);
	app.appendIniBlock(Addr.displayer_init_palette);

	auto pixels = image.bits;

	while (pixels.length)
	{
		auto chunk = pixels[0 .. min(chunkSize, pixels.length)];
		auto packedChunk = pack(Addr.pixels, chunk);
		if (chunk.length < packedChunk.length)
		{
			app.appendBlock(Addr.pixels, chunk);
			app.appendIniBlock(Addr.displayer_inc_bank);
		}
		else
		{
			app.appendBlock(Addr.packedPixels, packedChunk);
			app.appendIniBlock(Addr.displayer_unpack_inc_bank);
		}
		pixels = pixels[chunk.length .. $];
	}

	app.appendRunBlock(Addr.displayer_setup_interlace);

	return app.data;
}

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
	bool forceOverwrite;

	try
	{
		getopt(args,
			"h|help",      &help,
			"d",           &destDir,
			"v|verbose",   &verbose,
			"f|overwrite", &forceOverwrite,
			"c|caption",   &caption);
	}
	catch (Exception e)
	{
		stderr.writefln("%s: %s", args[0], e.msg);
		return 2;
	}

	if (help)
	{
		writeln("Convert pictures to Atari XL/XE executables for viewing on VBXE");
		writeln("Usage:");
		writefln(" %s [-d output_directory] [-f] [-v] [-c caption] input_file...", args[0]);
		writeln("Output files have their extension replaced with .xex");
		return 0;
	}

	try
	{
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
			auto result = convertImage(arg, caption);
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

