extends ColorRect
## Post-FX settings bridge. Remembers the authored grain/vignette strengths from the scene
## material, then applies the Settings toggles — now, on every settings change, and again
## automatically after a New Day reload (fresh node, fresh _ready). Pull-based on purpose:
## Settings never has to know this node exists.

var _grain := 0.0
var _vignette := 0.0

func _ready() -> void:
	var m := material as ShaderMaterial
	if m == null:
		return
	# authored strengths; shader defaults as fallback if the scene never overrode them
	var g: Variant = m.get_shader_parameter("grain")
	var v: Variant = m.get_shader_parameter("vignette")
	_grain = g if g is float else 0.035
	_vignette = v if v is float else 0.40
	Settings.changed.connect(_apply)
	_apply()

func _apply() -> void:
	# 2026-07-24 perf pass: on TOUCH platforms the pass defaults OFF (the fullscreen backbuffer
	# copy is real money on phone GPUs) — a phone player can still opt back in via Settings.
	var def := not Settings.touch_active()
	var grain_on: bool = Settings.get_setting("visual", "grain", def)
	var vig_on: bool = Settings.get_setting("visual", "vignette", def)
	# With BOTH off there's nothing to grade — hide the pass so it stops sampling the screen texture.
	# That skips the full-framebuffer copy every frame (the real cost), a genuine escape hatch for
	# low-end/mobile, instead of just zeroing the uniforms while still running the fullscreen pass.
	visible = grain_on or vig_on
	var m := material as ShaderMaterial
	m.set_shader_parameter("grain", _grain if grain_on else 0.0)
	m.set_shader_parameter("vignette", _vignette if vig_on else 0.0)
