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
	# Every closed loop field (waist, hips, bust, underbust, leg_circ,
	# wrist, neck_w) now resolves straight to the real, safely bounded-
	# shortened geodesic loop from TOOL_geodesiac_path's
	# --measure-loop-bounded-shorten (fixed 2026-11-08: the library's
	# maxRelativeLengthDecrease parameter had inverted semantics -- see
	# datasource-anny-render-corpus's export_real_geodesic_paths.py and
	# CHANGELOG.md for the full story). No plane-cut rendering
	# workaround needed anymore: this manifest path IS the smooth curve.
	var loop_fields := ["waist", "hips", "bust", "underbust", "leg_circ", "wrist", "neck_w"]
	var callouts: Array = []   # [{name, anchor: Vector3, color: Color}]
	const CORPUS_ROOT := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/"

	if manifest != null:
		for field_name in manifest.keys():
			var closed: bool = field_name in loop_fields
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
			var mi := _line_mesh(pts, BRIGHT, closed)
			root.add_child(mi)
			callouts.append({"name": field_name, "anchor": pts[pts.size() / 2], "color": BRIGHT})

	var euclid = _load_json(EUCLID)
	if euclid != null:
		# shoulder_w, armscye_depth, bust_points, bum_points moved to the
		# real geodesic manifest above (iFire: "use geodesic for the ones
		# that seem like tape measurable" -- a tailor runs the tape along
		# the surface for all four). head_l remains a straight axis
		# extent (a tailor uses a rule/stadiometer for height-style
		# measurements, not a draped tape over the scalp).
		for field_name in ["head_l"]:
			if not euclid.has(field_name) or euclid[field_name] == null:
				continue
			var pair = euclid[field_name]
			var pts := PackedVector3Array()
			for p in pair:
				pts.append(Vector3(p[0], p[1], p[2]))
			var mi := _line_mesh(pts, AMBER, false)
			root.add_child(mi)
			callouts.append({"name": field_name, "anchor": (pts[0] + pts[1]) / 2.0, "color": AMBER})

	_layout_callouts(label_layer, cam, callouts)
	print("added ", callouts.size(), " real measurement overlay curves")



# Standard diagramming technique: a leader line drawn from the real
# measurement point OUT to a margin column, with the text label at the
# far end of the leader -- not text sitting on top of the curve/body it
# describes. Anchors are bucketed left/right of the image centre (so a
# leader never has to cross the body) and evenly spaced vertically
# within each margin to avoid label overlap, same idea standard
# anatomical/engineering diagrams use.
func _layout_callouts(label_layer: CanvasLayer, cam: Camera3D, callouts: Array) -> void:
	var w := float(root.size.x)
	var h := float(root.size.y)
	var left: Array = []
	var right: Array = []
	for c in callouts:
		var screen := cam.unproject_position(c["anchor"])
		c["screen"] = screen
		if screen.x < w / 2.0:
			left.append(c)
		else:
			right.append(c)
	left.sort_custom(func(a, b): return a["screen"].y < b["screen"].y)
	right.sort_custom(func(a, b): return a["screen"].y < b["screen"].y)

	var margin_top := 40.0
	var margin_bottom := h - 40.0
	var left_x := 195.0
	var right_x := w - 195.0

	_place_column(label_layer, left, left_x, margin_top, margin_bottom, false)
	_place_column(label_layer, right, right_x, margin_top, margin_bottom, true)


func _place_column(label_layer: CanvasLayer, items: Array, margin_x: float,
		top: float, bottom: float, right_aligned: bool) -> void:
	var n := items.size()
	if n == 0:
		return
	var step: float = (bottom - top) / max(1, n - 1) if n > 1 else 0.0
	# Type-opo boundary labeling (Bekos, Kaufmann, Symvonis & Wolff,
	# "Boundary Labeling: Models and Efficient Algorithms for
	# Rectangular Maps", Comput. Geom. 36(3), 2007 -- the leader-line
	# classification this package already names in its own docs): a
	# 3-segment orthogonal-parallel-orthogonal leader per site, with
	# EACH leader given its own unique "rail" x for the parallel
	# (height-adjusting) segment, not one shared boundary line for all
	# of them. iFire: "lines extending out should never overlap" --
	# the PRIOR 2-segment construction put every leader's vertical run
	# on the exact same x=margin_x; whenever two anchors' y-spans
	# overlapped (common once more than a couple of labels stack up),
	# their vertical segments literally coincided along a shared
	# sub-range, not merely crossed. Distinct per-leader rails make
	# that geometrically impossible: no two leaders can share any
	# point on their parallel segment if the segments live on
	# different x-coordinates. Rails are assigned in the SAME sorted
	# order as the anchors/labels (both already sorted by screen.y
	# before this call), which is the paper's Lemma 5/Theorem 9
	# condition for a non-crossing one-side labeling.
	const RAIL_BASE := 14.0
	const RAIL_SPACING := 14.0
	# Rails sit BETWEEN the margin and the anchors (toward image
	# center), never past the margin off-canvas: left column's rails
	# move right (+x) from margin_x toward center; right column's
	# rails move left (-x) from margin_x toward center.
	var rail_sign := -1.0 if right_aligned else 1.0
	for i in n:
		var c = items[i]
		var anchor: Vector2 = c["screen"]
		var label_y: float = top + step * i if n > 1 else (top + bottom) / 2.0
		var label_pos := Vector2(margin_x, label_y)
		var rail_x := margin_x + rail_sign * (RAIL_BASE + float(i) * RAIL_SPACING)
		_draw_leader(label_layer, anchor, rail_x, label_pos, c["color"])
		_add_label(label_layer, label_pos, c["name"], c["color"], right_aligned)


# Type-opo leader (Bekos et al. 2007): orthogonal (anchor -> rail at
# anchor's height) -> parallel (rail: anchor's height -> label's
# height, on this leader's OWN unique rail_x) -> orthogonal (rail ->
# label). Plus a small dot marking the exact measurement point.
func _draw_leader(label_layer: CanvasLayer, anchor: Vector2, rail_x: float, label_pos: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color(color.r, color.g, color.b, 0.75)
	line.add_point(anchor)
	line.add_point(Vector2(rail_x, anchor.y))
	line.add_point(Vector2(rail_x, label_pos.y))
	line.add_point(label_pos)
	label_layer.add_child(line)

	var dot := Line2D.new()  # a tiny filled circle approximation via a short thick point
	dot.width = 5.0
	dot.default_color = color
	dot.add_point(anchor - Vector2(0.01, 0))
	dot.add_point(anchor + Vector2(0.01, 0))
	label_layer.add_child(dot)


func _add_label(label_layer: CanvasLayer, screen_pos: Vector2, text: String, color: Color, right_aligned: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.size = Vector2(170, 16)
	if right_aligned:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.position = Vector2(screen_pos.x, screen_pos.y - 8)
	else:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.position = Vector2(screen_pos.x - 170, screen_pos.y - 8)
	label_layer.add_child(lbl)
