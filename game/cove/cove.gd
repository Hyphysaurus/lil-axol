extends Node2D
## Cove composition root. Owns the CoveConfig and injects it into each component in
## _ready() so children depend on the config's interface — never on each other or on
## walking the scene tree. One-way dependency: the parent hands data down.
##
## Child _ready() runs before this (bottom-up), so setup() lands after each child has
## initialised but before the first physics frame — config is always present in time.

@export var config: CoveConfig

const IrisWipe := preload("res://game/fx/iris_wipe.gd")

func _ready() -> void:
	_inject($Axolotl)
	_inject($OilSpill)
	_inject($CoveLife)
	_inject($SeabedBackdrop)
	_inject($RestorationBanner)
	_inject($NewDay)
	_inject($CoveAudio)
	_inject($Friend)
	_inject($LeakSource)
	_inject($ShorePollution)
	_inject($Portal)
	_inject($DebrisField)
	_inject($PestField)
	if Settings.arrive_via_portal:
		Settings.arrive_via_portal = false
		_arrive()

## A tunnel crossing brought us here: the axolotl emerges at THIS cove's passage mouth (the left
## edge of the water — you exited the last cove travelling right), already swimming, behind an
## opening iris — the two coves read as one continuous passage.
func _arrive() -> void:
	var axo := $Axolotl as CharacterBody2D
	axo.position = Vector2(config.water_left + 34.0, config.surface_y + 46.0)
	var speed: float = axo.tuning.run_speed if axo.tuning else 150.0
	axo.velocity = Vector2(speed, 0.0)      # still swimming out of the tunnel
	var wipe := IrisWipe.new()
	add_child(wipe)
	wipe.set_closed()
	wipe.open(0.7)

func _inject(n: Node) -> void:
	# has_method guard keeps the scene runnable while components are migrated one at a time
	if n and n.has_method("setup"):
		n.setup(config)
