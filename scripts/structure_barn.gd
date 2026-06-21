## structure_barn.gd — Node2D
## Abandoned barn/house: contains loot crates the player can interact with.
## Occasionally spawns 1-2 guarding enemies.
extends Node2D

@export var loot_count: int = 3
@export var guard_count: int = 1
@export var guard_scene: PackedScene

@onready var loot_area:    Area2D  = $LootArea
@onready var prompt_label: Label   = $PromptLabel
@onready var sprite:       Sprite2D = $Sprite2D

var _looted: bool = false
var _player_inside: bool = false
var _loot_remaining: int = 0

func _ready() -> void:
	_loot_remaining = loot_count
	prompt_label.visible = false
	loot_area.connect("body_entered", _on_player_entered)
	loot_area.connect("body_exited",  _on_player_exited)
	_spawn_guards()

func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and not _looted and event.is_action_pressed("interact"):
		_give_loot()

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if not _looted:
			prompt_label.visible = true
			prompt_label.text = "[E] Search Barn (%d items)" % _loot_remaining

func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		prompt_label.visible = false

func _give_loot() -> void:
	var item := GameManager.random_barn_loot()
	var camel := get_tree().get_first_node_in_group("camel")
	if camel and camel.has_method("add_to_cart"):
		if camel.add_to_cart(item):
			_loot_remaining -= 1
			prompt_label.text = "[E] Search Barn (%d items)" % _loot_remaining
			if _loot_remaining <= 0:
				_looted = true
				prompt_label.text = "Empty"
				await get_tree().create_timer(1.5).timeout
				prompt_label.visible = false
		else:
			prompt_label.text = "Cart full!"
	else:
		# Drop loot for player to manually consume
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("consume_item"):
			player.consume_item(item)

func _spawn_guards() -> void:
	if not guard_scene:
		return
	for _i in guard_count:
		var g: Node2D = guard_scene.instantiate()
		g.global_position = global_position + Vector2(randf_range(-60.0, 60.0), randf_range(-40.0, 40.0))
		get_parent().add_child(g)
