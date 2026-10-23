class_name GoldLightOverlay
extends Control
## Full-screen warm glow with the words spoken when God speaks.

var _text: Label
var _reference: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(1.0, 0.86, 0.45, 0.55)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = 1200
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_text = _label(44)
	box.add_child(_text)
	_reference = _label(32)
	box.add_child(_reference)
	modulate.a = 0.0
	hide()


func _label(font_size: int) -> Label:
	var l: Label = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.15, 0.1, 0.0))
	return l


## seconds = hold time from the data beat; 0 uses the data default (balance.json feel).
func show_light(text: String, reference: String = "", seconds: float = 0.0) -> void:
	_text.text = text
	_reference.text = reference
	_reference.visible = not reference.is_empty()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	show()
	var hold: float = seconds if seconds > 0.0 else BalanceData.feel("goldLightHoldSec")
	var fade: float = BalanceData.feel("goldLightFadeSec")
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, fade)
	_tween.tween_callback(hide)


func dismiss() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	hide()
