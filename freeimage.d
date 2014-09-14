/*	FreeImage library bindings + refcounted RAII wrapper.

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

module freeimage;

import std.conv;
import std.exception;
import std.string;
import std.c.stdlib;

private
{
	struct Bitmap {}

	extern(Windows) void FreeImage_Initialise(int load_local_plugins_only = 0);
	extern(Windows) void FreeImage_DeInitialise();

	extern(Windows) const(char)* FreeImage_GetVersion();
	extern(Windows) const(char)* FreeImage_GetCopyrightMessage();

	extern(Windows) int FreeImage_FIFSupportsReading(Image.Format fif);

	extern(Windows) void FreeImage_Unload(Bitmap* dib);
	extern(Windows) Bitmap* FreeImage_Load(Image.Format fif, const(char)* filename, int flags = 0);
	extern(Windows) int FreeImage_Save(Image.Format fif, Bitmap* dib, const(char)* filename, int flags = 0);
	extern(Windows) Image.Format FreeImage_GetFileType(const(char)* filename, int size = 0);
	extern(Windows) Image.Format FreeImage_GetFIFFromFilename(const char *filename);

	extern(Windows) uint FreeImage_GetBPP(Bitmap* dib);
	extern(Windows) uint FreeImage_GetWidth(Bitmap* dib);
	extern(Windows) uint FreeImage_GetHeight(Bitmap* dib);
	extern(Windows) uint FreeImage_GetPitch(Bitmap* dib);

	extern(Windows) Bitmap* FreeImage_Rescale(Bitmap* dib, int dst_width, int dst_height, Image.Filter filter);
	extern(Windows) int FreeImage_FlipVertical(Bitmap* dib);
	extern(Windows) Bitmap* FreeImage_ConvertTo24Bits(Bitmap* dib);
	extern(Windows) Bitmap* FreeImage_ConvertTo32Bits(Bitmap* dib);
	extern(Windows) Bitmap* FreeImage_ColorQuantize(Bitmap* dib, Image.Quantize quantize);
	extern(Windows) Bitmap* FreeImage_ColorQuantizeEx(Bitmap* dib, Image.Quantize quantize = Image.Quantize.xiaolinWu,
		int PaletteSize = 256, 	int ReserveSize = 0, RGBQuad* ReservePalette = null);

	extern(Windows) Bitmap* FreeImage_EnlargeCanvas(Bitmap* src, int left, int top, int right, int bottom, const(void)* color, int options);

	extern(Windows) RGBQuad* FreeImage_GetPalette(Bitmap* dib);
	extern(Windows) ubyte* FreeImage_GetBits(Bitmap* dib);
}

__gshared static this()
{
	FreeImage_Initialise(0);
}

__gshared static ~this()
{
	FreeImage_DeInitialise();
}

struct RGBQuad
{
	version(BigEndian)
	{
		ubyte red;
		ubyte green;
		ubyte blue;
	}
	else version(LittleEndian)
	{
		ubyte blue;
		ubyte green;
		ubyte red;
	}
	else static assert(0);

	ubyte alpha;
}

struct Image
{
	enum Format
	{
		unknown = -1,
		bmp = 0,
		ico = 1,
		jpeg = 2,
		jng = 3,
		koala = 4,
		lbm = 5,
		iff = lbm,
		mng = 6,
		pbm = 7,
		pbmraw = 8,
		pcd = 9,
		pcx = 10,
		pgm = 11,
		pgmraw = 12,
		png = 13,
		ppm = 14,
		ppmraw = 15,
		ras = 16,
		targa = 17,
		tiff = 18,
		wbmp = 19,
		psd = 20,
		cut = 21,
		xbm = 22,
		xpm = 23,
		dds = 24,
		gif = 25,
		hdr = 26,
		faxg3 = 27,
		sgi = 28,
		exr = 29,
		j2k = 30,
		jp2 = 31,
		pfm = 32,
		pict = 33,
		raw = 34
	}

	enum Filter
	{
		box = 0,
		bicubic = 1,
		bilinear = 2,
		bSpline = 3,
		catmullRoom = 4,
		lanczos3 = 5
	}

	enum Quantize
	{
		xiaolinWu = 0,
		neuQuant = 1,
	}

	enum JPEG_EXIFROTATE = 0x0008;

	private struct Impl
	{
		Bitmap* bitmap;
		uint refs = uint.max / 2;
	}

	private Impl *_impl;

	private this(Bitmap* bitmap, uint refs = 1)
	{
		assert(!_impl);
		_impl = cast(Impl*) enforce(malloc(Impl.sizeof), "Out of memory");
		_impl.bitmap = bitmap;
		_impl.refs = refs;
	}

	this(string filename)
	{
		Bitmap* bitmap;
		const(char)* filenamez = toStringz(filename);
		Format fif = FreeImage_GetFileType(filenamez, 0);
		if (fif == Format.unknown)
			fif = FreeImage_GetFIFFromFilename(filenamez);
		if (fif != Format.unknown && FreeImage_FIFSupportsReading(fif))
			bitmap = FreeImage_Load(fif, filenamez, JPEG_EXIFROTATE);
		this(enforce(bitmap, text("Could not load image: ", filename)));
	}

	~this()
	{
		if (!_impl) return;
		assert(_impl.refs);
		if (--_impl.refs == 0)
		{
			FreeImage_Unload(_impl.bitmap);
			_impl.bitmap = null;
			free(_impl);
			_impl = null;
		}
	}

	this(this)
	{
		if (!_impl) return;
		assert(_impl.refs);
		++_impl.refs;
	}

	void opAssign(Image rhs)
	{
		import std.algorithm : swap;
		swap(this, rhs);
	}

	void save(Format format, string filename)
	{
		enforce(FreeImage_Save(format, _impl.bitmap, toStringz(filename), 0));
	}

	@property uint bpp()
	{
		return FreeImage_GetBPP(_impl.bitmap);
	}

	@property uint width()
	{
		return FreeImage_GetWidth(_impl.bitmap);
	}

	@property uint height()
	{
		return FreeImage_GetHeight(_impl.bitmap);
	}

	@property uint pitch()
	{
		return FreeImage_GetPitch(_impl.bitmap);
	}

	Image convertTo24Bits()
	{
		return Image(enforce(FreeImage_ConvertTo24Bits(_impl.bitmap),
			"Conversion to 24 bits failed"));
	}

	Image colorQuantize(Quantize method)
	{
		return Image(enforce(FreeImage_ColorQuantize(_impl.bitmap, method),
			"Quantization failed"));
	}

	Image colorQuantize(Quantize method, int paletteSize, RGBQuad[] reservePalette = null)
	in
	{
		assert(paletteSize >= reservePalette.length);
		assert(paletteSize > 2);
		assert(paletteSize <= 256);
		assert(reservePalette.length <= 256);
	}
	body
	{
		return Image(enforce(FreeImage_ColorQuantizeEx(_impl.bitmap, method,
			paletteSize, cast(int) reservePalette.length, reservePalette.ptr),
			"Quantization failed"));
	}

	Image rescale(uint dstWidth, uint dstHeight, Filter filter)
	{
		return Image(enforce(FreeImage_Rescale(_impl.bitmap, dstWidth, dstHeight, filter),
			"Rescaling failed"));
	}

	Image enlargeCanvas(T)(int left, int top, int right, int bottom, T fillColor)
		if (fillColor.sizeof >= 4)
	{
		return Image(enforce(FreeImage_EnlargeCanvas(_impl.bitmap,
			left, top, right, bottom, &fillColor, 0)));
	}

	void flipVertical()
	{
		enforce(FreeImage_FlipVertical(_impl.bitmap));
	}

	@property const(RGBQuad)[] palette()
	{
		if (this.bpp > 8)
			return null;
		return FreeImage_GetPalette(_impl.bitmap)[0 .. 1 << this.bpp];
	}

	@property ubyte[] bits()
	{
		return enforce(FreeImage_GetBits(_impl.bitmap))[0 .. this.pitch * this.height];
	}
}

