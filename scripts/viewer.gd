# Terra Nova map viewer: terrain, water, mission entities, named script zones, free camera.
extends Node3D

const TNData = preload("res://scripts/tn_data.gd")
const Terrain = preload("res://scripts/terrain.gd")
const TNObjects = preload("res://scripts/tn_objects.gd")
const GROUND = preload("res://terrain.gdshader")
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
	var env := Environment.new()
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
	world = Node3D.new()
	add_child(world)
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
	var nveg := _add_vegetation(m)
	var counts := {}
	for e in mis["entities"]:
		_add_object(m, e["cls"], e["sub"], e["x"], e["y"], e["heading"], e["group"], true)
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
		label: bool) -> void:
	var name: String = data.type_name(cls, sub)
	var low := name.to_lower()
	var ground := TNData.height_at(m, x, y)
	# the mission files store no altitude (always 0): ships sit on the ground / dock,
	# only probes are shown hovering a little
	var lift := 3.0 if cls == 3 and (low.contains("sonde") or low.contains("probe")) else 0.0
	var mi := MeshInstance3D.new()
	var top := 0.0
	var ref: Vector2i = objects.ref_for(cls, sub) if objects_ok else Vector2i.ZERO
	if TNObjects.is_model(ref):
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
	if mi.mesh == null:                 # nothing in the data (soldiers are animated sprites)
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


func _process(delta: float) -> void:
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
