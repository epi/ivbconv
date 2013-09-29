module bmptoasm;

import std.algorithm;
import std.exception;
import std.range;
import std.stdio;

align(1) struct BITMAPFILEHEADER
{
align(1):
	char[2] signature;
	uint fileSize;
	short reserved1;
	ushort reserved2;
	uint fileOffset;
}

static assert(BITMAPFILEHEADER.sizeof == 14);

align(1) struct BITMAPINFOHEADER
{
align(1):
	uint biSize;
	uint biWidth;
	uint biHeight;
	ushort biPlanes;
	ushort biBitCount;
	uint biCompression;
	uint biSizeImage;
	uint biXPelsPerMeter;
	uint biYPelsPerMeter;
	uint biClrUsed;
	uint biClrImportant;
}

static assert(BITMAPINFOHEADER.sizeof == 40);

enum BI_RGB = 0;

void main(string[] args)
{
	enforce(args.length == 2);
	auto bmpfile = File(args[1], "rb");
	BITMAPFILEHEADER bmfh;
	bmpfile.rawRead((&bmfh)[0 .. 1]);
	enforce(bmfh.signature == [ 'B', 'M' ]);
	BITMAPINFOHEADER bmih;
	bmpfile.rawRead((&bmih)[0 .. 1]);
	enforce(bmih.biSize == 40);
	enforce(bmih.biPlanes == 1);
	enforce(bmih.biCompression == BI_RGB);
	enforce(bmih.biBitCount == 8, "only 8bpp pics supported");
	enforce(bmih.biWidth == 320, "pic width must be 320");
	enforce(bmih.biHeight <= 480, "pic height must not be higher than 480");
	enforce(bmih.biClrUsed <= 256);
	ubyte[1024] palette;
	enforce(bmpfile.rawRead(palette).length == 1024, "EOF");
	writeln("\torg $7000");
	foreach (i; iota(0, palette.length, 4))
	{
		writefln("\tdta $%02x,$%02x,$%02x",
			palette[i + 2], palette[i + 1], palette[i]);
	}
	writeln("\tert *<>$7300");
	writeln("\tini $5803");
	auto rowsize = (bmih.biBitCount * bmih.biWidth + 31) / 32 * 4;
	enforce(rowsize == 320);
	ubyte[] pixels = new ubyte[rowsize * bmih.biHeight];
	foreach (row; 0 .. bmih.biHeight)
	{
		auto i = (bmih.biHeight - row - 1) * rowsize;
		enforce(bmpfile.rawRead(pixels[i .. i + rowsize]).length == rowsize, "EOF");
	}
	foreach (offs; iota(0, pixels.length, 4096))
	{
		auto c = pixels[offs .. min(offs + 4096, pixels.length)];
		writeln("\n\torg $8000");
		foreach (i; iota(0, c.length, 16))
		{
			auto j = i + 16 > c.length ? c.length : i + 16;
			writefln("\tdta %($%02x%|,%)", c[i .. j]);
		}
		writeln("\tert *>$9000");
		writeln("\tini $5806");		
	}
}
