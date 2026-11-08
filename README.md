# measure — sinew-mocap

CI

**A tape measure that actually follows the surface — formalized in Lean 4, checked against a real geodesic tool.**

A flat plane cut through a body mesh is not what a tailor's tape reads, and most measurement pipelines settle for it anyway.

![ANNY-SOMA-X — 26 GarmentCode measurement locations, real wireframe](docs/images/anny-soma-x-measurement-locations.svg)

A real rendered wireframe of the ANNY-SOMA-X mesh (vector SVG, not a stand-in diagram). Green = the 6 fields with real vertex-level data (the actual loops/path that produced the measured numbers below). Red = the other 20 fields, shown as approximate anatomical regions — their exact landmark is not picked yet, so the dot is honest about being a region, not a precise point.

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```

Run that to see today's 15 of 26 settled fields, backed by real measured numbers, not placeholders.

The sections below hold what is ported, what is not yet, why open paths and closed loops can never share one straightening step, and the sibling repos to clone: `docs/STATUS.md`.
