extends Control
## Pause overlay: Resume, Restart stage, Change mode (cycles), Quit to title. Texts from data.

signal resumed
signal restart_requested
signal mode_changed(mode: RunModel.Mode)
signal quit_requested

const ORDER: Array[RunModel.Mode] = [RunModel.Mode.LAMB, RunModel.Mode.SHEPHERD, RunModel.Mode.NORMAL]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var items: PackedStringArray = UiText.pause_items()
	var actions: Array[Callable] = [resumed.emit, restart_requested.emit, _cycle_mode, quit_requested.emit]
	var first: Button = null
	for i in mini(items.size(), actions.size()):
		var b: Button = Button.new()
		b.text = items[i]
		if i == 2:
			b.text += "\n" + _mode_name(RunState.model.mode)
		b.custom_minimum_size = Vector2(1000, 112)
		UiFocus.bind(b)
		b.pressed.connect(actions[i])
		box.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.grab_focus()


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().paused = false


func _cycle_mode() -> void:
	var i: int = ORDER.find(RunState.model.mode)
	mode_changed.emit(ORDER[(i + 1) % ORDER.size()])


func _mode_name(mode: RunModel.Mode) -> String:
	var key: String = RunModel.mode_key(mode)
	for n in UiText.mode_names():
		if n.to_lower() == key:
			return n
	return key
