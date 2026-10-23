class_name Hud
extends HBoxContainer
## Hearts, stones and followers. Listens to RunState; shows icons and numbers only.

var _hearts: Array[IconShape] = []
var _hearts_row: HBoxContainer
var _stones_label: Label
var _followers_label: Label
var _stones_box: Control
var _followers_box: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 64)
	_hearts_row = HBoxContainer.new()
	_hearts_row.add_theme_constant_override("separation", 8)
	add_child(_hearts_row)
	_stones_label = _counter(IconShape.Kind.STONE)
	_stones_box = _stones_label.get_parent() as Control
	_followers_label = _counter(IconShape.Kind.FOLLOWER)
	_followers_box = _followers_label.get_parent() as Control
	RunState.hearts_changed.connect(_on_hearts)
	RunState.stones_changed.connect(_on_stones)
	RunState.followers_changed.connect(_on_followers)
	_on_hearts(RunState.model.hearts, RunState.model.hearts_max)
	_on_stones(RunState.model.stones)
	_on_followers(RunState.model.followers)


func _counter(kind: IconShape.Kind) -> Label:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(IconShape.new(kind, 56.0))
	var label: Label = Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)
	add_child(box)
	return label


func _on_hearts(hearts: int, hearts_max: int) -> void:
	while _hearts.size() < hearts_max:
		var h: IconShape = IconShape.new(IconShape.Kind.HEART, 56.0)
		_hearts.append(h)
		_hearts_row.add_child(h)
	while _hearts.size() > hearts_max:
		_hearts.pop_back().queue_free()
	for i in _hearts.size():
		_hearts[i].filled = i < hearts


func _on_stones(n: int) -> void:
	_stones_label.text = str(n)
	# Counters appear only once there is something to count (Chapter 1 has neither).
	_stones_box.visible = n > 0


func _on_followers(n: int) -> void:
	_followers_label.text = str(n)
	_followers_box.visible = n > 0
