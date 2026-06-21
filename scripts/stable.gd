## stable.gd — Node2D (Stable scene root)
## Starting hub: spawns 3 random camel variants, lets player choose one,
## then triggers the run via GameManager.
extends Node2D

const CAMEL_SCRIPT = preload("res://scripts/camel.gd")

@export var camel_scene: PackedScene   # assign Camel.tscn in Inspector

# Spawn positions for 3 camels in the stable
const CAMEL_POSITIONS: Array[Vector2] = [
	Vector2(-160.0, 40.0),
	Vector2(  0.0,  40.0),
	Vector2( 160.0, 40.0),
]

@onready var start_label: Label   = $UI/StartLabel
@onready var tip_label:   Label   = $UI/TipLabel
@onready var bg:          ColorRect = $Background

var _spawned_camels: Array[Node] = []
var _selected_camel: Node = null

func _ready() -> void:
	start_label.text = "Choose your camel — approach and press [E]"
	tip_label.text   = "WASD/Joystick to move"
	_spawn_camels()

func _spawn_camels() -> void:
	if not camel_scene:
		push_error("stable.gd: camel_scene not assigned!")
		return
	for i in CAMEL_POSITIONS.size():
		var c: CharacterBody2D = camel_scene.instantiate()
		c.global_position = global_position + CAMEL_POSITIONS[i]
		# Roll a random variant
		var variant := c.roll_variant()
		c.apply_variant(variant)
		c.connect("camel_interacted", _on_camel_interacted)
		add_child(c)
		_spawned_camels.append(c)
		# Build tooltip label above each camel
		_add_camel_label(c, variant)

func _add_camel_label(camel_node: Node, variant: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = "%s\nSpd ×%.2f  [%s]" % [
		variant.get("label",   "Camel"),
		variant.get("speed_mod", 1.0),
		variant.get("rarity",  "Common")
	]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-50.0, -80.0)
	camel_node.add_child(lbl)

func _on_camel_interacted(camel_node: Node) -> void:
	if _selected_camel != null:
		return  # already chose
	_selected_camel = camel_node
	# Highlight selected
	if camel_node.has_node("Sprite2D"):
		camel_node.get_node("Sprite2D").modulate = Color(1.5, 1.5, 0.5)
	start_label.text = "Starting run with %s! Get ready..." % camel_node.variant_data.get("label", "Camel")
	tip_label.text   = "Sprint: Shift / Sprint button | Cart: collect loot | Survive!"
	# Short delay then begin
	await get_tree().create_timer(1.8).timeout
	GameManager.start_run(camel_node.variant_data)
