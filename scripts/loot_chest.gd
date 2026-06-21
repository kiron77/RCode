## loot_chest.gd — StaticBody3D
## Gold-colored interactive chest. Player presses E to open lid and receive loot.
## Lid animates open (rotates on X axis). One-use only.
extends StaticBody3D

@export var loot_source: String = "barn"   # "barn" or "oasis"
@export var loot_count:  int    = 2

@onready var lid_pivot:      Node3D        = $LidPivot
@onready var prompt_label:   Label3D       = $PromptLabel3D
@onready var interact_area:  Area3D        = $InteractArea
@onready var open_sound:     AudioStreamPlayer3D = $OpenSound

var is_open:         bool = false
var _player_nearby:  bool = false

# Closed lid local rotation
const LID_OPEN_ANGLE := -PI * 0.55   # rotate backward 100°

func _ready() -> void:
	prompt_label.visible = false
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and not is_open and event.is_action_pressed("interact"):
		_open()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if not is_open:
			prompt_label.visible = true
			prompt_label.text    = "[E] Open Chest"

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		prompt_label.visible = false

func _open() -> void:
	is_open = true
	prompt_label.visible = false

	# Animate lid
	var tw := create_tween()
	tw.tween_property(lid_pivot, "rotation:x", LID_OPEN_ANGLE, 0.45).set_ease(Tween.EASE_OUT)

	if open_sound:
		open_sound.play()

	# Distribute loot
	var player: Node = get_tree().get_first_node_in_group("player")
	var camel:  Node = get_tree().get_first_node_in_group("camel")

	for _i in loot_count:
		var item: Dictionary = GameManager.random_barn_loot() if loot_source == "barn" else GameManager.random_oasis_loot()
		# Try cart first, fall back to direct player consume
		var added := false
		if camel and camel.has_method("add_to_cart"):
			added = camel.add_to_cart(item)
		if not added and player and player.has_method("consume_item"):
			player.consume_item(item)

	# Show "Looted!" text briefly
	prompt_label.text    = "Looted!"
	prompt_label.visible = true
	await get_tree().create_timer(2.0).timeout
	prompt_label.visible = false
