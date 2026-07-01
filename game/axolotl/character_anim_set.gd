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

@export_group("Water")
@export var swim: StringName = &"swim"
@export var swim_idle: StringName = &"swim_idle"

## Reserved for the Celeste-movement pass — assign once the clips exist; empty = skipped.
@export_group("Planned")
@export var dash: StringName = &""
@export var wall_slide: StringName = &""
@export var land: StringName = &""
