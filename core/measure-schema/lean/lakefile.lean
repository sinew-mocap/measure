import Lake
open Lake DSL

-- Lean4 spec of the GarmentCode 26-field `body:` measurement schema (see
-- `maria-korosteleva/GarmentCode`'s `docs/Body Measurements GarmentCode.pdf`,
-- mirrored at V-Sekai-fire/NvidiaWarp-GarmentCode's companion pygarment
-- repo). This package has no dependency on the geodesic solver itself —
-- it is the schema plus a per-field QUERY PLAN (open path vs. closed loop,
-- which vertices/landmarks) that `core/geodesic` is wired to answer.
package MeasureSchema where

@[default_target] lean_lib MeasureSchema

lean_exe measure_schema_report where
  root := `Reports.FieldCoverage
