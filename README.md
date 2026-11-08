# measure — sinew-mocap

CI

A hexagon cluster (`core/` + `ports/` + `adapters/`) of the Sinew mocap
stack: body measurement via flip-geodesics (a "tape measure that follows
the surface"), extracted and formalized in Lean 4.

## What this is, and what it is not (yet)

This repo ports the LENGTH COMPUTATION at the heart of
[`V-Sekai-fire/TOOL_geodesiac_path`](https://github.com/V-Sekai-fire/TOOL_geodesiac_path)
(a fork of nmwsharp/geometry-central's flip-geodesics demo — "the rope") into
Lean 4, and defines the 26-field body-measurement schema from
[`V-Sekai-fire/NvidiaWarp-GarmentCode`](https://github.com/V-Sekai-fire/NvidiaWarp-GarmentCode)'s
companion `pygarment`/GarmentCode project, so the two can be wired together
against [`sinew-mocap/solve`](https://github.com/sinew-mocap/solve)'s ANNY
body mesh.

**Ported and real, today:**
- `core/geodesic`: a plain triangle-mesh type, a real Dijkstra shortest-path
  solve over its edge graph, and the open-path-vs-closed-loop API split that
  is the single most load-bearing finding from running the upstream C++ tool
  on a real body mesh (see "Pitfalls" below). All of it builds and its tests
  pass against analytic ground truth (a flat grid plane, a cylinder), with
  negative controls that must fail.
- `core/measure-schema`: the 26-field schema itself (field names verified
  character-for-character against GarmentCode's own
  `assets/bodies/mean_all.yaml`), each field classified by how it would be
  measured, plus a fixture of 7 real, previously-measured ANNY-SOMA-X values
  (from `V-Sekai-fire/datasource-anny-render-corpus` PR #2) that this
  package regression-checks itself against.

**Not yet ported (tracked, not faked):**
- The flip-edge straightening search itself (`FlipOut`/`iterativeShorten`
  and `makeDelaunay`) needs a continuous, barycentric path representation
  over an intrinsic triangulation — not just mesh vertex indices — to port
  faithfully. `core/geodesic`'s `GeodesicLength.straightenedLength` is
  `none` until that lands; only the (always-an-overestimate) Dijkstra
  length is reported today.
- 12 of the 26 schema fields still need their surface-distance endpoints or
  landmark definition read from GarmentCode's own
  `docs/Body Measurements GarmentCode.pdf` before any vertex indices can be
  picked — see `core/measure-schema`'s `unsettledFields`.
- The `adapters/` that would actually run any of this against a real mesh
  or against the upstream C++ CLI as an oracle (see `adapters/README.md`).

## Why open path and closed loop are NOT the same operation

A human body mesh is topologically a sphere (genus 0): every CLOSED LOOP
drawn on it (waist, bust, hips, ...) can be slid over a cap or limb end and
shrunk to a point, so it has no positive-length geodesic representative —
`iterativeShorten()` on a loop collapses it toward zero, which is correct
for "shortest loop in this homotopy class" and wrong for "what a tailor's
tape reads here". The upstream-verified fix: for a closed loop, run
`makeDelaunay()` ONLY (a retriangulation, not a length search); for an open
path, run `iterativeShorten()` directly off the Dijkstra path and never
call `makeDelaunay()` first (it measurably degrades the open-path result).
`core/geodesic/Geodesic/FlipOut.lean` encodes this split at the type level
so a caller cannot accidentally run the wrong operation on the wrong kind
of path.

## Build

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```

Both are from-scratch Lean 4 (no external `require`s) — no toolchain beyond
`elan`/`lake` is needed to build or test either package.

## Dependencies

See `ports/sibling-repos.txt` — clone the listed `sinew-mocap`/`V-Sekai-fire`
repos side-by-side in `~/` before writing an adapter.
