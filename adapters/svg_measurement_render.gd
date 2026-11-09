extends SceneTree
# Multi-view measurement-location SVG, generated entirely in GDScript.
# iFire 2026-11-08: "the svg generator needs to be godot", then (after
# a single crammed front view came back genuinely cluttered/crossing):
# "use multiple hammersly orbit views so that there's less clutter".
#
# Camera distribution: the REAL `sphere_hammersley_sequence`
# (TencentARC/Pixal3D @ cdbb2bb), ported exactly from this repo's own
# `render_view.py` (anny-render-corpus) -- not a hand-rolled orbit.
# That file's own header explains why: "the first pass here put four
# cameras at 0, 90, 180 and 270 degrees... that is a made-up rig" --
# the same house rule applies here, so this reuses the identical
# radical_inverse/sphere_hammersley math, not a re-derivation.
#
# Each of the N=4 views gets its OWN real 3D camera basis (not just a
# front/back X,Z swap); every curve/anchor is projected into that
# view's actual screen plane. Each labeled field is assigned to
# whichever view's camera direction most directly faces its real 3D
# anchor (highest dot product) -- real visibility, not a name-based
# "back_width -> back view" heuristic -- so the ~26 fields spread
# naturally across panels instead of piling onto one.
#
# Label layout per panel: Bekos, Kaufmann, Symvonis & Wolff (2007)
# type-opo boundary labeling, same as before -- but with the rail
# placement reverted to NEAR THE MARGIN (matching xray_oit_render.gd,
# which verified clean), not near the body. The near-body variant this
# file shipped earlier produced real crossings (an anchor whose x was
# near the body centerline got a "short" first segment that was
# actually almost as long as the whole panel width, defeating the
# design and crossing other leaders) -- see docs/CHANGELOG.md.

const CORPUS_ROOT := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/"
const OBJ_PATH := CORPUS_ROOT + "build/anny_export/anny-soma-x.obj"
const EXPORT_DIR := CORPUS_ROOT + "build/anny_export/"
const OUT_SVG := EXPORT_DIR + "anny_measurement_wireframe_godot.svg"

const LOOP_FIELDS := ["waist", "hips", "bust", "underbust", "leg_circ", "wrist", "neck_w"]
const EUCLID_DASHED_FIELDS := ["shoulder_w", "armscye_depth", "bust_points", "bum_points"]
# 4 real samples from a 16-sample sphere_hammersley_sequence, chosen for
# this use case (a readable 2D label diagram, not full-sphere photoreal
# coverage): sorted by |pitch| ascending, these are the first 4 whose
# yaws land exactly 90 degrees apart (45/135/225/315) -- i=0's pitch is
# -90 (straight down, a known degenerate case the house
# render-anny-sphere-hammersley skill already documents) and most other
# low indices either repeat a yaw or carry a steep pitch; this
# selection is the smallest-pitch combination with full yaw coverage.
# Still the real generator, real samples -- a chosen SUBSET of indices
# (normal usage per render_view.py's own --index/--views flags), not a
# hand-rolled angle.
const HAMMERSLEY_N := 16
const VIEW_INDICES := [4, 6, 5, 7]
const NUM_VIEWS := 4
const PRIMES0 := 2


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
# Returns [phi (yaw, radians), theta (pitch, radians)].
func _sphere_hammersley(i: int, num_samples: int, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var u: float = float(i) / num_samples + offset.x / num_samples
	var v: float = _radical_inverse(PRIMES0, i) + offset.y
	u = 2.0 * u if u < 0.25 else (2.0 / 3.0) * u + 1.0 / 3.0
	var theta: float = acos(1.0 - 2.0 * u) - PI / 2.0
	var phi: float = v * 2.0 * PI
	return Vector2(phi, theta)


class ViewCam:
	var eye_dir: Vector3
	var right: Vector3
	var up: Vector3
	var phi: float
	var theta: float

	func project(p: Vector3) -> Vector2:
		return Vector2(p.dot(right), p.dot(up))


func _make_view(phi: float, theta: float) -> ViewCam:
	var cam := ViewCam.new()
	cam.phi = phi
	cam.theta = theta
	# eye = (cos(yaw)cos(pitch), sin(yaw)cos(pitch), sin(pitch)) -- the
	# exact upstream formula (render_view.py header), Z-up.
	cam.eye_dir = Vector3(cos(phi) * cos(theta), sin(phi) * cos(theta), sin(theta)).normalized()
	var world_up := Vector3(0, 0, 1)
	if absf(cam.eye_dir.dot(world_up)) > 0.999:
		world_up = Vector3(1, 0, 0)  # near the poles: fall back to an arbitrary non-parallel up
	cam.right = world_up.cross(cam.eye_dir).normalized()
	cam.up = cam.eye_dir.cross(cam.right).normalized()
	return cam


func _init() -> void:
	# --- load the real mesh ---
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

	var manifest = _load_json(EXPORT_DIR + "paths_manifest.json")
	var angle_values = _load_json(EXPORT_DIR + "angle_fields.json")
	var hints = _load_json(EXPORT_DIR + "layout_hints.json")
	if manifest == null or angle_values == null or hints == null:
		printerr("missing required JSON exports -- run export_real_geodesic_paths.py first")
		quit(1)
		return

	# --- build the N real Hammersley-sequence cameras ---
	var views: Array[ViewCam] = []
	for idx in VIEW_INDICES:
		var ph: Vector2 = _sphere_hammersley(idx, HAMMERSLEY_N, Vector2.ZERO)
		views.append(_make_view(ph.x, ph.y))
		print("view (hammersley i=", idx, "/", HAMMERSLEY_N, ") yaw=", rad_to_deg(ph.x), "deg pitch=", rad_to_deg(ph.y), "deg")

	# --- collect every real curve/loop field with its full 3D anchor ---
	# items: {text, anchor3d: Vector3, line_color, text_color, dashed, closed, pts3d (Array[Vector3])}
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
		var pts3d: Array[Vector3] = []
		var sum3 := Vector3.ZERO
		for p in line3d:
			var pv := Vector3(float(p[0]), float(p[1]), float(p[2]))
			pts3d.append(pv)
			sum3 += pv
		var anchor3d: Vector3 = sum3 / pts3d.size()
		curve_items.append({
			"text": field_name, "anchor3d": anchor3d, "pts3d": pts3d,
			"closed": field_name in LOOP_FIELDS, "dashed": field_name in EUCLID_DASHED_FIELDS,
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204),
		})

	# --- angle/diff + unsettled fields + axis ticks: layout_hints.json
	# only gives a 2D (x, z) placement (no real depth), so give each a
	# pseudo-3D position at y=0 and project it through whichever
	# camera it's assigned to, same as every real-3D item -- this is
	# what lets them distribute across views instead of all dumping on
	# one panel, and still project correctly for any of the 4 cameras
	# (not just the original X,Z front convention).
	var torso: Dictionary = hints["torso_heights"]
	var head_top_z: float = float(hints["head_top_z"])
	var fixed_items: Array = []  # {text, pos3d, line_color, text_color}
	for field_name in ["shoulder_incl", "hip_inclination", "arm_pose_angle", "crotch_hip_diff"]:
		if not hints["marker_anchors"].has(field_name):
			continue
		var m = hints["marker_anchors"][field_name]
		var z_ref: float = _resolve_z_ref(str(m["z_ref"]), torso, head_top_z)
		var ax: float = float(m["dx"])
		var az: float = z_ref + float(m["dz"])
		var val = angle_values.get(field_name + "_deg")
		if val == null:
			val = angle_values.get(field_name + "_cm")
		var unit := "deg" if angle_values.has(field_name + "_deg") else "cm"
		var text := "%s\n%.1f%s" % [field_name, float(val), unit]
		fixed_items.append({"text": text, "pos3d": Vector3(ax, 0.0, az),
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204)})
	for field_name in ["bust_line", "waist_over_bust_line"]:
		if not hints["marker_anchors"].has(field_name):
			continue
		var m2 = hints["marker_anchors"][field_name]
		var z_ref2: float = _resolve_z_ref(str(m2["z_ref"]), torso, head_top_z)
		var ax2: float = float(m2["dx"])
		var az2: float = z_ref2 + float(m2["dz"])
		fixed_items.append({"text": field_name, "pos3d": Vector3(ax2, 0.0, az2),
			"line_color": Color(0.863, 0.149, 0.149), "text_color": Color(0.498, 0.114, 0.114)})

	var axis_tick_x := {"head_l": 0.55, "vert_bust_line": 0.62}
	var axis_ticks: Array = []  # {name, pos3d_a, pos3d_b}
	for name in axis_tick_x.keys():
		if not hints["axis_ticks"].has(name):
			continue
		var pair = hints["axis_ticks"][name]
		var za: float = float(pair[0][2])
		var zb: float = float(pair[1][2])
		var x := float(axis_tick_x[name])
		axis_ticks.append({"name": name, "pos3d_a": Vector3(x, 0.0, za), "pos3d_b": Vector3(x, 0.0, zb)})
		fixed_items.append({"text": name, "pos3d": Vector3(x, 0.0, (za + zb) / 2.0),
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204)})

	# round-robin distribute the fixed items (and their matching axis
	# ticks) across all views for balance, same reasoning as the curve
	# items above -- these have no real facing direction to rank by.
	var per_view_fixed: Array = []
	var per_view_axis_ticks: Array = []
	for i in NUM_VIEWS:
		per_view_fixed.append([])
		per_view_axis_ticks.append([])
	for i in fixed_items.size():
		per_view_fixed[i % NUM_VIEWS].append(fixed_items[i])
	for t in axis_ticks:
		var owning_view: int = 0
		for i in fixed_items.size():
			if fixed_items[i]["text"] == t["name"]:
				owning_view = i % NUM_VIEWS
				break
		per_view_axis_ticks[owning_view].append(t)

	# --- assign each real-3D curve field to the view whose camera
	# direction most directly faces its anchor: real visibility, via
	# dot(eye_dir, anchor - body_center) -- but CAPACITY-BALANCED, not
	# pure greedy-best. GarmentCode's own fields are mostly front-torso
	# landmarks by nature, so a pure "best match" assignment piles most
	# of the 26 onto whichever one view faces the front, defeating the
	# point of splitting across views. Each item ranks ALL views by dot
	# product; items are processed in order of their OWN top-choice
	# confidence (most unambiguous first), each taking its best-ranked
	# view that still has room under a per-view cap.
	var per_view_curves: Array = []
	for i in NUM_VIEWS:
		per_view_curves.append([])
	var ranked_items: Array = []  # {item, ranking: Array[int] (view idx, best dot first), top_dot}
	for item in curve_items:
		var dir3: Vector3 = (item["anchor3d"] - body_center)
		dir3.z = 0.0  # facing is about XY orientation around the standing axis
		if dir3.length() < 0.0001:
			dir3 = Vector3(1, 0, 0)
		dir3 = dir3.normalized()
		var dots: Array = []
		for i in NUM_VIEWS:
			dots.append({"i": i, "d": views[i].eye_dir.dot(dir3)})
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
			per_view_curves[ri["ranking"][0]].append(ri["item"])  # all at cap: take the best anyway

	# --- wireframe (every view gets the full silhouette for context) ---
	var stride := 14
	var wire_edges: Array = []  # [Vector3, Vector3]
	var fi := 0
	while fi < faces.size():
		var f = faces[fi]
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		wire_edges.append([a, b])
		wire_edges.append([b, c])
		wire_edges.append([c, a])
		fi += stride

	# --- build each panel ---
	var panels: Array = []  # {svg_body, w, h}
	for i in NUM_VIEWS:
		panels.append(_build_panel(views[i], i, wire_edges, per_view_curves[i],
			per_view_fixed[i], per_view_axis_ticks[i], zmin, zmax))

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


# One panel: projects everything into this view's 2D (right, up) plane,
# runs the type-opo boundary labeling for just this panel's items, and
# returns the SVG body fragment + its own width/height.
func _build_panel(cam: ViewCam, view_idx: int, wire_edges: Array, curve_items: Array,
		fixed_items: Array, axis_ticks_panel: Array,
		zmin: float, zmax: float) -> Dictionary:
	# project wireframe edges
	var wire_2d: Array = []
	for e in wire_edges:
		wire_2d.append([cam.project(e[0]), cam.project(e[1])])

	# project curves + compute 2D anchors
	var curves_2d: Array = []
	var label_queue: Array = []
	for item in curve_items:
		var pts2d := PackedVector2Array()
		for p3 in item["pts3d"]:
			pts2d.append(cam.project(p3))
		curves_2d.append({"pts": pts2d, "color": item["line_color"], "dashed": item["dashed"], "closed": item["closed"]})
		var sx := 0.0
		var sy := 0.0
		for p in pts2d:
			sx += p.x
			sy += p.y
		sx /= pts2d.size()
		sy /= pts2d.size()
		label_queue.append({"text": item["text"], "x": sx, "z": sy,
			"line_color": item["line_color"], "text_color": item["text_color"]})

	# fixed-position items (angle markers, axis ticks, unsettled fields)
	# have no real depth, so they were given a pseudo-3D position at
	# y=0 -- project that through THIS panel's own camera, same as
	# every real curve item, so they land correctly regardless of
	# which view they were round-robin assigned to.
	for item2 in fixed_items:
		var p2d: Vector2 = cam.project(item2["pos3d"])
		label_queue.append({"text": item2["text"], "x": p2d.x, "z": p2d.y,
			"line_color": item2["line_color"], "text_color": item2["text_color"]})

	var axis_ticks_2d: Array = []
	for t in axis_ticks_panel:
		axis_ticks_2d.append({"name": t["name"], "pt_a": cam.project(t["pos3d_a"]), "pt_b": cam.project(t["pos3d_b"])})

	if label_queue.is_empty() and curves_2d.is_empty():
		return {"body": "", "w": 0.0, "h": 0.0}

	# --- type-opo boundary labeling, THIS PANEL ONLY, rails NEAR THE
	# MARGIN (reverted from the near-body variant -- see module doc) ---
	var margin_z_top: float = zmax - 0.05
	var margin_z_bottom: float = zmin + 0.05
	var margin_x_left := -1.25
	var margin_x_right := 1.20
	var rail_base := 0.05

	var left_q: Array = []
	var right_q: Array = []
	for item3 in label_queue:
		if item3["x"] < 0:
			left_q.append(item3)
		else:
			right_q.append(item3)
	left_q.sort_custom(func(a, b): return a["z"] > b["z"])
	right_q.sort_custom(func(a, b): return a["z"] > b["z"])

	var leader_lines: Array = []
	var label_texts: Array = []
	_place_column(left_q, margin_x_left, -1.0, rail_base, margin_z_top, margin_z_bottom, leader_lines, label_texts)
	_place_column(right_q, margin_x_right, 1.0, rail_base, margin_z_top, margin_z_bottom, leader_lines, label_texts)

	var px_per_m := 300.0
	var pad := 110.0
	var data_min_x := margin_x_left - 0.1
	var data_max_x := margin_x_right + 0.1
	var data_min_z := margin_z_bottom - 0.1
	var data_max_z := zmax + 0.12
	var svg_cx: float = -data_min_x * px_per_m + pad
	var svg_bottom_z: float = data_max_z
	var w: float = (data_max_x - data_min_x) * px_per_m + 2 * pad
	var h: float = (data_max_z - data_min_z) * px_per_m + 2 * pad

	var body := _panel_body(w, h, view_idx, cam, wire_2d, curves_2d, axis_ticks_2d, leader_lines,
		label_texts, svg_cx, svg_bottom_z, px_per_m)
	return {"body": body, "w": w, "h": h}


func _place_column(items: Array, margin_x: float, rail_sign: float, rail_base: float,
		margin_z_top: float, margin_z_bottom: float, leader_lines: Array, label_texts: Array) -> void:
	var n := items.size()
	if n == 0:
		return
	var step: float = (margin_z_top - margin_z_bottom) / max(1, n - 1) if n > 1 else 0.0
	# Rail spacing scaled to the actual item count on THIS panel, capped
	# so later rails can never reach past the margin (the real bug found
	# in the single-view version -- see docs/CHANGELOG.md). With panels
	# now carrying far fewer items each (visibility-split across 4
	# views instead of ~26 on one), this matters less in practice but
	# the cap stays so it is never reintroduced by construction.
	var max_reach := 0.45  # rails stay within this x-distance of margin_x
	var rail_spacing: float = max_reach / max(1, n - 1) if n > 1 else 0.0
	for i in n:
		var item = items[i]
		var label_z: float = margin_z_top - step * i if n > 1 else (margin_z_top + margin_z_bottom) / 2.0
		var rail_x: float = margin_x + rail_sign * (rail_base + i * rail_spacing)
		leader_lines.append({
			"pts": [Vector2(item["x"], item["z"]), Vector2(rail_x, item["z"]),
					Vector2(rail_x, label_z), Vector2(margin_x, label_z)],
			"color": item["line_color"],
		})
		var ha := "start" if rail_sign > 0 else "end"
		var text_x: float = margin_x + (0.03 if rail_sign > 0 else -0.03)
		label_texts.append({"text": item["text"], "x": text_x, "z": label_z + 0.025,
			"color": item["text_color"], "anchor": ha})


func _panel_body(w: float, h: float, view_idx: int, cam: ViewCam, wire_2d: Array, curves: Array,
		axis_ticks_out: Array, leader_lines: Array, label_texts: Array,
		svg_cx: float, svg_bottom_z: float, px_per_m: float) -> String:
	var xp := func(x: float) -> float: return svg_cx + x * px_per_m
	var yp := func(z: float) -> float: return (svg_bottom_z - z) * px_per_m
	var pts_path := func(pts, closed: bool) -> String:
		var s := ""
		for i in pts.size():
			var p = pts[i]
			var cmd := "M" if i == 0 else "L"
			s += "%s%.2f,%.2f " % [cmd, xp.call(p.x), yp.call(p.y)]
		if closed:
			s += "Z"
		return s

	var parts: Array = []
	parts.append('<rect width="100%%" height="100%%" fill="white"/>'.replace("%%", "%"))
	var title := "view %d — yaw %.0f° pitch %.0f°" % [view_idx, rad_to_deg(cam.phi), rad_to_deg(cam.theta)]
	parts.append('<text x="%.1f" y="18" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#111">%s</text>' % [w / 2.0, title])

	parts.append('<g stroke="#9ca3af" stroke-width="0.4" opacity="0.5">')
	for seg in wire_2d:
		parts.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f"/>' %
			[xp.call(seg[0].x), yp.call(seg[0].y), xp.call(seg[1].x), yp.call(seg[1].y)])
	parts.append('</g>')

	for c in curves:
		var dash := ' stroke-dasharray="6,4"' if c["dashed"] else ''
		var col: Color = c["color"]
		var hexcol := "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]
		var d: String = pts_path.call(c["pts"], c["closed"])
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.6"%s/>' % [d, hexcol, dash])

	for t in axis_ticks_out:
		var x: float = xp.call(t["pt_a"].x)
		var ya: float = yp.call(t["pt_a"].y)
		var xb: float = xp.call(t["pt_b"].x)
		var yb: float = yp.call(t["pt_b"].y)
		parts.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#166534" stroke-width="1.0"/>' % [x, ya, xb, yb])
		parts.append('<circle cx="%.2f" cy="%.2f" r="1.6" fill="#166534"/>' % [x, ya])
		parts.append('<circle cx="%.2f" cy="%.2f" r="1.6" fill="#166534"/>' % [xb, yb])

	for ll in leader_lines:
		var col2 = ll["color"]
		var hexcol2 := "#%02x%02x%02x" % [int(col2.r * 255), int(col2.g * 255), int(col2.b * 255)]
		var d2: String = pts_path.call(ll["pts"], false)
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="0.6" opacity="0.8"/>' % [d2, hexcol2])

	for lt in label_texts:
		var lines: Array = str(lt["text"]).split("\n")
		var col3 = lt["color"]
		var hexcol3 := "#%02x%02x%02x" % [int(col3.r * 255), int(col3.g * 255), int(col3.b * 255)]
		var base_y: float = yp.call(lt["z"])
		for li in lines.size():
			var dy: float = -float(lines.size() - 1 - li) * 10.0
			parts.append('<text x="%.2f" y="%.2f" font-family="sans-serif" font-size="9" text-anchor="%s" fill="%s">%s</text>' %
				[xp.call(lt["x"]), base_y + dy, lt["anchor"], hexcol3, lines[li]])

	return "\n".join(parts)


# Tiles the N panels into one 2xN/2 grid SVG (<svg> per panel wrapped in
# a <g transform="translate(...)">), each panel keeping its own local
# coordinate system -- no cross-panel coordinate collisions possible.
func _compose_tiled_svg(panels: Array) -> String:
	var cols := 2
	var gap := 24.0
	var col_w := 0.0
	for p in panels:
		col_w = max(col_w, p["w"])
	var row_h := 0.0
	for p in panels:
		row_h = max(row_h, p["h"])
	var rows := int(ceil(float(panels.size()) / cols))
	var total_w := col_w * cols + gap * (cols - 1)
	var total_h := row_h * rows + gap * (rows - 1) + 40.0  # +40 for the overall title

	var parts: Array = []
	parts.append('<?xml version="1.0" encoding="utf-8"?>')
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%.1f" height="%.1f" viewBox="0 0 %.1f %.1f">' % [total_w, total_h, total_w, total_h])
	parts.append('<rect width="100%%" height="100%%" fill="white"/>'.replace("%%", "%"))
	parts.append('<text x="%.1f" y="24" font-family="sans-serif" font-size="15" text-anchor="middle" fill="#111">ANNY-SOMA-X — 26 GarmentCode measurement locations, %d real Hammersley-sequence views</text>' % [total_w / 2.0, panels.size()])
	parts.append('<text x="%.1f" y="38" font-family="sans-serif" font-size="9" text-anchor="middle" fill="#444">green = 24 real fields (dashed = Euclidean, per the real mbotsch/GarmentMeasurements reference); red = 2 reverted to unsettled -- each field placed on the view that best faces it</text>')
	for i in panels.size():
		var p = panels[i]
		if p["w"] == 0.0:
			continue
		var col := i % cols
		var row := i / cols
		var tx := col * (col_w + gap)
		var ty := 40.0 + row * (row_h + gap)
		parts.append('<g transform="translate(%.1f,%.1f)">' % [tx, ty])
		parts.append(p["body"])
		parts.append('</g>')
	parts.append('</svg>')
	return "\n".join(parts)
