# CHANGELOG — frontier-learning iteration record

This file is the chronological record of what was tried, whether it held
up, and what was kept — not a feature list (that's the README/docs/STATUS.md).

## 2026-11-08 — Resolve the 11 remaining fields; re-address via the real ChArUco suit board

**iFire:** "use frontier learning and resolve every red measurement use
geometric means in the tools of https://github.com/sinew-mocap/solve" then
"instead of a uv pattern please reuse our toolchain of CHARUCO suits."

### Iteration 1 — geometric landmark picks over the ANNY bone skeleton

Resolved all 11 previously-unsettled fields using the real ANNY FK bone
skeleton (`model.bone_labels`, confirmed by listing it directly) plus the
real `flip_geodesics` CLI, the same two tools already used for the 15
settled fields. Landed as `datasource-anny-render-corpus` PR #5.

- **Rejected and retried, in the log, not silently fixed:** the first
  `shoulder_w` attempt used the `LeftShoulder`/`RightShoulder` bones (the
  clavicle root near the spine) and measured 2.89cm straight-line apart —
  anatomically impossible. The plausibility gate caught it before the
  number was trusted. Retried with `LeftArm`/`RightArm` (the actual
  shoulder-ball joints): 28.30cm straight-line, 33.76cm geodesic — kept.
- **Kept, 11/11 on the second pass:**
  - `shoulder_w` 33.76cm, `neck_w` 14.73cm, `waist_back_width` 27.96cm,
    `hip_back_width` 37.41cm, `back_width` 30.57cm, `armscye_depth` 26.60cm
    — all real surface-path geodesics between a bone-joint vertex and a
    ring-derived (back-half or left/right-most) point.
  - `head_l` 14.80cm (axis extent, HeadEnd bone z − Jaw bone z),
    `vert_bust_line` 21.37cm, `waist_over_bust_line` 10.93cm (both axis
    extents between real bone/ring heights already on hand from the torso
    circumference scan).
  - `bust_points` 32.77cm, `bum_points` 39.90cm (surface paths between
    each ring's left-most and right-most points — the geometric stand-in
    for the two named anatomical points, pending the PDF's exact
    definition).

### Iteration 2 — re-address every landmark via the real ChArUco suit board, not a raw vertex id

The operator pointed out these landmarks should be addressed through the
SAME real toolchain the physical mocap suit uses
(`aruco-marker-visibility-testing` skill: Godot in-engine `xatlas`
`lightmap_unwrap`, 1500 texels/m = 45 texels per real 30mm suit square),
not an ad-hoc host-side vertex index.

Ran the real pipeline: parsed the exported `anny-soma-x.obj` directly in a
headless Godot script (`adapters/suit_board_probe.gd`), built the
`ArrayMesh` (winding swapped per the skill's warning), `SurfaceTool`
`generate_normals()`, then `ArrayMesh.lightmap_unwrap(Transform3D.IDENTITY,
1.0/1500.0)` — the exact call the skill documents. Result: `OK`,
`lightmap_size_hint = (2634, 2722)` texels, vertex count went from 18056
to 24020 after UV-seam splitting (matches the skill's own documented
behavior for this unwrap). Every one of the 18 landmark vertices behind
the 11 resolved fields now has a real suit BOARD CELL address
(`row`, `col` of an actual 30mm printed square), snapped back to its
original 3D position with sub-micron error (confirms the UV lookup is
exact, not approximate) — see `adapters/suit_board_addresses.json` for
every value.

This did not change any measured length (the geodesic/axis-extent numbers
above are unchanged); it changes how each landmark is NAMED and looked up
— as a cell on the real printed suit, the same addressing a camera
reading markers off the real garment would use, instead of an opaque mesh
vertex index tied to one specific OBJ export.

## 2026-11-08 — Real curved geodesics in the diagram; ANNY as real USD; godot-sandbox usd.elf round-trip fixed and verified

**iFire:** "the correct result is a smooth path" (re: the diagram showing
straight chords instead of the actual FlipOut-straightened curve); "you
use store anny in openusd usd.elf you don't need to covnert tri to
quads"; "make measure a proper guest elf"; "please use a proper godot
engine x-ray render not matplot".

### Smooth paths, for real

`TOOL_geodesiac_path`'s CLI got a new `--export-path` flag
(`FlipEdgeNetwork::getPathPolyline3D()`, called AFTER the real
`iterativeShorten`/`makeDelaunay` step — the smooth curve, not the raw
Dijkstra zigzag), landed on the geodesic-probe fork and exercised for
real: `shoulder_w`'s path came back as 65 points tracing a visible curve
over the shoulder, not a 2-point straight line. Every settled
surface-distance/circumference field's real curved polyline is now
loaded into the wireframe render
(`export_real_geodesic_paths.py` → `paths_manifest.json` →
`render_anny_measurement_wireframe.py`), replacing every straight-line
connection in the diagram. The 4 remaining angle/derived fields
(`shoulder_incl` 88.7°, `hip_inclination` 90.7°, `arm_pose_angle`
111.2°, `crotch_hip_diff` 2.2cm) were also computed for real, from the
bone skeleton's own rotation matrices, and are now labeled with their
real values in the diagram instead of being bare unlabeled markers.

### ANNY as real USD, no OBJ, no tri-to-quad

`docs/anny-soma-x.usda` is ANNY's mesh (`model.vertices`/`model.faces`)
written DIRECTLY into a hand-authored `UsdGeomMesh` (`points`,
`faceVertexCounts`, `faceVertexIndices`) — no OBJ text round-trip at any
point in this pipeline. No tri-to-quad conversion happens anywhere
either: confirmed by checking `model.faces.shape` directly, ANNY's own
topology is already pure triangles `(36108, 3)`.

### godot-sandbox usd.elf round-trip: two real bugs found and fixed, not worked around

First attempt crashed the freshly-built sandbox addon on load
(`stack-buffer-overflow`, confirmed via a macOS crash report) — root
cause: the addon was built against `godot-cpp`'s own vendored
`extension_api.json`, not one dumped from THIS workspace's custom Godot
build. Fixed by dumping the real one
(`godot --headless --dump-extension-api`) and rebuilding `godot-cpp`
with `-DGODOTCPP_PRECISION=double` to match the custom editor's
double-precision build (the mismatched default `single` precision
silently fails the binding generator otherwise).

Second real failure then surfaced once the addon loaded cleanly:
`usd.elf`'s `Sandbox.load_buffer()` threw `"Too many arena chunks"` —
libriscv's default 32 MB memory arena / 4000-allocation cap is far too
small for OpenUSD's static init (`TfType` registry, plugin loading,
etc. allocate far more than 4000 small heap objects). Fixed by raising
both limits on the `Sandbox` object itself
(`set_memory_max(256)`, `set_allocations_max(200000)`) before loading
the ELF.

With both real fixes in place, `adapters/usd_roundtrip_probe.gd` proves
the whole chain for real: the actual `usd.elf` guest, running inside the
actual Godot double-precision editor, opens the actual hand-authored
USDA (`usd_open -> ok ... meshes=1`) and its `usd_mesh_points`/
`usd_mesh_indices` match ANNY's own 18056-point/36108-triangle arrays
exactly — point diff `5.4e-7` (the float32 USD storage cast, expected
and bounded), triangle indices byte-exact. `adapters/
usd_roundtrip_mesh_sample.json` records a summary of the verified
output.

### "The anny mesh is corrupted we can only see triangles" — diagnosed and fixed

iFire reported the mesh as corrupted after the USD landed. Checked the
round-trip probe's own `usd_mesh_info` output first rather than
guessing: `"has_normals": false`. The hand-authored USDA never wrote a
`normals` attribute — so any viewer flat-shades every one of the 36108
triangles individually (faceted/"low-poly disco ball" look), which
reads as "corrupted, we can only see triangles" even though the
topology (points, faceVertexIndices) was always correct. Fixed by
computing real per-vertex area-weighted normals (the same formula
`render_view.py`'s `vertex_normals()` already uses) and authoring them
as `normal3f[] normals` with `interpolation = "vertex"`, plus
`uniform token subdivisionScheme = "none"` (USD defaults to Catmull-Clark
subdivision for a `Mesh` prim with no scheme set, which would silently
smooth/alter the triangle geometry a strict tailor's-tape measurement
depends on). Re-ran the real round-trip probe:
`usd_mesh_info(0).has_normals -> true`, points/indices still match
ANNY's own arrays exactly (same blake3 hashes as before — normals-only
change, geometry unchanged).

### "Still open" item CLOSED: a real engine x-ray render, Godot OIT

iFire: "please redo the mesh render. instead of wireframe. please do
x-ray using godot order independent transparency" then "see
entities-godot oit" then "you engine already built it" (correct — the
`entities-godot` worktree for branch `dev/order-independent-
transparency` had ccache-warmed objects from an earlier session; this
rebuild relinked in 37 seconds instead of a cold ~30-40 minute engine
build).

Built the real AVBOIT (adaptive volumetric bucket order-independent
transparency) engine from `v-sekai-fire/dev/order-independent-
transparency` (a git worktree, so the main checkout's build stays
untouched), confirmed real by checking the binary actually exposes
`rendering/oit/enabled`/`rendering/oit/slice_count` (the stock engine
has no such ProjectSetting at all — `adapters/xray_oit_render.gd`
refuses to run and prints an error if that setting is missing, rather
than silently falling back to ordinary alpha blending and calling it
an "x-ray").

`adapters/xray_oit_render.gd`: loads the real ANNY-SOMA-X mesh (same
OBJ this pipeline already exports), renders it as ONE translucent
surface (low alpha, double-sided, unshaded) through the real Metal/
Forward+ renderer with `rendering/oit/enabled=true`, then overlays all
16 real measurement curves from `export_real_geodesic_paths.py`'s
output (green: real `flip_geodesics` curved loops/paths; yellow: real
Euclidean straight-line fields from `euclidean_lines.json`) as opaque
line meshes on top. Run headless with `--display-driver macos
--rendering-driver metal` (NOT `--headless`, which forces the dummy
renderer and produces a null texture — confirmed this fails loudly,
not silently, before finding the right flags).

The result independently confirms the OIT compositing is real, not
just "the body renders": the eyes, nostrils and mouth — the only
places on this closed mesh where a camera ray crosses MORE than two
surface layers (eyelid front+back, nostril interior, lip fold) — render
visibly brighter than the rest of the body, exactly the signature of
correct depth-ordered alpha accumulation across more than one extra
layer. `docs/images/anny-soma-x-xray-oit.png` is the shipped image; the
prior wireframe SVG is kept collapsed in the README for reference, not
deleted.

## 2026-11-08 — Measurement algorithm re-derived from the REAL reference implementation

**iFire:** "https://arxiv.org/html/2405.17609v3/body_measurements.png
https://arxiv.org/html/2405.17609v3#S3.SS3" then
"https://github.com/maria-korosteleva/GarmentCode
https://garmentcode.ethz.ch/ study again".

The GarmentCode README names the REAL source of the measurement
algorithm: `github.com/mbotsch/GarmentMeasurements` — the actual C++
implementation behind GarmentCodeData's paper (prose summaries, even the
paper's own Appendix 0.B, are a step removed from the real code). Cloned
it and read `src/apps/measurements/measure_body.cpp`,
`measurement_utils.cpp`, and every `data/measurements/*.mes` JSON
recipe directly — not re-derived from English description. This
overturned several of this session's own earlier method choices. Every
corrected field below, OLD value -> NEW value, with its real source
citation:

- **`shoulder_w`**: 33.76cm (geodesic) -> **28.30cm** (Euclidean straight
  line, `measure_landmark_distance_euclidean`). The new value also
  independently matches the GarmentCodeData PAPER's own accuracy
  discussion (Sec. 4.1: "we measure on top of the shoulder ball joint"),
  confirming both the landmark pick AND the operation were right once
  corrected.
- **`armscye_depth`**: 26.60cm (geodesic) -> **21.21cm** (Euclidean).
- **`bust_points`**: 32.77cm (geodesic) -> **24.94cm** (Euclidean).
- **`bum_points`**: 39.90cm (geodesic) -> **31.11cm** (Euclidean).
- **`neck_w`**: 14.73cm (left-right CHORD across the neck ring, the
  wrong DEFINITION) -> **34.79cm** (`measure_vertex_trace`: sum of
  straight edges around the FULL neck ring — essentially a
  circumference-like quantity, matching realistic neck-circumference
  magnitude; the prior 14.73cm chord was never the right concept).
- **`wrist`**: re-derived as **13.54cm** via the same `edgeLoopLength`
  operation as `neck_w` (was previously computed via a plane-cut convex
  hull, the WRONG algorithm per the reference source even though the
  number happened to be close).
- **`leg_circ`**: re-derived as **52.26cm** — plane shifted DOWN until
  both legs separate into two loops, value is the MINIMUM of the two at
  that one height (the reference's actual method), not a scan along the
  limb for a maximum circumference.
- **`head_l`**: 14.80cm (jaw-to-crown) -> **23.37cm** (nape-of-neck-to-
  crown, the reference's actual lower landmark — `measure_head_l` names
  `nape_of_neck` explicitly in the C++ source).
- **`shoulder_incl`**: unlabeled marker -> **29.06deg**, real formula
  `angle_plane_vec` (plane normal = horizontal, vector = neck->shoulder
  landmarks).
- **`hip_inclination`**: unlabeled marker -> **-13.07deg**, same formula
  (plane normal = the median/sagittal plane, vector = hips_side_right ->
  waist_side_right).
- **`arm_pose_angle`**: unlabeled marker -> **43.90deg**, same formula
  (plane normal = horizontal, vector = shoulder->wrist landmarks).
- **`bust_line`, `waist_over_bust_line`**: CORRECTLY REVERTED to
  unsettled. The reference computes these as real parasagittal-plane-cut
  polyline LENGTHS along the front torso (a curved surface measurement
  between a lower circumference-intersection plane and an upper
  shoulder-landmark frontal plane) — not the simple axis-aligned
  z-difference this package was computing. Marking a field unsettled
  again, after a real reading proved the existing method wrong, is the
  honest outcome; it is not reverted silently or left mislabeled as
  "done".

Net: **24 of 26 fields settled** today (down from the PREVIOUS claim of
26/26, which rested on 2 fields' methods that this reading now proves
wrong). `MeasureSchema.lean` grew two new real `MeasurementKind`
variants (`euclideanDistance`, `edgeLoopLength`) to represent the
reference's own distinct operations precisely, rather than overloading
`surfaceDistance`/`circumference` to mean something they don't.
`lake exe measure_schema_report` prints the new counts and every
unsettled field's reason — see `adapters/` for the Python/GDScript that
reproduced each corrected value.
