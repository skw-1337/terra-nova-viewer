# Terra Nova game data: install detection, mission list, maps, planet colors.
# Everything is read straight from the player's own install (nothing is copied).
extends RefCounted

const LGRes = preload("res://scripts/lgres.gd")

const CANDIDATES := [
	"C:/Program Files (x86)/GOG Galaxy/Games/Terra Nova Strike Force Centauri",
	"C:/Program Files (x86)/Steam/steamapps/common/Terra Nova Strike Force Centauri",
	"C:/Program Files/Steam/steamapps/common/Terra Nova Strike Force Centauri",
	"C:/GOG Games/Terra Nova Strike Force Centauri",
	"D:/SteamLibrary/steamapps/common/Terra Nova Strike Force Centauri",
]
# campaign order (mission 1..37) -> MISSx.RES number
const CAMPAIGN := [37, 38, 1, 2, 3, 4, 5, 6, 7, 8, 9, 32, 33, 10, 11, 12, 13, 34, 29, 15, 17, 16, 36,
		14, 20, 39, 21, 35, 22, 23, 19, 24, 27, 25, 26, 30, 31]
const FRIENDLY := ["SFC", "Nikola", "Strike Force", "Centauri"]
const DETAIL_N := 513        # detailed grid: 513 x 513, 1 unit apart, covers 0..512
const COARSE_N := 257        # outer grid: 257 x 257, 4 units apart, covers -256..768
const HEIGHT_SCALE := 0.6875 / 256.0

var root := ""               # game folder (contains TNOVA)
var type_names := {}         # class -> PackedStringArray
var mission_names := PackedStringArray()


static func find_root(extra: String) -> String:
	var tries := [extra] + CANDIDATES
	for t in tries:
		if t != "" and FileAccess.file_exists(t.path_join("TNOVA/DATA/RESMISS.RES")):
			return t
	return ""


func setup(game_root: String) -> bool:
	root = game_root
	var g = LGRes.open(data_dir().path_join("RESGAME.RES"))
	var m = LGRes.open(data_dir().path_join("RESMISS.RES"))
	if g == null or m == null:
		return false
	for c in 5:
		type_names[c] = g.strings(381 + c)
	mission_names = m.strings(1706)
	return true


func data_dir() -> String:
	return root.path_join("TNOVA/DATA")


func maps_dir() -> String:
	return root.path_join("TNOVA/MAPS")


func type_name(cls: int, sub: int) -> String:
	var names: PackedStringArray = type_names.get(cls, PackedStringArray())
	if sub < names.size() and names[sub] != "":
		return names[sub]
	return "?%d/%d" % [cls, sub]


func is_friendly(name: String) -> bool:
	for f in FRIENDLY:
		if name.contains(f):
			return true
	return false


# [{label, file, dirs}] in a sensible order: campaign, training, cut, generator, demos.
func mission_list() -> Array:
	var out := []
	var d := data_dir()
	for i in CAMPAIGN.size():
		var n: int = CAMPAIGN[i]
		out.append({"label": "%02d  %s" % [i + 1, _mname(n)], "file": d.path_join("MISS%d.RES" % n)})
	for n in [46, 47]:
		out.append({"label": "Training  %s" % _mname(n), "file": d.path_join("MISS%d.RES" % n)})
	out.append({"label": "Cut  MISS40 - %s" % _mname(40), "file": d.path_join("MISS40.RES")})
	out.append({"label": "Cut  MISS41 (prototype)", "file": d.path_join("MISS41.RES")})
	for f in DirAccess.get_files_at(d):
		var u := f.to_upper()
		if u.begins_with("MISS") and u.ends_with(".RES") and not u.substr(4, u.length() - 8).is_valid_int():
			out.append({"label": "Generator  %s" % u.substr(4, u.length() - 8), "file": d.path_join(f)})
	for demo in [["TNDEMO1/DATA/MISS1D.RES", "Demo 1  exclusive mission"],
			["TNDEMO2/MAPS/MISS2D.RES", "CD demo  mission 1"],
			["TNDEMO2/MAPS/MISS3D.RES", "CD demo  mission 2"],
			["TNDEMO2/MAPS/MISS4D.RES", "CD demo  mission 3"]]:
		var p := root.path_join(demo[0])
		if FileAccess.file_exists(p):
			out.append({"label": demo[1], "file": p})
	var kept := []
	for e in out:
		if FileAccess.file_exists(e["file"]):
			kept.append(e)
	return kept


func _mname(n: int) -> String:
	if n - 1 < mission_names.size() and mission_names[n - 1].strip_edges() != "":
		return mission_names[n - 1].strip_edges()
	return "MISS%d" % n


# Looks for a data file next to the mission, in the demo folders, then in the main game.
func resolve(mission_file: String, name: String) -> String:
	var here := mission_file.get_base_dir()
	for dir in [here, here.get_base_dir().path_join("DATA"), here.get_base_dir().path_join("MAPS"),
			maps_dir(), data_dir()]:
		var p: String = dir.path_join(name.to_upper())
		if FileAccess.file_exists(p):
			return p
	return ""


# Mission file -> {map, groups, zones, entities}
func load_mission(path: String) -> Dictionary:
	var r = LGRes.open(path)
	if r == null:
		return {}
	var groups: PackedStringArray = LGRes.names16(r.data(172))
	var zone_names: PackedStringArray = LGRes.names16(r.data(177))
	var zc: PackedByteArray = r.data(176)
	var zones := []
	for i in zone_names.size():
		if 8 * i + 8 > zc.size():
			break
		var x := zc.decode_s32(8 * i) / 65536.0
		var y := zc.decode_s32(8 * i + 4) / 65536.0
		var nm := zone_names[i]
		var label := nm.substr(nm.find(": ") + 2) if nm.contains(": ") else nm
		if label.strip_edges() != "" or x != 0.0 or y != 0.0:
			zones.append({"name": label, "x": x, "y": y})
	var ents := []
	for t in LGRes.frames(r.data(173)):
		var f: PackedByteArray = t
		if f.size() < 24:
			continue
		var g := f[7]
		ents.append({"cls": f[0], "sub": f[1], "group": groups[g] if g < groups.size() else "",
				"x": f.decode_s32(8) / 65536.0, "y": f.decode_s32(12) / 65536.0,
				"heading": f.decode_u16(20) / 65536.0 * TAU})
	return {"map": LGRes.text(r.data(170)), "groups": groups, "zones": zones, "entities": ents}


# Map file -> heights, tile colors (detail + outer grid), fixed vegetation.
func load_map(path: String, mission_file: String) -> Dictionary:
	var r = LGRes.open(path)
	if r == null or not r.has(86):
		return {}
	var planet := "RESPLNT0.RES"
	var info: String = r.data(80).get_string_from_ascii()
	var raw80: PackedByteArray = r.data(80)
	for i in raw80.size() - 12:
		if raw80.slice(i, i + 7).get_string_from_ascii().to_lower() == "resplnt":
			planet = raw80.slice(i, i + 12).get_string_from_ascii()
			break
	var bands := planet_bands(resolve(mission_file, planet))
	var detail := _grid(r.data(86), DETAIL_N, bands)
	var outer := _grid(r.data(85), COARSE_N, bands) if r.has(85) else {}
	var veg := []
	for rid in range(120, 150):
		for t in LGRes.frames(r.data(rid)):
			var f: PackedByteArray = t
			if f.size() >= 24:
				veg.append({"cls": f[0], "sub": f[1], "x": f.decode_s32(8) / 256.0, "y": f.decode_s32(12) / 256.0})
	return {"planet": planet, "detail": detail, "outer": outer, "veg": veg, "info": info}


func _grid(d: PackedByteArray, n: int, bands: PackedColorArray) -> Dictionary:
	var h := PackedFloat32Array()
	h.resize(n * n)
	var col := PackedColorArray()
	col.resize(n * n)
	var tiles := PackedByteArray()
	tiles.resize(n * n)
	for i in n * n:
		var b0 := d[3 * i]
		h[i] = d.decode_s16(3 * i + 1) * HEIGHT_SCALE
		var band := mini((b0 & 0x1F) >> 2, bands.size() - 1)
		tiles[i] = band
		col[i] = bands[band] * (0.94 + 0.04 * (b0 & 3))
	return {"n": n, "h": h, "col": col, "tile": tiles}


# Average color of each 32-pixel band of the planet's 512x512 ground texture atlas
# (band 0 water, 1 sand, 2 grass, 3 rock, 4 snow, then transitions...).
# Palette: resource 50 = 239 RGB colors starting at palette index 17.
func planet_bands(path: String) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(16)
	for b in 16:
		out[b] = Color(0.45, 0.5, 0.35)
	var r = LGRes.open(path)
	if r == null or not r.has(48) or not r.has(50):
		return out
	var pal: PackedByteArray = r.data(50)
	var atlas: PackedByteArray = r.data(48)
	var bands := mini(16, atlas.size() / 512 / 32)   # some planets have a shorter atlas
	for b in bands:
		var acc := Vector3.ZERO
		var cnt := 0
		for y in range(b * 32, b * 32 + 32, 2):
			for x in range(0, 512, 2):
				var idx := atlas[y * 512 + x] - 17
				if idx >= 0 and 3 * idx + 2 < pal.size():
					acc += Vector3(pal[3 * idx], pal[3 * idx + 1], pal[3 * idx + 2])
					cnt += 1
		if cnt > 0:
			acc /= float(cnt) * 255.0
			out[b] = Color(acc.x, acc.y, acc.z)
	return out


# Terrain height at game coordinates (x, y), bilinear, detail grid first then outer grid.
static func height_at(m: Dictionary, x: float, y: float) -> float:
	if x >= 0 and y >= 0 and x < 512 and y < 512:
		return _bilinear(m["detail"], x, y)
	if not m["outer"].is_empty():
		return _bilinear(m["outer"], (x + 256.0) / 4.0, (y + 256.0) / 4.0)
	return 0.0


static func _bilinear(g: Dictionary, gx: float, gy: float) -> float:
	var n: int = g["n"]
	var h: PackedFloat32Array = g["h"]
	gx = clampf(gx, 0, n - 1.001)
	gy = clampf(gy, 0, n - 1.001)
	var x0 := int(gx)
	var y0 := int(gy)
	var fx := gx - x0
	var fy := gy - y0
	var a := lerpf(h[y0 * n + x0], h[y0 * n + x0 + 1], fx)
	var b := lerpf(h[(y0 + 1) * n + x0], h[(y0 + 1) * n + x0 + 1], fx)
	return lerpf(a, b, fy)
