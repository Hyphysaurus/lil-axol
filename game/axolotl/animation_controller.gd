extends RefCounted
class_name AnimationController
## Reusable sprite animation driver. Owns an AnimatedSprite2D and plays clips by name,
## centralising facing-flip and the "don't restart a clip that's already playing" guard in
## one place. Characters decide their logical state and hand the mapped clip name here (from a
## CharacterAnimSet), so clip strings live in data, never scattered through movement code.
## Reusable by any character (axolotl now, enemies later).

var _spr: AnimatedSprite2D

func _init(sprite: AnimatedSprite2D) -> void:
	_spr = sprite

## Play `clip`, facing by the sign of `facing` (0 = leave facing unchanged). Empty clip = no-op,
## so a not-yet-authored state (e.g. a reserved CharacterAnimSet field) is safely ignored.
func play(clip: StringName, facing := 0.0) -> void:
	if clip == &"" or _spr == null:
		return
	if facing != 0.0:
		_spr.flip_h = facing < 0.0
	if _spr.animation != clip:
		_spr.play(clip)
