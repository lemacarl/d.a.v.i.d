extends Node
## Audio: buses, volume from Settings, and play methods that do nothing when an asset is
## absent. Cues are looked up by id in data/audio.json (path or paths, bus, loop); narration
## is looked up by line id under the narration folder named in the same file. No game rules here.

const BUS_MUSIC: StringName = &"Music"
const BUS_NARRATION: StringName = &"Narration"
const BUS_SFX: StringName = &"Sfx"
## Cue id of the one looping music track (data/audio.json).
const MUSIC_MAIN: StringName = &"music-main"
const AUDIO_PATH: String = "res://data/audio.json"
const SFX_VOICES: int = 4

var current_music: StringName = &""
var _ducked: bool = false
var _duck_db: float = -9.0
var _base_db: Dictionary = {}
var _cues: Dictionary = {}
var _narration: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _music_player: AudioStreamPlayer = null
var _voice_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0


func _ready() -> void:
	_read_data()
	for bus in [BUS_MUSIC, BUS_NARRATION, BUS_SFX]:
		_ensure_bus(bus)
	_music_player = _make_player(BUS_MUSIC)
	_voice_player = _make_player(BUS_NARRATION)
	_voice_player.finished.connect(_on_voice_finished)
	for i in SFX_VOICES:
		_sfx_players.append(_make_player(BUS_SFX))
	var st: Node = get_node_or_null("/root/Settings")
	if st != null and st.has_signal("changed"):
		st.connect("changed", _apply_volumes)
	_apply_volumes()


func _read_data() -> void:
	var d: Dictionary = BalanceData.read_json(AUDIO_PATH)
	_cues = BalanceData.as_dict(d.get("cues", {}))
	_narration = BalanceData.as_dict(d.get("narration", {}))
	_duck_db = float(d.get("duckDb", -9.0))
	var buses: Dictionary = BalanceData.as_dict(d.get("buses", {}))
	for b in buses:
		_base_db[StringName(str(b))] = float(BalanceData.as_dict(buses[b]).get("baseDb", 0.0))


## Resource paths of a cue (several = random variants). [] for an unknown cue.
func cue_paths(cue: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var entry: Dictionary = BalanceData.as_dict(_cues.get(String(cue), {}))
	var v: Variant = entry.get("paths", [])
	if v is Array:
		for p in (v as Array):
			out.append(str(p))
	return out


func cue_ids() -> Array:
	return _cues.keys()


## Resource path narration for a line id would load from (the file may not exist).
func narration_path(line_id: StringName) -> String:
	var dir: String = str(_narration.get("dir", "res://audio/narration/"))
	return dir + String(line_id) + "." + str(_narration.get("ext", "ogg"))


func play_music(cue: StringName) -> void:
	if cue == current_music and _music_player != null and _music_player.playing:
		return
	current_music = cue
	var stream: AudioStream = _cue_stream(cue)
	if stream != null and _music_player != null:
		_music_player.bus = _cue_bus(cue, BUS_MUSIC)
		_music_player.stream = stream
		_music_player.play()
	elif _cues.has(String(cue)) and _music_player != null:
		# A known music cue with no file yet (the 4.1 slow harp): silence, never the main theme over it.
		_music_player.stop()


func stop_music() -> void:
	current_music = &""
	if _music_player != null:
		_music_player.stop()


func play_sfx(cue: StringName) -> void:
	var stream: AudioStream = _cue_stream(cue)
	if stream == null or _sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	p.bus = _cue_bus(cue, BUS_SFX)
	p.stream = stream
	p.play()


## Narration for a line id (bundled audio). No file means silence; subtitles still show.
func narrate(line_id: StringName) -> void:
	if String(line_id).is_empty():
		return
	var path: String = narration_path(line_id)
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream != null and _voice_player != null:
		duck(true)
		_voice_player.stream = stream
		_voice_player.play()


func stop_narration() -> void:
	if _voice_player != null:
		_voice_player.stop()
	duck(false)


func play_harp() -> void:
	play_sfx(&"harp")


## Lowers music under narration.
func duck(on: bool) -> void:
	_ducked = on
	_apply_volumes()


func _on_voice_finished() -> void:
	duck(false)


func _apply_volumes() -> void:
	var st: Node = get_node_or_null("/root/Settings")
	var music: float = 1.0
	var voice: float = 1.0
	if st != null:
		music = float(st.get("music_volume"))
		voice = float(st.get("narration_volume"))
	_set_bus(BUS_MUSIC, music, float(_base_db.get(BUS_MUSIC, 0.0)) + (_duck_db if _ducked else 0.0))
	_set_bus(BUS_NARRATION, voice, float(_base_db.get(BUS_NARRATION, 0.0)))
	_set_bus(BUS_SFX, 1.0, float(_base_db.get(BUS_SFX, 0.0)))


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


func _cue_bus(cue: StringName, default: StringName) -> StringName:
	var entry: Dictionary = BalanceData.as_dict(_cues.get(String(cue), {}))
	var bus: StringName = StringName(str(entry.get("bus", default)))
	return bus if AudioServer.get_bus_index(bus) >= 0 else default


## Loads one of a cue's files (.ogg or .mp3). Null when the cue or file is missing.
func _cue_stream(cue: StringName) -> AudioStream:
	var entry: Dictionary = BalanceData.as_dict(_cues.get(String(cue), {}))
	var paths: PackedStringArray = cue_paths(cue)
	if paths.is_empty():
		return null
	var path: String = paths[_rng.randi_range(0, paths.size() - 1)]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream != null and bool(entry.get("loop", false)):
		stream.set("loop", true)
	return stream
