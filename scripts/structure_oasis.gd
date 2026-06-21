## structure_oasis.gd — Node2D
## Rare high-risk oasis: pure water source and valuable loot, heavily guarded.
extends Node2D

@export var guard_count:  int = 3
@export var guard_scene:  PackedScene
@export var water_amount: float = 80.0  # thirst restore from the water source

@onready var water_area:   Area2D  = $WaterArea
@onready var loot_area:    Area2D  = $LootArea
@onready var prompt_label: Label   = $PromptLabel
@onready var sprite:       Sprite2D = $Sprite2D

var _water_used:     bool = false
var _looted:         bool = false
var _player_in_water:bool = false
var _player_in_loot: bool = false

func _ready() -> void:
	prompt_label.visible = false
	water_area.connect("body_entered", _on_water_entered)
	water_area.connect("body_exited",  _on_water_exited)
	loot_area.connect("body_entered",  _on_loot_entered)
	loot_area.connect("body_exited",   _on_loot_exited)
	_spawn_guards()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if _player_in_water and not _water_used:
		_use_water_source()
	elif _player_in_loot and not _looted:
		_take_oasis_loot()

func _on_water_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_water = true
		if not _water_used:
			prompt_label.visible = true
			prompt_label.text = "[E] Drink from Oasis"

func _on_water_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_water = false
		_refresh_prompt()

func _on_loot_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_loot = true
		if not _looted:
			prompt_label.visible = true
			prompt_label.text = "[E] Search Temple"

func _on_loot_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_loot = false
		_refresh_prompt()

func _use_water_source() -> void:
	_water_used = true
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("consume_item"):
		player.consume_item({"type": "drink", "thirst_restore": water_amount})
	# Also fill water flasks in cart inventory
	var camel: Node2D = get_tree().get_first_node_in_group("camel")
	if camel and camel.has_method("add_to_cart"):
		camel.add_to_cart({"id": "oasis_water", "name": "Oasis Water", "type": "drink", "thirst_restore": 60.0, "weight": 2})
	prompt_label.text = "Oasis depleted"
	await get_tree().create_timer(2.0).timeout
	_refresh_prompt()

func _take_oasis_loot() -> void:
	_looted = true
	var item := GameManager.random_oasis_loot()
	var camel: Node2D = get_tree().get_first_node_in_group("camel")
	if camel and camel.has_method("add_to_cart"):
		camel.add_to_cart(item)
	prompt_label.text = "Temple looted!"
	await get_tree().create_timer(2.0).timeout
	_refresh_prompt()

func _refresh_prompt() -> void:
	if not _player_in_water and not _player_in_loot:
		prompt_label.visible = false
	elif _player_in_water and not _water_used:
		prompt_label.text = "[E] Drink from Oasis"
	elif _player_in_loot and not _looted:
		prompt_label.text = "[E] Search Temple"

func _spawn_guards() -> void:
	if not guard_scene:
		return
	for _i in guard_count:
		var g: Node2D = guard_scene.instantiate()
		var angle := randf() * TAU
		var radius := randf_range(80.0, 140.0)
		g.global_position = global_position + Vector2(cos(angle), sin(angle)) * radius
		get_parent().add_child(g)
