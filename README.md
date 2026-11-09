# measure — sinew-mocap

**A tape measure that actually follows the surface.**

![ANNY-SOMA-X — real measurement locations, vector SVG](docs/images/anny-soma-x-measurement-locations.svg)

Green = 24 of 26 fields with real vertex/geodesic/axis-extent data.

Values re-derived against the actual published reference implementation ([`mbotsch/GarmentMeasurements`](https://github.com/mbotsch/GarmentMeasurements), the source behind [GarmentCodeData](https://arxiv.org/abs/2405.17609v3)).

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```
