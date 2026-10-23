extends Node
## Volume, subtitle size, narration on/off. Persisted through SaveData. Mode is not a setting.

signal changed

var music_volume: float = 1.0
var narration_volume: float = 1.0
var subtitle_scale: float = 1.0


func _ready() -> void:
	var sd: Node = get_node_or_null("/root/SaveData")
	if sd != null:
		var m: SaveModel = sd.get("model") as SaveModel
		if m != null:
			music_volume = float(m.settings["music_volume"])
			narration_volume = float(m.settings["narration_volume"])
			subtitle_scale = float(m.settings["subtitle_scale"])
	changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_commit()


func set_narration_volume(v: float) -> void:
	narration_volume = clampf(v, 0.0, 1.0)
	_commit()


func set_narration_enabled(on: bool) -> void:
	narration_volume = 1.0 if on else 0.0
	_commit()


func narration_enabled() -> bool:
	return narration_volume > 0.0


## Subtitle multiplier, floor 1.0.
func set_subtitle_scale(v: float) -> void:
	subtitle_scale = clampf(v, 1.0, SaveModel.SUBTITLE_SCALE_MAX)
	_commit()


func _commit() -> void:
	var sd: Node = get_node_or_null("/root/SaveData")
	if sd != null:
		var m: SaveModel = sd.get("model") as SaveModel
		if m != null:
			m.settings["music_volume"] = music_volume
			m.settings["narration_volume"] = narration_volume
			m.settings["subtitle_scale"] = subtitle_scale
		sd.call("save")
	changed.emit()
