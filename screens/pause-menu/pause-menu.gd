extends Control
## Pause overlay: Resume, Restart stage, Change mode (cycles), Quit to title. Texts from data.

signal resumed
signal restart_requested
signal mode_changed(mode: RunModel.Mode)
signal quit_requested


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


## Cycles through the modes listed in data (screens.modes), in that order.
func _cycle_mode() -> void:
	var modes: Array = UiText.modes()
	if modes.is_empty():
		return
	var current: String = RunModel.mode_key(RunState.model.mode)
	var i: int = 0
	for k in modes.size():
		if str((modes[k] as Dictionary)["id"]) == current:
			i = k
	var next_id: String = str((modes[(i + 1) % modes.size()] as Dictionary)["id"])
	mode_changed.emit(RunModel.mode_from_key(next_id))


func _mode_name(mode: RunModel.Mode) -> String:
	return UiText.mode_name(RunModel.mode_key(mode))
