/-
BodyMeasurements.lean — Lean4 spec of the GarmentCode 26-field `body:`
measurement schema.

Field NAMES and units (cm) are taken verbatim from the upstream repo's own
shipped body preset (`maria-korosteleva/GarmentCode`,
`assets/bodies/mean_all.yaml`, `body:` block — 26 keys, confirmed by
counting that file directly, not inferred from `pattern_fitter.py`). This
package does not ship that body's actual measured VALUES (that would be
someone else's fitted data, not a schema); it ships the field set and,
per field, a `MeasurementKind` classification of how `core/geodesic`
would compute it from a mesh.

The precise tailor's-tape definition of each field (which plane, which
landmark) lives in the upstream repo's own
`docs/Body Measurements GarmentCode.pdf` — this module's `kind`
classification is a first-pass reading of each field's NAME and is NOT a
substitute for reading that PDF before wiring real landmark vertex picks;
see the per-field comments below for what is settled vs. still open.
-/
namespace MeasureSchema

/-- How a field's value is obtained from a mesh, in terms of the
`core/geodesic` API (`measureOpenPath` / `measureClosedLoop`) from
`sinew-mocap/measure`'s sibling package. -/
inductive MeasurementKind where
  /-- A closed loop around the body (waist, bust, ...): `measureClosedLoop`,
  Delaunay-only, per the geodesic package's closed-loop safety rule. -/
  | circumference
  /-- A distance between two fixed landmarks along the surface (e.g.
  shoulder to wrist): `measureOpenPath`. -/
  | surfaceDistance
  /-- A straight-line extent along one mesh axis (e.g. overall height):
  no geodesic solve needed, just a min/max over vertex coordinates. -/
  | axisExtent
  /-- A straight 3D (chord) distance between two landmarks — NOT a surface
  geodesic. GarmentCodeData's own published algorithm
  (arxiv.org/abs/2405.17609v3, Appendix 0.B) specifies this exact
  operation for `armscye_depth`, `bum_points`, `bust_points`, and
  `shoulder_w` ("we compute the respective distances between the two
  landmarks") — a straight ruler, not a tape measure laid flat on the
  body. -/
  | euclideanDistance
  /-- The straight-edge (Euclidean, chord-by-chord) perimeter of a loop —
  distinct from `circumference`'s plane-cut convex hull. The published
  algorithm specifies this exact operation for `neck_w` and `wrist`
  ("We use the Euclidean edge loop length to measure the neck width and
  wrist circumference", Appendix 0.B). -/
  | edgeLoopLength
  /-- The height (along the body's vertical axis) at which some OTHER
  field's circumference loop should be sampled, not a distance in its own
  right (the `*_line` fields: `bust_line`, `waist_line`, `hips_line`,
  `vert_bust_line`, `waist_over_bust_line`). -/
  | heightMarker
  /-- A 3D landmark position, not a distance (`bust_points`, `bum_points`:
  GarmentCode's own issue #6 confirms these are POINTS used elsewhere in
  pattern fitting, not lengths). -/
  | landmarkPosition
  /-- An angle, in degrees (`shoulder_incl`, `hip_inclination`,
  `arm_pose_angle`). -/
  | angle
  /-- A derived difference between two other measurements
  (`crotch_hip_diff`). -/
  | difference
  deriving Repr, BEq

/-- One field of the 26-field schema. `settled := true` means the
`kind` classification is confident from the name alone (a plain
circumference or an axis extent); `settled := false` flags a field whose
surface-distance/landmark wiring still needs the PDF definition read
before any vertex indices are picked (see `garmentcodedata-xpbd-pipeline`
skill's warning: ~19 of the 26 fields need geodesic distances and/or named
landmarks a plane cross-section cannot produce). -/
structure Field where
  name : String
  units : String := "cm"
  kind : MeasurementKind
  settled : Bool
  note : String := ""
  deriving Repr

/-- The 26 fields, verbatim names from `assets/bodies/mean_all.yaml`
(counted directly against that file: 26 keys under its `body:` block). -/
def fields : Array Field := #[
  ⟨"height", "cm", .axisExtent, true,
    "top-of-head to floor, trivial mesh extent along the up axis"⟩,
  ⟨"waist", "cm", .circumference, true, "closed loop at waist line height"⟩,
  ⟨"bust", "cm", .circumference, true, "closed loop at bust line height"⟩,
  ⟨"underbust", "cm", .circumference, true,
    "closed loop just below the bust"⟩,
  ⟨"hips", "cm", .circumference, true, "closed loop at hip line height"⟩,
  ⟨"leg_circ", "cm", .circumference, true,
    "CORRECTED per GarmentCodeData arxiv.org/abs/2405.17609v3 App. 0.B: " ++
    "plane shifted DOWN until both legs separate into two loops; value is " ++
    "the MINIMUM of the two legs' perimeters at that one height (not a " ++
    "scan along the limb for a max) — real 52.26cm (plane z=-0.0861)"⟩,
  ⟨"wrist", "cm", .edgeLoopLength, true,
    "CORRECTED per GarmentCodeData App. 0.B: 'Euclidean edge loop length', " ++
    "the same operation as neck_w, not a plane-cut convex hull — real " ++
    "13.54cm"⟩,
  ⟨"arm_length", "cm", .surfaceDistance, true,
    "shoulder (LeftArm bone) to wrist (LeftHand bone), vertices 6058/818 on " ++
    "the ANNY-SOMA-X mesh; real GEODESIC_LENGTH 47.30cm measured via " ++
    "TOOL_geodesiac_path's FlipOut straightening — see AnnySomaX.lean's " ++
    "annySomaXGeodesic fixture and datasource-anny-render-corpus PR #3"⟩,
  ⟨"shoulder_w", "cm", .euclideanDistance, true,
    "CORRECTED per GarmentCodeData arxiv.org/abs/2405.17609v3 App. 0.B: " ++
    "'we compute the respective distances between the two landmarks' — " ++
    "a straight 3D chord, NOT a surface geodesic. LeftArm bone vertex " ++
    "(6058) -> RightArm bone vertex (10523); real EUCLIDEAN 28.30cm — this " ++
    "also matches the paper's own accuracy discussion (Sec. 4.1: 'we " ++
    "measure on top of the shoulder ball joint', confirming the landmark " ++
    "pick). Prior value (33.76cm geodesic) was the wrong OPERATION, kept " ++
    "in CHANGELOG.md's log rather than silently erased."⟩,
  ⟨"neck_w", "cm", .edgeLoopLength, true,
    "CORRECTED per GarmentCodeData App. 0.B: 'We use the Euclidean edge " ++
    "loop length to measure the neck width and wrist circumference' — " ++
    "this is a FULL LOOP's straight-segment perimeter, not a left-right " ++
    "chord. Real 34.79cm (neck ring at z=0.5103). Prior value (14.73cm, " ++
    "a left-right chord across the ring) used the wrong definition " ++
    "entirely, not just the wrong operation — kept in CHANGELOG.md."⟩,
  ⟨"back_width", "cm", .surfaceDistance, true,
    "surface path across the BACK half of the bust ring (z=0.2966), " ++
    "vertex 16650 (row55/col56) <-> vertex 14388 (row53/col3); real " ++
    "30.57cm — PR #5"⟩,
  ⟨"hip_back_width", "cm", .surfaceDistance, true,
    "surface path across the BACK half of the hips ring (z=0.0257), " ++
    "vertex 3752 (row46/col55) <-> vertex 1548 (row52/col12); real " ++
    "37.41cm — PR #5"⟩,
  ⟨"waist_back_width", "cm", .surfaceDistance, true,
    "surface path across the BACK half of the waist ring (z=0.1873), " ++
    "vertex 10814 (row51/col56) <-> vertex 6349 (row53/col7); real " ++
    "27.96cm — PR #5"⟩,
  ⟨"head_l", "cm", .axisExtent, true,
    "CORRECTED per GarmentCodeData App. 0.B: 'distance between the NECK " ++
    "landmark and the highest point of the head', not jaw-to-crown. Axis " ++
    "extent, HeadEnd bone z - Neck1/Neck2 midpoint z; real 23.37cm (prior " ++
    "jaw-based 14.80cm used the wrong lower landmark) — PR #5"⟩,
  ⟨"armscye_depth", "cm", .euclideanDistance, true,
    "CORRECTED per GarmentCodeData App. 0.B (grouped with shoulder_w/" ++
    "bust_points/bum_points as straight-line landmark distances). " ++
    "LeftShoulder bone vertex (2265) -> bust ring's left-most (underarm-" ++
    "side) vertex (10655); real EUCLIDEAN 21.21cm (prior 26.60cm was the " ++
    "geodesic, wrong operation) — PR #5"⟩,
  ⟨"bust_line", "cm", .heightMarker, false,
    "GarmentCodeData App. 0.B reveals this is NOT a sampling-height " ++
    "scalar but a real frontal-torso polyline LENGTH (parasagittal-plane " ++
    "cut from the bust circumference's intersection plane up to the " ++
    "shoulder landmarks' frontal plane) — this package's heightMarker " ++
    "classification and the schema's plane-cut torso_heights usage is " ++
    "the SIMPLER GarmentCode (not GarmentCodeData) reading; marked " ++
    "unsettled again pending a real parasagittal-plane-cut implementation"⟩,
  ⟨"waist_line", "cm", .heightMarker, true,
    "height at which the waist circumference loop is sampled"⟩,
  ⟨"hips_line", "cm", .heightMarker, true,
    "height at which the hips circumference loop is sampled"⟩,
  ⟨"vert_bust_line", "cm", .axisExtent, true,
    "per GarmentCodeData App. 0.B: 'distances between two landmarks ALONG " ++
    "THE UPWARD AXIS' (grouped with crotch_hip_diff and hip_line) — a " ++
    "true axis extent, confirming this package's method. Neck1/Neck2 " ++
    "midpoint z - bust ring z; real 21.37cm — PR #5"⟩,
  ⟨"waist_over_bust_line", "cm", .heightMarker, false,
    "GarmentCodeData App. 0.B: NOT an axis extent — 'a parasagittal " ++
    "plane with least-squares distance to a predefined edge loop', cut " ++
    "polyline between the waist circumference's plane (bottom) and the " ++
    "frontal plane nearest the shoulder landmarks (top). This package's " ++
    "prior axisExtent value (10.93cm, a straight z-difference) is a " ++
    "DOCUMENTED SIMPLIFICATION, not the published method — marked " ++
    "unsettled again pending a real parasagittal-plane-cut implementation"⟩,
  ⟨"bust_points", "cm", .euclideanDistance, true,
    "CORRECTED per GarmentCodeData App. 0.B: straight 3D distance between " ++
    "the bust_left/bust_right landmarks (the bust ring's left-most " ++
    "vertex 10655 and right-most vertex 6190), not a surface path; real " ++
    "EUCLIDEAN 24.94cm (prior 32.77cm was the geodesic) — PR #5"⟩,
  ⟨"bum_points", "cm", .euclideanDistance, true,
    "CORRECTED per GarmentCodeData App. 0.B: straight 3D distance between " ++
    "the bum_left/bum_right landmarks (hips ring's left-most vertex " ++
    "16772, right-most vertex 14510); real EUCLIDEAN 31.11cm (prior " ++
    "39.90cm was the geodesic) — PR #5"⟩,
  ⟨"shoulder_incl", "deg", .angle, true,
    "REAL formula from the published reference implementation " ++
    "(github.com/mbotsch/GarmentMeasurements measure_body.cpp's " ++
    "angle_plane_vec: v=normalize(shoulder-neck), theta=acos(dot(planeN,v))-pi/2, " ++
    "result=-theta in degrees), plane normal = the horizontal (-Y in " ++
    "their Y-up convention = -Z here). Real 29.06deg — PR #6"⟩,
  ⟨"hip_inclination", "deg", .angle, true,
    "REAL formula from GarmentMeasurements (angle_plane_vec, landmarks " ++
    "hips_side_right/waist_side_right, plane normal = the median/" ++
    "sagittal plane, X axis in their convention = X here). Real " ++
    "-13.07deg — PR #6"⟩,
  ⟨"arm_pose_angle", "deg", .angle, true,
    "REAL formula from GarmentMeasurements (angle_plane_vec, landmarks " ++
    "shoulder_right/wrist_right, plane normal = the horizontal, same " ++
    "-Y/-Z convention as shoulder_incl). Real 43.90deg — PR #6"⟩,
  ⟨"crotch_hip_diff", "cm", .difference, true,
    "derived: crotch height vs. hip line height difference"⟩
]

/-- Fields the `core/geodesic` package can already answer with
`measureClosedLoop` once vertex rings are picked (the settled
circumferences). -/
def circumferenceFields : Array Field :=
  fields.filter fun f => f.kind == .circumference

/-- Fields still needing their surface-distance endpoints or landmark
definition read from the upstream PDF before any geodesic query can be
wired — the honest "not done yet" list, not silently skipped. -/
def unsettledFields : Array Field :=
  fields.filter fun f => !f.settled

end MeasureSchema
