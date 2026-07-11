extends RefCounted
## Tiny indirection so tests/test_reach_map.gd — the direct `--script` target, which under
## `--headless --script` gets fully statically compiled BEFORE SceneTree.initialize() registers
## autoload singletons as GDScript globals — never has a bare `WorldState` identifier in its own
## source (that would fail to compile with "Identifier not found: WorldState" regardless of which
## function it's written inside, since GDScript analyzes every function body at load time). This
## file is load()'d lazily from test_reach_map.gd's first _process() callback, by which point
## autoloads are live, so referencing WorldState here compiles and runs fine.

## Redirect the WorldState AUTOLOAD singleton to a scratch save file (removing any stale scratch
## + its .bad quarantine first) so the real user save at user://world.save is never touched.
## Mirrors tests/test_world_state.gd's _fresh() idiom, just aimed at the live singleton instead of
## a fresh instance (reach_map.gd's _build_breakables() calls the global, not an injected one).
static func reset_scratch(path: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs)
	if FileAccess.file_exists(path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")
	WorldState.save_path = path
	WorldState.load_file()

static func mark(id: String, key: String, value: Variant) -> void:
	WorldState.mark(id, key, value)
