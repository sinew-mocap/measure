import Lake
open Lake DSL

-- Lean4 spec + pure-Lean port of the flip-geodesics length computation
-- (nmwsharp/geometry-central's FlipEdgeNetwork, forked as
-- V-Sekai-fire/TOOL_geodesiac_path — "the rope"). No external deps: this
-- is a from-scratch geometric spec over Lean's own Float/Array, not a
-- binding to the upstream C++ geometry-central library.
package Geodesic where

-- Mesh types, Dijkstra initial path, FlipOut straightening for OPEN
-- paths, Delaunay-only flips for CLOSED loops (see Geodesic/FlipOut.lean
-- for why the two cases must NOT share one code path), and length.
@[default_target] lean_lib Geodesic

-- Property/unit tests against analytic ground truth (flat grid plane for
-- an open path, cylinder for a closed loop). Exits 1 on any failure or on
-- a planted negative control passing.
lean_exe geodesic_test where
  root := `Tests.GeodesicTest
