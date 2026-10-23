extends Control
## Four chapter cards (locked ones visible, not focusable) and the Lamb / Shepherd / Normal row.

signal chapter_chosen(chapter: int)

const CHAPTER_COUNT: int = 4
const CHAPTER_PATH: String = "res://data/chapters/ch%d.json"
const CARD_SIZE: Vector2 = Vector2(400, 360)

var _cards: Array[Button] = []
var _mode_buttons: Array[Button] = []


func _ready() -> void:
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 64)
	center.add_child(box)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	box.add_child(cards)
	var first: Button = null
	for n in range(1, CHAPTER_COUNT + 1):
		var b: Button = _make_card(n)
		cards.add_child(b)
		_cards.append(b)
		if first == null and not b.disabled:
			first = b
	var modes: HBoxContainer = HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 24)
	box.add_child(modes)
	var group: ButtonGroup = ButtonGroup.new()
	for name_text in UiText.mode_names():
		var key: String = name_text.to_lower()
		var m: Button = Button.new()
		m.text = name_text
		m.toggle_mode = true
		m.button_group = group
		m.button_pressed = (key == SaveData.model.mode)
		m.custom_minimum_size = Vector2(360, 112)
		UiFocus.bind(m)
		m.pressed.connect(SaveData.set_mode.bind(key))
		modes.add_child(m)
		_mode_buttons.append(m)
	for c in _cards:
		if not c.disabled:
			c.focus_entered.connect(_on_card_focused.bind(c))
	if first != null:
		_on_card_focused(first)
		first.grab_focus()
	elif modes.get_child_count() > 0:
		(modes.get_child(0) as Control).grab_focus()


## Up from the mode row returns to the card that was focused last.
func _on_card_focused(card: Button) -> void:
	for m in _mode_buttons:
		m.focus_neighbor_top = m.get_path_to(card)


func _make_card(n: int) -> Button:
	var data: Dictionary = BalanceData.read_json(CHAPTER_PATH % n)
	var b: Button = Button.new()
	b.text = "%d\n%s" % [n, str(data.get("title", ""))]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = CARD_SIZE
	UiFocus.bind(b)
	# A chapter without data (not built yet) stays locked even when the save has it unlocked.
	if SaveData.is_unlocked(n) and not data.is_empty():
		b.pressed.connect(chapter_chosen.emit.bind(n))
	else:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	return b
