/-
AnnySomaX.lean — real, previously-measured values for the ANNY-SOMA-X body,
used as a verification fixture for this schema (NOT placeholder/fabricated
data).

Provenance: computed in a prior session from the ANNY-SOMA-X mesh via plane
cross-sections (not from this package, and not yet via the geodesic solve
this repo ports — see `core/geodesic`'s README "Status" section for why a
plane cross-section is a rough starting value, not the final tailor's-tape
answer). Landed in `V-Sekai-fire/datasource-anny-render-corpus` PR #2
(`measure_anny_circumferences.py`, commit `aee706a`), with two real bugs
caught by planted controls before trusting the numbers (a loop-selection
bug that silently rejected every torso slice, and a 101cm "thigh" that was
actually the pelvis bleeding through) — see that PR's description for
detail. 7 of the 26 schema fields; the rest were explicitly left undone
rather than guessed.
-/
import MeasureSchema.BodyMeasurements

namespace MeasureSchema

/-- The 7 of 26 fields with a real, previously-computed value for the
ANNY-SOMA-X body (cm). Everything else is `none`: this constant exists to
regression-test `BodyMeasurements.fields`' names against known-real data,
not to pretend the schema is fully populated. -/
def annySomaXPartial : List (String × Float) := [
  ("waist", 62.4941),
  ("bust", 71.7924),
  ("underbust", 62.5103),
  ("hips", 85.4339),
  ("leg_circ", 51.3488),
  ("wrist", 13.5361),
  ("height", 156.7366)
]

/-- Sanity: every name in the fixture must be a real field of the schema
(catches a typo'd field name silently going unchecked), and every one of
those fields must itself be classified `circumference` or `axisExtent` —
the mechanically well-defined subset a plane cross-section can answer at
all, consistent with how these 7 were actually computed. (`wrist` is
back to `circumference` as of the 2026-11-08 geodesic-reversion pass —
see `annySomaXFrontier`'s module doc.) -/
def annySomaXFixtureIsConsistent : Bool := Id.run do
  for (name, _) in annySomaXPartial do
    match fields.find? (·.name == name) with
    | none => return false
    | some f =>
      if f.kind != .circumference && f.kind != .axisExtent then
        return false
  return true

/-- Real geodesic measurements (cm) for the same ANNY-SOMA-X mesh, from
`V-Sekai-fire/datasource-anny-render-corpus` PR #3
(`measure_anny_geodesic_loops.py`, commit `ad0fab9`), run through the
ACTUAL `V-Sekai-fire/TOOL_geodesiac_path` headless CLI
(`--measure-loop`/`--measure-path`) against the real exported mesh — not
a plane cross-section, and not a Lean-internal simulation. Loop vertex
rings were snapped from the already-validated `annySomaXPartial`
cross-section loop to their nearest actual mesh vertices (a naive
angular-bin pick over all near-plane vertices pulled in arm vertices and
produced a nonsense 276cm "waist" on the first attempt — see that PR's
commit message); every value here passed an explicit plausibility gate
(closed loop: within 15% of the cross-section reference; open path:
`>=` the straight-line chord distance) before being trusted.

`arm_length` is new: the open path from the `LeftArm` shoulder bone to
the `LeftHand` wrist bone (mesh vertices 6058 and 818), reported as
`GEODESIC_LENGTH` — the actual FlipOut-straightened result (50
`iterativeShorten` iterations, 191 edge flips), not just the unstraightened
Dijkstra length — making this the first of the 26 fields' previously
"needs landmark data" subset settled with a real measured value rather
than left undone.

The waist/underbust/hips/bust VALUES were revised again 2026-11-08
(`datasource-anny-render-corpus` PR #10, then PR #11): DELAUNAY_LENGTH
(plain Delaunay retriangulation, no shortening) was superseded by the
real geodesic length from `TOOL_geodesiac_path`'s
`--measure-loop-adaptive-shorten` (a mesh-size-INDEPENDENT stopping
criterion -- target max turning angle, not a fixed iteration/length-
decrease budget tuned to one mesh; iFire: "it has to work for possible
anny and custom models so you can't hard code" -- see
`annySomaXFrontier`'s module doc for PR #11's fix). Found and fixed a
real inverted-parameter bug in `iterativeShorten`'s wrapper along the
way (iFire: "please use the tool for geodesic paths pls and fix it",
then "uh thats not a definition of geodesiac" correcting an earlier
misdiagnosis) -- see CHANGELOG.md for the full story and every old
value. -/
def annySomaXGeodesic : List (String × Float) := [
  ("waist", 63.057),
  ("underbust", 62.9899),
  ("hips", 86.8116),
  ("bust", 71.3415),
  ("arm_length", 47.2983)
]

/-- Same consistency check as `annySomaXFixtureIsConsistent`, for the
geodesic fixture: `arm_length` is `surfaceDistance` rather than
`circumference`/`axisExtent`, since it is an open path, not a loop. -/
def annySomaXGeodesicFixtureIsConsistent : Bool := Id.run do
  for (name, _) in annySomaXGeodesic do
    match fields.find? (·.name == name) with
    | none => return false
    | some f =>
      if f.kind != .circumference && f.kind != .axisExtent && f.kind != .surfaceDistance then
        return false
  return true

/-- A cell address on the real printed ChArUco suit board: one 30mm square,
identified by (row, col) in the generated 49x65 board grid (see the
`aruco-marker-visibility-testing` skill's `CharucoBoard((49, 65), 0.03,
0.022, ...)`). This is the suit's own addressing scheme, not a raw mesh
vertex index tied to one specific OBJ export. -/
structure SuitBoardCell where
  row : Nat
  col : Nat
  deriving Repr, BEq

/-- The 11 fields resolved in the frontier-learning iteration of
2026-11-08 (CHANGELOG.md), via real geometric means over the ANNY FK bone
skeleton and the real `flip_geodesics` CLI — `datasource-anny-render-corpus`
PR #5. `shoulder_w` is the KEPT value after a first attempt (via the
clavicle-root bones) was rejected by its own plausibility gate for
measuring an anatomically-impossible 2.89cm — see that PR and the
CHANGELOG for the rejected attempt, kept in the log rather than erased.

A second pass (PR #6) read the published reference implementation
(`github.com/mbotsch/GarmentMeasurements`, the actual C++ source behind
GarmentCodeData, arxiv.org/abs/2405.17609v3) and switched `shoulder_w`,
`armscye_depth`, `bust_points`, `bum_points` to its literal Euclidean
straight-line operation, and `neck_w`/`wrist` to its literal Euclidean
edge-loop-length operation.

A THIRD pass (2026-11-08, PR #7, iFire: "you must use geodesic for the
ones that seem like tape masurable") reverted ALL SIX of those back to
the real surface geodesic / Delaunay-tightened closed loop: a tailor's
physical tape follows the body's surface for every one of these
(shoulder-to-shoulder over the trapezius, shoulder-to-underarm down the
front, nipple-to-nipple across the chest, hip-point-to-hip-point,
around the neck, around the wrist) — a DELIBERATE, STATED deviation
from the published reference's literal (and, for these six, less
physically faithful) Euclidean choice. `head_l` stays an axis extent
(a tailor uses a straight rule for height-style measurements, not a
draped tape over the scalp) and the 3 angle fields are unaffected
(`angle_plane_vec`, plane-normal vs. landmark-vector angle, not a
bone-rotation comparison).

A FOURTH pass (2026-11-08, PR #10) replaced `neck_w`/`wrist`/`leg_circ`'s
DELAUNAY_LENGTH with a real shortened geodesic length, after finding
and fixing a genuinely inverted-semantics bug in `TOOL_geodesiac_path`'s
`iterativeShorten` CLI wrapper (iFire: "please use the tool for
geodesic paths pls and fix it"; an earlier misdiagnosis blaming
inherent 3D surface wobble was corrected: "uh thats not a definition of
geodesiac" — a piecewise-Dijkstra-stitched loop has real hard corners
at every anchor vertex by construction, not a geodesic at all).

A FIFTH pass (2026-11-08, PR #11) replaced the fixed iteration/length-
decrease budget from PR #10 with `--measure-loop-adaptive-shorten`'s
mesh-size-INDEPENDENT stopping rule (target max turning angle, not an
empirically-tuned count): iFire: "it has to work for possible anny and
custom models so you can't hard code" -- the PR #10 budget (200
iterations, 10% max decrease) was tuned against THIS mesh's specific
loop sizes and would not transfer correctly to a different ANNY
phenotype or a custom model. Every superseded value from all five
passes is kept in CHANGELOG.md's log, not silently erased. -/
def annySomaXFrontier : List (String × Float) := [
  ("shoulder_w", 33.76), ("neck_w", 35.31), ("back_width", 30.57),
  ("hip_back_width", 37.41), ("waist_back_width", 27.96),
  ("head_l", 23.37), ("armscye_depth", 26.60),
  ("vert_bust_line", 21.37),
  ("bust_points", 32.77), ("bum_points", 39.90),
  ("wrist", 13.69), ("leg_circ", 51.75),
  ("shoulder_incl", 29.06), ("hip_inclination", -13.07), ("arm_pose_angle", 43.90)
]

/-- Every landmark vertex behind `annySomaXFrontier`'s surface-distance
fields (the axis-extent fields -- head_l, vert_bust_line,
waist_over_bust_line -- have no single vertex pair and so no board cell
here), re-addressed via the REAL ChArUco suit toolchain: a headless Godot
run (`adapters/suit_board_probe.gd`) that parses the real exported OBJ,
builds the `ArrayMesh`, runs the actual `SurfaceTool.generate_normals()`
+ `ArrayMesh.lightmap_unwrap(Transform3D.IDENTITY, 1.0/1500.0)` call the
suit pipeline itself uses (1500 texels/m = 45 texels per real 30mm
square), and floors each landmark's UV2 texel position by 45 to get its
board cell. See `adapters/suit_board_addresses.json` for the full
per-landmark detail (UV2, texel position, sub-micron snap distance back
to the original 3D point, confirming the lookup is exact). -/
def annySomaXSuitBoardCells : List (String × SuitBoardCell) := [
  ("shoulder_w_left", ⟨24, 4⟩), ("shoulder_w_right", ⟨20, 23⟩),
  ("neck_w_left", ⟨24, 48⟩), ("neck_w_right", ⟨25, 2⟩),
  ("back_width_left", ⟨55, 56⟩), ("back_width_right", ⟨53, 3⟩),
  ("hip_back_width_left", ⟨46, 55⟩), ("hip_back_width_right", ⟨52, 12⟩),
  ("waist_back_width_left", ⟨51, 56⟩), ("waist_back_width_right", ⟨53, 7⟩),
  ("armscye_depth_shoulder", ⟨31, 50⟩), ("armscye_depth_underarm", ⟨55, 55⟩),
  ("bust_points_left", ⟨55, 55⟩), ("bust_points_right", ⟨52, 3⟩),
  ("bum_points_left", ⟨46, 54⟩), ("bum_points_right", ⟨51, 12⟩),
  ("arm_length_shoulder", ⟨24, 4⟩), ("arm_length_wrist", ⟨23, 20⟩)
]

/-- Sanity: every frontier field is a real schema field, classified
`surfaceDistance`, `axisExtent`, `circumference`, or `angle` — the
kinds `annySomaXFrontier` actually covers after the 2026-11-08
geodesic-reversion pass (see that constant's module doc: `shoulder_w`,
`armscye_depth`, `bust_points`, `bum_points` moved back to
`surfaceDistance`; `neck_w`, `wrist` moved back to `circumference`).
`heightMarker` is NOT included: `waist_over_bust_line` was dropped from
this fixture entirely rather than kept under the wrong kind — see
CHANGELOG.md. -/
def annySomaXFrontierFixtureIsConsistent : Bool := Id.run do
  for (name, _) in annySomaXFrontier do
    match fields.find? (·.name == name) with
    | none => return false
    | some f =>
      if f.kind != .surfaceDistance && f.kind != .axisExtent &&
         f.kind != .circumference && f.kind != .angle then
        return false
  return true

end MeasureSchema
