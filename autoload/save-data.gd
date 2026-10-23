extends Node
## Loads and saves SaveModel at user://save.json. Atomic write; a corrupt file is kept as save.json.bad.
## No gameplay decisions. Never writes to res://.

signal saved

const SAVE_PATH: String = "user://save.json"

var save_path: String = SAVE_PATH
var model: SaveModel = SaveModel.new()


func _ready() -> void:
	load_save()
	var rs: Node = get_node_or_null("/root/RunState")
	if rs != null and rs.has_signal("chapter_completed"):
		rs.connect("chapter_completed", _on_chapter_completed)


func load_save() -> void:
	model = SaveModel.new()
	if not FileAccess.file_exists(save_path):
		return
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	if SaveModel.validate(parsed):
		model = SaveModel.from_dict(parsed as Dictionary)
	else:
		DirAccess.rename_absolute(save_path, save_path + ".bad")


## Writes save.json.tmp then renames it over save.json. Returns false on failure.
func save() -> bool:
	var tmp: String = save_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(model.to_dict()))
	f.close()
	var err: Error = DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		DirAccess.remove_absolute(save_path)
		err = DirAccess.rename_absolute(tmp, save_path)
	if err == OK:
		saved.emit()
	return err == OK


func is_unlocked(chapter: int) -> bool:
	return model.is_unlocked(chapter)


## Unlocks chapter completed+1 (Lamb honors balance.json profile flag) and saves.
func unlock_after(completed: int, mode_key: String = "normal") -> void:
	if model.unlock_after(completed, mode_key, BalanceData.lamb_completion_unlocks()):
		save()


func set_mode(mode_key: String) -> void:
	if SaveModel.MODES.has(mode_key) and model.mode != mode_key:
		model.mode = mode_key
		save()


func _on_chapter_completed(chapter: int) -> void:
	var rs: Node = get_node_or_null("/root/RunState")
	var key: String = "normal"
	if rs != null:
		key = RunModel.mode_key((rs.get("model") as RunModel).mode)
	unlock_after(chapter, key)
