extends SceneTree
# Real x-ray render of the ANNY-SOMA-X mesh using Godot's real AVBOIT
# (order-independent transparency, entities-godot's dev/
# order-independent-transparency branch) -- not a matplotlib wireframe,
# not sorted alpha blending. iFire: "please do x-ray using godot order
# independent transparency. see entities-godot oit".
#
# Requires a project.godot with rendering/oit/enabled=true (this
# project's project.godot sets it) and the OIT-build
# godot.macos.editor.double.arm64 from the dev/order-independent-
# transparency worktree -- the stock engine has no rendering/oit/*
# setting at all and will silently ignore it.
#
# The mesh is drawn as ONE translucent surface (BaseMaterial3D,
# TRANSPARENCY_ALPHA, low alpha, unshaded so lighting doesn't hide the
# x-ray effect) so every layer of the body (front skin, spine, back
# skin) is visible through every other layer, composited in the correct
# depth order regardless of triangle draw order -- the actual point of
# OIT, and the actual point of an x-ray view of a body mesh.

const USDA_PATH := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny-soma-x.usda"
const OBJ_PATH := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny-soma-x.obj"
const OUT_PNG := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny_xray_oit.png"


func _init() -> void:
	# sanity: confirm this IS the OIT build, not the stock engine --
	# refuse to produce a fake x-ray if the setting doesn't exist.
	if not ProjectSettings.has_setting("rendering/oit/enabled"):
		printerr("rendering/oit/enabled does not exist on this engine build -- " +
			"this is NOT the dev/order-independent-transparency build. Refusing " +
			"to render a fake x-ray with sorted alpha blending.")
		quit(1)
		return
	if not bool(ProjectSettings.get_setting("rendering/oit/enabled")):
		printerr("rendering/oit/enabled is false -- set it in project.godot")
		quit(1)
		return
	print("Confirmed: running on the real AVBOIT build, rendering/oit/enabled=true, " +
		"slice_count=", ProjectSettings.get_setting("rendering/oit/slice_count"))

	root.size = Vector2i(1024, 1024)
	root.transparent_bg = false

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.93, 0.95)  # light background, for text labels
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = false
	env.glow_enabled = false

	var cam := Camera3D.new()
	cam.environment = env
	cam.fov = 35.0
	cam.near = 0.05
	cam.far = 10.0
	root.add_child(cam)
	await process_frame

	# load the real ANNY-SOMA-X mesh (same OBJ this pipeline already
	# exports for flip_geodesics) via ImporterMesh/ArrayMesh, same
	# winding-swap pattern as adapters/suit_board_probe.gd.
	var obj_bytes := FileAccess.get_file_as_string(OBJ_PATH)
	if obj_bytes.is_empty():
		printerr("could not read OBJ at ", OBJ_PATH)
		quit(1)
		return

	var verts: PackedVector3Array = PackedVector3Array()
	var faces: Array = []
	for line in obj_bytes.split("\n"):
		if line.begins_with("v "):
			var parts = line.split(" ", false)
			verts.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
		elif line.begins_with("f "):
			var parts2 = line.split(" ", false)
			var idx: Array = []
			for p in parts2.slice(1):
				idx.append(int(p.split("/")[0]) - 1)
			faces.append(idx)
	print("loaded mesh: ", verts.size(), " verts, ", faces.size(), " faces")

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		# winding swap (aruco-marker-visibility-testing skill's warning,
		# same as adapters/suit_board_probe.gd): OBJ export winds the
		# opposite way Godot expects for front-facing normals.
		st.add_vertex(verts[f[0]])
		st.add_vertex(verts[f[2]])
		st.add_vertex(verts[f[1]])
	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.15, 0.35, 0.55, 0.22)  # darker steel-blue, low alpha: x-ray look on a light background
	array_mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = array_mesh
	root.add_child(mi)
	await process_frame

	# frame the mesh: center camera on its AABB, back off along -Y
	# (front view, matching the wireframe render's X/Z front-view convention)
	var aabb := array_mesh.get_aabb()
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	cam.position = center + Vector3(0, -radius * 2.6, 0)
	cam.look_at(center, Vector3(0, 0, 1))

	# overlay the real measurement curves/lines on top of the x-ray body
	# -- opaque bright lines (not OIT: these are 1D curves, not
	# surfaces, so there's nothing for OIT to resolve), loaded from the
	# same real geodesic/Euclidean data the wireframe diagram used --
	# plus real text labels (CanvasLayer/Label, screen-projected via
	# Camera3D.unproject_position), so field names are readable on the
	# light background.
	var label_layer := CanvasLayer.new()
	root.add_child(label_layer)
	await process_frame
	_add_measurement_overlays(cam, label_layer)

	for i in 10:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT_PNG)
	print("wrote ", OUT_PNG)
	quit(0)


func _line_mesh(points: PackedVector3Array, color: Color, closed: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		st.add_vertex(p)
	if closed and points.size() > 1:
		st.add_vertex(points[0])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = false
	m.albedo_color = color
	m.no_depth_test = false
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	return JSON.parse_string(txt)


func _add_measurement_overlays(cam: Camera3D, label_layer: CanvasLayer) -> void:
	const MANIFEST := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/paths_manifest.json"
	const EUCLID := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/euclidean_lines.json"
	const BRIGHT := Color(0.0, 0.45, 0.1, 1.0)    # dark green: real curved geodesics / loops, on a light bg
	const AMBER := Color(0.75, 0.42, 0.0, 1.0)    # dark amber: real Euclidean straight-line fields

	var manifest = _load_json(MANIFEST)
	var overlay_count := 0
	const CORPUS_ROOT := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/"
	if manifest != null:
		for field_name in manifest.keys():
			var rel_path: String = str(manifest[field_name])
			var abs_path := rel_path if rel_path.begins_with("/") else CORPUS_ROOT + rel_path
			var path_json = _load_json(abs_path)
			if path_json == null or path_json.is_empty():
				continue
			var line = path_json[0]
			if line.size() < 2:
				continue
			var pts := PackedVector3Array()
			for p in line:
				pts.append(Vector3(p[0], p[1], p[2]))
			var closed: bool = field_name in ["waist", "hips", "bust", "underbust", "leg_circ", "wrist"]
			var mi := _line_mesh(pts, BRIGHT, closed)
			root.add_child(mi)
			_add_label(label_layer, cam, pts[pts.size() / 2], field_name, BRIGHT)
			overlay_count += 1

	var euclid = _load_json(EUCLID)
	if euclid != null:
		for field_name in ["shoulder_w", "armscye_depth", "bust_points", "bum_points", "head_l"]:
			if not euclid.has(field_name) or euclid[field_name] == null:
				continue
			var pair = euclid[field_name]
			var pts := PackedVector3Array()
			for p in pair:
				pts.append(Vector3(p[0], p[1], p[2]))
			var mi := _line_mesh(pts, AMBER, false)
			root.add_child(mi)
			_add_label(label_layer, cam, (pts[0] + pts[1]) / 2.0, field_name, AMBER)
			overlay_count += 1
		if euclid.has("neck_w_loop") and euclid["neck_w_loop"] != null:
			var pts2 := PackedVector3Array()
			for p in euclid["neck_w_loop"]:
				pts2.append(Vector3(p[0], p[1], p[2]))
			var mi2 := _line_mesh(pts2, BRIGHT, true)
			root.add_child(mi2)
			_add_label(label_layer, cam, pts2[0], "neck_w", BRIGHT)
			overlay_count += 1

	print("added ", overlay_count, " real measurement overlay curves")


func _add_label(label_layer: CanvasLayer, cam: Camera3D, world_pos: Vector3, text: String, color: Color) -> void:
	var screen_pos := cam.unproject_position(world_pos)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = screen_pos
	label_layer.add_child(lbl)
