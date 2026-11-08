/-
Dijkstra.lean — shortest path over the mesh's own edge graph.

This produces the upstream tool's `DIJKSTRA_LENGTH` value: the initial,
unstraightened path along mesh edges between two vertices (open path) or
through a vertex sequence (closed loop). It is a real graph shortest path,
not a stub — and it is also the one length value FlipOut straightening can
only ever shorten, never lengthen, so it is a sound (if pessimistic) upper
bound on the true geodesic distance even before any straightening runs.

Implementation is a plain O(V^2) scan-for-minimum Dijkstra (no heap): the
meshes this targets (body-measurement vertex rings, a few hundred vertices
at most) are small enough that this is not a performance concern, and it
keeps the proof-relevant state (the `dist`/`prev` arrays) simple to reason
about.
-/
import Geodesic.Mesh

namespace Geodesic

/-- Shortest-path distance array and predecessor array from `source`,
computed by Dijkstra's algorithm over `m`'s edge graph with Euclidean edge
weights. `distTo[source] = 0`; unreached vertices keep `Float.inf`. -/
structure DijkstraResult where
  distTo : Array Float
  prevOf : Array (Option VertexId)
  deriving Inhabited

/-- Run Dijkstra from `source` over every vertex of `m`. -/
def dijkstra (m : TriMesh) (source : VertexId) : DijkstraResult := Id.run do
  let n := m.verts.size
  let mut dist : Array Float := Array.replicate n Float.inf
  let mut prev : Array (Option VertexId) := Array.replicate n none
  let mut visited : Array Bool := Array.replicate n false
  if source < n then
    dist := dist.set! source 0
  for _ in [0:n] do
    -- pick the unvisited vertex with the smallest tentative distance
    let mut bestV : Option VertexId := none
    let mut bestD := Float.inf
    for v in [0:n] do
      if !visited.getD v true && dist.getD v Float.inf < bestD then
        bestV := some v
        bestD := dist.getD v Float.inf
    match bestV with
    | none => pure ()
    | some u =>
      visited := visited.set! u true
      if bestD != Float.inf then
        for w in m.neighbors u do
          let cand := bestD + Vec3.dist (m.position u) (m.position w)
          if cand < dist.getD w Float.inf then
            dist := dist.set! w cand
            prev := prev.set! w (some u)
  return { distTo := dist, prevOf := prev }

/-- Reconstruct the vertex sequence of the shortest path from `source` to
`target`, `none` when `target` is unreachable. -/
def DijkstraResult.pathTo (r : DijkstraResult) (source target : VertexId) :
    Option (Array VertexId) := Id.run do
  if r.distTo.getD target Float.inf == Float.inf && source != target then
    return none
  let mut path : Array VertexId := #[target]
  let mut cur := target
  let mut fuel := r.distTo.size + 1
  while cur != source && fuel > 0 do
    match r.prevOf.getD cur none with
    | none => return none
    | some p =>
      path := path.push p
      cur := p
    fuel := fuel - 1
  if cur != source then return none
  return some path.reverse

/-- Total Euclidean length of a vertex-sequence path on the mesh. This is
the quantity the upstream tool prints as `DIJKSTRA_LENGTH` (before any
FlipOut straightening). -/
def pathLength (m : TriMesh) (path : Array VertexId) : Float := Id.run do
  let mut total : Float := 0
  for i in [0:path.size] do
    if i + 1 < path.size then
      total := total + Vec3.dist (m.position (path[i]!)) (m.position (path[i+1]!))
  return total

/-- Dijkstra shortest-path length between two vertices, walking mesh edges
only (an open path's `DIJKSTRA_LENGTH`). -/
def dijkstraOpenLength (m : TriMesh) (a b : VertexId) : Option Float :=
  (dijkstra m a).distTo[b]?

/-- Dijkstra length of a closed loop: the sum of shortest-path legs between
consecutive vertices of `loop`, closing back to the first. All legs must be
reachable or this returns `none`. -/
def dijkstraLoopLength (m : TriMesh) (loop : Array VertexId) : Option Float := Id.run do
  if loop.size < 2 then return none
  let mut total : Float := 0
  for i in [0:loop.size] do
    let a := loop[i]!
    let b := loop[(i + 1) % loop.size]!
    match dijkstraOpenLength m a b with
    | none => return none
    | some d => total := total + d
  return some total

end Geodesic
