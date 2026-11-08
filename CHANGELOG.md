# CHANGELOG — frontier-learning iteration record

This file is the chronological record of what was tried, whether it held
up, and what was kept — not a feature list (that's the README/docs/STATUS.md).

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
