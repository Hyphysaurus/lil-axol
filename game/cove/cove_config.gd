extends Resource
class_name CoveConfig
## Single source of truth for one cove's geometry + gameplay tuning.
## Every cove component (axolotl, oil spill, ecosystem) reads these instead of
## hardcoding its own copy. One .tres per cove/level — new numbers, zero code.
##
## Frame: all coordinates are in the Cove node's local space (the same frame the
## water bounds have always been authored in). Shader COLORS are intentionally NOT
## here — they stay authored on the scene materials in the inspector.

@export_group("Identity")
## Stable save key for this cove ("hub", "estuary", ...). WorldState files all progress under it —
## never rename once players have saves.
@export var id: String = "hub"

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
## Floating pollution debris the FROG's tongue clears (out of the axolotl's spray reach). 0 = none.
@export var debris_count: int = 0
## Pest-flies that swarm dirty water (a living symptom of pollution — they gently re-oil beneath
## themselves, hard-capped by D-0005). The frog auto-tongues them into a cleanse; as the water heals
## they give way to dragonflies (ambient reward). 0 = none.
@export var pest_count: int = 0
## Marsh set-dressing: lilypads riding the waterline (frog perches) and cattail reeds rooted in
## the shallows near each bank. 0 = none (the component retires) — the hub default.
@export var lilypad_count: int = 0
@export var reed_count: int = 0
## Hidden Field Guide CURIOS (Living Watershed §8), cove-local positions. Each unlocks the card
## keyed "<id>_<index>" in game/log/field_guide.gd — keep both lists in step. Empty = none.
@export var curios: Array[Vector2] = []
## The rescued friend: an oil-matted companion asleep at friend_pos until sprayed clean.
@export var friend_enabled: bool = true
@export var friend_pos: Vector2 = Vector2(425.0, 148.0)
## Which companion + verb: TURTLE = shell-spin demolition, FROG = tongue-grab, OTTER + DRAGONFLY =
## registered followers (their verbs land with their slices). The art fields below let one companion
## rig serve them all — swap frames/anims/scale per cove, zero code (D-0006 data-driven rig).
@export_enum("Turtle", "Frog", "Otter", "Dragonfly") var friend_kind: int = 0
## Optional per-cove companion art; null = the companion's own @export defaults (the turtle).
@export var friend_frames: SpriteFrames
@export var friend_anims: CharacterAnimSet
@export var friend_scale: float = 1.0   # the frogpack frames are 50px vs the turtle's 40px — scale to match

@export_group("Environment")
## Optional per-cove looks, applied by the composition root (alpha 0 = unset, keep defaults).
## Water tint multiplies the water sprite's shader output (green-tea marsh water); land tint
## the block-land soil. Real per-cove identity instead of a whole-scene CanvasModulate wash.
@export var env_water_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var env_land_tint: Color = Color(0.0, 0.0, 0.0, 0.0)

@export_group("Audio")
## Optional per-cove soundscape; null keeps the shared defaults (see cove_audio.gd).
@export var ambience: AudioStream
@export var life_layer: AudioStream
@export var music: AudioStream

@export_group("Leak")
## A leaking valve on the right ledge trickles fresh oil back into the spill near the source
## until the player caps it (sustained spray on the valve). Off = today's static spill.
@export var leak_enabled: bool = true
@export var leak_pos: Vector2 = Vector2(-160.0, -26.0)  # cove-local, BASE settled into the grass at the shoreline
@export var leak_rate: float = 0.20                     # coverage/sec trickled back until capped

@export_group("Win")
## Cleanliness (0..1) at which the cove counts as restored. The banner and any future
## gate (cove exit, afterglow content) all read this one value so they can never desync.
## 0.98, not 0.999: progress is visibility-weighted now, but the last shimmer specks
## still shouldn't demand a pixel hunt.
@export var win_threshold: float = 0.98

@export_group("Exit / Pathway")
## A one-way pathway out of this cove to the NEXT scene — the seam the multi-cove world is built on
## (see cove_portal.gd). Off = a self-contained level with no exit.
@export var exit_enabled: bool = false
## Scene loaded when the axolotl enters the open passage (e.g. "res://estuary.tscn").
@export var exit_target: String = ""
## Where the passage sits, in cove-local coordinates.
@export var exit_pos: Vector2 = Vector2.ZERO
## true = a rubble plug blocks it until broken open (turtle ram / bubble bomb); false = already open.
@export var exit_blocked: bool = true
