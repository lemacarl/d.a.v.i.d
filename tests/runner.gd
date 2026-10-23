class_name TestRunner
extends SceneTree
## Headless runner. Discovers tests/test-*.gd; each has `func run(t: TestRunner) -> void`.
## Run: Godot --headless --path . -s res://tests/runner.gd

var passed: int = 0
var failed: int = 0
var skipped: int = 0


var _ran: bool = false


## Tests run on the first frame so the scene tree is live (tests that need real nodes, focus, etc.).
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
	return false


func _run_all() -> void:
	var names: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://tests")
	if dir != null:
		for f in dir.get_files():
			if f.begins_with("test-") and f.ends_with(".gd"):
				names.append(f)
	names.sort()
	for n in names:
		var script: GDScript = load("res://tests/" + n) as GDScript
		if script == null:
			failed += 1
			print("FAIL  cannot load ", n)
			continue
		print("== ", n)
		var inst: Object = script.new()
		inst.call("run", self)
	print("---- passed: %d  failed: %d  skipped: %d" % [passed, failed, skipped])
	quit(1 if failed > 0 else 0)


func eq(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		passed += 1
	else:
		failed += 1
		print("FAIL  ", msg, "  (got ", a, ", expected ", b, ")")


func truthy(x: Variant, msg: String) -> void:
	if x:
		passed += 1
	else:
		failed += 1
		print("FAIL  ", msg)


func falsy(x: Variant, msg: String) -> void:
	truthy(not x, msg)


func near(a: float, b: float, msg: String) -> void:
	eq(absf(a - b) < 0.0001, true, msg + " (got %s, expected %s)" % [a, b])


func skip(msg: String) -> void:
	skipped += 1
	print("SKIP  ", msg)
