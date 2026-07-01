extends Node
## Day/night cycle. Advances a time value 0..1 (0 = midnight, 0.5 = noon) and blends
## the sky + Mood + clouds between hand-picked "moments", arcs a sun/moon across the
## sky, and feeds the sky colour to the water for a reflection. Edit KEYS to author the day.

@export var day_length := 120.0                  # real-time seconds for one full day
@export_range(0.0, 1.0) var start_time := 0.30   # where the day starts (0.30 = mid-morning)
@export var paused := false

# Each row: [time, sky_top, sky_horizon, sky_bottom, mood]. Times must climb 0 -> 1.
const KEYS := [
	[0.00, Color("06080f"), Color("0d1320"), Color("120e1e"), Color("4a5680")], # midnight
	[0.23, Color("2a2a52"), Color("d98a6e"), Color("8a6f8a"), Color("b9aec2")], # dawn
	[0.50, Color("4d8ad9"), Color("a6d9e6"), Color("cdd9d6"), Color("fbf7ea")], # noon
	[0.77, Color("33264d"), Color("e6744d"), Color("66405c"), Color("b08c86")], # dusk
	[1.00, Color("06080f"), Color("0d1320"), Color("120e1e"), Color("4a5680")], # midnight (wrap)
]

const SUNRISE := 0.22        # sun is up between SUNRISE and SUNSET; moon fills the night
const SUNSET := 0.78
const BODY_HORIZON := 0.62   # screen-UV height where sun/moon rise & set
const BODY_ARC := 0.42       # how high they climb at their peak

var _sky: ShaderMaterial
var _mood: CanvasModulate
var _clouds: ShaderMaterial   # optional; wired once the CloudLayer exists
var _bodies: ShaderMaterial   # optional; the sun/moon disc (SkyLayer/SunMoon)
var _water: ShaderMaterial    # optional; for the sky reflection
var _t := 0.0

func _ready() -> void:
	# $ returns a Node; cast it so we can reach the typed members.
	_sky = ($"../SkyLayer/Sky" as ColorRect).material as ShaderMaterial
	_mood = $"../Mood" as CanvasModulate
	var cl := get_node_or_null("../CloudLayer/Clouds")
	if cl:
		_clouds = (cl as ColorRect).material as ShaderMaterial
	var sm := get_node_or_null("../SkyLayer/SunMoon")
	if sm:
		_bodies = (sm as ColorRect).material as ShaderMaterial
	var wt := get_node_or_null("../Water")
	if wt:
		_water = (wt as Sprite2D).material as ShaderMaterial
	_t = start_time
	_apply(_t)

func _process(delta: float) -> void:
	if paused or day_length <= 0.0:
		return
	# fposmod wraps time back to 0 after a full day (0.98, 0.99, 0.00, 0.01 ...)
	_t = fposmod(_t + delta / day_length, 1.0)
	_apply(_t)

func _apply(t: float) -> void:
	# Find the two moments that surround t, then blend between them.
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var f := inverse_lerp(float(a[0]), float(b[0]), t)
			var top_col := (a[1] as Color).lerp(b[1] as Color, f)
			var horizon_col := (a[2] as Color).lerp(b[2] as Color, f)
			_sky.set_shader_parameter("col_top", top_col)
			_sky.set_shader_parameter("col_horizon", horizon_col)
			_sky.set_shader_parameter("col_bottom", (a[3] as Color).lerp(b[3] as Color, f))
			var mood_col := (a[4] as Color).lerp(b[4] as Color, f)
			_mood.color = mood_col
			if _clouds:
				_clouds.set_shader_parameter("light_col", mood_col.lerp(Color.WHITE, 0.45))
				_clouds.set_shader_parameter("shadow_col", mood_col.lerp(top_col, 0.45))
			if _water:
				# clean water mirrors the sky near the surface (the shader gates oil out)
				_water.set_shader_parameter("sky_reflect", horizon_col)
			_celestial(t)
			return

func _celestial(t: float) -> void:
	if not _bodies:
		return
	# sun arcs from the east horizon up to noon and down to the west horizon
	var sp := clampf(inverse_lerp(SUNRISE, SUNSET, t), 0.0, 1.0)
	var sun_uv := Vector2(lerpf(0.08, 0.92, sp), BODY_HORIZON - sin(sp * PI) * BODY_ARC)
	var sun_up := 1.0 if (t > SUNRISE and t < SUNSET) else 0.0
	# moon arcs across the night (sunset -> midnight -> sunrise)
	var mt := t + (1.0 if t < SUNRISE else 0.0)
	var mp := clampf(inverse_lerp(SUNSET, 1.0 + SUNRISE, mt), 0.0, 1.0)
	var moon_uv := Vector2(lerpf(0.08, 0.92, mp), BODY_HORIZON - sin(mp * PI) * BODY_ARC)
	var moon_up := 1.0 if (t > SUNSET or t < SUNRISE) else 0.0
	_bodies.set_shader_parameter("sun_uv", sun_uv)
	_bodies.set_shader_parameter("moon_uv", moon_uv)
	_bodies.set_shader_parameter("sun_vis", sun_up * clampf(sin(sp * PI) * 8.0, 0.0, 1.0))
	_bodies.set_shader_parameter("moon_vis", moon_up * clampf(sin(mp * PI) * 8.0, 0.0, 1.0))
