extends Control
## Chapter-complete card: stats from the data template, the completion line, Continue.

signal continue_pressed

const SUMMARY_SIZE: int = 44


func _ready() -> void:
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size.x = 1400
	box.add_theme_constant_override("separation", 48)
	center.add_child(box)
	var summary: Label = _label(_summary_text())
	summary.add_theme_font_size_override("font_size", SUMMARY_SIZE)
	box.add_child(summary)
	box.add_child(_label(_closing_text()))
	var b: Button = Button.new()
	b.text = UiText.continue_label()
	b.custom_minimum_size = Vector2(480, 112)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiFocus.bind(b)
	b.pressed.connect(continue_pressed.emit)
	box.add_child(b)
	b.grab_focus()


func _label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _summary_text() -> String:
	var names: PackedStringArray = PackedStringArray()
	for id in RunState.model.blessings:
		names.append(str(BalanceData.blessing_card(id).get("name", String(id))))
	var stats: Dictionary = RunState.model.stats
	return UiText.summary_template() \
		.replace("{sheepSaved}", str(stats.get("sheep_saved", 0))) \
		.replace("{stonesThrown}", str(stats.get("stones_thrown", 0))) \
		.replace("{blessings}", ", ".join(names))


func _closing_text() -> String:
	var line: Dictionary = LineBook.line(StringName(str(RunState.chapter_data.get("completeCard", ""))))
	var text: String = str(line.get("text", ""))
	var ref: String = str(line.get("reference", ""))
	if not ref.is_empty():
		text += "\n" + ref
	return text
