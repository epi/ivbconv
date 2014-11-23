/*	Generate Atari DOS binary files.

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

module dos;

import std.array;

void appendBlock(ref Appender!(ubyte[]) app, uint address, const(ubyte)[] data)
{
	assert(address + data.length < 0x10000);
	app.put(cast(ubyte) address);
	app.put(cast(ubyte) (address >> 8));
	app.put(cast(ubyte) (address + data.length - 1));
	app.put(cast(ubyte) ((address + data.length - 1) >> 8));
	app.put(data);
}

void appendIniBlock(ref Appender!(ubyte[]) app, uint address)
{
	appendBlock(app, 0x2e2, [ cast(ubyte) address, (address >> 8) & 0xff ]);
}

void appendRunBlock(ref Appender!(ubyte[]) app, uint address)
{
	appendBlock(app, 0x2e0, [ cast(ubyte) address, (address >> 8) & 0xff ]);
}
