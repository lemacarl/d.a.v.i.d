extends Node
## Placeholder audio: buses, volume from Settings, and play methods that do nothing
## when the asset is absent. No game rules here.

const BUS_MUSIC: StringName = &"Music"
const BUS_NARRATION: StringName = &"Narration"
const BUS_SFX: StringName = &"Sfx"
const MUSIC_DIR: String = "res://audio/music/"
const SFX_DIR: String = "res://audio/sfx/"
const NARRATION_DIR: String = "res://audio/narration/"
const DUCK_DB: float = -9.0

var current_music: StringName = &""
var _ducked: bool = false
var _music_player: AudioStreamPlayer = null
var _voice_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	for bus in [BUS_MUSIC, BUS_NARRATION, BUS_SFX]:
		_ensure_bus(bus)
	_music_player = _make_player(BUS_MUSIC)
	_voice_player = _make_player(BUS_NARRATION)
	_sfx_player = _make_player(BUS_SFX)
	var st: Node = get_node_or_null("/root/Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _apply_volumes)
	_apply_volumes()


func play_music(cue: StringName) -> void:
	current_music = cue
	var stream: AudioStream = _load_stream(MUSIC_DIR, cue)
	if stream != null and _music_player != null:
		_music_player.stream = stream
		_music_player.play()


func stop_music() -> void:
	current_music = &""
	if _music_player != null:
		_music_player.stop()


func play_sfx(cue: StringName) -> void:
	var stream: AudioStream = _load_stream(SFX_DIR, cue)
	if stream != null and _sfx_player != null:
		_sfx_player.stream = stream
		_sfx_player.play()


## Narration for a line id (bundled audio). No file means silence; subtitles still show.
func narrate(line_id: StringName) -> void:
	var stream: AudioStream = _load_stream(NARRATION_DIR, line_id)
	if stream != null and _voice_player != null:
		duck(true)
		_voice_player.stream = stream
		_voice_player.play()


func play_harp() -> void:
	play_sfx(&"harp")


## Lowers music under narration.
func duck(on: bool) -> void:
	_ducked = on
	_apply_volumes()


func _apply_volumes() -> void:
	var st: Node = get_node_or_null("/root/Settings")
	var music: float = 1.0
	var voice: float = 1.0
	if st != null:
		music = float(st.get("music_volume"))
		voice = float(st.get("narration_volume"))
	_set_bus(BUS_MUSIC, music, DUCK_DB if _ducked else 0.0)
	_set_bus(BUS_NARRATION, voice, 0.0)


func _set_bus(bus: StringName, linear: float, offset_db: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, linear <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)) + offset_db)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load_stream(dir: String, cue: StringName) -> AudioStream:
	var path: String = dir + String(cue) + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
