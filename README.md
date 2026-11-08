# measure — sinew-mocap

CI

**A tape measure that actually follows the surface — formalized in Lean 4, checked against a real geodesic tool.**

A flat plane cut through a body mesh is not what a tailor's tape reads, and most measurement pipelines settle for it anyway.

![ANNY-SOMA-X — 26 GarmentCode measurement locations, real wireframe](docs/images/anny-soma-x-measurement-locations.svg)

A real rendered wireframe of the ANNY-SOMA-X mesh (vector SVG, not a stand-in diagram). Green = 22 of 26 fields with real vertex/geodesic/axis-extent data — every landmark addressed through the real ChArUco suit board (Godot `lightmap_unwrap`, the same toolchain the physical mocap suit uses), not a raw mesh vertex id. Red = the 4 angle/derived fields with no vertex-level pick yet.

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```

Run that to see today's 26 of 26 settled fields, backed by real measured numbers, not placeholders.

The sections below hold what is ported, what is not yet, why open paths and closed loops can never share one straightening step, and the sibling repos to clone: `docs/STATUS.md`.
