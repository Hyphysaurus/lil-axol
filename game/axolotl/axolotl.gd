extends CharacterBody2D
## Lil Axolotl player controller — land movement with animation + facing.
## Reads InputMap actions (keyboard now; touch/gamepad drop in later). Swim arrives in Phase 3.

const WALK_SPEED := 90.0
const RUN_SPEED := 150.0          # Phase 1 had this NEGATIVE — that's why running went backwards
const JUMP_VELOCITY := -300.0
const GRAVITY := 760.0
const MOVE_EPS := 6.0             # x-speed below this counts as standing still (for the idle anim)

@onready var _spr: AnimatedSprite2D = $Sprite

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if running else WALK_SPEED
	velocity.x = dir * speed

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_animate(dir, running)

func _animate(dir: float, running: bool) -> void:
	if dir != 0.0:
		_spr.flip_h = dir < 0.0           # face the way we move (art faces right by default)
	if not is_on_floor():
		_anim("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > MOVE_EPS:
		_anim("run" if running else "walk")
	else:
		_anim("idle")

func _anim(a: String) -> void:
	if _spr.animation != a:
		_spr.play(a)
