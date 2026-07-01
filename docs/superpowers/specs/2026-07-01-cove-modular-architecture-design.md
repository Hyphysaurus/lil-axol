# Cove Modular Architecture — Design Spec

**Date:** 2026-07-01
**Branch:** `refactor/cove-modular-architecture`
**Goal:** Kill duplicated/hardcoded world dimensions and split tangled scripts into
single-purpose, config-driven components — without changing swim behavior.

## Problem

The cove's geometry and tuning are hardcoded across three scripts with **drifted,
conflicting values** (the single source-of-truth bug):

| Value | `axolotl` (canonical) | `oil_spill.gd` | `cove_life.gd` |
|---|---|---|---|
| surface Y | **−27** | −27 | −22 |
| left X | **−142** | 120 (spill) | −130 |
| right X | **457** | 445 (spill) | 445 |
| seabed Y | — | — | 165 |

Any cove tweak means editing 3–4 places and hoping they agree. `oil_spill.gd` also
mixes simulation with presentation.

## Decisions (approved)

- **Config home:** a `CoveConfig` **Resource** (`.tres`). Most modular + level-ready
  for the planned multi-scene game. One `.tres` per cove/level, zero code changes.
- **Wiring:** dependency injection from a `cove.gd` composition root. Children never
  call `get_parent()`; the parent hands config down one-way.
- **Scope:** geometry + gameplay tuning move to config. Shader **colors stay** authored
  in scene materials (art, inspector-tuned). YAGNI on config-driving color.

## Canonical values (config defaults)

The **axolotl's** numbers win, because those are the ones tuned until swim felt right.
`cove_life`'s drifted `−130 / −22` were only visual spawn bounds; they get pulled into
line (a tiny, correct kelp/fish placement nudge — never touches swim).

```
CoveConfig defaults:
  water_left  = -142.0
  water_right =  457.0
  surface_y   =  -27.0
  seabed_y    =  166.0   # matches the scene's Seabed polygon top edge
  blob_count  =  9
  spill_left  =  120.0
  spill_right =  445.0
  clean_rate  =  1.4
  kelp_count  =  6
  fish_count  =  5
```

## Architecture

### Data layer — `game/cove/cove_config.gd`
`class_name CoveConfig extends Resource`, `@export`ed vars grouped:
`Water Geometry` / `Oil Spill` / `Ecosystem`. Instance: `game/cove/cove_a.tres`.

### Composition root — `game/cove/cove.gd`
On the `Cove` root Node2D. Holds `@export var config: CoveConfig`. In `_ready()`
injects into each child: `$Axolotl.setup(config)`, `$OilSpill.setup(config)`,
`$CoveLife.setup(config)`.

### Components
| File | Responsibility | Change |
|---|---|---|
| `cove_config.gd` | Data only | **new** |
| `cove.gd` | Wires scene, injects config | **new** |
| `axolotl.gd` | Character controller (land/swim/spray input) | drop 4 hardcoded water `@export`s → read injected config; `setup(config)` |
| `oil_spill.gd` | Oil **simulation** (blob amounts, `cleanliness` signal) | config-driven; extract FX |
| `cleanup_fx.gd` | Particle bursts, expanding rings, sparkles | **new** — pulled out of `oil_spill.gd` |
| `cove_life.gd` | Ecosystem fade-in (kelp/fish/bubbles) | config-driven; align spawn bounds to canonical |
| `day_night.gd` | Sky/water/time | unchanged (already clean) |

### Dead code removed (falls out of this pass)
- `game/cove/polygon_2d.gd` — orphaned placeholder, attached to nothing.
- `WaterArea` (Area2D) + axolotl `WaterSensor` (Area2D) — disabled, superseded by
  config-driven math.
- Add missing `uid` on the `cove_life.gd` ext_resource in `cove.tscn`.

### Out of scope (future work)
Audio, win-state/game loop, unused prop-library decision, `TimeOfDay` 20s debug value,
Jolt physics / unused `dash` action cleanup.

## Swim-safety contract

The swim behavior is **not refactored** — only where three numbers come from changes.

**FROZEN — copied byte-for-byte, do not touch:**
`_cove_local()`, the hysteresis (`+4.0` enter / `−2.0` exit), `_swim()`, `_enter_water()`,
`_exit_water()`, `_splash()`, and every tuning const:
`WALK_SPEED 90, RUN_SPEED 150, JUMP_VELOCITY −300, GRAVITY 760, MOVE_EPS 6, HALF_H 9,
SWIM_H 60, SWIM_V 54, SWIM_LERP 7, REST_DEPTH 5, BUOY_SPRING 5.5, BUOY_MAX 42,
BOB_AMP 5, BOB_FREQ 2.2, SURFACE_HOP −300, SPRAY_REACH 40, SPRAY_RADIUS 36.`

Only `water_left / water_right / water_surface_y` change source: from local `@export`s
to the injected `CoveConfig`, read at the **same call sites, same cove-local frame**.
The axolotl sees identical values before and after.

## Implementation sequencing (isolates swim risk)

1. Create `CoveConfig` + `cove_a.tres` with the exact canonical numbers.
2. Add `cove.gd`, wire scene, inject into **axolotl only**; remove its 4 water `@export`s.
   → **CHECKPOINT: user playtests swim** — enter water, rest/bob at surface, dive,
   surface-hop clears the beach ledge, exit onto sand, spray. Confirm identical.
3. Only after the checkpoint passes: config-drive `oil_spill` + extract `cleanup_fx`,
   config-drive `cove_life`, remove dead code, fix the `uid`.

If swim ever feels off, it is isolated to the step-2 diff and reverts instantly.
