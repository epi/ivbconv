/*	VBXE output formats.

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

module vbxe;

import std.algorithm;
import std.array;

import dos;
import flashpack;
import freeimage;
import outputformat;

private class Vbxe : OutputFormat
{
	void parseOptions(ref string[] args) {}

	ubyte[] convert(string filename, const(ubyte)[] anticCaption, bool dither)
	{
		auto quantizedImage = preprocess(Image(filename), dither);
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

		app.put(_obx);
		app.appendBlock(Addr.caption, anticCaption);

		assert(quantizedImage.palette.length == 256);
		uint paletteSize = _packPixels ? 16 : 256;
		auto palette = new ubyte[3 * paletteSize];
		foreach (i, rgb; quantizedImage.palette[0 .. paletteSize])
		{
			palette[i * 3 + 0] = rgb.red;
			palette[i * 3 + 1] = rgb.green;
			palette[i * 3 + 2] = rgb.blue;
		}
		app.appendBlock(Addr.palette, palette);
		app.appendIniBlock(Addr.displayer_init_palette);

		auto pixels = quantizedImage.bits;

		void appendChunk(const(ubyte)[] outChunk)
		{
			auto packedChunk = pack(Addr.pixels, outChunk);
			if (outChunk.length < packedChunk.length)
			{
				app.appendBlock(Addr.pixels, outChunk);
				app.appendIniBlock(Addr.displayer_inc_bank);
			}
			else
			{
				app.appendBlock(Addr.packedPixels, packedChunk);
				app.appendIniBlock(Addr.displayer_unpack_inc_bank);
			}
		}

		if (_packPixels)
		{
			auto chunk16 = new ubyte[chunkSize];
			while (pixels.length)
			{
				auto chunk = pixels[0 .. min(chunkSize * 2, pixels.length)];
				foreach (i; 0 .. chunk.length / 2)
					chunk16[i] = ((chunk[i * 2] & 0xf) << 4) | (chunk[i * 2 + 1] & 0xf);
				appendChunk(chunk16);
				pixels = pixels[chunk.length .. $];
			}
		}
		else
		{
			while (pixels.length)
			{
				auto chunk = pixels[0 .. min(chunkSize, pixels.length)];
				appendChunk(chunk);
				pixels = pixels[chunk.length .. $];
			}
		}

		app.appendRunBlock(Addr.displayer_setup_interlace);

		return app.data;
	}

	static this()
	{
		OutputFormat.register("ivb", "xex", "VBXE 320x480i, 256 colors", &create!("ivb2.obx", 320, 480, 2, 1, false));
		OutputFormat.register("vb", "xex", "VBXE 320x240, 256 colors", &create!("vb.obx", 320, 240, 1, 1, false));
		OutputFormat.register("ivb16", "xex", "VBXE 640x480i, 256 colors", &create!("ivb216.obx", 640, 480, 1, 1, true));
		OutputFormat.register("vb16", "xex", "VBXE 640x240, 16 colors", &create!("vb16.obx", 640, 240, 1, 2, true));
	}

private:
	this(immutable(ubyte)[] obx, uint destWidth, uint destHeight, uint pixelWidth, uint pixelHeight, bool packPixels)
	{
		_obx = obx;
		_destWidth = destWidth;
		_destHeight = destHeight;
		_pixelWidth = pixelWidth;
		_pixelHeight = pixelHeight;
		_packPixels = packPixels;
	}

	private Image preprocess(Image image, bool dither)
	{
		if (image.bpp != 24)
			image = image.convertTo24Bits();

		uint newWidth;
		uint newHeight;
		if (image.height * _destWidth * _pixelWidth < image.width * _destHeight * _pixelHeight)
		{
			newWidth = _destWidth;
			newHeight = image.height * _destWidth * _pixelWidth / _pixelHeight / image.width;
		}
		else
		{
			newHeight = _destHeight;
			newWidth = image.width * _destHeight * _pixelHeight / _pixelWidth / image.height;
		}
		image = image.rescale(newWidth, newHeight, Image.Filter.bicubic);

		// position the image in the center of the screen. the image will be compressed,
		// so the black border will not occupy much additional space.
		enum black = 0;
		int left = (_destWidth - image.width) / 2;
		int top = (_destHeight - image.height) / 2;
		image = image.enlargeCanvas(left, top, _destWidth - left - image.width, _destHeight - top - image.height, black);

		// convert to 256 colors, make sure color #0 is black
		auto reservePalette = [ RGBQuad(0, 0, 0, 0) ];
		uint colors = _packPixels ? 16 : 256;
		image = dither
			? image.colorQuantize(Image.Quantize.xiaolinWu, colors, reservePalette, Image.Dither.floydSteinberg)
			: image.colorQuantize(Image.Quantize.neuQuant, colors, reservePalette, Image.Dither.none);

		image.flipVertical();

		return image;
	}

	static OutputFormat create(string obxname, uint destWidth, uint destHeight, uint pixelWidth, uint pixelHeight, bool packPixels)()
	{
		static obx = cast(immutable(ubyte)[]) import(obxname);
		return new Vbxe(obx, destWidth, destHeight, pixelWidth, pixelHeight, packPixels);
	}

	immutable(ubyte)[] _obx;
	uint _destWidth;
	uint _destHeight;
	uint _pixelWidth;
	uint _pixelHeight;
	uint _packPixels;
}
