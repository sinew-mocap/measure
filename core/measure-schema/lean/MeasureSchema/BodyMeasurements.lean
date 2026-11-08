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
  ⟨"arm_length", "cm", .surfaceDistance, false,
    "shoulder landmark to wrist landmark; open-path endpoints not yet picked"⟩,
  ⟨"shoulder_w", "cm", .surfaceDistance, false,
    "shoulder-to-shoulder across the back/front; endpoints not yet picked"⟩,
  ⟨"neck_w", "cm", .surfaceDistance, false,
    "neck base width; endpoints not yet picked"⟩,
  ⟨"back_width", "cm", .surfaceDistance, false,
    "across-back width; endpoints not yet picked"⟩,
  ⟨"hip_back_width", "cm", .surfaceDistance, false,
    "across-back width at hip height; endpoints not yet picked"⟩,
  ⟨"waist_back_width", "cm", .surfaceDistance, false,
    "across-back width at waist height; endpoints not yet picked"⟩,
  ⟨"head_l", "cm", .surfaceDistance, false,
    "head length; open-path endpoints not yet picked (could also be an " ++
    "axisExtent depending on the PDF's exact definition — unread)"⟩,
  ⟨"armscye_depth", "cm", .surfaceDistance, false,
    "armhole depth; definition needs the PDF, not yet read"⟩,
  ⟨"bust_line", "cm", .heightMarker, true,
    "height at which the bust circumference loop is sampled"⟩,
  ⟨"waist_line", "cm", .heightMarker, true,
    "height at which the waist circumference loop is sampled"⟩,
  ⟨"hips_line", "cm", .heightMarker, true,
    "height at which the hips circumference loop is sampled"⟩,
  ⟨"vert_bust_line", "cm", .heightMarker, false,
    "a second, vertical bust-related marker; exact meaning needs the PDF"⟩,
  ⟨"waist_over_bust_line", "cm", .heightMarker, false,
    "waist-to-bust vertical offset marker; exact meaning needs the PDF"⟩,
  ⟨"bust_points", "cm", .landmarkPosition, false,
    "bust point landmark(s); GarmentCode issue #6 confirms these are " ++
    "points, not a length — representation as a single scalar in the " ++
    "source yaml likely encodes an inter-bust-point distance or offset; " ++
    "confirm against the PDF before treating it as either"⟩,
  ⟨"bum_points", "cm", .landmarkPosition, false,
    "buttock point landmark(s); same caveat as bust_points"⟩,
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
