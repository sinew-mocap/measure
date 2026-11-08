/-
FlipOut.lean — status of the edge-flip straightening step, and WHY open
paths and closed loops must never share one code path.

Upstream (`nmwsharp/geometry-central`'s `FlipEdgeNetwork`, forked at
`V-Sekai-fire/TOOL_geodesiac_path`) straightens a path by repeatedly
flipping triangulation edges until the path is locally geodesic
(`FlipOut`/`iterativeShorten`), or by `makeDelaunay()` for a pure
retriangulation with no shortening search. This module does NOT yet port
that flip search itself — doing so needs a continuous, barycentric path
representation over an intrinsic triangulation, not just mesh vertex
indices (see `Mesh.lean`'s docstring), and is tracked as future work. What
IS ported here, and is load-bearing on its own, is the operation picked
per path KIND, which is the actual safety-critical finding from running the
upstream tool on real body meshes (see the `garmentcodedata-xpbd-pipeline`
skill, "Pitfall 1" and "Pitfall 2"):

* **Open path** (two fixed, distinct endpoints): safe to run the greedy
  FlipOut/`iterativeShorten` search directly off the Dijkstra initial path.
  Calling `makeDelaunay()` FIRST measurably *degrades* accuracy (observed
  0.3% error vs. the analytic answer) by changing which local flips the
  later search explores — so a correct port must never do that for an open
  path.
* **Closed loop** on a genus-0 body mesh: EVERY closed loop is
  topologically contractible (slide-and-shrink to a point over a cap or
  limb end), so it has no positive-length geodesic representative — its
  length infimum is zero. `iterativeShorten()` on a loop finds exactly
  that and collapses it toward zero, which is mathematically correct for
  the question "what is the shortest loop homotopic to this one" and
  completely wrong for the question "what does a tailor's tape measure
  read here". The fix is to call `makeDelaunay()` ONLY — a retriangulation,
  not a length search — and report that (unchanged-length) result.

So: `iterativeShorten` is an open-path-only operation and `makeDelaunay`
is the only loop-safe step. The type below encodes that split so a caller
cannot accidentally run the open-path search on a loop.
-/
import Geodesic.Mesh

namespace Geodesic

/-- Which straightening step is valid for a given path kind. The upstream
pitfalls above are the reason there are two cases and not one generic
"shorten" operation. -/
inductive StraightenOp where
  /-- Open path, both endpoints fixed: FlipOut / `iterativeShorten`, run
  directly off the Dijkstra initial path with no preceding `makeDelaunay`. -/
  | iterativeShortenOpenPath
  /-- Closed loop: `makeDelaunay` only. Never `iterativeShorten` — see the
  module docstring. -/
  | delaunayOnlyClosedLoop
  deriving Repr, BEq

/-- Reported length status for a geodesic query. `dijkstraLength` is always
computed (see `Dijkstra.lean`) and is already what the upstream tool prints
for an unstraightened path. `straightenedLength` is the FlipOut/Delaunay
result; it is `none` until the flip search itself is ported — callers must
not treat `dijkstraLength` alone as the final tape-measure answer, since
for a zigzagging initial path it overestimates the true geodesic/Delaunay
length (the gap the straightening step exists to close). -/
structure GeodesicLength where
  op : StraightenOp
  dijkstraLength : Float
  /-- `none`: the flip-based straightening itself is not yet ported (future
  work — tracked in README's "Status" section), so no numeric value is
  fabricated here. -/
  straightenedLength : Option Float := none
  deriving Repr

end Geodesic
