class_name StageHost
extends Control
## Loads one stage scene at a time, wires its signals to RunState and the HUD, and owns
## OK tap versus hold (release before harp_hold_sec = tap, reaching it while held = hold once).

const STAGE_PATH: String = "res://stage-scenes/stage-%s.tscn"

var _stage: StageBase = null
var _slot: Node2D
var _hud: Hud
var _subtitle: SubtitleBox
var _caption: CaptionBox
var _gold: GoldLightOverlay
var _dim: ColorRect
var _rest_timer: Timer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lines: LineQueue = LineQueue.new()
var _resting: bool = false
var _holding: bool = false
var _hold_fired: bool = false
var _held: float = 0.0
var _hold_limit: float = 2.0


func _ready() -> void:
	_hold_limit = BalanceData.harp_hold_sec()
	_slot = Node2D.new()
	add_child(_slot)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	var safe: SafeArea = SafeArea.new()
	root.add_child(safe)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 24)
	safe.add_child(col)
	_hud = Hud.new()
	col.add_child(_hud)
	_caption = CaptionBox.new()
	col.add_child(_caption)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_subtitle = SubtitleBox.new()
	col.add_child(_subtitle)
	_gold = GoldLightOverlay.new()
	root.add_child(_gold)
	_rest_timer = Timer.new()
	_rest_timer.one_shot = true
	_rest_timer.timeout.connect(_on_rest_over)
	add_child(_rest_timer)
	_lines.line_started.connect(_on_line_started)
	_lines.caption_started.connect(_on_caption_started)
	_lines.narration_started.connect(Audio.narrate)
	_lines.drained.connect(_on_lines_drained)
	_lines.gold_started.connect(_gold.show_light)
	Audio.play_music(Audio.MUSIC_MAIN)
	RunState.tired.connect(_on_tired)


func load_stage(def: StageDef) -> void:
	clear_stage()
	Audio.play_music(Audio.MUSIC_MAIN)
	_gold.dismiss()
	_subtitle.clear()
	_caption.clear()
	var path: String = scene_path(def)
	if not ResourceLoader.exists(path):
		push_error("StageHost: missing stage scene %s" % path)
		return
	var inst: Node = (load(path) as PackedScene).instantiate()
	var s: StageBase = inst as StageBase
	if s == null:
		push_error("StageHost: %s root does not extend StageBase" % path)
		inst.queue_free()
		return
	_stage = s
	s.stage_won.connect(_on_stage_won)
	s.stage_failed.connect(_on_stage_failed)
	s.hit_taken.connect(RunState.apply_hit)
	s.sheep_saved.connect(RunState.record_sheep_saved)
	s.stone_thrown.connect(RunState.record_stone_thrown)
	s.hit_taken.connect(_on_hit_taken)
	s.sheep_saved.connect(Audio.play_sfx.bind(&"sheep-baa"))
	s.stone_thrown.connect(Audio.play_sfx.bind(&"stone-throw"))
	s.sfx_requested.connect(Audio.play_sfx)
	s.follower_added.connect(RunState.add_followers)
	s.followers_scattered.connect(RunState.lose_followers)
	s.spared.connect(_on_spared)
	s.heal_requested.connect(RunState.heal)
	s.grant_requested.connect(RunState.apply_grant)
	s.stone_collected.connect(RunState.add_stones.bind(1))
	s.stone_spent.connect(RunState.spend_stone)
	s.counter_changed.connect(_hud.set_counter)
	s.line_requested.connect(_on_line)
	if s.has_signal(&"music_requested"):
		s.connect(&"music_requested", _on_music)
	s.gold_light_requested.connect(_lines.request_gold)
	_slot.add_child(s)
	s.setup(def, RunState.model, RunState.mods)
	s.wait_for_lines = true
	s.begin()
	if _stage == s and _lines.is_idle():
		s.on_lines_drained()


## Scene file of a stage: `stage-scenes/stage-<scene key>.tscn` (maze, patience and search are their own types).
static func scene_path(def: StageDef) -> String:
	return STAGE_PATH % _scene_key(def)


## Scene name for a stage: its type, except the Goliath (weak-point) and Ziklag (rescue) boss variants, which have their own classes.
static func _scene_key(def: StageDef) -> String:
	if def.type == &"boss" and def.param_string("variant") == "weak-point":
		return "goliath"
	if def.type == &"boss" and def.param_string("variant") == "rescue":
		return "ziklag"
	return str(def.type)


func clear_stage() -> void:
	# A cutscene may have slowed the clock: every way out of a stage puts it back.
	Engine.time_scale = 1.0
	_hud.set_counter(&"loaves", -1)
	_hud.set_counter(&"time", -1)
	_hud.set_counter(&"food", -1)
	_lines.clear()
	_caption.clear()
	Audio.stop_narration()
	_end_rest_state()
	cancel_hold()
	if _stage != null:
		if _stage.get_parent() != null:
			_stage.get_parent().remove_child(_stage)
		_stage.queue_free()
		_stage = null


## Drops any OK press in progress (used when the pause menu opens).
func cancel_hold() -> void:
	_holding = false
	_hold_fired = false
	_held = 0.0


func _process(delta: float) -> void:
	_lines.tick(delta)
	if not _holding or _hold_fired:
		return
	_held += delta
	if _held >= _hold_limit:
		_hold_fired = true
		if _stage != null and not _resting:
			_stage.on_action_hold()


func _input(event: InputEvent) -> void:
	if _stage == null or _resting or get_tree().paused:
		return
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		if RunState.model.mode == RunModel.Mode.LAMB:
			# Lamb: OK acts the moment it is pressed; there is no hold action.
			_stage.on_action_tap()
			return
		_holding = true
		_hold_fired = false
		_held = 0.0
		_stage.on_action_press()
	elif event.is_action_released(&"ui_accept") and _holding:
		# A long hold still counts as a tap on release, so a held press is never lost.
		cancel_hold()
		_stage.on_action_tap()


func _on_lines_drained() -> void:
	if _stage != null:
		_stage.on_lines_drained()


## The stage is over, but every requested line is shown first (queue drained, last line held).
func _on_stage_won() -> void:
	cancel_hold()
	if _stage != null and _stage.def != null and _stage.def.type != &"cutscene":
		Audio.play_sfx(&"win")
	_lines.when_drained(RunState.advance)


func _on_stage_failed(reason: StringName) -> void:
	# fail_stage restarts the chapter or stage itself (stage_changed follows) and
	# returns &"ignored" when the mode vetoes, in which case the stage keeps running.
	var outcome: StringName = RunState.fail_stage(reason)
	if outcome != &"ignored":
		cancel_hold()


func _on_line(speaker: StringName, text: String, reference: String, line_id: StringName) -> void:
	# Prompts (speaker ui) are sticky; a caption waits for its own line's turn; the rest queue.
	_lines.request(speaker, text, reference, line_id)


func _on_caption_started(text: String, reference: String, hold: float) -> void:
	_caption.show_line(text, reference, hold)


## A cutscene music cue (4.1 slow harp); an empty cue puts the main music back.
func _on_music(cue: StringName) -> void:
	Audio.play_music(Audio.MUSIC_MAIN if String(cue).is_empty() else cue)


func _on_hit_taken(_amount: int) -> void:
	Audio.play_sfx(&"hurt")


func _on_line_started(_speaker: StringName, text: String, reference: String, hold: float, sticky: bool) -> void:
	_subtitle.show_line(text, reference, hold, sticky)


func _on_spared() -> void:
	var hearts: int = int(RunState.mods.feature(&"heartOnSpare", 0))
	if hearts > 0:
		RunState.heal(hearts)


func _on_tired(seconds: float) -> void:
	_resting = true
	cancel_hold()
	if _stage != null:
		_stage.process_mode = Node.PROCESS_MODE_DISABLED
	_dim.show()
	var line: Dictionary = LineBook.pick(&"encouragement-low-hearts", _rng)
	_lines.push(&"ui", str(line.get("text", "")), str(line.get("reference", "")))
	_rest_timer.start(seconds)


func _on_rest_over() -> void:
	_end_rest_state()
	RunState.end_rest()


func _end_rest_state() -> void:
	_rest_timer.stop()
	_resting = false
	_dim.hide()
	if _stage != null:
		_stage.process_mode = Node.PROCESS_MODE_INHERIT
