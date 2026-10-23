extends Node
## Owns screen swapping, the pause overlay, the failure fade and ALL back handling.

enum Screen { NONE, TITLE, CHAPTER_SELECT, STAGE_HOST, BLESSING_PICK, RUN_SUMMARY }

const TITLE_SCENE: PackedScene = preload("res://screens/title/title.tscn")
const CHAPTER_SELECT_SCENE: PackedScene = preload("res://screens/chapter-select/chapter-select.tscn")
const STAGE_HOST_SCENE: PackedScene = preload("res://screens/stage-host/stage-host.tscn")
const BLESSING_PICK_SCENE: PackedScene = preload("res://screens/blessing-pick/blessing-pick.tscn")
const RUN_SUMMARY_SCENE: PackedScene = preload("res://screens/run-summary/run-summary.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://screens/pause-menu/pause-menu.tscn")
const BACK_DEDUPE_MSEC: int = 250
const FADE_SEC: float = 0.4
const FAIL_HOLD_SEC: float = 2.5
const CLEAR_COLOR: Color = Color(0.05, 0.06, 0.1)

var _screen: Screen = Screen.NONE
var _current: Control = null
var _host: Control = null
var _pause: Control = null
var _failing: bool = false
var _pending_def: StageDef = null
var _last_back_msec: int = -BACK_DEDUPE_MSEC
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _slot: Control = $ScreenSlot
@onready var _overlay: CanvasLayer = $Overlay
@onready var _veil: ColorRect = $Fade/Veil
@onready var _message: Label = $Fade/Veil/Message


func _ready() -> void:
	RenderingServer.set_default_clear_color(CLEAR_COLOR)
	RunState.stage_changed.connect(_on_stage_changed)
	RunState.blessing_offered.connect(_on_blessing_offered)
	RunState.run_failed.connect(_on_run_failed)
	RunState.chapter_completed.connect(_on_chapter_completed)
	_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_handle_back()


## The single back handler. Both ui_cancel and the Android back request land here;
## presses closer together than BACK_DEDUPE_MSEC count as one.
func _handle_back() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_back_msec < BACK_DEDUPE_MSEC:
		return
	_last_back_msec = now
	match _screen:
		Screen.TITLE:
			get_tree().quit()
		Screen.CHAPTER_SELECT:
			_show_title()
		Screen.STAGE_HOST, Screen.BLESSING_PICK:
			if _failing:
				return
			if _pause != null:
				_close_pause()
			else:
				_open_pause()
		Screen.RUN_SUMMARY:
			_show_chapter_select()


func _swap(screen: Screen, node: Control) -> void:
	_close_pause()
	if _current != null:
		_slot.remove_child(_current)
		_current.queue_free()
	_screen = screen
	_current = node
	_host = node if screen == Screen.STAGE_HOST else null
	_slot.add_child(node)


func _show_title() -> void:
	var t: Control = TITLE_SCENE.instantiate() as Control
	t.connect("start_requested", _show_chapter_select)
	_swap(Screen.TITLE, t)


func _show_chapter_select() -> void:
	var c: Control = CHAPTER_SELECT_SCENE.instantiate() as Control
	c.connect("chapter_chosen", _on_chapter_chosen)
	_swap(Screen.CHAPTER_SELECT, c)


func _on_chapter_chosen(chapter: int) -> void:
	RunState.start_chapter(chapter, RunModel.mode_from_key(SaveData.model.mode))


func _on_stage_changed(def: StageDef) -> void:
	if _failing:
		_pending_def = def
		return
	_enter_stage(def)


func _enter_stage(def: StageDef) -> void:
	if _screen != Screen.STAGE_HOST:
		_swap(Screen.STAGE_HOST, STAGE_HOST_SCENE.instantiate() as Control)
	_host.call("load_stage", def)


func _on_blessing_offered(options: Array) -> void:
	var b: Control = BLESSING_PICK_SCENE.instantiate() as Control
	b.set("options", options)
	b.connect("blessing_chosen", RunState.add_blessing)
	_swap(Screen.BLESSING_PICK, b)


func _on_chapter_completed(_chapter: int) -> void:
	var s: Control = RUN_SUMMARY_SCENE.instantiate() as Control
	s.connect("continue_pressed", _show_chapter_select)
	_swap(Screen.RUN_SUMMARY, s)


func _on_run_failed(message: String) -> void:
	if _failing:
		return
	_failing = true
	_close_pause()
	if _host != null:
		_host.call("clear_stage")
	var line: Dictionary = LineBook.resolve(message, _rng)
	var text: String = str(line.get("text", ""))
	var ref: String = str(line.get("reference", ""))
	if not ref.is_empty():
		text += "\n" + ref
	_message.text = text
	var tw: Tween = create_tween()
	tw.tween_property(_veil, "modulate:a", 1.0, FADE_SEC)
	tw.tween_interval(FAIL_HOLD_SEC)
	tw.tween_callback(_enter_pending)
	tw.tween_property(_veil, "modulate:a", 0.0, FADE_SEC)


func _enter_pending() -> void:
	_failing = false
	var def: StageDef = _pending_def
	_pending_def = null
	if def != null:
		_enter_stage(def)


func _open_pause() -> void:
	if _host != null:
		_host.call("cancel_hold")
	var p: Control = PAUSE_MENU_SCENE.instantiate() as Control
	p.connect("resumed", _close_pause)
	p.connect("restart_requested", _on_pause_restart)
	p.connect("mode_changed", _on_pause_mode)
	p.connect("quit_requested", _on_pause_quit)
	_pause = p
	_overlay.add_child(p)


func _close_pause() -> void:
	if _pause == null:
		return
	_overlay.remove_child(_pause)
	_pause.queue_free()
	_pause = null


func _on_pause_restart() -> void:
	_close_pause()
	RunState.restart_stage()


func _on_pause_mode(mode: RunModel.Mode) -> void:
	_close_pause()
	SaveData.set_mode(RunModel.mode_key(mode))
	RunState.set_mode(mode)
	RunState.restart_stage()


func _on_pause_quit() -> void:
	RunState.end_run()
	_show_title()
