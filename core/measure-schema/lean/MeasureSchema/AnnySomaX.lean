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

end MeasureSchema
