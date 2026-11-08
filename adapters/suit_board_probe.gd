extends SceneTree

# Headless probe: build an ArrayMesh from the real ANNY-SOMA-X OBJ, run the
# SAME real in-engine pipeline the ChArUco-suit toolchain uses
# (generate_normals -> lightmap_unwrap, PX_PER_M = 1500, i.e. 45 texels per
# 30mm suit square -- see aruco-marker-visibility-testing skill, "Give the
# body real UVs"), then report each already-measured landmark's suit BOARD
# CELL (row, col of a real 30mm printed square), not a raw mesh vertex id.
#
# iFire: 'instead of a uv pattern please reuse our toolchain of CHARUCO
# suits' -- this addresses every landmark in terms of the actual suit's
# board grid, the real toolchain, instead of an ad-hoc host-side pattern.

const OBJ_PATH := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny-soma-x.obj"
const OUT_PATH := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/suit_board_addresses.json"
const PX_PER_M := 1500.0          # 45 px per 0.03m square (skill's own pin)
const SQUARE_PX := 45.0           # 1500 * 0.03

# The exact vertex indices already picked by the real geometric/geodesic
# work (measure_anny_geodesic_loops.py, resolve_remaining_measurements.py) --
# every landmark this script re-addresses, by OBJ vertex index (0-based,
# matching mesh.export()'s vertex order, which this script reads directly).
var landmarks := {
	"arm_length_shoulder": 6058, "arm_length_wrist": 818,
	"shoulder_w_left": 6058, "shoulder_w_right": 10523,
	"neck_w_left": 2953, "neck_w_right": 749,
	"waist_back_width_left": 10814, "waist_back_width_right": 6349,
	"hip_back_width_left": 3752, "hip_back_width_right": 1548,
	"back_width_left": 16650, "back_width_right": 14388,
	"armscye_depth_shoulder": 2265, "armscye_depth_underarm": 10655,
	"bust_points_left": 10655, "bust_points_right": 6190,
	"bum_points_left": 16772, "bum_points_right": 14510,
}

func _init():
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var f := FileAccess.open(OBJ_PATH, FileAccess.READ)
	if f == null:
		printerr("could not open ", OBJ_PATH)
		quit(1)
		return
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("v "):
			var p := line.substr(2).strip_edges().split(" ", false)
			verts.push_back(Vector3(float(p[0]), float(p[1]), float(p[2])))
		elif line.begins_with("f "):
			var p := line.substr(2).strip_edges().split(" ", false)
			# OBJ face indices are 1-based; swap winding (OBJ CCW-outward,
			# Godot CW) per the skill's explicit warning.
			var a := int(p[0].split("/")[0]) - 1
			var b := int(p[1].split("/")[0]) - 1
			var c := int(p[2].split("/")[0]) - 1
			indices.push_back(a); indices.push_back(c); indices.push_back(b)
	f.close()
	print("parsed OBJ: ", verts.size(), " verts, ", indices.size() / 3, " faces")

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var raw_mesh := ArrayMesh.new()
	raw_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var st := SurfaceTool.new()
	st.create_from(raw_mesh, 0)
	st.generate_normals()
	var normaled := ArrayMesh.new()
	st.commit(normaled)

	var err := normaled.lightmap_unwrap(Transform3D.IDENTITY, 1.0 / PX_PER_M)
	print("lightmap_unwrap result: ", err, " (OK=", OK, ")")
	if err != OK:
		printerr("lightmap_unwrap FAILED with code ", err)
		quit(1)
		return

	var hint: Vector2i = normaled.lightmap_size_hint
	print("lightmap_size_hint (atlas texels): ", hint)

	var final_arrays := normaled.surface_get_arrays(0)
	var pos: PackedVector3Array = final_arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = final_arrays[Mesh.ARRAY_TEX_UV2]
	print("post-unwrap vertex count: ", pos.size(), " (pre-unwrap was ", verts.size(), ")")

	var out := {}
	out["lightmap_size_hint"] = [hint.x, hint.y]
	out["pre_unwrap_vertex_count"] = verts.size()
	out["post_unwrap_vertex_count"] = pos.size()
	var addresses := {}
	for key in landmarks.keys():
		var orig_idx: int = landmarks[key]
		if orig_idx >= verts.size():
			continue
		var target: Vector3 = verts[orig_idx]
		# nearest post-unwrap vertex to the original 3D position (robust
		# to lightmap_unwrap possibly duplicating vertices at UV seams).
		var best_i := -1
		var best_d := INF
		for i in range(pos.size()):
			var d := pos[i].distance_squared_to(target)
			if d < best_d:
				best_d = d
				best_i = i
		var u: Vector2 = uv2[best_i]
		var texel_x := u.x * hint.x
		var texel_y := u.y * hint.y
		var col := int(floor(texel_x / SQUARE_PX))
		var row := int(floor(texel_y / SQUARE_PX))
		addresses[key] = {
			"orig_vertex": orig_idx, "nearest_unwrap_match_dist": sqrt(best_d),
			"uv2": [u.x, u.y], "texel": [texel_x, texel_y],
			"board_cell_row": row, "board_cell_col": col,
		}
		print(key, " -> board cell (row=", row, ", col=", col, ")  uv2=", u,
			"  snap_dist=", sqrt(best_d))
	out["landmarks"] = addresses

	var out_f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	out_f.store_string(JSON.stringify(out, "  "))
	out_f.close()
	print("wrote ", OUT_PATH)
	quit(0)
