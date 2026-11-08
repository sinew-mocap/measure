/-
FieldCoverage.lean — prints the 26-field schema's coverage status, and
regression-checks every ANNY-SOMA-X fixture against it. Exits 1 on any
inconsistency (a typo'd fixture field name, or a fixture value attached to
a field this schema doesn't classify as reachable by that fixture's
technique).
-/
import MeasureSchema

def main : IO Unit := do
  let settled := MeasureSchema.fields.filter (·.settled)
  let unsettled := MeasureSchema.unsettledFields
  IO.println s!"MeasureSchema: {MeasureSchema.fields.size} fields total"
  IO.println s!"  settled (kind classification confident): {settled.size}"
  IO.println s!"  unsettled (needs the upstream PDF before wiring): {unsettled.size}"
  IO.println s!"  circumference fields (closed-loop, geodesic-ready): {MeasureSchema.circumferenceFields.size}"
  for f in unsettled do
    IO.println s!"    unsettled: {f.name} — {f.note}"
  if MeasureSchema.fields.size != 26 then
    IO.eprintln s!"FAIL: expected 26 fields (the upstream mean_all.yaml body: block), got {MeasureSchema.fields.size}"
    IO.Process.exit 1
  if !MeasureSchema.annySomaXFixtureIsConsistent then
    IO.eprintln "FAIL: ANNY-SOMA-X fixture is inconsistent with the schema (see AnnySomaX.lean)"
    IO.Process.exit 1
  if !MeasureSchema.annySomaXGeodesicFixtureIsConsistent then
    IO.eprintln "FAIL: ANNY-SOMA-X geodesic fixture is inconsistent with the schema (see AnnySomaX.lean)"
    IO.Process.exit 1
  if !MeasureSchema.annySomaXFrontierFixtureIsConsistent then
    IO.eprintln "FAIL: ANNY-SOMA-X frontier fixture is inconsistent with the schema (see AnnySomaX.lean)"
    IO.Process.exit 1
  IO.println s!"ANNY-SOMA-X fixture: {MeasureSchema.annySomaXPartial.length} real measured values, consistent with schema"
  IO.println s!"ANNY-SOMA-X geodesic fixture: {MeasureSchema.annySomaXGeodesic.length} real flip_geodesics-measured values, consistent with schema"
  IO.println s!"ANNY-SOMA-X frontier fixture: {MeasureSchema.annySomaXFrontier.length} real geometric-means values, consistent with schema"
  IO.println s!"ANNY-SOMA-X suit board cells: {MeasureSchema.annySomaXSuitBoardCells.length} landmarks re-addressed via the real ChArUco suit board"
  if unsettled.size == 0 then
    IO.println "all 26 of 26 fields settled"
  IO.println "all checks passed"
