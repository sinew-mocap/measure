extends SceneTree
# Real front-view measurement-location SVG, generated entirely in
# GDScript -- iFire 2026-11-08: "the svg generator needs to be godot".
#
# Replaces anny-render-corpus/render_anny_measurement_wireframe.py
# (matplotlib). The real anatomy computation stays where it has to:
# that script's torso-height/bone-position math depends on the Anny
# PyTorch body model, which has no Godot equivalent, so it is retired
# in favor of export_real_geodesic_paths.py's layout_hints.json export
# (plus the paths_manifest.json / angle_fields.json it already wrote)
# -- the same "Python computes real anatomy once, Godot loads the
# JSON/OBJ and does all drawing" split xray_oit_render.gd already
# uses for the PNG x-ray render. Everything downstream of that real
# data -- the wireframe silhouette sampling, the label layout, the SVG
# XML itself -- runs here, in pure GDScript, no Python.
#
# Label layout: Bekos, Kaufmann, Symvonis & Wolff, "Boundary Labeling:
# Models and Efficient Algorithms for Rectangular Maps" (Comput. Geom.
# 36(3), 2007), type-opo (orthogonal-parallel-orthogonal) leaders --
# the SAME validated construction from xray_oit_render.gd, ported a
# second time (after the Python matplotlib port, now retired). Key
# fix carried over from that port's 3 real bugs (see
# docs/CHANGELOG.md): rails sit NEAR THE BODY so the long sweep to the
# margin runs at each item's own TARGET z (not its raw anchor z), and
# rail spacing is scaled to the actual per-column item count so later
# rails can never reach past the margin into the text column.

const CORPUS_ROOT := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/"
const OBJ_PATH := CORPUS_ROOT + "build/anny_export/anny-soma-x.obj"
const EXPORT_DIR := CORPUS_ROOT + "build/anny_export/"
const OUT_SVG := EXPORT_DIR + "anny_measurement_wireframe_godot.svg"

const LOOP_FIELDS := ["waist", "hips", "bust", "underbust", "leg_circ", "wrist", "neck_w"]
const EUCLID_DASHED_FIELDS := ["shoulder_w", "armscye_depth", "bust_points", "bum_points"]

# front-view projection + SVG pixel scale/transform, set once zmin/zmax known
var px_per_m: float = 300.0
var svg_cx: float = 0.0   # data x=0 maps to this many px from the left
var svg_bottom_z: float = 0.0  # data z mapped to SVG y = (svg_bottom_z - z) * px_per_m + top_pad


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


func _init() -> void:
	# --- load the real mesh (same OBJ, same winding convention as
	# xray_oit_render.gd / adapters/suit_board_probe.gd) ---
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

	var zmin := INF
	var zmax := -INF
	for v in verts:
		zmin = min(zmin, v.z)
		zmax = max(zmax, v.z)

	# --- real data: paths_manifest.json (15 curve/loop fields),
	# angle_fields.json (4 angle/diff values + all cm values),
	# layout_hints.json (axis ticks, torso heights, marker anchors) ---
	var manifest = _load_json(EXPORT_DIR + "paths_manifest.json")
	var angle_values = _load_json(EXPORT_DIR + "angle_fields.json")
	var hints = _load_json(EXPORT_DIR + "layout_hints.json")
	if manifest == null or angle_values == null or hints == null:
		printerr("missing required JSON exports -- run export_real_geodesic_paths.py first")
		quit(1)
		return

	# label_queue entries: {text, x, z, line_color, text_color, curve (optional PackedVector2Array front-view pts), closed}
	var label_queue: Array = []
	var curves: Array = []  # {pts: PackedVector2Array, color, dashed, closed}

	for field_name in manifest.keys():
		var rel_path: String = str(manifest[field_name])
		var abs_path := rel_path if rel_path.begins_with("/") else CORPUS_ROOT + rel_path
		var path_json = _load_json(abs_path)
		if path_json == null or path_json.is_empty():
			continue
		var line3d = path_json[0]
		if line3d.size() < 2:
			continue
		var pts2d := PackedVector2Array()
		for p in line3d:
			pts2d.append(Vector2(float(p[0]), float(p[2])))  # front view: X horizontal, Z vertical
		var closed: bool = field_name in LOOP_FIELDS
		var dashed: bool = field_name in EUCLID_DASHED_FIELDS
		curves.append({"pts": pts2d, "color": Color(0.086, 0.639, 0.290), "dashed": dashed, "closed": closed})
		var sx := 0.0
		var sz := 0.0
		for p in pts2d:
			sx += p.x
			sz += p.y
		sx /= pts2d.size()
		sz /= pts2d.size()
		label_queue.append({"text": field_name, "x": sx, "z": sz,
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204)})

	# angle/diff fields with real values but no single curve -- anchor
	# via layout_hints.json's marker_anchors (dx + a named z reference).
	var torso: Dictionary = hints["torso_heights"]
	var head_top_z: float = float(hints["head_top_z"])

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
		label_queue.append({"text": text, "x": ax, "z": az,
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204)})

	# 2 fields reverted to unsettled (red): no real value, marker only.
	for field_name in ["bust_line", "waist_over_bust_line"]:
		if not hints["marker_anchors"].has(field_name):
			continue
		var m2 = hints["marker_anchors"][field_name]
		var z_ref2: float = _resolve_z_ref(str(m2["z_ref"]), torso, head_top_z)
		var ax2: float = float(m2["dx"])
		var az2: float = z_ref2 + float(m2["dz"])
		label_queue.append({"text": field_name, "x": ax2, "z": az2,
			"line_color": Color(0.863, 0.149, 0.149), "text_color": Color(0.498, 0.114, 0.114)})

	# axis ticks (head_l, vert_bust_line): real Z extents from
	# layout_hints.json, a fixed visual X offset to draw the up/down
	# arrow clear of the body silhouette (there is no real "X" for a
	# pure height extent -- same convention the retired matplotlib
	# script used).
	var axis_tick_x := {"head_l": 0.55, "vert_bust_line": 0.62}
	var axis_ticks_out: Array = []  # {name, x, za, zb}
	for name in axis_tick_x.keys():
		if not hints["axis_ticks"].has(name):
			continue
		var pair = hints["axis_ticks"][name]
		var za: float = float(pair[0][2])
		var zb: float = float(pair[1][2])
		var x := float(axis_tick_x[name])
		axis_ticks_out.append({"name": name, "x": x, "za": za, "zb": zb})
		label_queue.append({"text": name, "x": x, "z": (za + zb) / 2.0,
			"line_color": Color(0.086, 0.639, 0.290), "text_color": Color(0.086, 0.396, 0.204)})

	# --- wireframe silhouette: every 14th face's 3 edges, front view ---
	var wireframe_segs: Array = []  # [Vector2, Vector2]
	var stride := 14
	var fi := 0
	while fi < faces.size():
		var f = faces[fi]
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		wireframe_segs.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
		wireframe_segs.append([Vector2(b.x, b.z), Vector2(c.x, c.z)])
		wireframe_segs.append([Vector2(c.x, c.z), Vector2(a.x, a.z)])
		fi += stride

	# --- type-opo boundary labeling (see module doc) ---
	var margin_z_top: float = zmax - 0.05
	var margin_z_bottom: float = zmin + 0.05
	var margin_x_left := -1.25
	var margin_x_right := 1.20
	var inner_rail_base_left := -0.78
	var inner_rail_base_right := 0.78
	var rail_margin_buffer := 0.08

	var left_q: Array = []
	var right_q: Array = []
	for item in label_queue:
		if item["x"] < 0:
			left_q.append(item)
		else:
			right_q.append(item)
	left_q.sort_custom(func(a, b): return a["z"] > b["z"])   # top-to-bottom = descending z
	right_q.sort_custom(func(a, b): return a["z"] > b["z"])

	var leader_lines: Array = []  # {pts: Array[Vector2], color}
	var label_texts: Array = []  # {text, x, z, color, anchor} anchor="start"/"end"

	_place_column(left_q, margin_x_left, -1.0, inner_rail_base_left, margin_z_top, margin_z_bottom,
		rail_margin_buffer, leader_lines, label_texts)
	_place_column(right_q, margin_x_right, 1.0, inner_rail_base_right, margin_z_top, margin_z_bottom,
		rail_margin_buffer, leader_lines, label_texts)

	# --- SVG transform: X horizontal (as-is), Z vertical but FLIPPED
	# (SVG y grows downward; our data z grows upward) ---
	px_per_m = 300.0
	var pad := 110.0  # room for the longest label text beyond margin_x
	var data_min_x := margin_x_left - 0.1
	var data_max_x := margin_x_right + 0.1
	# tight vertical bounds: the lowest ACTUAL content (label rows,
	# curves, wireframe silhouette), not an arbitrary margin -- but the
	# wireframe (full head-to-feet body) must stay included, or the
	# body gets visibly clipped mid-leg even though no label needs that
	# space.
	var content_min_z := zmin
	for lt2 in label_texts:
		content_min_z = min(content_min_z, lt2["z"])
	for c2 in curves:
		for p2 in c2["pts"]:
			content_min_z = min(content_min_z, p2.y)
	var data_min_z: float = content_min_z - 0.1
	var data_max_z := zmax + 0.12
	svg_cx = -data_min_x * px_per_m + pad
	svg_bottom_z = data_max_z
	var svg_w := (data_max_x - data_min_x) * px_per_m + 2 * pad
	var svg_h := (data_max_z - data_min_z) * px_per_m + 2 * pad

	var svg := _build_svg(svg_w, svg_h, wireframe_segs, curves, axis_ticks_out, leader_lines, label_texts)

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


func _place_column(items: Array, margin_x: float, rail_sign: float, inner_rail_base: float,
		margin_z_top: float, margin_z_bottom: float, rail_margin_buffer: float,
		leader_lines: Array, label_texts: Array) -> void:
	var n := items.size()
	if n == 0:
		return
	var step: float = (margin_z_top - margin_z_bottom) / max(1, n - 1) if n > 1 else 0.0
	var available_span: float = absf(margin_x - inner_rail_base) - rail_margin_buffer
	var rail_spacing: float = available_span / max(1, n - 1) if n > 1 else 0.0
	for i in n:
		var item = items[i]
		var label_z: float = margin_z_top - step * i if n > 1 else (margin_z_top + margin_z_bottom) / 2.0
		var rail_x: float = inner_rail_base + rail_sign * i * rail_spacing
		leader_lines.append({
			"pts": [Vector2(item["x"], item["z"]), Vector2(rail_x, item["z"]),
					Vector2(rail_x, label_z), Vector2(margin_x, label_z)],
			"color": item["line_color"],
		})
		var ha := "start" if rail_sign > 0 else "end"
		var text_x: float = margin_x + (0.03 if rail_sign > 0 else -0.03)
		label_texts.append({"text": item["text"], "x": text_x, "z": label_z + 0.025,
			"color": item["text_color"], "anchor": ha})


func _xp(x: float) -> float:
	return svg_cx + x * px_per_m


func _yp(z: float) -> float:
	return (svg_bottom_z - z) * px_per_m


func _pts_to_svg_path(pts, closed: bool) -> String:
	var s := ""
	for i in pts.size():
		var p = pts[i]
		var cmd := "M" if i == 0 else "L"
		s += "%s%.2f,%.2f " % [cmd, _xp(p.x), _yp(p.y)]
	if closed:
		s += "Z"
	return s


func _build_svg(w: float, h: float, wireframe_segs: Array, curves: Array,
		axis_ticks_out: Array, leader_lines: Array, label_texts: Array) -> String:
	var parts: Array = []
	parts.append('<?xml version="1.0" encoding="utf-8"?>')
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="%.1f" height="%.1f" viewBox="0 0 %.1f %.1f">' % [w, h, w, h])
	parts.append('<rect width="100%" height="100%" fill="white"/>')
	parts.append('<text x="%.1f" y="18" font-family="sans-serif" font-size="13" text-anchor="middle" fill="#111">ANNY-SOMA-X — 26 GarmentCode measurement locations</text>' % (w / 2.0))
	parts.append('<text x="%.1f" y="33" font-family="sans-serif" font-size="9" text-anchor="middle" fill="#444">green = 24 real fields (dashed = Euclidean, per the real mbotsch/GarmentMeasurements reference); red = 2 reverted to unsettled</text>' % (w / 2.0))

	# wireframe silhouette (light gray, thin, low-ish opacity)
	parts.append('<g stroke="#9ca3af" stroke-width="0.4" opacity="0.5">')
	for seg in wireframe_segs:
		parts.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f"/>' %
			[_xp(seg[0].x), _yp(seg[0].y), _xp(seg[1].x), _yp(seg[1].y)])
	parts.append('</g>')

	# real curves/loops
	for c in curves:
		var dash := ' stroke-dasharray="6,4"' if c["dashed"] else ''
		var col: Color = c["color"]
		var hexcol := "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]
		var d := _pts_to_svg_path(c["pts"], c["closed"])
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.6"%s/>' % [d, hexcol, dash])

	# axis tick double-arrows (head_l, vert_bust_line)
	for t in axis_ticks_out:
		var x: float = _xp(t["x"])
		var ya: float = _yp(t["za"])
		var yb: float = _yp(t["zb"])
		parts.append('<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="#166534" stroke-width="1.0"/>' % [x, ya, x, yb])
		parts.append('<circle cx="%.2f" cy="%.2f" r="1.6" fill="#166534"/>' % [x, ya])
		parts.append('<circle cx="%.2f" cy="%.2f" r="1.6" fill="#166534"/>' % [x, yb])

	# leader lines (type-opo)
	for ll in leader_lines:
		var pts2 = ll["pts"]
		var col2 = ll["color"]
		var hexcol2 := "#%02x%02x%02x" % [int(col2.r * 255), int(col2.g * 255), int(col2.b * 255)]
		var d2 := _pts_to_svg_path(pts2, false)
		parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="0.6" opacity="0.8"/>' % [d2, hexcol2])

	# label text (multi-line via \n -> separate <text> rows)
	for lt in label_texts:
		var lines: Array = str(lt["text"]).split("\n")
		var col3 = lt["color"]
		var hexcol3 := "#%02x%02x%02x" % [int(col3.r * 255), int(col3.g * 255), int(col3.b * 255)]
		var base_y := _yp(lt["z"])
		for li in lines.size():
			var dy: float = -float(lines.size() - 1 - li) * 10.0
			parts.append('<text x="%.2f" y="%.2f" font-family="sans-serif" font-size="9" text-anchor="%s" fill="%s">%s</text>' %
				[_xp(lt["x"]), base_y + dy, lt["anchor"], hexcol3, lines[li]])

	parts.append('</svg>')
	return "\n".join(parts)
