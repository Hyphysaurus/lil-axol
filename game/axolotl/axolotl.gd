extends CharacterBody2D

## Lil Axolotl player controller.
## Reads InputMap actions

const WALK_SPEED := 90.0
const RUN_SPEED := -150.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 760.0


func _physics_process(delta: float) -> void:
	# horizontal: get axis returns -1..1
	var dir := Input.get_axis("move_left", "move_right")
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity.x = dir * speed
		# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	move_and_slide()
