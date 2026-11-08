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
    "closed loop around the upper leg (see the `_apart` pose note in " ++
    "garmentcodedata-xpbd-pipeline for why this needs the legs abducted)"⟩,
  ⟨"wrist", "cm", .circumference, true, "closed loop around the wrist"⟩,
  ⟨"arm_length", "cm", .surfaceDistance, true,
    "shoulder (LeftArm bone) to wrist (LeftHand bone), vertices 6058/818 on " ++
    "the ANNY-SOMA-X mesh; real GEODESIC_LENGTH 47.30cm measured via " ++
    "TOOL_geodesiac_path's FlipOut straightening — see AnnySomaX.lean's " ++
    "annySomaXGeodesic fixture and datasource-anny-render-corpus PR #3"⟩,
  ⟨"shoulder_w", "cm", .surfaceDistance, true,
    "surface path, LeftArm bone vertex (6058, suit board cell row24/col4) -> " ++
    "RightArm bone vertex (10523, row20/col23); real GEODESIC/DIJKSTRA " ++
    "33.76cm. A first attempt via LeftShoulder/RightShoulder (the clavicle " ++
    "root) measured an anatomically-impossible 2.89cm and was rejected — " ++
    "see CHANGELOG.md's frontier-learning log and " ++
    "datasource-anny-render-corpus PR #5"⟩,
  ⟨"neck_w", "cm", .surfaceDistance, true,
    "surface path across the neck ring (z=0.5103, Neck1/Neck2 bone height), " ++
    "left-most vertex 2953 (row24/col48) <-> right-most vertex 749 " ++
    "(row25/col2); real 14.73cm — PR #5"⟩,
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
    "axis extent, HeadEnd bone z - Jaw bone z (crown to chin); real " ++
    "14.80cm — PR #5"⟩,
  ⟨"armscye_depth", "cm", .surfaceDistance, true,
    "surface path, LeftShoulder bone vertex 2265 (row31/col50) -> bust " ++
    "ring's left-most (underarm-side) vertex 10655 (row55/col55); real " ++
    "26.60cm — PR #5"⟩,
  ⟨"bust_line", "cm", .heightMarker, true,
    "height at which the bust circumference loop is sampled"⟩,
  ⟨"waist_line", "cm", .heightMarker, true,
    "height at which the waist circumference loop is sampled"⟩,
  ⟨"hips_line", "cm", .heightMarker, true,
    "height at which the hips circumference loop is sampled"⟩,
  ⟨"vert_bust_line", "cm", .heightMarker, true,
    "axis extent, Neck1/Neck2 midpoint z - bust ring z; real 21.37cm — PR #5"⟩,
  ⟨"waist_over_bust_line", "cm", .heightMarker, true,
    "axis extent, bust ring z - waist ring z; real 10.93cm — PR #5"⟩,
  ⟨"bust_points", "cm", .surfaceDistance, true,
    "surface path between the bust ring's left-most vertex 10655 " ++
    "(row55/col55) and right-most vertex 6190 (row52/col3); real " ++
    "32.77cm — the geometric stand-in for the two named bust-apex " ++
    "points (GarmentCode issue #6 confirms these are points, not a " ++
    "length in general, but this schema's scalar field reads as an " ++
    "inter-point distance) — PR #5"⟩,
  ⟨"bum_points", "cm", .surfaceDistance, true,
    "surface path between the hips ring's left-most vertex 16772 " ++
    "(row46/col54) and right-most vertex 14510 (row51/col12); real " ++
    "39.90cm — same caveat as bust_points — PR #5"⟩,
  ⟨"shoulder_incl", "deg", .angle, true, "shoulder slope angle"⟩,
  ⟨"hip_inclination", "deg", .angle, true, "hip tilt angle"⟩,
  ⟨"arm_pose_angle", "deg", .angle, true, "rest-pose arm abduction angle"⟩,
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
