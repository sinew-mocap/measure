/*
measure_api.h — the C-ABI contract for the sinew-mocap body-measurement
guest. Any host (a godot-sandbox RISC-V guest load, or a plain C caller)
reaches the 26-field GarmentCode schema and the geodesic solve through
this surface only.

Conventions (see the godot-sandbox-build-workflow skill's "Designing the
guest C-ABI"):
  - Pascal strings everywhere a name crosses the boundary: a length plus a
    bytes pointer, never a NUL-terminated char*. `bytes` is NULL only when
    `length` is 0. Callers never `strlen()` a field here.
  - A universal property of a type is a required member of that type, not
    a side-channel function: every `MeasureField` carries its own `kind`
    and `settled` flag inline, the same way `BodyMeasurements.lean`'s
    `Field` structure does — this header is the C mirror of that Lean
    type, not an independent redesign.
*/
#ifndef SINEW_MEASURE_API_H
#define SINEW_MEASURE_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Pascal string: length counts UTF-8 bytes; bytes may be NULL iff length == 0. */
typedef struct {
  uint32_t length;
  const uint8_t* bytes;
} measure_str_t;

/* Mirrors Geodesic.MeasurementKind (core/geodesic/lean/MeasureSchema/BodyMeasurements.lean). */
typedef enum {
  MEASURE_KIND_CIRCUMFERENCE = 0,   /* closed loop, measureClosedLoop, Delaunay-only */
  MEASURE_KIND_SURFACE_DISTANCE = 1,/* open path, measureOpenPath, FlipOut-straightened */
  MEASURE_KIND_AXIS_EXTENT = 2,     /* straight-line extent along one mesh axis */
  MEASURE_KIND_HEIGHT_MARKER = 3,   /* a height at which another field's loop is sampled */
  MEASURE_KIND_LANDMARK_POSITION = 4,
  MEASURE_KIND_ANGLE = 5,
  MEASURE_KIND_DIFFERENCE = 6
} measure_kind_t;

/* One of the 26 GarmentCode body-measurement fields, and its current
   value on whatever mesh the host most recently loaded. `settled` is a
   REQUIRED member (every Field carries its own answer to "do we trust
   this classification"), not something a caller recomputes. */
typedef struct {
  measure_str_t name;
  measure_kind_t kind;
  int32_t settled;         /* 0/1 */
  double value_cm;          /* NaN until a mesh has been measured */
  measure_str_t note;
} measure_field_t;

/* --- Mesh loading --- */

/* Load a triangle mesh (OBJ-format vertex/face text, already decoded by
   the host into flat arrays) as the subject of the next measure_* calls.
   Returns 0 on success, nonzero on a malformed mesh (e.g. a face index
   out of range). */
int32_t measure_load_mesh(const double* vertices_xyz, uint32_t vertex_count,
                           const uint32_t* face_indices, uint32_t face_count);

/* --- Geodesic queries (core/geodesic's Measure.lean, mirrored) --- */

/* Dijkstra + FlipOut-straightened length (cm) between two vertex ids of
   the loaded mesh, an OPEN path. Returns a negative value on failure
   (unreachable vertex, no mesh loaded) rather than a fabricated length. */
double measure_open_path_cm(uint32_t vertex_a, uint32_t vertex_b);

/* Dijkstra + Delaunay-only length (cm) of a CLOSED loop through the given
   vertex ids, in order. iterativeShorten is NEVER run here — see
   Geodesic/FlipOut.lean's module doc for why a loop must not be
   shortened on a genus-0 body. Returns a negative value on failure. */
double measure_closed_loop_cm(const uint32_t* vertex_ids, uint32_t count);

/* --- Schema introspection --- */

/* Number of fields in the 26-field schema (always 26; exposed so a
   caller never hardcodes the count). */
uint32_t measure_field_count(void);

/* Field `index` (0..measure_field_count()-1), in BodyMeasurements.lean's
   `fields` order. Returns 0 on success, nonzero if `index` is out of
   range. */
int32_t measure_field_at(uint32_t index, measure_field_t* out);

#ifdef __cplusplus
}
#endif

#endif /* SINEW_MEASURE_API_H */
