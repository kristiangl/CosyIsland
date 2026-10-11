class_name Figure
extends Node3D
## A little figure of a neighbour sitting on its stand (placeable "figure"): what a best
## friend gives you (Story `_best_friends`). Their own model, small and sat down, posed
## once and then left still.

const SCALE := 0.36
## How high the stand (Models "toy:<id>") lifts them.
const STAND := 0.05

var character := ""


func _init(character_id: String) -> void:
	character = character_id


func _ready() -> void:
	var m := NpcData.model(character)
	m.mode = "floor"
	m.position.y = STAND / SCALE
	add_child(m)
	m.animate(1.0, 0.0)
	scale = Vector3.ONE * SCALE
