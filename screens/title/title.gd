extends Control
## Title: heading and prompt from data, a bouncing placeholder sheep beside the OK button.

signal start_requested

const HEADING_SIZE: int = 96


func _ready() -> void:
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 64)
	center.add_child(box)
	var parts: PackedStringArray = UiText.title_parts()
	if not parts[1].is_empty():
		var heading: Label = Label.new()
		heading.text = parts[0]
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", HEADING_SIZE)
		box.add_child(heading)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	box.add_child(row)
	row.add_child(IconShape.new(IconShape.Kind.SHEEP, 160.0))
	var ok: Button = Button.new()
	ok.text = parts[1] if not parts[1].is_empty() else parts[0]
	ok.custom_minimum_size = Vector2(720, 128)
	UiFocus.bind(ok)
	ok.pressed.connect(start_requested.emit)
	row.add_child(ok)
	ok.grab_focus()
