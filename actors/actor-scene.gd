class_name ActorScene
extends Node2D
## Base of a drawn cutscene backdrop (placeholder shapes). The cutscene stage owns one at a time,
## tells it which action a visual cue means (`play`) and feeds it time (`advance`).

const SCREEN: Vector2 = Vector2(1920, 1080)


## A visual cue's action started (see StageUtil.CUE_SCENES).
func play(_action: StringName) -> void:
	pass


func advance(_delta: float) -> void:
	pass


## Gold light on or off (God speaks).
func set_glow(_on: bool) -> void:
	pass


## The player now controls David on the field: scene people who are David leave the scene.
func begin_play() -> void:
	pass


## The lost sheep reached the flock: it stays in the scene from now on.
func sheep_returned() -> void:
	pass
