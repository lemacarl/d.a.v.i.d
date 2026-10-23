extends Control
## Baseline remote tester: shows which remote button arrived.

@onready var _label: Label = $Margin/Label

var _lines: Array[String] = []


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_log("hello TV - press remote buttons")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var action := _action_for(event)
		_log("key %s (physical %d) -> %s" % [OS.get_keycode_string(event.keycode), event.physical_keycode, action])
	elif event is InputEventJoypadButton and event.pressed:
		_log("joypad button %d -> %s" % [event.button_index, _action_for(event)])
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_log("joypad axis %d = %.1f -> %s" % [event.axis, event.axis_value, _action_for(event)])
	elif not (event is InputEventMouseMotion or event is InputEventKey):
		_log("other event %s" % event.as_text())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_log("ANDROID BACK request")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_log("close request ignored")


func _action_for(event: InputEvent) -> String:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
		if event.is_action_pressed(action):
			return action
	return "none"


func _log(text: String) -> void:
	print("[hello-tv] ", text)
	_lines.append(text)
	if _lines.size() > 12:
		_lines.pop_front()
	_label.text = "\n".join(_lines)
