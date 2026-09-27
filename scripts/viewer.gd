# Terra Nova map viewer: terrain, water, mission entities, named script zones, free camera.
extends Node3D

const TNData = preload("res://scripts/tn_data.gd")
const Terrain = preload("res://scripts/terrain.gd")
const GROUND = preload("res://terrain.gdshader")
const CFG := "user://viewer.cfg"

var data = TNData.new()
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
	status.text = "Right mouse: look   WASD/ZQSD: move   Space/Ctrl: up/down   Shift: fast   Wheel: speed   Tab: panel   F2: labels   F3: script zones (yellow posts)"
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
	_fill_list()


func _fill_list() -> void:
	missions = data.mission_list()
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
	# m["veg"] (map resources 120-149) are NOT placed objects: 30 lists, one per ground type,
	# used by the engine to scatter vegetation (their coordinates are a pattern, some fall
	# outside the map or in water). Not drawn until that generation is understood.
	var counts := {}
	for e in mis["entities"]:
		_add_object(m, e["cls"], e["sub"], e["x"], e["y"], e["heading"], e["group"], true)
		counts[e["cls"]] = counts.get(e["cls"], 0) + 1
	for z in mis["zones"]:
		_add_zone(m, z)
	current = {"map": m, "mission": mis, "entry": entry}
	_place_camera(m, mis)
	info.text = "%s\nmap %s (%s), %d objects, %d named zones%s\nloaded in %.1f s" % [
		entry["label"], mis["map"], m["planet"], mis["entities"].size(), mis["zones"].size(), note,
		(Time.get_ticks_msec() - t0) / 1000.0]
	print(info.text.replace("\n", " | "))
	var args := OS.get_cmdline_user_args()
	var s := args.find("--shot")
	if s >= 0 and s + 1 < args.size():
		_screenshot(args[s + 1])


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
	var ground := TNData.height_at(m, x, y)
	var mesh: Mesh
	var mat: Material
	var lift := 0.0
	match cls:
		0:
			var low := name.to_lower()
			if low.contains("arbre") or low.contains("tree"):
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 1.2
				cone.height = 5.0
				mesh = cone
				mat = mats["tree"]
			elif low.contains("buisson") or low.contains("bush"):
				var sph := SphereMesh.new()
				sph.radius = 0.8
				sph.height = 1.2
				mesh = sph
				mat = mats["tree"]
			elif low.contains("rocher") or low.contains("rock"):
				var rb := BoxMesh.new()
				rb.size = Vector3(2, 1.4, 2)
				mesh = rb
				mat = mats["rock"]
			else:
				var db := BoxMesh.new()
				db.size = Vector3(1.2, 1.2, 1.2)
				mesh = db
				mat = mats["decor"]
		1:
			var u := BoxMesh.new()
			u.size = Vector3(0.9, 2.2, 0.9)
			mesh = u
			mat = mats["friend"] if data.is_friendly(name) else mats["enemy"]
		2:
			var vb := BoxMesh.new()
			vb.size = Vector3(2.2, 1.4, 3.4)
			mesh = vb
			mat = mats["friend"] if data.is_friendly(name) else mats["enemy"]
		3:
			var ab := PrismMesh.new()
			ab.size = Vector3(2.5, 0.8, 3.0)
			mesh = ab
			mat = mats["friend"] if data.is_friendly(name) else mats["enemy"]
			# the mission files store no altitude (always 0): ships sit on the ground / dock,
			# only probes are shown hovering a little
			var low3 := name.to_lower()
			lift = 3.0 if low3.contains("sonde") or low3.contains("probe") else 0.0
		_:
			var bb := BoxMesh.new()
			bb.size = Vector3(4, 3, 4)
			mesh = bb
			mat = mats["building"]
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var aabb := mesh.get_aabb()
	mi.position = Vector3(x, ground + lift + aabb.size.y * 0.5, y)
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
		l.position = Vector3(0, aabb.size.y * 0.5 + 1.2, 0)
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
