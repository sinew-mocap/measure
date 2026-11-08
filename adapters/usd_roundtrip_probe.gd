extends SceneTree

# Real USD round-trip: load the ACTUAL usd.elf godot-sandbox guest
# (OpenUSD-from-bytes, V-Sekai-fire interactor-usd-guest's "Cut U"),
# open the hand-authored ANNY-SOMA-X USDA (real UsdGeomMesh points/
# faceVertexIndices, written straight from ANNY's own float64 arrays --
# no OBJ text, no tri/quad conversion since ANNY's own topology is
# already triangles), and read the mesh back through usd.elf's real
# C-ABI (usd_mesh_points / usd_mesh_indices), verifying every point and
# every index round-trips exactly against the Python-side original.
#
# iFire: 'you use store anny in openusd usd.elf you don't need to covnert
# tri to quads'

const USD_ELF := "/Users/ernest.lee/.hermes/cache/scratch/usd_measure_project/usd.elf"
const USDA_PATH := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny-soma-x.usda"
const ORIGINAL_NPZ_JSON := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/anny_verts_faces_check.json"
const OUT_JSON := "/Users/ernest.lee/3-interactor/meshing-pen/6-datasource/anny-render-corpus/build/anny_export/usd_roundtrip_mesh.json"


func _init():
	var sb := Sandbox.new()
	sb.set_memory_max(256)  # MB, power-of-two: OpenUSD's static init needs
	# much more than the 32 MB default arena.
	sb.set_allocations_max(200000)  # default 4000 is far too few for
	# OpenUSD's static init (TfType registry etc. allocate many small
	# objects) -- confirmed: 32MB/4000-alloc defaults crashed with
	# "Too many arena chunks" partway through libstdc++/pxr static init.
	var buf := FileAccess.get_file_as_bytes(USD_ELF)
	if buf.size() == 0:
		printerr("could not read usd.elf at ", USD_ELF)
		quit(1)
		return
	sb.load_buffer(buf)
	print("usd.elf loaded: ", buf.size(), " bytes, has usd_open=", sb.has_function("usd_open"))

	var init_result = sb.vmcall("usd_init")
	print("usd_init -> ", init_result)

	var usda_bytes := FileAccess.get_file_as_bytes(USDA_PATH)
	print("usda file: ", usda_bytes.size(), " bytes")
	var open_result = sb.vmcall("usd_open", usda_bytes)
	print("usd_open -> ", open_result)
	if typeof(open_result) != TYPE_STRING or not open_result.begins_with("ok"):
		printerr("usd_open did not report ok: ", open_result)
		quit(1)
		return

	var mesh_count = sb.vmcall("usd_mesh_count")
	print("usd_mesh_count -> ", mesh_count)
	if mesh_count != 1:
		printerr("expected exactly 1 mesh, got ", mesh_count)
		quit(1)
		return

	var info = sb.vmcall("usd_mesh_info", 0)
	print("usd_mesh_info(0) -> ", info)

	var points = sb.vmcall("usd_mesh_points", 0)
	var indices = sb.vmcall("usd_mesh_indices", 0)
	print("usd_mesh_points: ", points.size() / 3, " points  usd_mesh_indices: ", indices.size() / 3, " triangles")

	# compare against the Python-side original (float64 -> float32 cast,
	# since the USDA stores point3f) to CONFIRM this is a real, exact
	# round-trip, not just "it opened".
	var orig_text := FileAccess.get_file_as_string(ORIGINAL_NPZ_JSON)
	var orig: Dictionary = JSON.parse_string(orig_text)
	var orig_verts: Array = orig["verts"]
	var orig_faces: Array = orig["faces"]

	var points_ok: bool = points.size() / 3 == orig_verts.size()
	var max_point_diff := 0.0
	if points_ok:
		for i in range(orig_verts.size()):
			var p: Array = orig_verts[i]
			for k in range(3):
				var d: float = abs(points[i * 3 + k] - float(p[k]))
				if d > max_point_diff:
					max_point_diff = d
	var indices_ok: bool = indices.size() / 3 == orig_faces.size()
	var indices_match := true
	if indices_ok:
		for i in range(orig_faces.size()):
			var f: Array = orig_faces[i]
			for k in range(3):
				if indices[i * 3 + k] != int(f[k]):
					indices_match = false
					break
			if not indices_match:
				break

	print("ROUND-TRIP: points_count_match=", points_ok, " max_point_diff=", max_point_diff,
		"  indices_count_match=", indices_ok, " indices_exact_match=", indices_match)

	if not (points_ok and max_point_diff < 1e-4 and indices_ok and indices_match):
		printerr("ROUND-TRIP FAILED -- usd.elf's mesh does not match the Python original")
		quit(1)
		return

	print("ROUND-TRIP VERIFIED: usd.elf's real OpenUSD read matches ANNY's own arrays exactly")

	# write the round-tripped mesh out for the x-ray render to consume
	# directly -- the actual bytes usd.elf returned, not a re-parse of OBJ.
	var out := {"points": Array(points), "indices": Array(indices)}
	var f := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote ", OUT_JSON)

	quit(0)
