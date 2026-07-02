extends Resource
class_name AxolotlTuning
## Movement + spray tuning for the axolotl, in the CoveConfig idiom (D-0002): numbers
## live in a Resource, code reads the interface. Defaults ARE the frozen swim-safety
## contract (D-0003) — a refactor may change where these come from, never the values.

@export_group("Land")
@export var walk_speed: float = 90.0
@export var run_speed: float = 150.0
@export var jump_velocity: float = -300.0
@export var gravity: float = 760.0

@export_group("Swim")
@export var swim_h: float = 60.0
@export var swim_v: float = 54.0
@export var swim_lerp: float = 7.0
## Feet settle this far below the surface (head floats out).
@export var rest_depth: float = 5.0
@export var buoy_spring: float = 5.5
@export var buoy_max: float = 42.0
@export var bob_amp: float = 5.0
@export var bob_freq: float = 2.2
## Strong enough to clear the beach ledge out of the water.
@export var surface_hop: float = -300.0
## Max swim slow-down in thick oil (0 = none .. 1 = stuck). Pending ruling P-3.
@export var oil_drag: float = 0.5

@export_group("Spray")
## Px in front of the axo the spray reaches.
@export var spray_reach: float = 40.0
## Clean radius around the spray point.
@export var spray_radius: float = 36.0

@export_group("Dash")
## Clean Wake Dash — swim-only burst that scrubs the oil film along its path.
@export var dash_speed: float = 240.0
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 0.8
## Erode radius of the wake stripe (smaller than the spray's 36).
@export var dash_clean_radius: float = 16.0
