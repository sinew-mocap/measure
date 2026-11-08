/-
Mesh.lean — minimal triangle-mesh types for the geodesic solve.

This is deliberately a plain index-based mesh (vertex positions + triangle
vertex triples + an adjacency map derived from it), not a full half-edge
structure: everything the flip-geodesics algorithm needs — "which triangles
touch this edge", "what are the two opposite vertices" — is expressible over
this simpler representation, and a simpler representation is easier to state
and check proofs about later.
-/
namespace Geodesic

/-- A 3D point. `Float` throughout: this is a numerical geometry spec, not an
exact-arithmetic one — the upstream flip-geodesics algorithm is itself
floating point (see its own `check path` tool, which reports a swept-angle
tolerance rather than an exact zero). -/
structure Vec3 where
  x : Float
  y : Float
  z : Float
  deriving Repr, Inhabited, BEq

namespace Vec3

def sub (a b : Vec3) : Vec3 := ⟨a.x - b.x, a.y - b.y, a.z - b.z⟩

def normSq (a : Vec3) : Float := a.x * a.x + a.y * a.y + a.z * a.z

def norm (a : Vec3) : Float := Float.sqrt a.normSq

/-- Euclidean distance between two points — this is what a straight-line
geodesic degenerates to on a flat patch, and is the analytic ground truth
used by the open-path test in `Tests/GeodesicTest.lean`. -/
def dist (a b : Vec3) : Float := (a.sub b).norm

end Vec3

/-- 0-indexed vertex id into `TriMesh.verts`. -/
abbrev VertexId := Nat

/-- A triangle mesh: vertex positions plus the vertex-index triple of each
face. No explicit edge/half-edge table — `edgeKey` below gives a canonical,
order-independent key for "the edge between these two vertices" so edge
adjacency can be computed on demand (see `Mesh.facesOfEdge`). -/
structure TriMesh where
  verts : Array Vec3
  faces : Array (VertexId × VertexId × VertexId)
  deriving Inhabited

namespace TriMesh

def position (m : TriMesh) (v : VertexId) : Vec3 :=
  m.verts.getD v ⟨0, 0, 0⟩

/-- Canonical (order-independent) key for the edge `{a, b}`. -/
def edgeKey (a b : VertexId) : VertexId × VertexId :=
  if a ≤ b then (a, b) else (b, a)

/-- Every edge of every face, each tagged with the face it came from. Used to
build adjacency (`facesOfEdge`) and the per-vertex neighbor list
(`neighbors`) that Dijkstra walks. -/
def faceEdges (m : TriMesh) : Array ((VertexId × VertexId) × Nat) := Id.run do
  let mut out : Array ((VertexId × VertexId) × Nat) := #[]
  for fi in [0:m.faces.size] do
    let (a, b, c) := m.faces[fi]!
    out := out.push (edgeKey a b, fi)
    out := out.push (edgeKey b c, fi)
    out := out.push (edgeKey c a, fi)
  return out

/-- Vertex ids adjacent to `v` via some mesh edge, deduplicated. -/
def neighbors (m : TriMesh) (v : VertexId) : Array VertexId := Id.run do
  let mut out : Array VertexId := #[]
  for (a, b, c) in m.faces do
    if a == v then
      if !out.contains b then out := out.push b
      if !out.contains c then out := out.push c
    if b == v then
      if !out.contains a then out := out.push a
      if !out.contains c then out := out.push c
    if c == v then
      if !out.contains a then out := out.push a
      if !out.contains b then out := out.push b
  return out

/-- The (at most two, for a closed manifold edge) triangle indices touching
edge `{a, b}`. An edge with one incident face is a boundary edge. -/
def facesOfEdge (m : TriMesh) (a b : VertexId) : Array Nat :=
  let key := edgeKey a b
  m.faceEdges.filterMap fun (k, fi) => if k == key then some fi else none

end TriMesh

end Geodesic
