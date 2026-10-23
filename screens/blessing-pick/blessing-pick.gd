extends Control
## Between stages: the stage-cleared line and three Blessing cards. Left/right and OK.

signal blessing_chosen(id: StringName)

## Set by the caller before adding to the tree: Array of card dictionaries.
var options: Array = []


func _ready() -> void:
	var safe: SafeArea = SafeArea.new()
	add_child(safe)
	var center: CenterContainer = CenterContainer.new()
	safe.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 48)
	center.add_child(box)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var line: Dictionary = LineBook.pick(&"stage-cleared", rng)
	var prompt: Label = Label.new()
	prompt.text = str(line.get("text", ""))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)
	var first: BlessingCard = null
	for c in options:
		var card: BlessingCard = BlessingCard.new()
		card.setup(c as Dictionary)
		card.pressed.connect(_on_pick.bind(card))
		row.add_child(card)
		if first == null:
			first = card
	if first != null:
		first.grab_focus()


func _on_pick(card: BlessingCard) -> void:
	blessing_chosen.emit(card.card_id)
