# measure — sinew-mocap

**A tape measure that actually follows the surface.**

![ANNY-SOMA-X — real measurement locations, vector SVG](docs/images/anny-soma-x-measurement-locations.svg)

Green = 24 of 26 fields with real vertex/geodesic/axis-extent data, every landmark addressed through the real ChArUco suit board (Godot `lightmap_unwrap`, the same toolchain the physical mocap suit uses), not a raw mesh vertex id.

Values re-derived against the actual published reference implementation ([`mbotsch/GarmentMeasurements`](https://github.com/mbotsch/GarmentMeasurements), the real C++ source behind [GarmentCodeData](https://arxiv.org/abs/2405.17609v3)), not just the paper's prose.

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```
