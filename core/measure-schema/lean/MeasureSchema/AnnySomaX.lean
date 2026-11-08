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
all, consistent with how these 7 were actually computed. -/
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
than left undone. -/
def annySomaXGeodesic : List (String × Float) := [
  ("waist", 65.4053),
  ("underbust", 69.3587),
  ("hips", 94.9053),
  ("bust", 81.0787),
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
CHANGELOG for the rejected attempt, kept in the log rather than erased. -/
def annySomaXFrontier : List (String × Float) := [
  ("shoulder_w", 33.76), ("neck_w", 14.73), ("back_width", 30.57),
  ("hip_back_width", 37.41), ("waist_back_width", 27.96),
  ("head_l", 14.80), ("armscye_depth", 26.60),
  ("vert_bust_line", 21.37), ("waist_over_bust_line", 10.93),
  ("bust_points", 32.77), ("bum_points", 39.90)
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
`surfaceDistance`, `axisExtent`, or `heightMarker` (the three kinds
`annySomaXFrontier` actually covers). -/
def annySomaXFrontierFixtureIsConsistent : Bool := Id.run do
  for (name, _) in annySomaXFrontier do
    match fields.find? (·.name == name) with
    | none => return false
    | some f =>
      if f.kind != .surfaceDistance && f.kind != .axisExtent && f.kind != .heightMarker then
        return false
  return true

end MeasureSchema
