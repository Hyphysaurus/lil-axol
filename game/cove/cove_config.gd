extends Resource
class_name CoveConfig
## Single source of truth for one cove's geometry + gameplay tuning.
## Every cove component (axolotl, oil spill, ecosystem) reads these instead of
## hardcoding its own copy. One .tres per cove/level — new numbers, zero code.
##
## Frame: all coordinates are in the Cove node's local space (the same frame the
## water bounds have always been authored in). Shader COLORS are intentionally NOT
## here — they stay authored on the scene materials in the inspector.

@export_group("Water Geometry")
## Whether this cove has a swimmable water body at all (land-only levels set false).
@export var has_water: bool = true
## Horizontal span of the water body. Outside [left, right] the axo is on land.
@export var water_left: float = -142.0
@export var water_right: float = 457.0
## Y of the still waterline (feet below this = submerged).
@export var surface_y: float = -27.0
## Y of the seabed top (floor of the water column; kelp bases sit here).
@export var seabed_y: float = 166.0

@export_group("Oil Spill")
## Horizontal span the oil slick covers on the water surface.
@export var spill_left: float = 120.0
@export var spill_right: float = 445.0
## Brush erase strength — how fast the spray scrubs oil coverage away (coverage/sec at the
## brush centre). Higher = easier/faster cleaning.
@export var clean_rate: float = 1.4

@export_group("Ecosystem")
@export var kelp_count: int = 6
@export var fish_count: int = 5
## The rescued friend: an oil-matted companion asleep at friend_pos until sprayed clean.
@export var friend_enabled: bool = true
@export var friend_pos: Vector2 = Vector2(425.0, 148.0)

@export_group("Audio")
## Optional per-cove soundscape; null keeps the shared defaults (see cove_audio.gd).
@export var ambience: AudioStream
@export var life_layer: AudioStream
@export var music: AudioStream

@export_group("Leak")
## A leaking valve on the right ledge trickles fresh oil back into the spill near the source
## until the player caps it (sustained spray on the valve). Off = today's static spill.
@export var leak_enabled: bool = true
@export var leak_pos: Vector2 = Vector2(-160.0, -32.0)  # cove-local, BASE settled into the grass at the shoreline
@export var leak_rate: float = 0.20                     # coverage/sec trickled back until capped

@export_group("Win")
## Cleanliness (0..1) at which the cove counts as restored. The banner and any future
## gate (cove exit, afterglow content) all read this one value so they can never desync.
## 0.98, not 0.999: progress is visibility-weighted now, but the last shimmer specks
## still shouldn't demand a pixel hunt.
@export var win_threshold: float = 0.98
