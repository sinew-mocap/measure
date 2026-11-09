# measure — sinew-mocap

**A tape measure that actually follows the surface of the body.**

![ANNY-SOMA-X — real measurement locations, vector SVG](docs/images/anny-soma-x-measurement-locations.svg)

* [GarmentMeasurements](https://github.com/mbotsch/GarmentMeasurements)
* [GarmentCodeData](https://arxiv.org/abs/2405.17609v3).

```sh
cd core/geodesic/lean && lake build && lake exe geodesic_test
cd core/measure-schema/lean && lake build && lake exe measure_schema_report
```
