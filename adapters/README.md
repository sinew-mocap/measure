# adapters — not yet implemented

The `core/geodesic` and `core/measure-schema` Lean4 packages are pure specs
with no IO and no dependency on any sibling repo (see
`ports/sibling-repos.txt`). An adapter here would be the piece that drives
them against something real:

- A `TOOL_geodesiac_path` adapter: shell out to its headless CLI
  (`--measure-path vStart,vEnd` / `--measure-loop v1,v2,...`, see that
  repo's own README "Command line interface") as the ground-truth oracle
  for `core/geodesic`'s `DIJKSTRA_LENGTH`/`DELAUNAY_LENGTH`, the same
  differential-oracle step `hexagonal-ports-adapters` prescribes before any
  running C++ implementation is retired in favor of the Lean port.
- A `sinew-mocap/solve` adapter: read the ANNY body mesh `solve` produces
  and hand its vertex positions/faces to `core/geodesic`'s `TriMesh`.
- A landmark-picker adapter: resolve the ~12 still-`unsettled` fields in
  `core/measure-schema`'s `BodyMeasurements.lean` to actual vertex indices
  (via ANNY's own keypoint regressor or a manual pick), once their exact
  tailor's-tape definition is read from GarmentCode's own
  `docs/Body Measurements GarmentCode.pdf`.

None of the three exist yet. This file is the placeholder so the hexagon
layout (`core/` + `ports/` + `adapters/`) is visible from the first commit.
