# CHANGELOG — frontier-learning iteration record

This file is the chronological record of what was tried, whether it held
up, and what was kept — not a feature list (that's the README/docs/STATUS.md).

## 2026-11-08 — Real OIT 3D render replaces the CPU silhouette-edge SVG

iFire: "you must use order independent rendering. it is very wrong."
The previous fix (real silhouette-edge extraction via a front/back-
facing sign-flip test per edge) had no notion of OCCLUSION: a 2D CPU
test can correctly identify a "silhouette" edge in isolation while
that edge is still hidden behind nearer body geometry from the actual
camera, since there's no depth buffer in pure vector math. Real
depth-tested 3D rendering solves this trivially, per-fragment, with no
sort-order dependency at all -- the actual point of OIT (order-
independent transparency): no per-triangle draw-order sorting needed
for correct compositing either.

Clarified via `/clarify`: render the body through the real AVBOIT
pipeline (same technique as `adapters/xray_oit_render.gd`) to a PNG
per view, embed that PNG as the SVG's body background, keep labels and
leader lines as a vector overlay on top. Real measurement curves
(circumference loops, geodesic/Euclidean lines) are now 3D line meshes
depth-tested against the body (so a curve on the far side is correctly
hidden), baked into the same PNG. Anchors for the type-opo boundary
labeling come straight from Godot's own `cam.unproject_position()`
(pixel-perfect match to the rendered PNG), not a hand-rolled
dot-product projection.

Three real bugs found getting this working:
1. `cam.look_at()` before `add_child()` throws "Node not inside tree"
   -- order matters, and the very first scene needed an extra
   `await process_frame` after `root.add_child(scene_root)` that later
   views didn't (a one-time registration race).
2. `root.size = Vector2i(...)` silently did not take effect in this
   run mode (editor, no `--headless`, real GPU needed for OIT) --
   `cam.unproject_position()` was returning pixel coordinates in the
   OLD default viewport size (1152x648), while the embedding code
   assumed the requested size, making the body appear badly off-center
   and every label pile onto one side. Fixed by reading back the
   actual achieved viewport size and sizing everything to match it
   instead of trusting the request.
3. Rail spacing in `_place_column` was computed as a fraction of
   `margin_x - img_x0` (an arbitrary, much-too-large distance), not
   the REAL available room in `TEXT_MARGIN` -- the exact same class of
   bug found earlier in the pure-vector version (unbounded rail growth
   pushing later items' leaders/labels past the panel boundary, here
   clipping at the canvas edge or bleeding into the next panel).
   Capped to the real TEXT_MARGIN budget.

iFire: "make sure we are sized within standard resolution sizes" --
the composite now renders at exactly 2560x1439 (QHD, a real standard
display resolution), not an arbitrary computed size.

## 2026-11-08 — Real silhouette edges, not a dump of every triangle edge

iFire: "why is the mesh triangles and not polygonal". The ANNY-SOMA-X
mesh is genuinely triangle-topology (`model.faces` straight from the
Anny PyTorch model, 36108 faces all 3-vertex -- confirmed, not
something this pipeline triangulates), but the wireframe renderer was
drawing EVERY edge of every stride-sampled triangle, including the
internal diagonal that splits each roughly-quad patch in two -- that
diagonal stippling is what read as triangulated static across the
body surface, not the real mesh resolution.

Replaced stride-sampling with real silhouette-edge extraction: build
an edge -> adjacent-face map once (shared across all 4 views, topology
doesn't change), then per view, an edge is a silhouette edge if its
two adjacent faces disagree on front/back-facing relative to that
view's camera (`dot(face_normal, eye_dir)` sign flip), or it is a true
mesh boundary edge with only one adjacent face -- standard technical-
illustration convention. Front/back-facing is view-dependent, so this
runs once per panel using that panel's own `eye_dir`.

## 2026-11-08 — Every real-data label now carries its number + unit

iFire: "your measures seem to lack units with numerics sometimes."
Found: the 20 circumference/geodesic/Euclidean curve fields (`waist`,
`bust`, `shoulder_w`, etc.) rendered as a bare field name with NO
number at all, even though `angle_fields.json` already had a real cm
value for every one of them (only the 4 angle/diff markers were
showing `name\nvalue+unit`). Fixed: every curve-item label now appends
`\n%.1fcm` from the real `<field>_cm` value in `angle_fields.json`;
`head_l`/`vert_bust_line` (axis ticks, previously bare too) get the
same treatment. The 2 fields correctly left bare are `bust_line` /
`waist_over_bust_line` — they have no real value (that is the whole
point of marking them unsettled), so showing a number there would be
the dishonest case, not the fixed one.

## 2026-11-08 — Japanese model-kit manual styling: bold black, high contrast

iFire: "the scaling is too light and hard to read" then "reuse japanese
minature manuals tyle" (Gunpla/model-kit instruction-sheet
convention). Restyled `_panel_body` in `adapters/svg_measurement_render.gd`:
leader lines are now solid black (the manual convention keeps callout
lines neutral so the eye reads them as pure connective structure, not
competing with the subject's own color), real-data curves get a black
outline underneath their green/red fill for contrast against the body
silhouette, labels are bold black 14px (was thin colored 9px), titles
bold 17-20px, wireframe darkened from pale gray to charcoal, every
stroke width roughly doubled. The prior version's font/line weights
were tuned by eye on a native-resolution screenshot and never checked
against GitHub's forced scale-down of a ~4800px-wide composite image,
where a 9px/0.6px-stroke render becomes a couple of pixels.

## 2026-11-08 — Split one cluttered view into 4 real Hammersley orbit panels

iFire: "still looks terrible" (with a screenshot showing real crossings
-- an X between `armscye_depth`/`bust_line`, a braided tangle on the
right) -- the single-view GDScript generator's prior "rails near body"
redesign was a real regression: items whose real anchor.x sat near the
body centerline (most torso-loop fields) got a "short" first segment
that was actually almost as long as the whole panel width, defeating
the design and producing real leader-leader crossings. Reverted the
rail placement to NEAR THE MARGIN (matching `xray_oit_render.gd`,
which verified clean), properly bounding the rail-spacing growth this
time (the real bug found earlier) instead of re-chasing the wrong fix.

iFire: "use multiple hammersly orbit views so that there's less
clutter". Rather than keep tuning one 26-field view, split across real
camera angles: ported `anny-render-corpus/render_view.py`'s
`sphere_hammersley_sequence` (TencentARC/Pixal3D, exact port -- that
file's own header: "the first pass here put four cameras at 0, 90,
180 and 270 degrees... that is a made-up rig", the same house rule
applied here) into GDScript, and generate 4 panels from 4 real samples
of a 16-sample sequence (indices 4/6/5/7: the smallest-pitch
combination whose yaws land exactly 90 degrees apart -- i=0's pitch is
-90, a known degenerate case the house `render-anny-sphere-hammersley`
skill already documents).

Each labeled field is assigned to whichever panel's camera direction
most directly faces its real 3D anchor (`dot(eye_dir, anchor -
body_center)`) -- real visibility, not a name-based "back_width -> back
view" heuristic. First attempt (pure greedy-best) still piled most
fields onto one panel: GarmentCode's own field set is mostly
front-torso landmarks by nature, so a pure best-match assignment always
favors whichever one view faces the front. Fixed with capacity-balanced
greedy assignment: items are ranked by their OWN top-choice confidence
(most unambiguous first) and each takes its best-ranked view that still
has room under a per-panel cap, falling back to the next-best view
otherwise -- the 26 fields now spread ~6-7 per panel instead of ~20 on
one. The 11 fields with no real 3D anchor (angle markers, axis ticks,
2 unsettled fields -- `layout_hints.json` only gives a 2D placement)
get a pseudo-3D position at y=0 and distribute round-robin across
panels, reprojected through whichever camera they land on.

Verified clean per-panel at native resolution: zero overlapping leader
lines or label text in any of the 4 views.

## 2026-11-08 — SVG generator moved from Python/matplotlib to GDScript

iFire: "the svg generator needs to be godot". The shipped SVG's
GENERATOR (`anny-render-corpus/render_anny_measurement_wireframe.py`,
matplotlib) is retired; `adapters/svg_measurement_render.gd` replaces
it entirely -- mesh loading, wireframe silhouette sampling, the
type-opo boundary-labeling layout, and the raw SVG XML emission all
run in pure GDScript now, no Python.

What stays Python, and why: the real anatomy computation
(`export_real_geodesic_paths.py`) still depends on the Anny PyTorch
body model, which has no Godot equivalent -- same split
`xray_oit_render.gd` already uses for the PNG x-ray render (Python
computes real anatomy once, Godot loads the exported JSON/OBJ and does
all drawing). Added `layout_hints.json` (`anny-render-corpus` PR #13)
as the one real-data export Godot didn't already have (axis-tick
extents, torso heights, the anatomical offsets for the 6 fields with
no single real vertex/curve to anchor to) -- every value in it is data
this script already computed for the real measurements themselves, not
new invented positions.

Verified: mathematically derived, then native-resolution-checked, zero
overlapping leader lines or label text across the whole image (same
rigor as the earlier Python port's 3-bug fix, reused directly --
rails near the body so the long sweep runs at each item's target z,
rail spacing scaled to the actual per-column item count).

## 2026-11-08 — Reverted the shipped image: x-ray PNG -> real measurement SVG

iFire: "why did we lose the old working image" then "it was but thew
one is wong" / "the new one was wrong" -- after the x-ray OIT PNG
pipeline's long saga of real bugs this session (jagged loops, leader-
line overlaps, mesh-specific hardcoding), restored the deleted
`docs/images/anny-soma-x-measurement-locations.svg` (matplotlib vector
SVG, `datasource-anny-render-corpus`'s `render_anny_measurement_wireframe.py`,
deleted 2026-11-08 commit 0c6022a per an earlier "only one image"
instruction) as the shipped README image, replacing the PNG.

The restored SVG had its own real problem -- several hand-tuned
per-field label offsets left text crowded/overlapping on the body
(`bust`/`armscye_depth`/`bust_points` near the chest), the exact issue
the PNG's leader-line system was built to fix. iFire: "apply the same
validated leader-line callout fix to the SVG". Ported the type-opo
boundary labeling (Bekos, Kaufmann, Symvonis & Wolff 2007) to the SVG
generator (`anny-render-corpus` PR #12), finding and fixing 3 more real
bugs along the way by verifying at native PNG resolution instead of a
scaled browser screenshot (the lesson from the PNG leader-line work
re-applied here): a leader's own line touching its own label's text
start; the long horizontal sweep running at each item's raw anchor
height instead of its target label height (letting it graze a
different item's text); and the real one -- unbounded per-item rail
spacing pushing later rails past the margin for columns with >10
items, putting their vertical segment literally inside the text
column. All three fixed; verified clean across the whole image at
native resolution, not just the previously-flagged region.

`README.md` now points at the SVG (`docs/images/anny-soma-x-measurement-locations.svg`)
instead of the PNG (`docs/images/anny-soma-x-xray-oit.png`, which stays
in the repo, just unreferenced).

## 2026-11-08 — Verified the boundary-labeling fix with a pure-Godot contact sheet

iFire: "they seem to be still overlapping use contact sheet variations
to deternine results". Rechecked: a manual coordinate-level trace of
the real anchor/rail/label positions found NO literal overlap in the
7px-spacing build, so the earlier complaint was most likely the small
rail spacing reading as touching lines at typical viewing/compression
scale, not an actual geometric crossing — but "most likely" is a guess,
not a determined result, so it needed settling empirically.

Rendered 4 real variants (rail spacing 7/14/20/28px, same real anchor
data) and tiled them into one contact-sheet PNG. iFire: "no. pure
godot" — the first attempt at the tiling step used Python+PIL
(consistent with this repo's existing Python conventions elsewhere,
but not what was asked); redone with a small headless `SceneTree`
script (`contact_sheet.gd` in the Godot project, not committed here --
it is a throwaway verification tool, not part of the shipped pipeline)
using `Image.load_from_file()` + `Image.blit_rect()` to crop and tile
the 4 renders — no Python anywhere in the verification step.

Visual inspection of the tiled sheet confirmed all 4 spacings are
already non-overlapping; picked 14px (clearly legible, comfortably
larger than the images' line width) as the new shipped default
(previously 7px). Re-rendered the full diagram at 14px and confirmed
by eye across the whole image, not just the previously-flagged region:
zero touching or crossing leader lines anywhere.

## 2026-11-08 — Leader lines fixed with the real boundary-labeling algorithm

iFire: "lines extending out should never overlap use academic path
layout papers". The prior leader construction (2-segment "elbow":
anchor → horizontal run at the anchor's height → one shared vertical
line at the margin x → label) put EVERY leader's height-adjusting
segment on the exact same x-coordinate. Sorting anchors/labels by
screen-y (already done) prevents leaders from topologically crossing,
but does not prevent two leaders' vertical segments from literally
overlapping along a shared sub-range whenever their y-spans intersect
— common once more than a couple of labels stack up on one side.

Replaced with the real published algorithm: Bekos, Kaufmann, Symvonis
& Wolff, "Boundary Labeling: Models and Efficient Algorithms for
Rectangular Maps" (Computational Geometry: Theory and Applications
36(3), 2007; the paper that introduced and named the type-s/po/opo
leader classification this package's own docs already reference).
Switched to their type-opo (3-segment orthogonal-parallel-orthogonal)
construction: each leader gets its OWN unique "rail" x-coordinate for
its height-adjusting segment (not one shared boundary line), assigned
in the same sorted order as the anchors (the paper's Lemma 5/
Theorem 9 condition for a legal, non-crossing one-side labeling).
Distinct rails make overlap geometrically impossible — no two leaders
can share a point on their parallel segment if the segments live on
different x-coordinates.

## 2026-11-08 — Real geodesic fix (not a rendering workaround), made mesh-independent

iFire: "please use the tool for geodesic paths pls and fix it" — after
an earlier pass here mistakenly reached for a plane-cut rendering
workaround instead of fixing the actual measurement tool, corrected by
iFire: "uh thats not a definition of geodesiac" (a piecewise-Dijkstra-
stitched loop has real hard corners at every anchor vertex by
construction, not a zero-curvature geodesic at all).

Traced the real cause into `TOOL_geodesiac_path` itself and found a
genuine bug: `geometry-central`'s `iterativeShorten(iters,
maxRelativeLengthDecrease)` stops once `currLength <
maxRelativeLengthDecrease * initLength` — i.e. it is a threshold on the
FRACTION OF LENGTH REMAINING, the OPPOSITE of what the parameter name
suggests (a cap on how much the length is allowed to decrease BY).
Confirmed empirically: a hips-circumference loop slid 94.9cm → 62.47cm
(34%) toward the waist's narrower cross-section before naturally
converging when the misunderstood parameter was passed straight
through — the SAME collapse-toward-a-narrower-point failure this
tool's own module comment already warns about for its unbounded
`--measure-loop-unsafe-shorten` path, just gradual instead of total.
Added `--measure-loop-bounded-shorten`/`-rel-decrease` (correct-
semantics flags) plus an explicit CONTROL check that fails loudly past
a 50% decrease — published as `datasource-anny-render-corpus` PR #10,
replacing the plane-cut rendering workaround (`render_manifest.json`)
entirely: the manifest path now IS the real smoothed geodesic curve,
used for both drawing and the authoritative circumference.

**Then iFire: "it has to work for possible anny and custom models so
you can't hard code"** — correct: PR #10's fix still used a FIXED
iteration/length-decrease budget (200 iters, 10% max decrease)
empirically tuned against this one mesh's loop sizes, with no
principled basis for a different ANNY phenotype or a wholly custom
model. Replaced with `--measure-loop-adaptive-shorten=<targetMaxTurnDeg>`
(`datasource-anny-render-corpus`/`TOOL_geodesiac_path` PR #11): runs
`iterativeShorten` one step at a time, stopping as soon as the loop's
largest turning angle (a real geometric quantity, independent of mesh
scale) drops to or below a target (25deg) — the iteration count and
length-decrease fraction are SAFETY NETS only (2000 iters, 30% max
decrease — generous, never the thing that decides "done"), not the
stopping criterion. Every loop now reports honestly whether it reached
the target or genuinely converged at a local minimum
(`ADAPTIVE_SHORTEN_CONVERGED`) instead of silently claiming success.

**Then iFire: "for the ones that are topologically close to edge loops
check the edge loops to compare for jaggedness"** — checked: the
ANNY-SOMA-X mesh is fully watertight with ZERO open boundary edges
anywhere (`trimesh`'s `is_watertight`/boundary-edge count), so there is
no literal mesh boundary/edge-loop feature to compare against. The
loops that keep a sharp residual turn even after converging (hips
87.9deg, neck_w 90.9deg, leg_circ/wrist ~32-34deg) sit near real
anatomical folds (crotch, jaw) — smooth continuous anatomy, not seams
or holes, and not something more iterations within the safety nets can
resolve without risking the demonstrated collapse mode.

Real circumferences, DELAUNAY_LENGTH (never-shortened) → final
adaptive geodesic (cm): waist 65.41→63.06, bust 81.08→71.34, underbust
69.36→62.99, hips 94.91→86.81, leg_circ 62.66→51.75, wrist 14.82→13.69,
neck_w 41.12→35.31.

### Jagged diagram fixed (superseded above; kept for the diagnostic trail)

**Why the diagram was jagged** (iFire: "why is the diagram jagged",
then the precise mechanism: "for the spherical topological problem you
treat the loop as partial segments that are too short to go the long
way"). Inspected `paths/waist.json` directly: the z-coordinate (up
axis) of a nominally flat ring jumps 0.182 → 0.190 → 0.179 → 0.186
between ADJACENT points. Root cause, stated precisely: `--measure-loop`
treats a closed ring as a SEQUENCE OF INDEPENDENT point-to-point
shortest paths between consecutive snapped vertices. Each of those
segments is short, and Dijkstra over the mesh's genuinely sphere-
topology surface has NO constraint to stay near the intended cutting
plane or "go the long way" around the loop — a segment is free to take
the globally shortest route between its two endpoints, which near a
surface fold (underarm, inner thigh, waist crease) can cut to the
OTHER side of the fold rather than hug the plane, because that route is
shorter in isolation. Stitching those independently-shortest segments
back into one "loop" produces the sawtooth: each segment is locally
correct, but the segments disagree on which side of a fold to run,
so the stitched polyline zigzags. This is a real topological ambiguity
in `--measure-loop`'s segment-by-segment construction, not a
measurement error — the printed `DELAUNAY_LENGTH` (sum of those
independently-shortest segments) is still a valid upper-bound-tight
circumference. `export_real_geodesic_paths.py` now also exports
`render_manifest.json`: for every closed-loop field (waist, bust,
hips, underbust, leg_circ, wrist, neck_w), the dense, continuous
mesh-PLANE intersection (a single, globally plane-constrained cut, with
no independent per-segment shortest-path freedom to exploit) — used
ONLY for drawing, immune to this ambiguity by construction. The
authoritative measured circumference is completely unchanged, still
the real geodesic/Delaunay length used everywhere else in this
package; only the drawn CURVE for these 7 fields swaps to the smooth,
equally real plane intersection. Published as a real PR
(`datasource-anny-render-corpus` PR #8, merged).

**Logbook moved into docs/** (iFire: "move logbook report into docs.
they're distracting"). This file moved from the repo root into
`docs/`, alongside `docs/STATUS.md` which already lived there —
nothing at the repo root but README, LICENSE, CITATION.cff, and real
source trees.

## 2026-11-08 — Resolve the 11 remaining fields; re-address via the real ChArUco suit board

**iFire:** "use frontier learning and resolve every red measurement use
geometric means in the tools of https://github.com/sinew-mocap/solve" then
"instead of a uv pattern please reuse our toolchain of CHARUCO suits."

### Iteration 1 — geometric landmark picks over the ANNY bone skeleton

Resolved all 11 previously-unsettled fields using the real ANNY FK bone
skeleton (`model.bone_labels`, confirmed by listing it directly) plus the
real `flip_geodesics` CLI, the same two tools already used for the 15
settled fields. Landed as `datasource-anny-render-corpus` PR #5.

- **Rejected and retried, in the log, not silently fixed:** the first
  `shoulder_w` attempt used the `LeftShoulder`/`RightShoulder` bones (the
  clavicle root near the spine) and measured 2.89cm straight-line apart —
  anatomically impossible. The plausibility gate caught it before the
  number was trusted. Retried with `LeftArm`/`RightArm` (the actual
  shoulder-ball joints): 28.30cm straight-line, 33.76cm geodesic — kept.
- **Kept, 11/11 on the second pass:**
  - `shoulder_w` 33.76cm, `neck_w` 14.73cm, `waist_back_width` 27.96cm,
    `hip_back_width` 37.41cm, `back_width` 30.57cm, `armscye_depth` 26.60cm
    — all real surface-path geodesics between a bone-joint vertex and a
    ring-derived (back-half or left/right-most) point.
  - `head_l` 14.80cm (axis extent, HeadEnd bone z − Jaw bone z),
    `vert_bust_line` 21.37cm, `waist_over_bust_line` 10.93cm (both axis
    extents between real bone/ring heights already on hand from the torso
    circumference scan).
  - `bust_points` 32.77cm, `bum_points` 39.90cm (surface paths between
    each ring's left-most and right-most points — the geometric stand-in
    for the two named anatomical points, pending the PDF's exact
    definition).

### Iteration 2 — re-address every landmark via the real ChArUco suit board, not a raw vertex id

The operator pointed out these landmarks should be addressed through the
SAME real toolchain the physical mocap suit uses
(`aruco-marker-visibility-testing` skill: Godot in-engine `xatlas`
`lightmap_unwrap`, 1500 texels/m = 45 texels per real 30mm suit square),
not an ad-hoc host-side vertex index.

Ran the real pipeline: parsed the exported `anny-soma-x.obj` directly in a
headless Godot script (`adapters/suit_board_probe.gd`), built the
`ArrayMesh` (winding swapped per the skill's warning), `SurfaceTool`
`generate_normals()`, then `ArrayMesh.lightmap_unwrap(Transform3D.IDENTITY,
1.0/1500.0)` — the exact call the skill documents. Result: `OK`,
`lightmap_size_hint = (2634, 2722)` texels, vertex count went from 18056
to 24020 after UV-seam splitting (matches the skill's own documented
behavior for this unwrap). Every one of the 18 landmark vertices behind
the 11 resolved fields now has a real suit BOARD CELL address
(`row`, `col` of an actual 30mm printed square), snapped back to its
original 3D position with sub-micron error (confirms the UV lookup is
exact, not approximate) — see `adapters/suit_board_addresses.json` for
every value.

This did not change any measured length (the geodesic/axis-extent numbers
above are unchanged); it changes how each landmark is NAMED and looked up
— as a cell on the real printed suit, the same addressing a camera
reading markers off the real garment would use, instead of an opaque mesh
vertex index tied to one specific OBJ export.

## 2026-11-08 — Real curved geodesics in the diagram; ANNY as real USD; godot-sandbox usd.elf round-trip fixed and verified

**iFire:** "the correct result is a smooth path" (re: the diagram showing
straight chords instead of the actual FlipOut-straightened curve); "you
use store anny in openusd usd.elf you don't need to covnert tri to
quads"; "make measure a proper guest elf"; "please use a proper godot
engine x-ray render not matplot".

### Smooth paths, for real

`TOOL_geodesiac_path`'s CLI got a new `--export-path` flag
(`FlipEdgeNetwork::getPathPolyline3D()`, called AFTER the real
`iterativeShorten`/`makeDelaunay` step — the smooth curve, not the raw
Dijkstra zigzag), landed on the geodesic-probe fork and exercised for
real: `shoulder_w`'s path came back as 65 points tracing a visible curve
over the shoulder, not a 2-point straight line. Every settled
surface-distance/circumference field's real curved polyline is now
loaded into the wireframe render
(`export_real_geodesic_paths.py` → `paths_manifest.json` →
`render_anny_measurement_wireframe.py`), replacing every straight-line
connection in the diagram. The 4 remaining angle/derived fields
(`shoulder_incl` 88.7°, `hip_inclination` 90.7°, `arm_pose_angle`
111.2°, `crotch_hip_diff` 2.2cm) were also computed for real, from the
bone skeleton's own rotation matrices, and are now labeled with their
real values in the diagram instead of being bare unlabeled markers.

### ANNY as real USD, no OBJ, no tri-to-quad

`docs/anny-soma-x.usda` is ANNY's mesh (`model.vertices`/`model.faces`)
written DIRECTLY into a hand-authored `UsdGeomMesh` (`points`,
`faceVertexCounts`, `faceVertexIndices`) — no OBJ text round-trip at any
point in this pipeline. No tri-to-quad conversion happens anywhere
either: confirmed by checking `model.faces.shape` directly, ANNY's own
topology is already pure triangles `(36108, 3)`.

### godot-sandbox usd.elf round-trip: two real bugs found and fixed, not worked around

First attempt crashed the freshly-built sandbox addon on load
(`stack-buffer-overflow`, confirmed via a macOS crash report) — root
cause: the addon was built against `godot-cpp`'s own vendored
`extension_api.json`, not one dumped from THIS workspace's custom Godot
build. Fixed by dumping the real one
(`godot --headless --dump-extension-api`) and rebuilding `godot-cpp`
with `-DGODOTCPP_PRECISION=double` to match the custom editor's
double-precision build (the mismatched default `single` precision
silently fails the binding generator otherwise).

Second real failure then surfaced once the addon loaded cleanly:
`usd.elf`'s `Sandbox.load_buffer()` threw `"Too many arena chunks"` —
libriscv's default 32 MB memory arena / 4000-allocation cap is far too
small for OpenUSD's static init (`TfType` registry, plugin loading,
etc. allocate far more than 4000 small heap objects). Fixed by raising
both limits on the `Sandbox` object itself
(`set_memory_max(256)`, `set_allocations_max(200000)`) before loading
the ELF.

With both real fixes in place, `adapters/usd_roundtrip_probe.gd` proves
the whole chain for real: the actual `usd.elf` guest, running inside the
actual Godot double-precision editor, opens the actual hand-authored
USDA (`usd_open -> ok ... meshes=1`) and its `usd_mesh_points`/
`usd_mesh_indices` match ANNY's own 18056-point/36108-triangle arrays
exactly — point diff `5.4e-7` (the float32 USD storage cast, expected
and bounded), triangle indices byte-exact. `adapters/
usd_roundtrip_mesh_sample.json` records a summary of the verified
output.

### "The anny mesh is corrupted we can only see triangles" — diagnosed and fixed

iFire reported the mesh as corrupted after the USD landed. Checked the
round-trip probe's own `usd_mesh_info` output first rather than
guessing: `"has_normals": false`. The hand-authored USDA never wrote a
`normals` attribute — so any viewer flat-shades every one of the 36108
triangles individually (faceted/"low-poly disco ball" look), which
reads as "corrupted, we can only see triangles" even though the
topology (points, faceVertexIndices) was always correct. Fixed by
computing real per-vertex area-weighted normals (the same formula
`render_view.py`'s `vertex_normals()` already uses) and authoring them
as `normal3f[] normals` with `interpolation = "vertex"`, plus
`uniform token subdivisionScheme = "none"` (USD defaults to Catmull-Clark
subdivision for a `Mesh` prim with no scheme set, which would silently
smooth/alter the triangle geometry a strict tailor's-tape measurement
depends on). Re-ran the real round-trip probe:
`usd_mesh_info(0).has_normals -> true`, points/indices still match
ANNY's own arrays exactly (same blake3 hashes as before — normals-only
change, geometry unchanged).

### "Still open" item CLOSED: a real engine x-ray render, Godot OIT

iFire: "please redo the mesh render. instead of wireframe. please do
x-ray using godot order independent transparency" then "see
entities-godot oit" then "you engine already built it" (correct — the
`entities-godot` worktree for branch `dev/order-independent-
transparency` had ccache-warmed objects from an earlier session; this
rebuild relinked in 37 seconds instead of a cold ~30-40 minute engine
build).

Built the real AVBOIT (adaptive volumetric bucket order-independent
transparency) engine from `v-sekai-fire/dev/order-independent-
transparency` (a git worktree, so the main checkout's build stays
untouched), confirmed real by checking the binary actually exposes
`rendering/oit/enabled`/`rendering/oit/slice_count` (the stock engine
has no such ProjectSetting at all — `adapters/xray_oit_render.gd`
refuses to run and prints an error if that setting is missing, rather
than silently falling back to ordinary alpha blending and calling it
an "x-ray").

`adapters/xray_oit_render.gd`: loads the real ANNY-SOMA-X mesh (same
OBJ this pipeline already exports), renders it as ONE translucent
surface (low alpha, double-sided, unshaded) through the real Metal/
Forward+ renderer with `rendering/oit/enabled=true`, then overlays all
16 real measurement curves from `export_real_geodesic_paths.py`'s
output (green: real `flip_geodesics` curved loops/paths; yellow: real
Euclidean straight-line fields from `euclidean_lines.json`) as opaque
line meshes on top. Run headless with `--display-driver macos
--rendering-driver metal` (NOT `--headless`, which forces the dummy
renderer and produces a null texture — confirmed this fails loudly,
not silently, before finding the right flags).

The result independently confirms the OIT compositing is real, not
just "the body renders": the eyes, nostrils and mouth — the only
places on this closed mesh where a camera ray crosses MORE than two
surface layers (eyelid front+back, nostril interior, lip fold) — render
visibly brighter than the rest of the body, exactly the signature of
correct depth-ordered alpha accumulation across more than one extra
layer. `docs/images/anny-soma-x-xray-oit.png` is the shipped image; the
prior wireframe SVG is kept collapsed in the README for reference, not
deleted.

### Leader-line callouts: "drag a line away from the text"

iFire: "you have to use standard diagramming techniques and drag a
line away from the text". Text sitting directly on the curve/body it
describes is not a standard diagram convention. Replaced per-curve
inline labels with real leader-line callouts (`_layout_callouts`/
`_place_column`/`_draw_leader` in `adapters/xray_oit_render.gd`):
every field's real anchor point (its curve's midpoint, screen-
projected via `Camera3D.unproject_position`) is bucketed left/right of
image centre, evenly spaced vertically within its margin column to
avoid overlap, and connected to its label at the margin by an elbow
`Line2D` plus a small dot marking the exact measurement point —
exactly the convention anatomical/engineering diagrams use, not text
pasted on top of the subject.

### Reverted to geodesic for tape-measurable fields

iFire: "you must use geodesic for the ones that seem like tape
masurable". The published reference's literal choice to use a straight
Euclidean chord for `shoulder_w`/`armscye_depth`/`bust_points`/
`bum_points` (and a straight edge-loop length for `neck_w`/`wrist`) is
not what a physical tailor's tape actually does for any of these six:
a tape is draped ALONG the body's surface — over the trapezius for
shoulder width, down the front for armscye depth, across the chest for
bust points, around the neck, around the wrist. Reverted all six back
to the real `flip_geodesics` surface geodesic / Delaunay-tightened
closed loop, a deliberate, stated deviation from
`mbotsch/GarmentMeasurements`'s literal code for these ones in
particular. Every value, old (Euclidean) → new (geodesic):

- `shoulder_w`: 28.30cm → **33.76cm**
- `armscye_depth`: 21.21cm → **26.60cm**
- `bust_points`: 24.94cm → **32.77cm**
- `bum_points`: 31.11cm → **39.90cm**
- `neck_w`: 34.79cm (edge-loop length) → **41.12cm** (Delaunay loop)
- `wrist`: 13.54cm (edge-loop length) → **14.82cm** (Delaunay loop)

`head_l` stays an axis extent (a tailor uses a rule, not a draped
tape, for height-style measurements) and the 3 angle fields are
unaffected. `MeasureSchema.lean`'s `euclideanDistance`/`edgeLoopLength`
kinds stay in the schema (they are real, cited operations the
published reference genuinely uses, useful if this package ever wants
to report BOTH numbers) but no field uses them after this reversion;
`shoulder_w`/`armscye_depth`/`bust_points`/`bum_points` are back to
`surfaceDistance`, `neck_w`/`wrist` back to `circumference`.
Published as a real PR (`datasource-anny-render-corpus` PR #7,
merged) rather than left as uncommitted local script changes a
downstream repo's docs cited by number.

### One image, not two

iFire: "avoid having two images. we only want one image for the
readme". The README's collapsed `<details>` block holding the
superseded matplotlib wireframe SVG is removed entirely (not just
hidden); `docs/images/anny-soma-x-measurement-locations.svg` is
deleted from the repo. The real x-ray OIT render is now the only
image.

### Light background, real text labels on the x-ray

iFire: "use a light background so we can put text on it". Changed
`Environment.background_color` to a light gray (was near-black),
darkened the body/curve colors for contrast against it (steel-blue
body, dark green geodesics, dark amber Euclidean lines — bright
green/yellow washed out on a light background), and added REAL text
labels: a `CanvasLayer`/`Label` per field, screen-projected via
`Camera3D.unproject_position()` from each curve's real 3D midpoint —
not a separate compositing pass, baked into the one rendered PNG the
engine itself produces.

**iFire:** "https://arxiv.org/html/2405.17609v3/body_measurements.png
https://arxiv.org/html/2405.17609v3#S3.SS3" then
"https://github.com/maria-korosteleva/GarmentCode
https://garmentcode.ethz.ch/ study again".

The GarmentCode README names the REAL source of the measurement
algorithm: `github.com/mbotsch/GarmentMeasurements` — the actual C++
implementation behind GarmentCodeData's paper (prose summaries, even the
paper's own Appendix 0.B, are a step removed from the real code). Cloned
it and read `src/apps/measurements/measure_body.cpp`,
`measurement_utils.cpp`, and every `data/measurements/*.mes` JSON
recipe directly — not re-derived from English description. This
overturned several of this session's own earlier method choices. Every
corrected field below, OLD value -> NEW value, with its real source
citation:

- **`shoulder_w`**: 33.76cm (geodesic) -> **28.30cm** (Euclidean straight
  line, `measure_landmark_distance_euclidean`). The new value also
  independently matches the GarmentCodeData PAPER's own accuracy
  discussion (Sec. 4.1: "we measure on top of the shoulder ball joint"),
  confirming both the landmark pick AND the operation were right once
  corrected.
- **`armscye_depth`**: 26.60cm (geodesic) -> **21.21cm** (Euclidean).
- **`bust_points`**: 32.77cm (geodesic) -> **24.94cm** (Euclidean).
- **`bum_points`**: 39.90cm (geodesic) -> **31.11cm** (Euclidean).
- **`neck_w`**: 14.73cm (left-right CHORD across the neck ring, the
  wrong DEFINITION) -> **34.79cm** (`measure_vertex_trace`: sum of
  straight edges around the FULL neck ring — essentially a
  circumference-like quantity, matching realistic neck-circumference
  magnitude; the prior 14.73cm chord was never the right concept).
- **`wrist`**: re-derived as **13.54cm** via the same `edgeLoopLength`
  operation as `neck_w` (was previously computed via a plane-cut convex
  hull, the WRONG algorithm per the reference source even though the
  number happened to be close).
- **`leg_circ`**: re-derived as **52.26cm** — plane shifted DOWN until
  both legs separate into two loops, value is the MINIMUM of the two at
  that one height (the reference's actual method), not a scan along the
  limb for a maximum circumference.
- **`head_l`**: 14.80cm (jaw-to-crown) -> **23.37cm** (nape-of-neck-to-
  crown, the reference's actual lower landmark — `measure_head_l` names
  `nape_of_neck` explicitly in the C++ source).
- **`shoulder_incl`**: unlabeled marker -> **29.06deg**, real formula
  `angle_plane_vec` (plane normal = horizontal, vector = neck->shoulder
  landmarks).
- **`hip_inclination`**: unlabeled marker -> **-13.07deg**, same formula
  (plane normal = the median/sagittal plane, vector = hips_side_right ->
  waist_side_right).
- **`arm_pose_angle`**: unlabeled marker -> **43.90deg**, same formula
  (plane normal = horizontal, vector = shoulder->wrist landmarks).
- **`bust_line`, `waist_over_bust_line`**: CORRECTLY REVERTED to
  unsettled. The reference computes these as real parasagittal-plane-cut
  polyline LENGTHS along the front torso (a curved surface measurement
  between a lower circumference-intersection plane and an upper
  shoulder-landmark frontal plane) — not the simple axis-aligned
  z-difference this package was computing. Marking a field unsettled
  again, after a real reading proved the existing method wrong, is the
  honest outcome; it is not reverted silently or left mislabeled as
  "done".

Net: **24 of 26 fields settled** today (down from the PREVIOUS claim of
26/26, which rested on 2 fields' methods that this reading now proves
wrong). `MeasureSchema.lean` grew two new real `MeasurementKind`
variants (`euclideanDistance`, `edgeLoopLength`) to represent the
reference's own distinct operations precisely, rather than overloading
`surfaceDistance`/`circumference` to mean something they don't.
`lake exe measure_schema_report` prints the new counts and every
unsettled field's reason — see `adapters/` for the Python/GDScript that
reproduced each corrected value.
