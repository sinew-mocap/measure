/*
main.c — the sinew-mocap/measure guest shim: a static RISC-V64 Linux
executable that exposes api/measure_api.h to the godot-sandbox host.

STAGE 1 of 3 (per godot-sandbox-build-workflow's C-ABI domain recipe):
this shim exists so the guest BUILDS and its symbol/.sandbox_variant
section gates pass. Every function below is an explicit, documented
STUB — it returns a clearly-failure value (negative length, nonzero
error code) rather than a fabricated measurement. Stage 2 is wiring the
real `core/geodesic`/`core/measure-schema` Lean computation in as a
cross-checked oracle from the host side; stage 3 is porting the Lean
itself to run ON the RISC-V guest (the `lean4-riscv-guest` skill's
"runtime port"), at which point these stubs become real Lean-compiled
calls. Do not read a zero-looking "success" out of this file today —
every numeric stub is deliberately a sentinel a caller must check.

The field TABLE below (names, kind, settled) is real data copied
verbatim from BodyMeasurements.lean's `fields` array — not a
computation, so embedding it here is not "stage 3 work done early".
*/
#include "../api/measure_api.h"
#include <string.h>

/* --- .sandbox_variant marker (godot-sandbox-build-workflow skill) ---
   SBXV + Variant size as little-endian u32. 40 = double-precision host
   (the pinned Godot double editor this workspace standardizes on); flip
   to 24 only when building against a single-precision host. */
__attribute__((used, retain, section(".sandbox_variant")))
static const unsigned char sandbox_variant_marker[8] = {'S', 'B', 'X', 'V', 40, 0, 0, 0};

/* --- field table: verbatim from BodyMeasurements.lean's `fields` --- */
typedef struct {
  const char* name;
  measure_kind_t kind;
  int settled;
} field_row_t;

static const field_row_t FIELD_TABLE[26] = {
    {"height", MEASURE_KIND_AXIS_EXTENT, 1},
    {"waist", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"bust", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"underbust", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"hips", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"leg_circ", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"wrist", MEASURE_KIND_CIRCUMFERENCE, 1},
    {"arm_length", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"shoulder_w", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"neck_w", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"back_width", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"hip_back_width", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"waist_back_width", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"head_l", MEASURE_KIND_AXIS_EXTENT, 1},
    {"armscye_depth", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"bust_line", MEASURE_KIND_HEIGHT_MARKER, 1},
    {"waist_line", MEASURE_KIND_HEIGHT_MARKER, 1},
    {"hips_line", MEASURE_KIND_HEIGHT_MARKER, 1},
    {"vert_bust_line", MEASURE_KIND_HEIGHT_MARKER, 1},
    {"waist_over_bust_line", MEASURE_KIND_HEIGHT_MARKER, 1},
    {"bust_points", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"bum_points", MEASURE_KIND_SURFACE_DISTANCE, 1},
    {"shoulder_incl", MEASURE_KIND_ANGLE, 1},
    {"hip_inclination", MEASURE_KIND_ANGLE, 1},
    {"arm_pose_angle", MEASURE_KIND_ANGLE, 1},
    {"crotch_hip_diff", MEASURE_KIND_DIFFERENCE, 1},
};

static measure_str_t str_of(const char* s) {
  measure_str_t out;
  out.length = (uint32_t)strlen(s);
  out.bytes = (const uint8_t*)s;
  return out;
}

/* --- STUB: mesh loading. Always reports "ok" shape-wise (count check)
   but does not actually retain the mesh for later geodesic queries —
   that retention is stage 2/3 work. --- */
int32_t measure_load_mesh(const double* vertices_xyz, uint32_t vertex_count,
                           const uint32_t* face_indices, uint32_t face_count) {
  (void)vertices_xyz;
  (void)face_indices;
  if (vertex_count == 0 || face_count == 0) {
    return 1; /* malformed: an empty mesh is never valid input */
  }
  return 0;
}

/* --- STUB: geodesic queries. Always fail (negative sentinel) since no
   real geodesic solve is wired into the guest yet — see the module
   docstring. A caller MUST check for a negative return, not trust any
   value here as measured. --- */
double measure_open_path_cm(uint32_t vertex_a, uint32_t vertex_b) {
  (void)vertex_a;
  (void)vertex_b;
  return -1.0;
}

double measure_closed_loop_cm(const uint32_t* vertex_ids, uint32_t count) {
  (void)vertex_ids;
  (void)count;
  return -1.0;
}

/* --- Real (not stubbed): schema introspection is pure static data. --- */
uint32_t measure_field_count(void) { return 26; }

int32_t measure_field_at(uint32_t index, measure_field_t* out) {
  if (index >= 26 || out == 0) {
    return 1;
  }
  const field_row_t* row = &FIELD_TABLE[index];
  out->name = str_of(row->name);
  out->kind = row->kind;
  out->settled = row->settled;
  out->value_cm = -1.0; /* no mesh measured yet in this stage */
  out->note = str_of("");
  return 0;
}

int main(void) {
  /* A plain entry point so the structural ELF checks (file type,
     .sandbox_variant, GLOBAL symbols) have something to load; a
     godot-sandbox host calls the measure_* functions directly via
     vmcall, never main(). */
  return 0;
}
