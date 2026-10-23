class_name SubtitleBox
extends PanelContainer
## Subtitle panel: 70% black, 40 px body (times Settings.subtitle_scale), 32 px reference.

const BODY_SIZE: int = 40
const REFERENCE_SIZE: int = 32
const MIN_SECONDS: float = 3.0
const SECONDS_PER_CHAR: float = 0.06

var body_color: Color = Color(1, 1, 1)

var _body: Label
var _reference: Label
var _timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_color_override("font_color", body_color)
	box.add_child(_body)
	_reference = Label.new()
	_reference.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reference.add_theme_font_size_override("font_size", REFERENCE_SIZE)
	_reference.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	box.add_child(_reference)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(clear)
	add_child(_timer)
	hide()


## duration <= 0 picks a time from the text length.
func show_line(text: String, reference: String = "", duration: float = -1.0) -> void:
	var scale_factor: float = maxf(Settings.subtitle_scale, 1.0)
	_body.add_theme_font_size_override("font_size", roundi(BODY_SIZE * scale_factor))
	_body.text = text
	_reference.text = reference
	_reference.visible = not reference.is_empty()
	show()
	_timer.start(duration if duration > 0.0 else maxf(MIN_SECONDS, text.length() * SECONDS_PER_CHAR))


func clear() -> void:
	_timer.stop()
	hide()
