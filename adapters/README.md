# adapters

## `measure_anny_geodesic_loops.py` — real, run and verified

Drives `TOOL_geodesiac_path`'s headless `flip_geodesics` CLI against the
real ANNY-SOMA-X mesh (`sinew-mocap/solve`'s ANNY body). This is the
TOOL_geodesiac_path + solve adapter: it exports the mesh to OBJ, picks real
vertex rings/landmark pairs, and reads back `DIJKSTRA_LENGTH`/
`DELAUNAY_LENGTH`/`GEODESIC_LENGTH` from the actual tool. Run and landed
upstream (with results) as `V-Sekai-fire/datasource-anny-render-corpus`
PR #3, commit `ad0fab9`; see the script's own module docstring for the
real measured numbers and `core/measure-schema`'s `AnnySomaX.lean`
`annySomaXGeodesic` fixture for where those numbers are regression-checked.

Needs (not vendored here): a built `TOOL_geodesiac_path` (`flip_geodesics`
binary) and a Python env with `anny`, `trimesh`, `torch` (the `anny-mac`
pixi env in `sinew-mocap`'s render-corpus repos has both).

Not yet done the same way: `leg_circ`/`wrist` (limb circumferences — would
need the same ring-snap technique applied to the limb's own perpendicular
cross-section loop), and the remaining ~11 schema fields still flagged
`unsettled` in `core/measure-schema`'s `BodyMeasurements.lean`.

## Still not implemented

- A landmark-picker adapter for the fields whose exact definition still
  needs reading from GarmentCode's own
  `docs/Body Measurements GarmentCode.pdf` (shoulder_w, neck_w, back_width,
  hip_back_width, waist_back_width, head_l, armscye_depth, vert_bust_line,
  waist_over_bust_line, bust_points, bum_points).
- A Lean-side binding that calls out to `flip_geodesics` directly (today
  the adapter above is a standalone Python script; `core/geodesic`'s Lean
  port and this script are two independent implementations compared by
  hand, not wired together automatically).
