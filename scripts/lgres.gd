# Reader for Looking Glass "LG Res File v2" archives (Terra Nova, System Shock).
# Header: 16-byte signature + comment, directory offset (u32) at 0x7C.
# Directory: count (u16), data offset (u32), then count x 10 bytes:
#   id (u16), size (24 bits) + flags (8), compressed size (24) + type (8).
# Data follows from the data offset, each resource aligned on 4 bytes.
# flags: 0x01 LZW (not supported here, not needed by the viewer), 0x02 compound.
extends RefCounted

const CP850 := "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜø£Ø×ƒáíóúñÑªº¿®¬½¼¡«»░▒▓│┤ÁÂÀ©╣║╗╝¢¥┐└┴┬├─┼ãÃ╚╔╩╦╠═╬¤ðÐÊËÈıÍÎÏ┘┌█▄¦Ì▀ÓßÔÒõÕµþÞÚÛÙýÝ¯´\u00AD±‗¾¶§÷¸°¨·¹³²■\u00A0"

var resources := {}   # id -> {"type": int, "flags": int, "data": PackedByteArray}


static func open(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d := f.get_buffer(f.get_length())
	if d.size() < 0x80 or d.slice(0, 14).get_string_from_ascii() != "LG Res File v2":
		return null
	var r = load("res://scripts/lgres.gd").new()
	var diro := d.decode_u32(0x7C)
	var n := d.decode_u16(diro)
	var off := d.decode_u32(diro + 2)
	var p := diro + 6
	for i in n:
		var rid := d.decode_u16(p)
		var a := d.decode_u32(p + 2)
		var b := d.decode_u32(p + 6)
		p += 10
		var size := a & 0xFFFFFF
		var flags := a >> 24
		var length := (b & 0xFFFFFF) if (flags & 1) else size
		r.resources[rid] = {"type": b >> 24, "flags": flags, "data": d.slice(off, off + length)}
		off += (length + 3) & ~3
	return r


func has(rid: int) -> bool:
	return resources.has(rid)


func data(rid: int) -> PackedByteArray:
	if not resources.has(rid):
		return PackedByteArray()
	return resources[rid]["data"]


# Compound resource: count (u16), then count + 1 offsets (u32), then the items.
static func frames(d: PackedByteArray) -> Array:
	var out := []
	if d.size() < 2:
		return out
	var n := d.decode_u16(0)
	for k in n:
		out.append(d.slice(d.decode_u32(2 + 4 * k), d.decode_u32(2 + 4 * (k + 1))))
	return out


# DOS code page 850 text (the French data uses accented letters), stops at the first 0.
static func text(b: PackedByteArray) -> String:
	var s := ""
	for c in b:
		if c == 0:
			break
		s += String.chr(c) if c < 128 else CP850[c - 128]
	return s


# Fixed 16-byte name records, as used by several tables.
static func names16(d: PackedByteArray) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(0, d.size() - 15, 16):
		out.append(text(d.slice(i, i + 16)))
	return out


func strings(rid: int) -> PackedStringArray:
	var out := PackedStringArray()
	for f in frames(data(rid)):
		out.append(text(f))
	return out
