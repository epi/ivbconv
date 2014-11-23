/*	Interface for output formats.

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

module outputformat;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.getopt;

interface OutputFormat
{
	void parseOptions(ref string[] args);
	ubyte[] convert(string filename, const(ubyte)[] caption, bool dither);

	static OutputFormat create(string name)
	{
		auto info = _registeredFormats.get(name, FormatInfo.init);
		enforce(info.name !is null, text("Unknown output format " ~ name));
		return info.create();
	}

	static register(string name, string extension, string description, CreateFunc create)
	{
		enforce(name !in _registeredFormats, text(name, " already registered"));
		_registeredFormats[name] = FormatInfo(name, extension, description, create);
	}

	static FormatInfo[] getAllFormats()
	{
		return _registeredFormats.values.sort!"a.name < b.name"().array();
	}

	alias CreateFunc = OutputFormat function();

	struct FormatInfo
	{
		string name;
		string extension;
		string description;
		CreateFunc create;
	}

private:
	static FormatInfo[string] _registeredFormats;
}
