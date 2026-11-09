extends SceneTree
# Real OIT-rendered measurement SVG: the body is rendered through
# Godot's actual AVBOIT (order-independent transparency) 3D pipeline --
# iFire 2026-11-08, after the pure-vector silhouette-edge version:
# "you must use order independent rendering. it is very wrong." The
# prior silhouette-edge CPU test (front/back-facing sign flip per
# edge) has no notion of occlusion: it drew edges that were correct
# "silhouette" edges in isolation but actually hidden behind nearer
# body geometry from that view, since there was no depth test at all --
# a 2D vector approximation can't solve that; real depth-tested 3D
# rendering can, trivially, per-fragment, with no sort-order
# dependency (the actual point of OIT: no per-triangle draw-order
# sorting needed for correct transparency compositing either).
#
# Clarified approach (iFire, 2026-11-08): render the body via the real
# OIT pipeline (same technique as adapters/xray_oit_render.gd) to a
# PNG per view, embed that PNG as the SVG's body background, with
# labels and leader lines as a vector overlay on top -- so the
# labeling/layout code (type-opo boundary labeling, capacity-balanced
# per-field view assignment, real cm/deg values) stays exactly as
# validated, just driven by Godot's own cam.unproject_position() for
# pixel-perfect alignment with the rendered PNG, instead of a
# hand-rolled dot-product projection that could drift from what's
# actually on screen.
#
# Camera: orthogonal (not perspective) -- matches the uniform-scale
# assumption the boundary-labeling math and the SVG pixel transform
# both rely on; a perspective camera's foreshortening would make
# anchor-to-pixel distances non-uniform across the frame.
#
# Measurement curves (circumference loops, geodesic/Euclidean lines)
# are REAL triangulated ribbon meshes, not flat lines: Godot's
# PRIMITIVE_LINE_STRIP renders at a fixed ~1px regardless of material
# width, invisible once scaled into the composite. iFire 2026-11-08:
# "wait a second isn't this merely curvenet + slughorn. like pen
# meshing + sliced to 2d?" -- a stroked ribbon around a curve is an
# annulus in the curve's own local 2D plane (outer offset = boundary,
# inner offset = hole), which is exactly curvenet.elf's
# cdt2d_triangulate (Constrained Delaunay with hole removal,
# GEO::CDT2d, the same triangulator mesh_build already trusts) --
# "sliced to 2D" is the plane projection, curvenet does the real
# triangulation. See _ribbon_mesh_curvenet. Depth-tested against the
# body (a curve on the far side is correctly hidden) and baked into
# the same PNG as the body.
#
# RUNTIME DEPENDENCY (not vendored into this repo): curvenet.elf +
# addons/godot_sandbox/, copied straight from meshing-pen's
# 1-transport/meshing-pen (not rebuilt -- real, already-tested guest).
# Both are present in the Godot project this script actually runs
# from (currently a scratch project outside this repo); if curvenet.elf
# is missing or the Sandbox class isn't registered, ribbons are
# silently skipped (see _ribbon_mesh_curvenet's `sb == null` guard) --
# everything else (body render, labels, leaders) still works.
#
# Camera distribution: the REAL sphere_hammersley_sequence
# (TencentARC/Pixal3D @ cdbb2bb), ported exactly from this repo's own
# render_view.py -- not a hand-rolled orbit. 4 real samples from a
# 16-sample sequence (indices 4/6/5/7: smallest-pitch combination
# Camera distribution: the REAL sphere_hammersley_sequence
# (TencentARC/Pixal3D @ cdbb2bb), ported exactly from this repo's own
# render_view.py -- not a hand-rolled orbit. iFire 2026-11-08: "can
# you only use two views. left and right." -- picked the 2 real
# samples (from a 128-sample sequence, searched for the closest match)
# nearest true left/right profile (yaw 90/270 degrees) with the
# smallest pitch: index 34 -> yaw 95.6deg pitch 1.2deg (left),
# index 35 -> yaw 275.6deg pitch 1.8deg (right). Still real Hammersley
# samples, not hand-picked angles -- just a different, smaller subset
# of the same real sequence used before.

const CORPUS_ROOT := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/"
const OBJ_PATH := CORPUS_ROOT + "build/anny_export/anny-soma-x.obj"
const EXPORT_DIR := CORPUS_ROOT + "build/anny_export/"
const OUT_SVG := EXPORT_DIR + "anny_measurement_wireframe_godot.svg"

const LOOP_FIELDS := ["waist", "hips", "bust", "underbust", "leg_circ", "wrist", "neck_w"]
const EUCLID_DASHED_FIELDS := ["shoulder_w", "armscye_depth", "bust_points", "bum_points"]
const HAMMERSLEY_N := 128
const VIEW_INDICES := [34, 35]
const NUM_VIEWS := 2
const PRIMES0 := 2
const IMG_W := 500
const IMG_H := 950  # sized (with TEXT_MARGIN/TITLE_H below) so the 2-panel composite lands on exactly 1920x1080 (iFire: "go back to 1080p")
const TEXT_MARGIN := 215.0
const TITLE_H := 40.0
const VTRACER_PATH := "/Users/ernest.lee/.local/bin/vtracer"


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(txt) != OK:
		printerr("failed to parse JSON: ", path)
		return null
	return json.data


# Exact port of render_view.py's radical_inverse (base-2 van der Corput).
func _radical_inverse(base: int, n: int) -> float:
	var val := 0.0
	var inv_base := 1.0 / base
	var inv_base_n := inv_base
	while n > 0:
		val += (n % base) * inv_base_n
		n = n / base
		inv_base_n *= inv_base
	return val


# Exact port of render_view.py's sphere_hammersley(i, num_samples, offset).
func _sphere_hammersley(i: int, num_samples: int, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var u: float = float(i) / num_samples + offset.x / num_samples
	var v: float = _radical_inverse(PRIMES0, i) + offset.y
	u = 2.0 * u if u < 0.25 else (2.0 / 3.0) * u + 1.0 / 3.0
	var theta: float = acos(1.0 - 2.0 * u) - PI / 2.0
	var phi: float = v * 2.0 * PI
	return Vector2(phi, theta)


func _init() -> void:
	# sanity: confirm this IS the OIT build (same check as xray_oit_render.gd)
	if not ProjectSettings.has_setting("rendering/oit/enabled") or not bool(ProjectSettings.get_setting("rendering/oit/enabled")):
		printerr("rendering/oit/enabled is not set -- this is NOT the OIT build. Refusing to fake it.")
		quit(1)
		return

	# iFire 2026-11-08: "you can reuse our slug code" -> "wait a second
	# isn't this merely curvenet + slughorn" -- curvenet.elf (already
	# built, already a godot-sandbox guest, vendored straight from
	# meshing-pen, not rebuilt) already has a REAL, tested Constrained
	# Delaunay triangulator with hole removal (cdt2d_triangulate,
	# GEO::CDT2d). A stroked ribbon around a curve is exactly an
	# annulus in the curve's own local 2D plane: the outer offset
	# curve is the boundary, the inner offset curve is the hole. This
	# replaces the earlier hand-rolled billboard quad-strip (no real
	# triangulation, no join handling) with curvenet's own tested
	# geometry code -- the same tool the garment-fitting pipeline
	# already trusts for mesh_build's triangulation.
	var curvenet_sb = null
	if not ClassDB.class_exists("Sandbox"):
		printerr("Sandbox class not registered -- godot_sandbox addon not loaded; ribbons will be skipped")
	else:
		curvenet_sb = ClassDB.instantiate("Sandbox")
		curvenet_sb.memory_max = 256
		curvenet_sb.references_max = 4096
		curvenet_sb.execution_timeout = 1 << 20
		curvenet_sb.allocations_max = 1000000
		var cn_prog = load("res://curvenet.elf")
		if cn_prog == null:
			printerr("curvenet.elf did not load -- ribbons will be skipped")
			curvenet_sb = null
		else:
			curvenet_sb.program = cn_prog
			root.add_child(curvenet_sb)
			await process_frame

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

	var body_center := Vector3.ZERO
	for v in verts:
		body_center += v
	body_center /= verts.size()
	var zmin := INF
	var zmax := -INF
	for v in verts:
		zmin = min(zmin, v.z)
		zmax = max(zmax, v.z)
	var radius := 0.0
	for v in verts:
		radius = max(radius, v.distance_to(body_center))

	var manifest = _load_json(EXPORT_DIR + "paths_manifest.json")
	var angle_values = _load_json(EXPORT_DIR + "angle_fields.json")
	var hints = _load_json(EXPORT_DIR + "layout_hints.json")
	if manifest == null or angle_values == null or hints == null:
		printerr("missing required JSON exports -- run export_real_geodesic_paths.py first")
		quit(1)
		return

	# real ArrayMesh, winding swap (same convention as xray_oit_render.gd)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		st.add_vertex(verts[f[0]])
		st.add_vertex(verts[f[2]])
		st.add_vertex(verts[f[1]])
	st.generate_normals()
	var array_mesh: ArrayMesh = st.commit()

	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body_mat.albedo_color = Color(0.70, 0.66, 0.60, 0.55)  # warm light gray, translucent OIT body
	array_mesh.surface_set_material(0, body_mat)

	# --- real 4-view Hammersley camera distribution ---
	var view_dirs: Array = []  # {eye_dir, phi, theta}
	for idx in VIEW_INDICES:
		var ph: Vector2 = _sphere_hammersley(idx, HAMMERSLEY_N, Vector2.ZERO)
		var eye_dir := Vector3(cos(ph.x) * cos(ph.y), sin(ph.x) * cos(ph.y), sin(ph.y)).normalized()
		view_dirs.append({"eye_dir": eye_dir, "phi": ph.x, "theta": ph.y})
		print("view (hammersley i=", idx, "/", HAMMERSLEY_N, ") yaw=", rad_to_deg(ph.x), "deg pitch=", rad_to_deg(ph.y), "deg")

	# --- every real curve/loop field, full 3D data ---
	var curve_items: Array = []
	for field_name in manifest.keys():
		var rel_path: String = str(manifest[field_name])
		var abs_path := rel_path if rel_path.begins_with("/") else CORPUS_ROOT + rel_path
		var path_json = _load_json(abs_path)
		if path_json == null or path_json.is_empty():
			continue
		var line3d = path_json[0]
		if line3d.size() < 2:
			continue
		var pts3d: PackedVector3Array = PackedVector3Array()
		var sum3 := Vector3.ZERO
		for p in line3d:
			var pv := Vector3(float(p[0]), float(p[1]), float(p[2]))
			pts3d.append(pv)
			sum3 += pv
		var anchor3d: Vector3 = sum3 / pts3d.size()
		var val_cm = angle_values.get(field_name + "_cm")
		var text: String = field_name
		if val_cm != null:
			text = "%s\n%.1fcm" % [field_name, float(val_cm)]
		var dashed: bool = field_name in EUCLID_DASHED_FIELDS
		curve_items.append({
			"text": text, "anchor3d": anchor3d, "pts3d": pts3d,
			"closed": field_name in LOOP_FIELDS,
			"color": Color(0.75, 0.42, 0.0) if dashed else Color(0.0, 0.45, 0.1),
			"text_color": Color(0.498, 0.235, 0.0) if dashed else Color(0.086, 0.396, 0.204),
		})

	# --- fixed-position items (angle markers, axis ticks, 2 unsettled) ---
	var torso: Dictionary = hints["torso_heights"]
	var head_top_z: float = float(hints["head_top_z"])
	var fixed_items: Array = []  # {text, pos3d, color, text_color, match_name (optional)}
	for field_name in ["shoulder_incl", "hip_inclination", "arm_pose_angle", "crotch_hip_diff"]:
		if not hints["marker_anchors"].has(field_name):
			continue
		var m = hints["marker_anchors"][field_name]
		var z_ref: float = _resolve_z_ref(str(m["z_ref"]), torso, head_top_z)
		var ax: float = float(m["dx"])
		var az: float = z_ref + float(m["dz"])
		var val = angle_values.get(field_name + "_deg")
		var unit := "deg"
		if val == null:
			val = angle_values.get(field_name + "_cm")
			unit = "cm"
		var text := "%s\n%.1f%s" % [field_name, float(val), unit]
		fixed_items.append({"text": text, "pos3d": Vector3(ax, 0.0, az),
			"color": Color(0.0, 0.45, 0.1), "text_color": Color(0.086, 0.396, 0.204)})
	for field_name in ["bust_line", "waist_over_bust_line"]:
		if not hints["marker_anchors"].has(field_name):
			continue
		var m2 = hints["marker_anchors"][field_name]
		var z_ref2: float = _resolve_z_ref(str(m2["z_ref"]), torso, head_top_z)
		var ax2: float = float(m2["dx"])
		var az2: float = z_ref2 + float(m2["dz"])
		fixed_items.append({"text": field_name, "pos3d": Vector3(ax2, 0.0, az2),
			"color": Color(0.80, 0.15, 0.15), "text_color": Color(0.498, 0.114, 0.114)})

	var axis_tick_x := {"head_l": 0.55, "vert_bust_line": 0.62}
	var axis_ticks: Array = []
	for name in axis_tick_x.keys():
		if not hints["axis_ticks"].has(name):
			continue
		var pair = hints["axis_ticks"][name]
		var za: float = float(pair[0][2])
		var zb: float = float(pair[1][2])
		var x := float(axis_tick_x[name])
		axis_ticks.append({"name": name, "pos3d_a": Vector3(x, 0.0, za), "pos3d_b": Vector3(x, 0.0, zb)})
		var tv = angle_values.get(name + "_cm")
		var tt: String = name
		if tv != null:
			tt = "%s\n%.1fcm" % [name, float(tv)]
		fixed_items.append({"text": tt, "match_name": name, "pos3d": Vector3(x, 0.0, (za + zb) / 2.0),
			"color": Color(0.0, 0.45, 0.1), "text_color": Color(0.086, 0.396, 0.204)})

	# --- capacity-balanced per-field view assignment (same algorithm as
	# the pure-vector version, just by eye_dir dict instead of ViewCam) ---
	var per_view_curves: Array = []
	var per_view_fixed: Array = []
	var per_view_axis_ticks: Array = []
	for i in NUM_VIEWS:
		per_view_curves.append([])
		per_view_fixed.append([])
		per_view_axis_ticks.append([])
	var ranked_items: Array = []
	for item in curve_items:
		var dir3: Vector3 = (item["anchor3d"] - body_center)
		dir3.z = 0.0
		if dir3.length() < 0.0001:
			dir3 = Vector3(1, 0, 0)
		dir3 = dir3.normalized()
		var dots: Array = []
		for i in NUM_VIEWS:
			var ev: Vector3 = view_dirs[i]["eye_dir"]
			dots.append({"i": i, "d": ev.dot(dir3)})
		dots.sort_custom(func(a, b): return a["d"] > b["d"])
		var ranking: Array = []
		for d in dots:
			ranking.append(d["i"])
		ranked_items.append({"item": item, "ranking": ranking, "top_dot": dots[0]["d"]})
	ranked_items.sort_custom(func(a, b): return a["top_dot"] > b["top_dot"])
	var cap: int = int(ceil(float(curve_items.size()) / NUM_VIEWS)) + 1
	for ri in ranked_items:
		var placed := false
		for view_i in ri["ranking"]:
			if per_view_curves[view_i].size() < cap:
				per_view_curves[view_i].append(ri["item"])
				placed = true
				break
		if not placed:
			per_view_curves[ri["ranking"][0]].append(ri["item"])
	for i in fixed_items.size():
		per_view_fixed[i % NUM_VIEWS].append(fixed_items[i])
	for t in axis_ticks:
		var owning_view: int = 0
		for i in fixed_items.size():
			if fixed_items[i].get("match_name", fixed_items[i]["text"]) == t["name"]:
				owning_view = i % NUM_VIEWS
				break
		per_view_axis_ticks[owning_view].append(t)

	# --- render each view through the real OIT pipeline ---
	root.size = Vector2i(IMG_W, IMG_H)
	DisplayServer.window_set_size(Vector2i(IMG_W, IMG_H))
	root.transparent_bg = false
	for i in 4:
		await process_frame
	var actual_size: Vector2i = root.get_viewport().get_visible_rect().size
	if actual_size != Vector2i(IMG_W, IMG_H):
		printerr("WARNING: viewport size is ", actual_size, " not the requested ", Vector2i(IMG_W, IMG_H),
			" -- window resize did not take effect in this run mode")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 1, 1)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = false
	env.glow_enabled = false

	var panels: Array = []
	for i in NUM_VIEWS:
		var p = await _render_view(view_dirs[i], i, array_mesh, body_center, zmin, zmax, radius, env,
			per_view_curves[i], per_view_fixed[i], per_view_axis_ticks[i], curvenet_sb)
		panels.append(p)

	var svg := _compose_tiled_svg(panels)
	var f_out := FileAccess.open(OUT_SVG, FileAccess.WRITE)
	f_out.store_string(svg)
	f_out.close()
	print("wrote ", OUT_SVG, " (", svg.length(), " bytes)")
	quit(0)


func _resolve_z_ref(name: String, torso: Dictionary, head_top_z: float) -> float:
	if name == "head_top_z":
		return head_top_z
	if name == "waist_bust_mid":
		return (float(torso["waist"]) + float(torso["bust"])) / 2.0
	return float(torso[name])


# Real tube/ribbon geometry around a 3D curve via curvenet.elf's
# cdt2d_triangulate (Constrained Delaunay with hole removal, GEO::CDT2d
# -- the same triangulator mesh_build already trusts). A stroked
# ribbon is exactly an annulus in the curve's own local 2D plane: the
# outer offset curve is the boundary, the inner offset curve is the
# hole (closed curves); an open curve is one simple strip polygon
# (outer forward + inner reversed, butt-capped ends), no hole needed.
#
# 1. Fit a local 2D plane via Newell's method (sum of p_i x p_{i+1}
#    over the polygon -- the standard best-fit-normal formula for a
#    roughly-planar polygon; these anatomical curves are all close to
#    planar). A 2-point open line has no well-defined normal, so it
#    falls back to an arbitrary perpendicular.
# 2. Project to 2D, offset ±half_width perpendicular to each vertex's
#    local tangent, hand the outline to curvenet, read back its real
#    triangulation, and map the 2D result back to 3D through the same
#    plane basis.
func _ribbon_mesh_curvenet(sb, points: PackedVector3Array, color: Color, closed: bool, half_width: float) -> MeshInstance3D:
	if sb == null or points.size() < 2:
		return null
	var n := points.size()

	var normal := Vector3.ZERO
	for i in n:
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % n]
		normal += a.cross(b)
	if normal.length() < 0.000001:
		var tangent0 := (points[1] - points[0]).normalized()
		normal = tangent0.cross(Vector3(0, 0, 1))
		if normal.length() < 0.001:
			normal = tangent0.cross(Vector3(1, 0, 0))
	normal = normal.normalized()

	var origin := Vector3.ZERO
	for p in points:
		origin += p
	origin /= n

	var u := Vector3(1, 0, 0).cross(normal)
	if u.length() < 0.001:
		u = Vector3(0, 1, 0).cross(normal)
	u = u.normalized()
	var v := normal.cross(u).normalized()

	var p2d: PackedVector2Array = PackedVector2Array()
	for p in points:
		var d: Vector3 = p - origin
		p2d.append(Vector2(d.dot(u), d.dot(v)))

	var outer2d := PackedVector2Array()
	var inner2d := PackedVector2Array()
	for i in n:
		var prev_i := (i - 1 + n) % n if closed else maxi(0, i - 1)
		var next_i := (i + 1) % n if closed else mini(n - 1, i + 1)
		var tang: Vector2 = (p2d[next_i] - p2d[prev_i])
		if tang.length() < 0.000001:
			tang = Vector2(1, 0)
		tang = tang.normalized()
		var perp := Vector2(-tang.y, tang.x) * half_width
		outer2d.append(p2d[i] + perp)
		inner2d.append(p2d[i] - perp)

	var boundary_xy := PackedFloat32Array()
	var holes_xy := PackedFloat32Array()
	var hole_counts := PackedInt32Array()
	if closed:
		for p in outer2d:
			boundary_xy.append(p.x); boundary_xy.append(p.y)
		for i in inner2d.size():
			var p2: Vector2 = inner2d[inner2d.size() - 1 - i]  # reversed: a hole winds opposite the outer boundary
			holes_xy.append(p2.x); holes_xy.append(p2.y)
		hole_counts.append(inner2d.size())
	else:
		for p in outer2d:
			boundary_xy.append(p.x); boundary_xy.append(p.y)
		for i in inner2d.size():
			var p3: Vector2 = inner2d[inner2d.size() - 1 - i]
			boundary_xy.append(p3.x); boundary_xy.append(p3.y)

	var interior_xy := PackedFloat32Array()
	var r = sb.callv("vmcall", ["cdt2d_triangulate", boundary_xy, holes_xy, hole_counts, interior_xy])
	var r_str := str(r)
	if not r_str.begins_with("ok"):
		printerr("cdt2d_triangulate failed: ", r_str)
		return null

	var out_pts = sb.callv("vmcall", ["cdt2d_points"])
	var out_faces = sb.callv("vmcall", ["cdt2d_faces"])
	if typeof(out_pts) != TYPE_PACKED_FLOAT32_ARRAY or typeof(out_faces) != TYPE_PACKED_INT32_ARRAY:
		printerr("cdt2d_points/cdt2d_faces: unexpected types")
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts3: PackedVector3Array = PackedVector3Array()
	for i in out_pts.size() / 2:
		var px: float = out_pts[i * 2]
		var py: float = out_pts[i * 2 + 1]
		pts3.append(origin + u * px + v * py)
	for i in out_faces.size() / 3:
		var i0: int = out_faces[i * 3]
		var i1: int = out_faces[i * 3 + 1]
		var i2: int = out_faces[i * 3 + 2]
		st.add_vertex(pts3[i0]); st.add_vertex(pts3[i1]); st.add_vertex(pts3[i2])

	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = false  # real depth test: a curve behind the body is correctly hidden
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _render_view(vd: Dictionary, view_idx: int, array_mesh: ArrayMesh, body_center: Vector3,
		zmin: float, zmax: float, radius: float, env: Environment,
		curve_items: Array, fixed_items: Array, axis_ticks_panel: Array, curvenet_sb) -> Dictionary:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	await process_frame

	var body_mi := MeshInstance3D.new()
	body_mi.mesh = array_mesh
	scene_root.add_child(body_mi)

	var half_width := 0.013  # world units; kept at ~2.6cm-scale (world-space ribbon width is independent of render pixel resolution)
	for item in curve_items:
		var mi := _ribbon_mesh_curvenet(curvenet_sb, item["pts3d"], item["color"], item["closed"], half_width)
		if mi != null:
			scene_root.add_child(mi)
	for t in axis_ticks_panel:
		var pts := PackedVector3Array([t["pos3d_a"], t["pos3d_b"]])
		var mi2 := _ribbon_mesh_curvenet(curvenet_sb, pts, Color(0.0, 0.45, 0.1), false, half_width)
		if mi2 != null:
			scene_root.add_child(mi2)

	var cam := Camera3D.new()
	cam.environment = env
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = (zmax - zmin) + 0.35  # world-space vertical extent, +margin above/below body
	cam.near = 0.01
	cam.far = radius * 8.0
	var eye_dir: Vector3 = vd["eye_dir"]
	cam.position = body_center + eye_dir * radius * 3.0
	scene_root.add_child(cam)
	var up := Vector3(0, 0, 1)
	if absf(eye_dir.dot(up)) > 0.999:
		up = Vector3(1, 0, 0)
	cam.look_at(body_center, up)

	for i in 6:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	# iFire 2026-11-08: "please vtracer to convert raster to vector" --
	# the body render is no longer embedded as a <image> (base64 PNG
	# blob); it is traced into REAL vector <path> elements by the real
	# vtracer CLI (visioncortex/vtracer, installed binary, not the
	# PyPI Python binding which segfaults on Python 3.14 -- see the
	# vtracer-install skill's own warning). Saved to a real temp PNG,
	# shelled out via OS.execute, result parsed back as vector markup.
	var png_path := EXPORT_DIR + ("panel_%d.png" % view_idx)
	var svg_path := EXPORT_DIR + ("panel_%d_traced.svg" % view_idx)
	img.save_png(png_path)
	var out: Array = []
	var exit_code := OS.execute(VTRACER_PATH, [
		"-i", png_path, "-o", svg_path,
		"--mode", "polygon", "--color-precision", "6", "--filter-speckle", "4",
	], out, true)
	var body_vector := ""
	if exit_code == 0 and FileAccess.file_exists(svg_path):
		var traced := FileAccess.get_file_as_string(svg_path)
		# Keep only the real traced <path> elements -- strip vtracer's
		# own <?xml?>/<svg>/</svg> wrapper, which this function's
		# caller re-wraps in its own <g transform> instead.
		var start := traced.find("<path")
		var end := traced.rfind("</svg>")
		if start != -1 and end != -1:
			body_vector = traced.substr(start, end - start)
	if body_vector.is_empty():
		printerr("vtracer trace failed for view ", view_idx, " (exit=", exit_code, ", out=", out,
			") -- falling back to the raw raster <image> embed for this panel only")
		var png_bytes: PackedByteArray = img.save_png_to_buffer()
		var b64 := Marshalls.raw_to_base64(png_bytes)
		body_vector = '<image x="0" y="0" width="%d" height="%d" href="data:image/png;base64,%s"/>' % [IMG_W, IMG_H, b64]

	# --- pixel-perfect anchors via Godot's OWN camera projection ---
	var label_queue: Array = []
	for item in curve_items:
		var p: Vector2 = cam.unproject_position(item["anchor3d"])
		label_queue.append({"text": item["text"], "x": p.x, "z": p.y, "color": item["text_color"]})
	for item2 in fixed_items:
		var p2: Vector2 = cam.unproject_position(item2["pos3d"])
		label_queue.append({"text": item2["text"], "x": p2.x, "z": p2.y, "color": item2["text_color"]})

	scene_root.queue_free()
	await process_frame

	var body := _panel_svg(view_idx, vd, body_vector, label_queue)
	return {"body": body, "w": float(IMG_W) + 2.0 * TEXT_MARGIN, "h": float(IMG_H) + TITLE_H}


# Type-opo boundary labeling over REAL screen-pixel anchors (from
# cam.unproject_position -- guaranteed to match the traced vector
# body pixel-for-pixel, since the trace is 1:1 on the same raster
# Godot's own camera produced).
func _panel_svg(view_idx: int, vd: Dictionary, body_vector: String, label_queue: Array) -> String:
	var w := float(IMG_W) + 2.0 * TEXT_MARGIN
	var img_x0 := TEXT_MARGIN
	# Rails terminate just outside the image edge; labels live in the
	# remaining TEXT_MARGIN band beyond that, growing AWAY from the
	# image (left column: right-aligned text growing further left;
	# right column: left-aligned text growing further right) -- not
	# at the canvas edge itself, which left zero room for the text
	# and clipped it against the SVG boundary.
	var left_margin_x := img_x0 - 15.0
	var right_margin_x := img_x0 + float(IMG_W) + 15.0

	var left_q: Array = []
	var right_q: Array = []
	for item in label_queue:
		if item["x"] < float(IMG_W) / 2.0:
			left_q.append(item)
		else:
			right_q.append(item)
	left_q.sort_custom(func(a, b): return a["z"] < b["z"])
	right_q.sort_custom(func(a, b): return a["z"] < b["z"])

	var leader_lines: Array = []
	var label_texts: Array = []
	# iFire: "the labels are clipping" -- the top/bottom of the label
	# column used the panel's own raw TITLE_H/height bounds, so the
	# first and last labels' text baselines sat exactly ON the panel's
	# top/bottom border, and a 2-line label's second row (offset below
	# the baseline) rendered PAST the border into the next panel/page
	# margin. Inset the usable column range by half a label's own
	# height on each end, so even the first/last item's full 2-line
	# text stays inside the panel.
	var label_half_height := 16.0
	var col_top := TITLE_H + label_half_height
	var col_bottom := float(IMG_H) + TITLE_H - label_half_height
	_place_column(left_q, left_margin_x, -1.0, img_x0, img_x0 + float(IMG_W), col_top, col_bottom, leader_lines, label_texts)
	_place_column(right_q, right_margin_x, 1.0, img_x0, img_x0 + float(IMG_W), col_top, col_bottom, leader_lines, label_texts)

	var parts: Array = []
	parts.append('<rect width="100%%" height="100%%" fill="white"/>'.replace("%%", "%"))
	var title := "view %d — yaw %.0f° pitch %.0f°" % [view_idx, rad_to_deg(vd["phi"]), rad_to_deg(vd["theta"])]
	parts.append('<text x="%.1f" y="26" font-family="Helvetica, Arial, sans-serif" font-size="18" font-weight="700" text-anchor="middle" fill="#000">%s</text>' % [w / 2.0, title])
	parts.append('<g transform="translate(%.1f,%.1f)">%s</g>' % [img_x0, TITLE_H, body_vector])

	for ll in leader_lines:
		parts.append('<path d="%s" fill="none" stroke="#000" stroke-width="1.0"/>' % _pts_to_path(ll["pts"]))
		var a0: Vector2 = ll["anchor"]
		# iFire 2026-11-08: "use something instead of a solid circle
		# for minature figures pointings" -- model-kit/Gunpla manuals
		# mark a callout point with a small OPEN ring (a reticle), not
		# a solid filled dot: it reads as "point at this exact spot"
		# without a heavy blob obscuring the measurement tape curve
		# directly underneath it.
		parts.append('<circle cx="%.2f" cy="%.2f" r="3.6" fill="none" stroke="#000" stroke-width="1.2"/>' % [a0.x, a0.y])

	for lt in label_texts:
		var lines: Array = str(lt["text"]).split("\n")
		var col: Color = lt["color"]
		var hexcol := "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]
		for li in lines.size():
			var dy: float = float(li) * 15.0
			parts.append('<text x="%.2f" y="%.2f" font-family="Helvetica, Arial, sans-serif" font-size="13" font-weight="700" text-anchor="%s" fill="%s">%s</text>' %
				[lt["x"], lt["z"] + dy, lt["anchor"], hexcol, lines[li]])

	return "\n".join(parts)


func _place_column(items: Array, margin_x: float, rail_sign: float, img_x0: float, img_x1: float,
		top: float, bottom: float, leader_lines: Array, label_texts: Array) -> void:
	var n := items.size()
	if n == 0:
		return
	var step: float = (bottom - top) / max(1, n - 1) if n > 1 else 0.0
	# Cap rail reach to the REAL available room within TEXT_MARGIN (not
	# a fraction of margin_x-img_x0, which can be much larger than the
	# actual text-margin band and let rails/labels overshoot into the
	# next panel or off the canvas edge -- the same class of bug found
	# earlier in the pure-vector version, see docs/CHANGELOG.md).
	# Budget: TEXT_MARGIN total, minus the initial 15px offset, minus
	# ~140px reserved for the longest label text itself.
	var max_rail_reach: float = max(15.0, TEXT_MARGIN - 15.0 - 140.0)
	var rail_spacing: float = max_rail_reach / max(1, n - 1) if n > 1 else 0.0
	for i in n:
		var item = items[i]
		var label_y: float = top + step * i if n > 1 else (top + bottom) / 2.0
		var rail_x: float = margin_x + rail_sign * (15.0 + i * rail_spacing)
		var anchor := Vector2(item["x"] + img_x0, item["z"] + TITLE_H)
		# iFire 2026-11-08: "I don't like how the lines block the
		# reading of the measurement tapes" -- the leader line used to
		# run straight from the anchor, crossing right over the
		# rendered body image (and whatever OTHER real curves happen
		# to sit along that path) on its way to the margin. The drawn
		# line now starts at the image's own edge instead: it never
		# enters the image area at all, so it can never cross a
		# measurement curve. Only a small dot marks the real anchor
		# position inside the image, where it belongs.
		var exit_x: float = img_x0 if rail_sign < 0 else img_x1
		var exit_point := Vector2(exit_x, anchor.y)
		leader_lines.append({
			"anchor": anchor,
			"pts": [exit_point, Vector2(rail_x, exit_point.y), Vector2(rail_x, label_y), Vector2(margin_x, label_y)],
		})
		var ha := "end" if rail_sign < 0 else "start"
		var text_x: float = margin_x - (5.0 if rail_sign < 0 else -5.0)
		label_texts.append({"text": item["text"], "x": text_x, "z": label_y - 3.5, "color": item["color"], "anchor": ha})


func _pts_to_path(pts: Array) -> String:
	var s := ""
	for i in pts.size():
		var p: Vector2 = pts[i]
		s += "%s%.2f,%.2f " % ["M" if i == 0 else "L", p.x, p.y]
	return s


func _compose_tiled_svg(panels: Array) -> String:
	var cols := 2
	var gap := 20.0
	var col_w := 0.0
	for p in panels:
		col_w = max(col_w, p["w"])
	var row_h := 0.0
	for p in panels:
		row_h = max(row_h, p["h"])
	var rows := int(ceil(float(panels.size()) / cols))
	# Page padding around the whole composite: the prior version placed
	# panel (0,0) flush against x=0/y=title_h with no margin, so its
	# own 0.5px-inset border sat right on the canvas edge and visibly
	# clipped there (iFire: "the borders need spans add white space" /
	# "the borders are clipped add white space"). A real page margin on
	# all four sides fixes that for every panel, not just the corner one.
	var page_pad := 20.0
	var header_h := 50.0
	var grid_w := col_w * cols + gap * (cols - 1)
	var grid_h := row_h * rows + gap * (rows - 1)
	var total_w := grid_w + 2.0 * page_pad
	var total_h := grid_h + header_h + 2.0 * page_pad

	var parts: Array = []
	parts.append('<?xml version="1.0" encoding="utf-8"?>')
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%.1f" height="%.1f" viewBox="0 0 %.1f %.1f">' % [total_w, total_h, total_w, total_h])
	parts.append('<rect width="100%%" height="100%%" fill="white"/>'.replace("%%", "%"))
	parts.append('<text x="%.1f" y="%.1f" font-family="Helvetica, Arial, sans-serif" font-size="20" font-weight="700" text-anchor="middle" fill="#000">ANNY-SOMA-X — 26 GarmentCode measurement locations, real order-independent (OIT) render, %d Hammersley-sequence views (left/right)</text>' % [total_w / 2.0, page_pad + 22.0, panels.size()])
	parts.append('<text x="%.1f" y="%.1f" font-family="Helvetica, Arial, sans-serif" font-size="13" font-weight="500" text-anchor="middle" fill="#1f2937">green curves = geodesic/circumference fields; amber = Euclidean; red = 2 reverted to unsettled — each field placed on the view that best faces it</text>' % [total_w / 2.0, page_pad + 40.0])
	for i in panels.size():
		var p = panels[i]
		var col := i % cols
		var row := i / cols
		var tx := page_pad + col * (col_w + gap)
		var ty := page_pad + header_h + row * (row_h + gap)
		parts.append('<g transform="translate(%.1f,%.1f)">' % [tx, ty])
		parts.append(p["body"])
		# Panel border: drawn AFTER the panel body (whose first element
		# is its own opaque white background rect, which would
		# otherwise paint right over a border drawn before it) -- a
		# full-span rect around each panel's own (w, h) footprint
		# (title + image + text margins), not just a gap between
		# panels. iFire: "the borders need spans". A bare gap relies on
		# background color alone to separate panels; a drawn border
		# spans the entire panel rectangle so the boundary is explicit
		# regardless of what's rendered inside.
		parts.append('<rect x="0.5" y="0.5" width="%.1f" height="%.1f" fill="none" stroke="#000" stroke-width="1.0"/>' % [p["w"] - 1.0, p["h"] - 1.0])
		parts.append('</g>')
	parts.append('</svg>')
	return "\n".join(parts)
