extends Node
## WorldState — the persistent world memory (Living Watershed spec §7). One ConfigFile at
## user://world.save (IndexedDB-backed on web, so lilaxol.vercel.app keeps saves): a section per
## cove keyed by CoveConfig.id, plus a meta section for versioning. Writes are milestone-driven
## (the cove root calls mark() on rescue/portal/restore and on scene exit) — never per-frame.
## Corrupt or future-versioned files are quarantined to `<file>.bad` and replaced with a fresh
## store: never crash, never silently clobber the evidence (spec §7).

const SAVE_VERSION := 1

## Injectable for tests; the game always uses the default.
var save_path := "user://world.save"

## SESSION flags (not persisted):
## echo — the next scene load is an ECHO RUN (score replay of a restored cove): the root skips
## applying saved state and suppresses saves, so the world stays untouched (spec §7).
var echo := false
## current_id — the live scene's cove id, set by the cove root (New Day reads it).
var current_id := ""

var _cfg := ConfigFile.new()

func _ready() -> void:
	load_file()

## Load (or re-load) the store. Missing file = fresh defaults; unreadable or future-versioned
## file = quarantine + fresh.
func load_file() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(save_path):
		var err := _cfg.load(save_path)
		var v := int(_cfg.get_value("meta", "version", SAVE_VERSION)) if err == OK else SAVE_VERSION + 1
		if err != OK or v > SAVE_VERSION:
			_quarantine()
	_cfg.set_value("meta", "version", SAVE_VERSION)

func _quarantine() -> void:
	var abs := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")   # Windows rename won't overwrite an existing target
	var err := DirAccess.rename_absolute(abs, abs + ".bad")   # keep the evidence
	if err != OK:
		push_warning("WorldState: could not quarantine save (%d); starting fresh over it" % err)
	_cfg = ConfigFile.new()

func get_cove(id: String, key: String, default: Variant) -> Variant:
	return _cfg.get_value("cove_" + id, key, default)

## Set one per-cove value and flush to disk. Milestone-cadence only — never call per frame.
func mark(id: String, key: String, value: Variant) -> void:
	_cfg.set_value("cove_" + id, key, value)
	var err := _cfg.save(save_path)
	if err != OK:
		push_warning("WorldState: save failed (%d) - progress kept in memory this session" % err)

func is_restored(id: String) -> bool:
	return bool(get_cove(id, "restored", false))

## Any world memory at all? Drives the title's continue / new-tide split — a brand-new player
## sees a single "begin"; a returning one gets the choice. True when any cove section exists.
func has_progress() -> bool:
	for s in _cfg.get_sections():
		if s.begins_with("cove_"):
			return true
	return false

## NEW TIDE: wash the whole world away — deliberate, player-chosen, offered at the title only.
## Deletes the save and starts a fresh memory; the caller resets session state and reloads.
## A .bad quarantine file (if any) is left alone — it's evidence, not progress.
func wipe() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_cfg = ConfigFile.new()
	_cfg.set_value("meta", "version", SAVE_VERSION)
	echo = false
