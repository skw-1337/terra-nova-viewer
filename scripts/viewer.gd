# Terra Nova map viewer: terrain, water, mission entities, named script zones, free camera.
extends Node3D

const TNData = preload("res://scripts/tn_data.gd")
const Terrain = preload("res://scripts/terrain.gd")
const TNObjects = preload("res://scripts/tn_objects.gd")
const GROUND = preload("res://terrain.gdshader")
const LIMB = preload("res://limb.gdshader")
const SMOKE = preload("res://smoke.gdshader")
const SKY_SHADER = preload("res://sky.gdshader")
const SKY_DISTANCE := 2400.0             # sky sprites: far away, following the camera
const SKY_PIXEL := 0.0024                # their angular size per image pixel (radians)
const DEFAULT_SUN := Vector3(-52, -35, 0)
const SMOKE_WIDTH := 1.4                # world width of a smoke column
const POSES_FILE := "res://data/soldier_poses.json"   # real poses read from the running game
# Standing pose computed by the game for a Hog scout (suit 4), read in a RAM snapshot:
# joints (right, up, forward) in world units, ground at 0. Other suits get the same joint
# directions with their own bone lengths (sprite pixel length / 256 x 1.09, the scout's own size).
const TEMPLATE_POSE := [Vector3(-0.0378, 0.0, 0.0329), Vector3(0.0378, 0.0, 0.0329),
		Vector3(-0.0279, 0.0422, -0.0169), Vector3(0.0279, 0.0422, -0.0169),
		Vector3(-0.0203, 0.1445, 0.0034), Vector3(0.0388, 0.1445, 0.0035),
		Vector3(-0.0312, 0.2494, 0.0), Vector3(0.0312, 0.2494, -0.0), Vector3(0.0, 0.2494, 0.0),
		Vector3(0.0, 0.4043, 0.0), Vector3(-0.0689, 0.3826, 0.0117), Vector3(0.0874, 0.3826, 0.012),
		Vector3(-0.0695, 0.322, 0.061), Vector3(0.0932, 0.3227, 0.0609),
		Vector3(-0.0714, 0.3061, 0.1374), Vector3(0.111, 0.3112, 0.136)]
const TEMPLATE_SUIT := 4
const BODY_SCALE := 1.09
const CFG := "user://viewer.cfg"

var data = TNData.new()
var objects = TNObjects.new()
var objects_ok := false
var pal := PackedColorArray()   # 256-color palette of the current planet
var pal_key := ""
var world: Node3D
var camera: Camera3D
var ui: CanvasLayer
var panel: PanelContainer
var list: ItemList
var info: Label
var status: Label
var path_edit: LineEdit
var missions := []
var labels_on := true
var zones_on := true
var veg_on := true
var yaw := 0.0
var pitch := -0.45
var speed := 30.0
var look := false
var current := {}
var env: Environment
var sun: DirectionalLight3D
var sky_root: Node3D
var mats := {}


func _ready() -> void:
	_build_scene()
	_build_ui()
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	var root := TNData.find_root(cfg.get_value("game", "root", ""))
	if root == "" or not data.setup(root):
		_ask_path("Terra Nova folder not found. Paste the game folder (the one containing TNOVA):")
		return
	objects_ok = objects.setup(data.data_dir())
	_fill_list()
	var args := OS.get_cmdline_user_args()
	if "--all" in args:                       # test: load every mission, then quit
		for k in missions.size():
			await _load(k)
		get_tree().quit()
		return
	var i := args.find("--mission")
	if i >= 0 and i + 1 < args.size():
		_load_by_label(args[i + 1])
	else:
		list.select(4)
		_load(4)


# ------------------------------------------------------------------ scene
func _build_scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.78)
	sm.sky_horizon_color = Color(0.72, 0.78, 0.86)
	sm.ground_horizon_color = Color(0.72, 0.78, 0.86)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.76, 0.84)
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = DEFAULT_SUN
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	world = Node3D.new()
	add_child(world)
	sky_root = Node3D.new()
	add_child(sky_root)
	camera = Camera3D.new()
	camera.far = 3000.0
	camera.fov = 70.0
	add_child(camera)
	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.vertex_color_is_srgb = true
	terrain_mat.roughness = 1.0
	mats["terrain"] = terrain_mat
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.42, 0.66, 0.72)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.15
	water.metallic = 0.2
	mats["water"] = water
	for key in ["friend", "enemy", "building", "decor", "tree", "rock", "zone"]:
		var m := StandardMaterial3D.new()
		m.roughness = 0.8
		m.albedo_color = {"friend": Color(0.25, 0.55, 1.0), "enemy": Color(0.95, 0.25, 0.2),
			"building": Color(0.72, 0.72, 0.78), "decor": Color(0.7, 0.55, 0.35),
			"tree": Color(0.16, 0.38, 0.14), "rock": Color(0.5, 0.48, 0.45),
			"zone": Color(1.0, 0.85, 0.15)}[key]
		if key == "zone":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.8, 0.1)
			m.emission_energy_multiplier = 0.6
		mats[key] = m


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Terra Nova map viewer"
	vb.add_child(title)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(360, 520)
	list.item_selected.connect(_load)
	vb.add_child(list)
	info = Label.new()
	info.custom_minimum_size = Vector2(360, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	path_edit = LineEdit.new()
	path_edit.visible = false
	path_edit.text_submitted.connect(_on_path)
	vb.add_child(path_edit)
	status = Label.new()
	status.anchor_top = 1.0
	status.anchor_bottom = 1.0
	status.offset_left = 10
	status.offset_top = -34
	status.text = "Right mouse: look   WASD/ZQSD: move   Space/Ctrl: up/down   Shift: fast   Wheel: speed   Tab: panel   F2: labels   F3: script zones (yellow posts)   F4: vegetation"
	ui.add_child(status)


func _ask_path(msg: String) -> void:
	info.text = msg
	path_edit.visible = true


func _on_path(t: String) -> void:
	var root := TNData.find_root(t.strip_edges().replace("\\", "/"))
	if root == "" or not data.setup(root):
		info.text = "Still not found: pick the folder that contains TNOVA."
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "root", root)
	cfg.save(CFG)
	path_edit.visible = false
	objects_ok = objects.setup(data.data_dir())
	_fill_list()


func _fill_list() -> void:
	missions = data.mission_list()
	if objects_ok:
		missions.append({"label": "Gallery  all 3D models", "file": "", "gallery": true})
	list.clear()
	for m in missions:
		list.add_item(m["label"])
	info.text = "%d missions found in\n%s" % [missions.size(), data.root]


func _load_by_label(t: String) -> void:
	for i in missions.size():
		if missions[i]["label"].contains(t) or missions[i]["file"].get_file().to_upper() == t.to_upper():
			list.select(i)
			_load(i)
			return


# ------------------------------------------------------------------ loading
func _load(index: int) -> void:
	var entry: Dictionary = missions[index]
	info.text = "Loading %s..." % entry["label"]
	await get_tree().process_frame
	await get_tree().process_frame
	if entry.get("gallery", false):
		_load_gallery()
		return
	var t0 := Time.get_ticks_msec()
	var mis: Dictionary = data.load_mission(entry["file"])
	if mis.is_empty():
		info.text = "Cannot read " + entry["file"]
		return
	var note := ""
	var map_path: String = data.resolve(entry["file"], mis["map"])
	if map_path == "":
		note = "\nMap %s is missing from the game: shown on the generator's flat terrain." % mis["map"]
		map_path = data.resolve(entry["file"], "FLAT.RES")
	var m: Dictionary = data.load_map(map_path, entry["file"])
	if m.is_empty():
		info.text = "Cannot read map " + map_path
		return
	for c in world.get_children():
		c.queue_free()
	var pl: Dictionary = m["planet_data"]
	var det_mat: Material = mats["terrain"]
	var out_mat: Material = mats["terrain"]
	if pl["ok"]:                          # real ground textures (else: average colors)
		det_mat = _ground_mat(pl, m["detail"], Vector2(0, 0), 1.0)
		if not m["outer"].is_empty():
			out_mat = _ground_mat(pl, m["outer"], Vector2(-256, -256), 4.0)
	Terrain.build(world, m["detail"], 1.0, Vector2(0, 0), Rect2i(), det_mat)
	if not m["outer"].is_empty():
		Terrain.build(world, m["outer"], 4.0, Vector2(-256, -256), Rect2i(64, 64, 128, 128), out_mat)
	var wl := Terrain.water_level(m["detail"])
	if not is_nan(wl):
		var plane := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1024, 1024)
		plane.mesh = pm
		plane.material_override = mats["water"]
		plane.position = Vector3(256, wl + 0.12, 256)
		world.add_child(plane)
	pal = pl["palette"] if pl.has("palette") else data.full_palette(PackedByteArray())
	pal_key = m["planet"]
	_set_sky(data.resolve(entry["file"], mis.get("sky", "")) if mis.get("sky", "") != "" else "", m["light"])
	var nveg := _add_vegetation(m)
	var counts := {}
	for e in mis["entities"]:
		_add_object(m, e["cls"], e["sub"], e["x"], e["y"], e["heading"], e["group"], true, e["z"])
		counts[e["cls"]] = counts.get(e["cls"], 0) + 1
	for z in mis["zones"]:
		_add_zone(m, z)
	current = {"map": m, "mission": mis, "entry": entry}
	_place_camera(m, mis)
	info.text = "%s\nmap %s (%s), %d objects, %d named zones, %d plants%s\nloaded in %.1f s" % [
		entry["label"], mis["map"], m["planet"], mis["entities"].size(), mis["zones"].size(), nveg, note,
		(Time.get_ticks_msec() - t0) / 1000.0]
	print(info.text.replace("\n", " | "))
	var args := OS.get_cmdline_user_args()
	var s := args.find("--shot")
	if s >= 0 and s + 1 < args.size():
		_screenshot(args[s + 1])


# Vegetation generated like the engine does (see TNData.load_map). Each plant is a decor type whose
# sprite (or model) comes from RESTNOBJ: one MultiMesh per sprite.
func _add_vegetation(m: Dictionary) -> int:
	var vmap: PackedByteArray = m["veg_map"]
	var sets: Array = m["veg_sets"]
	if vmap.size() < 128 * 128:
		return 0
	var groups := {}                  # sprite / model ref (or stand-in shape name) -> Array[Transform3D]
	var n := 0
	for cx in 128:
		for cy in 128:
			var v := vmap[cx * 128 + cy]  # column by column
			if v == 0 or v > sets.size():
				continue
			for it in sets[v - 1]:
				var x: float = cx * 4.0 + it["ox"]
				var y: float = cy * 4.0 + it["oy"]
				var key := Vector2i(it["cls"], it["sub"])
				if not groups.has(key):
					groups[key] = []
				groups[key].append(Transform3D(Basis.IDENTITY, Vector3(x, TNData.height_at(m, x, y), y)))
				n += 1
	for key in groups:                # key = (class, type)
		var mesh: Mesh = null
		var mat: Material = null
		var ref: Vector2i = objects.ref_for(key.x, key.y) if objects_ok else Vector2i.ZERO
		if TNObjects.is_sprite(ref):
			var sp: Dictionary = objects.sprite(ref, pal, pal_key)
			if not sp.is_empty():
				mesh = _sprite_quad(sp, objects.sprite_width(key.x, key.y))
				mat = _sprite_mat(ref, sp)
		elif TNObjects.is_model(ref):
			var md: Dictionary = objects.model(ref, pal, pal_key)
			if not md.is_empty():
				mesh = md["mesh"]
		if mesh == null:
			var name: String = data.type_name(key.x, key.y).to_lower()
			var shape := "rock" if name.contains("rocher") or name.contains("rock") else (
					"bush" if name.contains("buisson") or name.contains("bush") else "tree")
			mesh = _placeholder(shape)
			mat = mats["rock"] if shape == "rock" else mats["tree"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var trs: Array = groups[key]
		mm.instance_count = trs.size()
		for i in trs.size():
			mm.set_instance_transform(i, trs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mat != null:
			mmi.material_override = mat
		mmi.add_to_group("vegetation")
		mmi.visible = veg_on
		world.add_child(mmi)
	return n


# Simple stand-in shapes, standing on their base, when the game data has no sprite / model.
func _placeholder(shape: String) -> Mesh:
	var mesh: PrimitiveMesh
	match shape:
		"tree":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.1
			cone.height = 4.5
			cone.radial_segments = 7
			cone.rings = 1
			mesh = cone
		"bush":
			var sph := SphereMesh.new()
			sph.radius = 0.7
			sph.height = 1.0
			sph.radial_segments = 8
			sph.rings = 4
			mesh = sph
		_:
			var bx := BoxMesh.new()
			bx.size = Vector3(1.6, 1.0, 1.4)
			mesh = bx
	# lift the shape so that it stands on its base
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var up := Vector3(0, mesh.get_aabb().size.y * 0.5, 0)
	for i in verts.size():
		verts[i] += up
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


# Sprite (tree, bush, rock, probe): upright quad turning to face the camera, base on the ground.
func _sprite_quad(sp: Dictionary, width: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(width, width * sp["aspect"])
	q.center_offset = Vector3(0, q.size.y * 0.5, 0)
	return q


func _sprite_mat(key: Vector2i, sp: Dictionary) -> StandardMaterial3D:
	var k := "sprite%s" % key
	if mats.has(k):
		return mats[k]
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = sp["texture"]
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sm.alpha_scissor_threshold = 0.5
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	sm.billboard_keep_scale = true
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # the game draws sprites unlit
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[k] = sm
	return sm


# Every model of RESTNOBJ.RES in rows on flat ground (planet 0 colors), each with its file name
# and the object types that use it. Models face +X (east).
func _load_gallery() -> void:
	for c in world.get_children():
		c.queue_free()
	var pl: Dictionary = data.load_planet(data.data_dir().path_join("RESPLNT0.RES"))
	pal = pl["palette"] if pl.has("palette") else data.full_palette(PackedByteArray())
	pal_key = "RESPLNT0.RES"
	var users := {}                   # model ref -> names of the object types using it
	for c in objects.refs:
		var arr: Array = objects.refs[c]
		for i in arr.size():
			var nm: String = data.type_name(c, i).strip_edges()
			if nm == "" or nm.begins_with("?"):
				continue
			if not users.has(arr[i]):
				users[arr[i]] = PackedStringArray()
			if not users[arr[i]].has(nm):
				users[arr[i]].append(nm)
	var x := 0.0
	var z := 0.0
	var depth := 0.0
	var n := 0
	for ref in objects.all_models():
		var md: Dictionary = objects.model(ref, pal, pal_key)
		if md.is_empty():
			continue
		var box: AABB = md["mesh"].get_aabb()
		if x > 0.0 and x + box.size.x > 70.0:
			x = 0.0
			z += depth + 4.0
			depth = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = md["mesh"]
		mi.position = Vector3(x - box.position.x, 0.0, z - box.position.z)
		world.add_child(mi)
		var l := Label3D.new()
		var who: PackedStringArray = users.get(ref, PackedStringArray())
		l.text = md["name"] + ("" if who.is_empty() else "
" + ", ".join(who))
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 32
		l.pixel_size = 0.01
		l.outline_size = 8
		l.position = Vector3(box.get_center().x, md["height"] + 0.4, box.get_center().z)
		l.add_to_group("labels")
		l.visible = labels_on
		mi.add_child(l)
		x += box.size.x + 2.0
		depth = maxf(depth, box.size.z)
		n += 1
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.4, 0.34)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(35, -0.01, z * 0.5)
	world.add_child(ground)
	yaw = 0.0
	pitch = -0.3
	camera.position = Vector3(12, 5, z + depth + 14)
	var args := OS.get_cmdline_user_args()
	var c := args.find("--cam")          # test: --cam x,z,height,yaw_deg,pitch_deg
	if c >= 0 and c + 1 < args.size():
		var v := args[c + 1].split_floats(",")
		camera.position = Vector3(v[0], v[2], v[1])
		yaw = deg_to_rad(v[3])
		pitch = deg_to_rad(v[4])
	camera.rotation = Vector3(pitch, yaw, 0)
	current = {}
	info.text = "Gallery: %d distinct 3D models from RESTNOBJ.RES
(file name, then the object types using it)" % n
	print(info.text.replace("
", " | "))
	var sh := args.find("--shot")
	if sh >= 0 and sh + 1 < args.size():
		_screenshot(args[sh + 1])


func _ground_mat(pl: Dictionary, grid: Dictionary, origin: Vector2, step: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = GROUND
	sm.set_shader_parameter("tiles", pl["textures"])
	sm.set_shader_parameter("tilemap", ImageTexture.create_from_image(grid["tilemap"]))
	sm.set_shader_parameter("origin", origin)
	sm.set_shader_parameter("step_size", step)
	sm.set_shader_parameter("grid_n", float(grid["n"]))
	return sm


func _add_object(m: Dictionary, cls: int, sub: int, x: float, y: float, heading: float, group: String,
		label: bool, z: float = 0.0) -> void:
	var name: String = data.type_name(cls, sub)
	var low := name.to_lower()
	var ground := TNData.height_at(m, x, y)
	# z = height above the ground; the mission files leave it at 0 except for the Nid d'aigle bridge
	# (spanning a ravine): ships then sit on the ground / dock, probes are shown hovering a little
	var lift := z
	if z == 0.0 and cls == 3 and (low.contains("sonde") or low.contains("probe")):
		lift = 3.0
	var mi := MeshInstance3D.new()
	var top := 0.0
	var ref: Vector2i = objects.ref_for(cls, sub) if objects_ok else Vector2i.ZERO
	var soldier := false
	if cls == 1 and objects_ok:
		var suit := TNObjects.suit_of(sub)
		top = _add_mech(mi) if suit == TNObjects.MECH_SUIT else _add_soldier(mi, suit)   # parts = children
		soldier = top > 0.0
	if cls == 4 and sub == TNObjects.SMOKE_TYPE and objects_ok:
		var sm: Dictionary = objects.smoke_anim(pal, pal_key)
		if not sm.is_empty():
			var q := QuadMesh.new()
			q.size = Vector2(SMOKE_WIDTH, SMOKE_WIDTH * sm["aspect"])
			q.center_offset = Vector3(0, q.size.y * 0.5, 0)
			mi.mesh = q
			var smat := ShaderMaterial.new()
			smat.shader = SMOKE
			smat.set_shader_parameter("frames", sm["tex"])
			smat.set_shader_parameter("frame_count", sm["frames"])
			mi.material_override = smat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = SMOKE_WIDTH
			top = q.size.y
	if soldier or mi.mesh != null:
		pass
	elif TNObjects.is_model(ref):
		var md: Dictionary = objects.model(ref, pal, pal_key)
		if not md.is_empty():
			mi.mesh = md["mesh"]
			top = md["height"]
	elif TNObjects.is_sprite(ref):
		var sp: Dictionary = objects.sprite(ref, pal, pal_key)
		if not sp.is_empty():
			var q := _sprite_quad(sp, objects.sprite_width(cls, sub))
			mi.mesh = q
			mi.material_override = _sprite_mat(ref, sp)
			top = q.size.y
	if mi.mesh == null and not soldier:   # nothing usable in the data (e.g. the biped mech)
		var box := BoxMesh.new()
		match cls:
			0:
				box.size = Vector3(1.2, 1.2, 1.2)
				mi.material_override = mats["decor"]
			1:
				box.size = Vector3(0.5, 1.4, 0.5)
				mi.material_override = mats["friend"] if data.is_friendly(name) else mats["enemy"]
			2, 3:
				box.size = Vector3(1.4, 0.8, 1.4)
				mi.material_override = mats["friend"] if data.is_friendly(name) else mats["enemy"]
			_:
				box.size = Vector3(4, 3, 4)
				mi.material_override = mats["building"]
		mi.mesh = box
		top = box.size.y
		lift += box.size.y * 0.5
		top -= box.size.y * 0.5
	mi.position = Vector3(x, ground + lift, y)
	mi.rotation.y = -heading
	world.add_child(mi)
	if label:
		var l := Label3D.new()
		l.text = name if group == "" or group.begins_with("(NULL") or group.begins_with("DEFAULT") else "%s\n[%s]" % [name, group]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 36
		l.pixel_size = 0.02
		l.outline_size = 10
		l.visibility_range_end = 140.0
		l.position = Vector3(0, top + 1.0, 0)
		l.add_to_group("labels")
		l.visible = labels_on
		mi.add_child(l)


# Power suit in its standing pose (see TEMPLATE_POSE); the limbs become children of holder.
# Joints of skeletons 884 / 885: 0/1 toes, 2/3 ankles, 4/5 knees, 6/7 hips, 8 pelvis, 9 neck,
# 10/11 shoulders, 12/13 elbows, 14/15 hands. Returns the suit height (0 when it has no sprites).
func _add_soldier(holder: Node3D, suit: int) -> float:
	var segs: Array = objects.skeleton(suit)
	var limbs := {}
	for sg in segs:
		var ld: Dictionary = objects.limb(suit, sg[2], pal, pal_key)
		if ld.is_empty():
			return 0.0
		limbs[sg[2]] = ld
	var p := _soldier_pose(suit, segs, limbs)
	var top := 0.0
	for sg in segs:
		var ld: Dictionary = limbs[sg[2]]
		var a: Vector3 = p[sg[0]]
		var b: Vector3 = p[sg[1]]
		# (right, up, forward) -> node axes (forward = +X, right = +Z)
		var ga := Vector3(a.z, a.y, a.x)
		var gb := Vector3(b.z, b.y, b.x)
		var dir := gb - ga
		var sc: float = dir.length() / ld["len"]
		var yn := dir.normalized()
		var fw := Vector3(1, 0, 0)
		if absf(fw.dot(yn)) > 0.95:
			fw = Vector3(0, 1, 0)
		var xn := (fw - yn * fw.dot(yn)).normalized()
		var zn := xn.cross(yn)
		var seg := MeshInstance3D.new()
		seg.mesh = _limb_quad(ld)
		seg.material_override = _limb_mat(suit, sg[2], ld)
		seg.transform = Transform3D(Basis(xn * sc, yn * sc, zn * sc), ga)
		seg.extra_cull_margin = ld["size"].x * sc
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(seg)
		top = maxf(top, maxf(ga.y, gb.y))
	return top + 0.1


var captured_poses = null


# The pose captured in the game for this suit when there is one (data/soldier_poses.json, written
# by _MODS/re/poses.py), else the template pose rebuilt with this suit's bone lengths.
func _soldier_pose(suit: int, segs: Array, limbs: Dictionary) -> Array[Vector3]:
	if captured_poses == null:
		captured_poses = {}
		if FileAccess.file_exists(POSES_FILE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(POSES_FILE))
			if parsed is Dictionary:
				captured_poses = parsed
	var p: Array[Vector3] = []
	p.resize(16)
	if captured_poses.has(str(suit)):
		var raw: Array = captured_poses[str(suit)]
		for k in mini(16, raw.size()):
			p[k] = Vector3(raw[k][0], raw[k][1], raw[k][2])
		return p
	var t: Array[Vector3] = []
	for v in TEMPLATE_POSE:
		t.append(v)
	var length := func(part: int) -> float:
		return limbs[part]["len"] / 256.0 * BODY_SCALE if limbs.has(part) else 0.08
	# free joints (pelvis, hips, shoulders) keep their place relative to the pelvis / neck,
	# scaled with the torso; every limb keeps its direction and takes this suit's length
	var k_torso: float = length.call(5) / t[8].distance_to(t[9])
	p[8] = t[8]
	p[9] = p[8] + (t[9] - t[8]).normalized() * length.call(5)
	for i in 2:
		p[6 + i] = p[8] + (t[6 + i] - t[8]) * k_torso
		p[10 + i] = p[9] + (t[10 + i] - t[9]) * k_torso
	for chain in [[6, 4, 2, 0], [7, 5, 3, 1], [10, 12, 14], [11, 13, 15]]:
		for c in range(1, chain.size()):
			var a: int = chain[c - 1]
			var b: int = chain[c]
			var part := -1
			for sg in segs:
				if (sg[0] == a and sg[1] == b) or (sg[0] == b and sg[1] == a):
					part = sg[2]
			p[b] = p[a] + (t[b] - t[a]).normalized() * length.call(part)
	var ground := minf(minf(p[0].y, p[1].y), minf(p[2].y, p[3].y))
	for k in 16:
		p[k].y -= ground
	return p


# Biped mech (skeleton 886): legs and body are small 3D models (RESTNOBJ 877-883, "pbmb00-06"),
# each hanging from its first joint with its y axis along the segment. Rest pose in world units.
# Joints: 0/1 toes, 2/3 ankles, 4/5 knees, 6/7 hips, 8 body bottom, 9 body top.
func _add_mech(holder: Node3D) -> float:
	var segs: Array = objects.skeleton(TNObjects.MECH_SUIT)
	var p: Array[Vector3] = []                     # (right, up, forward)
	p.resize(16)
	var ankle := 0.1
	var knee_y := ankle + 0.39
	var hip_y := knee_y + 0.28
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		p[i] = Vector3(side * 0.3, 0.0, 0.24)
		p[2 + i] = Vector3(side * 0.3, ankle, 0.0)
		p[4 + i] = Vector3(side * 0.3, knee_y, 0.04)
		p[6 + i] = Vector3(side * 0.3, hip_y, 0.0)
	p[9] = Vector3(0.0, hip_y + 0.3, 0.0)
	p[8] = Vector3(0.0, hip_y - 0.08, 0.0)
	var top := 0.0
	for sg in segs:
		var md: Dictionary = objects.model(Vector2i(877 + sg[2], 0), pal, pal_key)
		if md.is_empty():
			return 0.0
		var a: Vector3 = p[sg[0]]
		var b: Vector3 = p[sg[1]]
		var ga := Vector3(a.z, a.y, a.x)
		var gb := Vector3(b.z, b.y, b.x)
		var down := (gb - ga).normalized()          # model y (mesh -Y) runs from joint a to b
		var yn := -down
		var fw := Vector3(1, 0, 0)
		if absf(fw.dot(yn)) > 0.95:
			fw = Vector3(0, 1, 0)
		var xn := (fw - yn * fw.dot(yn)).normalized()
		var part := MeshInstance3D.new()
		part.mesh = md["mesh"]
		part.transform = Transform3D(Basis(xn, yn, xn.cross(yn)), ga)
		holder.add_child(part)
		top = maxf(top, maxf(ga.y, gb.y))
	return top + 0.1


func _limb_quad(ld: Dictionary) -> ArrayMesh:
	if ld.has("mesh"):
		return ld["mesh"]
	var w: float = ld["size"].x
	var h: float = ld["size"].y
	var a1: float = ld["a1"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for c in corners:
		st.set_uv(c)
		st.add_vertex(Vector3((c.x - 0.5) * w, c.y * h - a1, 0.0))
	var mesh := st.commit()
	ld["mesh"] = mesh
	return mesh


func _limb_mat(suit: int, part: int, ld: Dictionary) -> ShaderMaterial:
	var k := "limb%d/%d/%s" % [suit, part, pal_key]
	if mats.has(k):
		return mats[k]
	var sm := ShaderMaterial.new()
	sm.shader = LIMB
	sm.set_shader_parameter("views", ld["tex"])
	sm.set_shader_parameter("view_count", ld["views"])
	mats[k] = sm
	return sm


func _add_zone(m: Dictionary, z: Dictionary) -> void:
	# script zone (waypoint, trigger, drop / pickup point): thin post, name at eye level
	var ground := TNData.height_at(m, z["x"], z["y"])
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 6.0
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mats["zone"]
	mi.position = Vector3(z["x"], ground + 3.0, z["y"])
	mi.add_to_group("zones")
	mi.visible = zones_on
	var l := Label3D.new()
	l.text = z["name"]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.018
	l.modulate = Color(1.0, 0.9, 0.3)
	l.outline_size = 12
	l.visibility_range_end = 300.0
	l.fixed_size = false
	l.position = Vector3(0, 3.6, 0)
	mi.add_child(l)
	world.add_child(mi)


func _place_camera(m: Dictionary, mis: Dictionary) -> void:
	var target := Vector2(256, 256)
	for z in mis["zones"]:
		if z["name"].to_lower().contains("drop"):
			target = Vector2(z["x"], z["y"])
			break
	var ground := TNData.height_at(m, target.x, target.y)
	yaw = 0.0
	pitch = -0.45
	camera.position = Vector3(target.x, ground + 28.0, target.y + 45.0)
	var args := OS.get_cmdline_user_args()
	var c := args.find("--cam")          # test: --cam x,y,height_above_ground,yaw_deg,pitch_deg
	if c >= 0 and c + 1 < args.size():
		var v := args[c + 1].split_floats(",")
		camera.position = Vector3(v[0], TNData.height_at(m, v[0], v[1]) + v[2], v[1])
		yaw = deg_to_rad(v[3])
		pitch = deg_to_rad(v[4])
	camera.rotation = Vector3(pitch, yaw, 0)


func _screenshot(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot ", path)
	get_tree().quit()


# ------------------------------------------------------------------ camera
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			look = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if look else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = minf(speed * 1.25, 400.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = maxf(speed / 1.25, 2.0)
	elif event is InputEventMouseMotion and look:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -1.5, 1.5)
		camera.rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				panel.visible = not panel.visible
			KEY_F2:
				labels_on = not labels_on
				get_tree().call_group("labels", "set_visible", labels_on)
			KEY_F3:
				zones_on = not zones_on
				get_tree().call_group("zones", "set_visible", zones_on)
			KEY_F4:
				veg_on = not veg_on
				get_tree().call_group("vegetation", "set_visible", veg_on)


# The mission's sky (see TNObjects.load_sky): shader sky with the cloud texture and the haze color
# (also the fog color), sprites placed by azimuth / elevation, the moon and the sunlight in the
# map's light direction (map resource 82).
func _set_sky(path: String, light: Vector2) -> void:
	for c in sky_root.get_children():
		c.queue_free()
	var sk: Dictionary = objects.load_sky(path, pal) if objects_ok and path != "" else {}
	# the map's light direction (azimuth, elevation; game y axis = Godot z)
	var to_light := Vector3(cos(light.y) * cos(light.x), sin(light.y), cos(light.y) * sin(light.x))
	sun.look_at_from_position(Vector3.ZERO, -to_light, Vector3.UP if absf(to_light.y) < 0.99 else Vector3.FORWARD)
	if sk.is_empty():
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color(0.32, 0.5, 0.78)
		sm.sky_horizon_color = Color(0.72, 0.78, 0.86)
		sm.ground_horizon_color = Color(0.72, 0.78, 0.86)
		env.sky.sky_material = sm
		env.fog_light_color = Color(0.7, 0.76, 0.84)
		return
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("has_clouds", sk["clouds"] != null)
	mat.set_shader_parameter("has_stars", sk.get("stars") != null)
	if sk.get("stars") != null:
		mat.set_shader_parameter("stars", sk["stars"])
	if sk["clouds"] != null:
		mat.set_shader_parameter("clouds", sk["clouds"])
	var haze: Color = sk["haze"]
	mat.set_shader_parameter("haze", Vector3(haze.r, haze.g, haze.b))
	env.sky.sky_material = mat
	env.fog_light_color = haze
	var sprites: Array = sk["items"].duplicate()
	if sk.get("moon") != null:
		var moon: Dictionary = sk["moon"].duplicate()
		moon["az"] = light.x
		moon["el"] = light.y
		sprites.append(moon)
	for it in sprites:
		var az: float = it["az"]
		var el: float = it["el"]
		var dir := Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))
		var q := QuadMesh.new()
		q.size = it["size"] * SKY_PIXEL * SKY_DISTANCE
		var m3 := StandardMaterial3D.new()
		m3.albedo_texture = it["tex"]
		m3.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m3.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m3.disable_fog = true
		m3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m3
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = dir * SKY_DISTANCE
		sky_root.add_child(mi)


func _process(delta: float) -> void:
	sky_root.position = camera.position
	if list.has_focus() and not look:
		return
	var b := camera.global_transform.basis
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move -= b.z
	if Input.is_physical_key_pressed(KEY_S):
		move += b.z
	if Input.is_physical_key_pressed(KEY_A):
		move -= b.x
	if Input.is_physical_key_pressed(KEY_D):
		move += b.x
	if Input.is_physical_key_pressed(KEY_SPACE):
		move += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		move -= Vector3.UP
	if move != Vector3.ZERO:
		var fast := 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		camera.position += move.normalized() * speed * fast * delta
