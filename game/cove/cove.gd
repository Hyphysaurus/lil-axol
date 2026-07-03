extends Node2D
## Cove composition root. Owns the CoveConfig and injects it into each component in
## _ready() so children depend on the config's interface — never on each other or on
## walking the scene tree. One-way dependency: the parent hands data down.
##
## Child _ready() runs before this (bottom-up), so setup() lands after each child has
## initialised but before the first physics frame — config is always present in time.

@export var config: CoveConfig

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

func _inject(n: Node) -> void:
	# has_method guard keeps the scene runnable while components are migrated one at a time
	if n and n.has_method("setup"):
		n.setup(config)
