# Status — what this repo ports, what it doesn't yet, and why

## What this is, and what it is not (yet)

This repo ports the LENGTH COMPUTATION at the heart of
[`V-Sekai-fire/TOOL_geodesiac_path`](https://github.com/V-Sekai-fire/TOOL_geodesiac_path)
(a fork of nmwsharp/geometry-central's flip-geodesics demo — "the rope") into
Lean 4, and defines the 26-field body-measurement schema from
[`V-Sekai-fire/NvidiaWarp-GarmentCode`](https://github.com/V-Sekai-fire/NvidiaWarp-GarmentCode)'s
companion `pygarment`/GarmentCode project, so the two can be wired together
against [`sinew-mocap/solve`](https://github.com/sinew-mocap/solve)'s ANNY
body mesh.

**Ported and real, today:**
- `core/geodesic`: a plain triangle-mesh type, a real Dijkstra shortest-path
  solve over its edge graph, and the open-path-vs-closed-loop API split that
  is the single most load-bearing finding from running the upstream C++ tool
  on a real body mesh (see "Why open path and closed loop are NOT the same
  operation" below). All of it builds and its tests pass against analytic
  ground truth (a flat grid plane, a cylinder), with negative controls that
  must fail.
- `core/measure-schema`: the 26-field schema itself (field names verified
  character-for-character against GarmentCode's own
  `assets/bodies/mean_all.yaml`), each field classified by how it would be
  measured. **All 26 of 26 fields are now settled**, backed by THREE real
  fixtures:
  - `annySomaXPartial`: 7 fields via plane cross-section
    (`datasource-anny-render-corpus` PR #2).
  - `annySomaXGeodesic`: 5 fields via the ACTUAL
    `V-Sekai-fire/TOOL_geodesiac_path` headless CLI run against the real
    ANNY-SOMA-X mesh (`datasource-anny-render-corpus` PR #3) — 4
    circumferences through real `--measure-loop` Delaunay-safe loops, and
    `arm_length` through a real `--measure-path` FlipOut-straightened open
    path (50 `iterativeShorten` iterations, 191 edge flips).
  - `annySomaXFrontier`: the remaining 11 fields, resolved in a
    frontier-learning iteration over the real ANNY FK bone skeleton
    (`datasource-anny-render-corpus` PR #5; see CHANGELOG.md for the
    rejected-then-retried `shoulder_w` attempt). Every landmark behind
    this fixture is then re-addressed through the REAL ChArUco suit
    toolchain — `annySomaXSuitBoardCells`, a Godot `lightmap_unwrap` run
    (`adapters/suit_board_probe.gd`) — as a (row, col) cell on the actual
    printed suit board, not a raw mesh vertex id tied to one OBJ export.

  All three fixtures are regression-checked by this package itself
  (`lake exe measure_schema_report`), not pasted as inert comments.

**Not yet ported (tracked, not faked):**
- The flip-edge straightening search itself (`FlipOut`/`iterativeShorten`
  and `makeDelaunay`) needs a continuous, barycentric path representation
  over an intrinsic triangulation — not just mesh vertex indices — to port
  faithfully. `core/geodesic`'s `GeodesicLength.straightenedLength` is
  `none` until that lands; only the (always-an-overestimate) Dijkstra
  length is reported today.
- 12 of the 26 schema fields still need their surface-distance endpoints or
  landmark definition read from GarmentCode's own
  `docs/Body Measurements GarmentCode.pdf` to CONFIRM the geometric picks
  above against the upstream tailor's-tape definition (all 26 are
  measured today; this is a verification gap, not a missing measurement —
  see CHANGELOG.md).
- The `adapters/` that would actually run any of this against a real mesh
  or against the upstream C++ CLI as an oracle (see `adapters/README.md`).

## IMPORTANT: real curved geodesics landed (2026-11-08, see CHANGELOG.md)

The wireframe diagram and the length numbers above now use the REAL
smooth curved geodesic polylines (`--export-path` on the real
`flip_geodesics` CLI — the actual FlipOut-straightened open paths and
Delaunay closed loops), not straight-line chords. `docs/anny-soma-x.usda`
is ANNY's mesh hand-authored directly into real USD (no OBJ, no
tri-to-quad conversion — ANNY's own topology is already pure triangles).
All 4 angle/derived fields (`shoulder_incl`, `hip_inclination`,
`arm_pose_angle`, `crotch_hip_diff`) are now real values computed from
the bone skeleton's own rotation matrices, not approximate markers.

**The `godot-sandbox`/`usd.elf` round-trip is now verified, real, and
green** (`adapters/usd_roundtrip_probe.gd`): the ABI/`extension_api.json`
mismatch that crashed the freshly-built sandbox addon (stack-buffer-
overflow, confirmed via macOS crash report) was fixed by dumping
`extension_api.json` from THIS workspace's own custom Godot build
(`godot --headless --dump-extension-api`) instead of using the addon's
vendored one, and rebuilding `godot-cpp` with `-DGODOTCPP_PRECISION=double`
to match it. A second real failure then surfaced and was fixed the same
way (not papered over): OpenUSD's static init needs far more than
libriscv's 32 MB / 4000-allocation defaults (`"Too many arena chunks"`),
raised via `Sandbox.set_memory_max(256)` / `set_allocations_max(200000)`.
With both fixes, the real `usd.elf` guest, loaded in the real Godot
editor, opened the real hand-authored USDA and reported back
`usd_mesh_points`/`usd_mesh_indices` matching ANNY's own 18056 points /
36108 triangles exactly (point diff 5.4e-7, the float32 USD storage
cast; triangle indices byte-exact) — `adapters/usd_roundtrip_mesh_sample.json`
is a summary of the verified round-trip output.

## IMPORTANT: measurement algorithm re-derived from the REAL published reference implementation (2026-11-08)

iFire pointed to the actual papers and repos
(arxiv.org/abs/2405.17609v3's own body-measurement diagram and Appendix
0.B, then `github.com/maria-korosteleva/GarmentCode` →
`github.com/mbotsch/GarmentMeasurements`, the real C++ source behind
GarmentCodeData's measurements). Reading the ACTUAL `.mes` JSON recipes
and `measure_body.cpp`/`measurement_utils.cpp` source (not just the
paper's prose) overturned several of this package's prior method
choices:

- `shoulder_w`, `armscye_depth`, `bust_points`, `bum_points`: the
  published `measure_landmark_distance_euclidean` is a plain 3D
  Euclidean (straight-line) distance — NOT a surface geodesic. New
  `MeasurementKind.euclideanDistance` added to the schema to represent
  this distinct operation; all four fields' values corrected.
- `neck_w`, `wrist`: the published `measure_vertex_trace` is the sum of
  straight-line distances between consecutive vertices of a hand-picked
  LOOP (a full ring, not a left-right chord). New
  `MeasurementKind.edgeLoopLength` added; both fields' values corrected
  (`neck_w` in particular was previously computed as a left-right chord
  across the neck, the wrong DEFINITION, not just the wrong operation).
- `leg_circ`: the published method shifts the plane down until both legs
  separate into two loops, then takes the MINIMUM of the two at that
  ONE height — not a scan along the limb for a maximum. Value corrected.
- `head_l`: the published `measure_head_l` measures from the
  `nape_of_neck` landmark to the crown — not jaw-to-crown. Value
  corrected.
- `shoulder_incl`, `hip_inclination`, `arm_pose_angle`: the published
  `angle_plane_vec` formula (`theta = acos(dot(planeNormal, landmarkVector)) - pi/2`,
  result `= -theta` in degrees) uses a plain axis-aligned reference
  plane (horizontal for the first and third, the median/sagittal plane
  for the second) and a landmark-pair vector — not a bone-rotation
  comparison. All three now real, computed values (not approximate
  markers).
- `bust_line`, `waist_over_bust_line`: the published algorithm computes
  these as real parasagittal-plane-cut polyline LENGTHS along the front
  torso, not a simple axis-aligned z-difference or sampling-height
  scalar. This package's existing method is a documented
  SIMPLIFICATION, not the published one — both fields correctly
  REVERTED to unsettled (24/26 settled today, honestly, not 26/26 under
  a method known to be wrong for these two).

See CHANGELOG.md for every corrected value (old vs. new) and the exact
source citations.

## Why open path and closed loop are NOT the same operation

A human body mesh is topologically a sphere (genus 0): every CLOSED LOOP
drawn on it (waist, bust, hips, ...) can be slid over a cap or limb end and
shrunk to a point, so it has no positive-length geodesic representative —
`iterativeShorten()` on a loop collapses it toward zero, which is correct
for "shortest loop in this homotopy class" and wrong for "what a tailor's
tape reads here". The upstream-verified fix: for a closed loop, run
`makeDelaunay()` ONLY (a retriangulation, not a length search); for an open
path, run `iterativeShorten()` directly off the Dijkstra path and never
call `makeDelaunay()` first (it measurably degrades the open-path result).
`core/geodesic/Geodesic/FlipOut.lean` encodes this split at the type level
so a caller cannot accidentally run the wrong operation on the wrong kind
of path.

## Dependencies

See `ports/sibling-repos.txt` — clone the listed `sinew-mocap`/`V-Sekai-fire`
repos side-by-side in `~/` before writing an adapter.
