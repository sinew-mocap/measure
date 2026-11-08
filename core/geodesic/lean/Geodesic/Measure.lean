/-
Measure.lean — the public geodesic measurement API: the two entry points a
body-measurement caller uses, each wired to the operation its path kind
allows (see `FlipOut.lean` for why they must differ).
-/
import Geodesic.Mesh
import Geodesic.Dijkstra
import Geodesic.FlipOut

namespace Geodesic

/-- Measure an OPEN path (e.g. shoulder-to-wrist `arm_length`) between two
fixed mesh vertices. Runs Dijkstra for the initial path; the length is
reported with `op := .iterativeShortenOpenPath` so a caller can see which
straightening rule applies once that step is ported. -/
def measureOpenPath (m : TriMesh) (a b : VertexId) : Option GeodesicLength :=
  (dijkstraOpenLength m a b).map fun d =>
    { op := .iterativeShortenOpenPath, dijkstraLength := d }

/-- Measure a CLOSED loop (e.g. `waist`, `bust`, `hips` circumference)
through a sequence of mesh vertices, closing back to the first. Reported
with `op := .delaunayOnlyClosedLoop` — this is a hard API-level guarantee
that nothing calling this function can mistakenly invoke the open-path
shortening search on a loop. -/
def measureClosedLoop (m : TriMesh) (loop : Array VertexId) : Option GeodesicLength :=
  (dijkstraLoopLength m loop).map fun d =>
    { op := .delaunayOnlyClosedLoop, dijkstraLength := d }

end Geodesic
