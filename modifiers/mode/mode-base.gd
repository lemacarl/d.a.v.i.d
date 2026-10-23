class_name ModeBase
extends Modifier
## Data-driven mode behaviour. Reads data/balance.json "modes". Booleans are 1.0 / 0.0.

var _s: Dictionary = {}


func _init(mode_key: String = "normal") -> void:
	id = StringName("mode-" + mode_key)
	_s = BalanceData.mode_settings(mode_key)


func apply(key: StringName, value: float, _ctx: Variant = null) -> float:
	match key:
		&"enemy-speed":
			return value * float(_s.get("enemySpeedMult", 1.0))
		&"sheep-wander":
			return value * float(_s.get("sheepWanderMult", 1.0))
		&"enemy-spawn-enabled":
			return value if bool(_s.get("enemiesEnabled", true)) else 0.0
		&"timer-enabled":
			return value if bool(_s.get("timeLimitEnabled", true)) else 0.0
		&"stones-refill":
			return 1.0 if bool(_s.get("stonesRefill", false)) else value
		&"rest-time":
			return float(_s.get("tiredRestSec", value))
	return value


func allows(event: StringName, _ctx: Variant = null) -> bool:
	match event:
		&"david-fall":
			return bool(_s.get("canFall", true))
		&"stage-fail", &"timeout-fail":
			return bool(_s.get("loseEnabled", true))
		&"enemy-spawn":
			return bool(_s.get("enemiesEnabled", true))
	return true
