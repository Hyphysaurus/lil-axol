extends Resource
class_name CharacterAnimSet
## Data-driven map of a character's logical motion states -> SpriteFrames clip names.
## Movement code references these fields (e.g. anim_set.run) instead of literal clip strings,
## so clips can be re-pointed or renamed as data, and a new state (dash, wall-slide) is a
## single field to add here + one call site — never a string scattered through the controller.
## One .tres per character; reusable by any script that owns an AnimationController.

@export_group("Land")
@export var idle: StringName = &"idle"
@export var walk: StringName = &"walk"
@export var run: StringName = &"run"
@export var jump: StringName = &"jump"
@export var fall: StringName = &"fall"
@export var land: StringName = &"land"

@export_group("Water")
@export var swim: StringName = &"swim"
@export var swim_idle: StringName = &"swim_idle"

## Idle life — one-shot flourishes and the cozy AFK chain (idle -> liedown -> sleep).
@export_group("Idle Life")
@export var idle_blink: StringName = &"idle_blink"
@export var sit: StringName = &"sit"
@export var liedown: StringName = &"liedown"
@export var sleep: StringName = &"sleep"

## Verbs. Spray reuses the attack strip (arm-pump into a held pose while the button is down).
@export_group("Actions")
@export var spray: StringName = &"attack"
@export var hurt: StringName = &"hurt"
@export var die: StringName = &"die"

## Clips exist in the SpriteFrames but no mechanic reads them yet; empty = skipped.
@export_group("Planned")
@export var dash: StringName = &"dash"
@export var crouch: StringName = &"crouch"
@export var sneak: StringName = &"sneak"
@export var wall_grab: StringName = &"wallgrab"
@export var wall_climb: StringName = &"wallclimb"
