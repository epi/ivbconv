/*	Compress data using FlashPack algorithm.

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

module flashpack;

import std.algorithm;
import std.array;

private struct Item
{
	bool special;
	ubyte[] data;
}

private Item[] toItems(uint addr, const(ubyte)[] data)
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

private ubyte[] toBytes(const(Item)[] items)
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

ubyte[] pack(uint addr, const(ubyte)[] data)
{
	return toItems(addr, data).toBytes();
}
