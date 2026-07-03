extends Node
## Sfx — the game's tiny code-first sound board (autoload). One-shots play through a small
## shared pool of AudioStreamPlayers on the SFX bus; named loops (spray) get their own
## dedicated player. Variations + subtle pitch drift come from AudioStreamRandomizer so
## repeated sounds never machine-gun. Non-positional on purpose: one screen, panning buys
## nothing. API: Sfx.play("splash"), Sfx.play("scrub", -14.0, 1.2), Sfx.loop("spray", true).

const POOL_SIZE := 8

# One-shot banks — variations fold into one AudioStreamRandomizer per name. "pitch" is the
# randomizer's subtle per-play drift (1.0 = none); meaningful pitch goes through play().
const BANK := {
	"splash": {
		"streams": [
			preload("res://assets/audio/sfx/splash_1.wav"),
			preload("res://assets/audio/sfx/splash_2.wav"),
			preload("res://assets/audio/sfx/splash_3.wav"),
			preload("res://assets/audio/sfx/splash_4.wav"),
			preload("res://assets/audio/sfx/splash_5.wav"),
			preload("res://assets/audio/sfx/splash_6.wav"),
		],
		"pitch": 1.08,
	},
	"scrub": {
		"streams": [
			preload("res://assets/audio/sfx/scrub_pop_1.wav"),
			preload("res://assets/audio/sfx/scrub_pop_2.wav"),
			preload("res://assets/audio/sfx/scrub_pop_3.wav"),
		],
		"pitch": 1.1,
	},
	"chime": {"streams": [preload("res://assets/audio/sfx/milestone_chime.wav")], "pitch": 1.0},
	"jump": {"streams": [preload("res://assets/audio/sfx/jump.wav")], "pitch": 1.06},
	"land": {"streams": [preload("res://assets/audio/sfx/land.wav")], "pitch": 1.06},
	"win": {"streams": [preload("res://assets/audio/sfx/win_stinger.wav")], "pitch": 1.0},
	"explode": {
		"streams": [
			preload("res://assets/audio/sfx/explode_1.ogg"),
			preload("res://assets/audio/sfx/explode_2.ogg"),
			preload("res://assets/audio/sfx/explode_3.ogg"),
		],
		"pitch": 1.06,
	},
}

const LOOPS := {
	"spray": preload("res://assets/audio/sfx/spray_loop.ogg"),
}

var _streams := {}                       # name -> AudioStreamRandomizer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {}                         # name -> dedicated AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menu sounds must survive the rest card's pause
	for sound_name in BANK:
		var r := AudioStreamRandomizer.new()
		r.random_pitch = BANK[sound_name].get("pitch", 1.0)
		for s in BANK[sound_name]["streams"]:
			r.add_stream(-1, s)
		_streams[sound_name] = r
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	for loop_name in LOOPS:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.stream = LOOPS[loop_name]
		add_child(p)
		_loops[loop_name] = p

## Fire a one-shot. vol_db offsets the bank's natural level; pitch stacks on top of the
## randomizer's drift (use it for meaningful pitch, e.g. scrub rising as the cove heals).
## Round-robin pool: a very old voice may be stolen under heavy load — inaudible at 8 voices.
func play(sound_name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound_name):
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound_name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

## Toggle a named loop (e.g. the spray while the button is held). Safe to call every frame.
func loop(loop_name: String, on: bool, vol_db := 0.0) -> void:
	var p = _loops.get(loop_name)
	if p == null:
		push_warning("Sfx: unknown loop '%s'" % loop_name)
		return
	if on and not p.playing:
		p.volume_db = vol_db
		p.play()
	elif not on and p.playing:
		p.stop()
