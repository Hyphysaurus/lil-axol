extends Node
## CoveAudio — the cove breathes (audio spec, phases 2–3). Three loops:
##  · sea bed: always on behind the healing low-pass
##  · life layer (grass + birds): swells with cleanliness × daylight — first birds arrive
##    around a quarter clean, and they go quiet at night
##  · music: EARNED — the Music bus stays silent until ~85% clean, then a cozy track eases
##    in, opening fully the moment the cove is restored
## The Ambience bus carries one LowPassFilter (default_bus_layout.tres): its cutoff sweeps
## in octaves with the heal (700 Hz oily → ~18 kHz clean) so scrubbing literally opens the
## sound of the world, and it clamps low while the axolotl is submerged (diving muffles,
## surfacing pops back). The SFX bus stays crisp — verbs must read responsive.
## Per-cove streams may be overridden on CoveConfig; defaults are the staged assets.

const SEA := preload("res://assets/audio/ambience/sea.ogg")
const LIFE := preload("res://assets/audio/ambience/grassy_field_loop.wav")
# The title theme is two stems that loop at different lengths (45s pad + 57s bells) so they
# drift and never phase-lock — the same generative feel authored in Ableton.
const MUSIC_PAD := preload("res://assets/audio/music/mus_base.ogg")
const MUSIC_BELLS := preload("res://assets/audio/music/mus_alive.ogg")

const MIX_RATE := 0.5              # cleanliness smoothing, matched to the kelp's heal rate
const CUTOFF_OILY := 700.0
const CUTOFF_OCTAVES := 4.7        # 700 * 2^4.7 ≈ 18 kHz fully clean
const SUBMERGED_CUTOFF := 2500.0
const CUTOFF_SWEEP := 24000.0      # Hz/s toward the target — fast, but never a pop
const SEA_DB := -6.0
const LIFE_MIN_DB := -60.0
const LIFE_MAX_DB := -8.0
const NIGHT_DUCK_DB := -4.0        # deep-night hush on the whole ambience
const MUSIC_AT := 0.85             # the music is the prize
const MUSIC_DB := -6.0             # approaching the win
const MUSIC_FULL_DB := 0.0         # fully restored
const TITLE_DB := -8.0             # the theme also plays under the title veil, then fades:
const FADE_OUT_DB := -50.0         # the spilled cove has lost its song until you restore it

var _cfg: CoveConfig
var _sea: AudioStreamPlayer
var _life: AudioStreamPlayer
var _music: AudioStreamPlayer      # pad bed (mus_base)
var _music_hi: AudioStreamPlayer   # bells melody (mus_alive)
var _lpf: AudioEffectLowPassFilter
var _day_src: Node                 # TimeOfDay (day_night.gd), optional
var _clean := 0.0
var _mix := 0.0                    # smoothed clean; the whole soundscape follows this
var _submerged := false
var _music_on := false
var _restored := false

func _ready() -> void:
	_sea = _make_player(SEA, &"Ambience", SEA_DB, true)
	_life = _make_player(LIFE, &"Ambience", LIFE_MIN_DB, true)
	_music = _make_player(MUSIC_PAD, &"Music", -30.0, false)
	_music_hi = _make_player(MUSIC_BELLS, &"Music", -30.0, false)
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(func(v: float) -> void: _clean = v)
	var axo := get_node_or_null("../Axolotl")
	if axo and axo.has_signal("submerged_changed"):
		axo.submerged_changed.connect(func(on: bool) -> void: _submerged = on)
	var banner = get_tree().get_first_node_in_group("restoration")
	if banner and banner.has_signal("restored"):
		banner.restored.connect(_on_restored)
	var day := get_node_or_null("../TimeOfDay")
	if day and day.has_method("time_of_day"):
		_day_src = day
	var bus := AudioServer.get_bus_index("Ambience")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		_lpf = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter

## Injected by the Cove composition root; optional per-cove streams (null = defaults).
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.ambience:
		_sea.stream = cfg.ambience
		_sea.play()
	if cfg.life_layer:
		_life.stream = cfg.life_layer
		_life.play()
	if cfg.music:
		_music.stream = cfg.music   # per-cove override swaps the pad bed

func _process(delta: float) -> void:
	_mix = move_toward(_mix, _clean, delta * MIX_RATE)
	var day := _day_weight()
	# healing mix: murky water muffles the world; scrubbing opens it octave by octave
	if _lpf:
		var cutoff := CUTOFF_OILY * pow(2.0, _mix * CUTOFF_OCTAVES)
		if _submerged:
			cutoff = minf(cutoff, SUBMERGED_CUTOFF)
		_lpf.cutoff_hz = move_toward(_lpf.cutoff_hz, cutoff, delta * CUTOFF_SWEEP)
	# life layer: cleanliness × daylight — birds return where (and when) it's worth singing
	var life := smoothstep(0.05, 0.45, _mix) * day
	_life.volume_db = lerpf(LIFE_MIN_DB, LIFE_MAX_DB, life)
	_sea.volume_db = SEA_DB + NIGHT_DUCK_DB * (1.0 - day) * 0.5
	# music: plays under the title veil, fades out for the spilled cove, and is EARNED
	# back near the end of the heal — the restored cove remembers its song
	var title_up := get_tree().get_first_node_in_group("title_veil") != null
	if not _music_on and _mix >= MUSIC_AT:
		_start_music()
	if title_up and not _music.playing:
		_play_music(-30.0)
	if _music.playing:
		var target := FADE_OUT_DB
		if title_up:
			target = TITLE_DB
		elif _restored:
			target = MUSIC_FULL_DB
		elif _music_on:
			target = MUSIC_DB
		var v := move_toward(_music.volume_db, target, delta * 6.0)
		_music.volume_db = v
		_music_hi.volume_db = v
		if not title_up and not _music_on and v <= FADE_OUT_DB + 1.0:
			_music.stop()
			_music_hi.stop()

func _on_restored() -> void:
	_restored = true
	_start_music()

func _start_music() -> void:
	if _music_on:
		return
	_music_on = true
	_play_music(-30.0)         # rise from a whisper

## Start both title-theme stems together (idempotent; each loops at its own length so they drift).
func _play_music(db: float) -> void:
	for p in [_music, _music_hi]:
		if not p.playing:
			p.volume_db = db
			p.play()

## 1.0 in full daylight, 0.0 at deep night, smooth ramps around sunrise/sunset.
func _day_weight() -> float:
	if _day_src == null:
		return 1.0
	var t: float = _day_src.time_of_day()
	return smoothstep(0.19, 0.26, t) * (1.0 - smoothstep(0.74, 0.81, t))

func _make_player(stream: AudioStream, bus: StringName, db: float, start: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = db
	add_child(p)
	if start:
		p.play()
	return p
