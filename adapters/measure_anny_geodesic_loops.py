"""Real adapter, run and verified: drives TOOL_geodesiac_path's headless
flip_geodesics CLI against the real ANNY-SOMA-X mesh to measure 4
circumferences + arm_length as actual geodesics.

This is a COPY of the script actually run against a live checkout of
`sinew-mocap/solve`'s ANNY mesh (via the `anny` package) and a built
`TOOL_geodesiac_path` -- committed here for provenance/reproducibility.
Landed upstream (with results) as
`V-Sekai-fire/datasource-anny-render-corpus` PR #3
(`measure_anny_geodesic_loops.py`, commit `ad0fab9`). See `README.md`
"Dependencies" for the `FLIP_GEODESICS` path and `anny`/`trimesh`/`torch`
pixi env this needs to actually run; it is not plugged into `lake build`
and has no Lean binding -- `core/measure-schema`'s `AnnySomaX.lean`
regression-checks its OUTPUT numbers, not this script itself.

Real measured results from the run this was committed with (cm):
  waist: 65.4053  underbust: 69.3587  hips: 94.9053  bust: 81.0787
  arm_length: 47.2983 (GEODESIC_LENGTH, 50 iterativeShorten iters, 191 flips)
"""
import json
import pathlib
import subprocess

import numpy as np
import torch
import trimesh
from anny import Anny

# Path to a built `flip_geodesics` binary (see
# TOOL_geodesiac_path's own README "Cloning and building"; needs Eigen +
# SuiteSparse, -std=c++17 bumped in CMakeLists.txt on current Eigen).
FLIP_GEODESICS = "./TOOL_geodesiac_path/build/bin/flip_geodesics"
OUT_DIR = pathlib.Path("build/anny_export")
OUT_DIR.mkdir(parents=True, exist_ok=True)
OBJ_PATH = OUT_DIR / "anny-soma-x.obj"

model = Anny(rig="soma", topology="soma", pose_parameterization="local-ref", phenotypes="all")
model.eval()
with torch.no_grad():
    rest_out = model(phenotype_kwargs={"gender": 1.0})
rest_bone_poses = rest_out["rest_bone_poses"]
verts = rest_out["rest_vertices"][0].numpy().astype(np.float64)
faces = np.asarray(model.faces, dtype=np.int64)
mesh = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
mesh.export(str(OBJ_PATH))
print(f"wrote {OBJ_PATH} ({len(verts)} verts, {len(faces)} faces)")

M_TO_CM = 100.0


def section_perimeter(mesh, origin, normal, centerline_point):
    """The validated plane-cross-section loop (nearest-centroid-to-
    centerline, discards arm loops crossing the torso band): both the
    reference perimeter AND the actual 3D loop points, so the vertex
    ring below can be snapped from it rather than re-derived separately."""
    sec = mesh.section(plane_origin=origin, plane_normal=normal)
    if sec is None or len(sec.discrete) == 0:
        return None, None
    loops = sec.discrete
    centroids = [loop.mean(axis=0) for loop in loops]
    dists = [np.linalg.norm(c - centerline_point) for c in centroids]
    best = int(np.argmin(dists))
    chosen = loops[best]
    d = np.diff(chosen, axis=0)
    total = np.linalg.norm(d, axis=1).sum()
    if not np.allclose(chosen[0], chosen[-1]):
        total += np.linalg.norm(chosen[0] - chosen[-1])
    return total, chosen


def vertex_ring_from_section_loop(mesh, origin, normal, centerline_point):
    """Snap the validated cross-section loop to actual mesh vertex
    indices (the CLI's --measure-loop takes vertex indices, not edge-
    intersection points). A naive angular-bin pick over ALL near-plane
    vertices (first attempt) pulled in arm vertices crossing the same
    height band and produced a nonsense 276cm "waist" -- caught only by
    comparing against this reference perimeter before trusting anything."""
    ref_perim, loop_pts = section_perimeter(mesh, origin, normal, centerline_point)
    if loop_pts is None:
        return None, None
    ring = []
    for p in loop_pts:
        d2 = np.sum((mesh.vertices - p) ** 2, axis=1)
        vtx = int(np.argmin(d2))
        if not ring or ring[-1] != vtx:
            ring.append(vtx)
    if ring and ring[0] == ring[-1]:
        ring.pop()
    return ring, ref_perim * M_TO_CM


def _parse_kv_lines(stdout):
    out = {}
    for line in stdout.splitlines():
        parts = line.split()
        if len(parts) == 2:
            try:
                out[parts[0]] = float(parts[1])
            except ValueError:
                pass
    return out


def run_measure_loop(obj_path, ring):
    if len(ring) < 3:
        return None
    arg = ",".join(str(v) for v in ring)
    r = subprocess.run(
        [FLIP_GEODESICS, str(obj_path), f"--measure-loop={arg}", "--units-scale=100"],
        capture_output=True, text=True, timeout=30,
    )
    out = _parse_kv_lines(r.stdout)
    return out if out else {"ERROR": r.stdout + r.stderr, "returncode": r.returncode}


def run_measure_path(obj_path, a, b):
    r = subprocess.run(
        [FLIP_GEODESICS, str(obj_path), f"--measure-path={a},{b}", "--units-scale=100"],
        capture_output=True, text=True, timeout=30,
    )
    out = _parse_kv_lines(r.stdout)
    return out if out else {"ERROR": r.stdout + r.stderr, "returncode": r.returncode}


HIPS_BONE, CHEST_BONE = 1, 4
hips_z = rest_bone_poses[0, HIPS_BONE, 2, 3].item()
chest_z = rest_bone_poses[0, CHEST_BONE, 2, 3].item()

z_scan = np.linspace(hips_z - 0.05, chest_z + 0.05, 120)
profile = np.array([
    (section_perimeter(mesh, [0, 0, z], [0, 0, 1], [0, 0, z])[0] or np.nan) for z in z_scan
])
valid = ~np.isnan(profile)
waist_idx = np.nanargmin(profile)
waist_z = z_scan[waist_idx]
below_valid = np.where(z_scan < waist_z)[0]
below_valid = below_valid[valid[below_valid]]
hips_idx = below_valid[np.nanargmax(profile[below_valid])]
above_valid = np.where(z_scan > waist_z)[0]
above_valid = above_valid[valid[above_valid]]
bust_idx = above_valid[np.nanargmax(profile[above_valid])]
between_valid = np.where((z_scan > waist_z) & (z_scan < z_scan[bust_idx]))[0]
between_valid = between_valid[valid[between_valid]]
underbust_idx = between_valid[np.nanargmin(profile[between_valid])] if len(between_valid) > 2 else waist_idx

heights = {
    "waist": z_scan[waist_idx], "hips": z_scan[hips_idx],
    "bust": z_scan[bust_idx], "underbust": z_scan[underbust_idx],
}

results = {}
for name, z in heights.items():
    ring, ref_perim_cm = vertex_ring_from_section_loop(mesh, [0, 0, z], [0, 0, 1], [0, 0, z])
    if not ring or len(ring) < 8:
        print(f"{name}: no usable loop/ring found")
        results[name] = {"error": "could not pick a usable vertex ring"}
        continue
    print(f"{name}: z={z:.4f}  ring_size={len(ring)}  ref_section_perim={ref_perim_cm:.2f}cm")
    out = run_measure_loop(OBJ_PATH, ring)
    dij = out.get("DIJKSTRA_LENGTH") if isinstance(out, dict) else None
    plausible = bool(dij is not None and abs(dij - ref_perim_cm) / ref_perim_cm < 0.15)
    results[name] = {"ring_size": len(ring), "ref_section_perim_cm": round(ref_perim_cm, 2),
                      "plausible_vs_reference": plausible, **out}
    print(f"  {out}  plausible_vs_reference={plausible}")

LEFT_ARM, LEFT_HAND = 13, 15  # LeftArm (shoulder), LeftHand (wrist) bones
shoulder_pos = rest_bone_poses[0, LEFT_ARM, :3, 3].numpy()
wrist_pos = rest_bone_poses[0, LEFT_HAND, :3, 3].numpy()


def nearest_vertex(mesh, p):
    d2 = np.sum((mesh.vertices - np.asarray(p)) ** 2, axis=1)
    return int(np.argmin(d2))


v_shoulder = nearest_vertex(mesh, shoulder_pos)
v_wrist = nearest_vertex(mesh, wrist_pos)
straight_line_cm = np.linalg.norm(shoulder_pos - wrist_pos) * M_TO_CM
path_out = run_measure_path(OBJ_PATH, v_shoulder, v_wrist)
dij = path_out.get("DIJKSTRA_LENGTH") if isinstance(path_out, dict) else None
arm_plausible = bool(dij is not None and dij >= straight_line_cm * 0.98)
print(f"arm_length: v_shoulder={v_shoulder} v_wrist={v_wrist} "
      f"straight_line={straight_line_cm:.2f}cm  {path_out}  plausible={arm_plausible}")
results["arm_length"] = {"v_shoulder": v_shoulder, "v_wrist": v_wrist,
                          "straight_line_cm": round(float(straight_line_cm), 2),
                          "plausible_vs_straight_line": arm_plausible, **path_out}

with open(OUT_DIR / "geodesic_loop_results.json", "w") as f:
    json.dump(results, f, indent=2)
print(json.dumps(results, indent=2))
