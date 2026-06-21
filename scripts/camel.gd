## camel.gd — CharacterBody2D
## Represents one rideable camel entity.
## Auto-marches rightward during a run; speed is modulated by variant and load.
extends CharacterBody2D

# ── Variant definitions ──────────────────────────────────────────────────────
const BASE_CAMEL_SPEED := 130.0

const VARIANTS: Array[Dictionary] = [
	{"id": "white",  "color": Color(1.00, 1.00, 0.95), "speed_mod": 1.30, "label": "White Camel",  "rarity": "Rare"},
	{"id": "black",  "color": Color(0.12, 0.10, 0.10), "speed_mod": 1.15, "label": "Black Camel",  "rarity": "Uncommon"},
	{"id": "brown",  "color": Color(0.60, 0.40, 0.20), "speed_mod": 1.00, "label": "Brown Camel",  "rarity": "Common"},
	{"id": "orange", "color": Color(0.90, 0.50, 0.08), "speed_mod": 0.85, "label": "Orange Camel", "rarity": "Common"},
]
# Cumulative probability table (must sum to 100)
const VARIANT_WEIGHTS: Array[int] = [10, 25, 50, 15]

# ── Cart weight system ───────────────────────────────────────────────────────
const MAX_CART_SLOTS     := 20
const WEIGHT_PENALTY_PER_5 := 0.10  # -10 % per 5 items
const MIN_SPEED_RATIO    := 0.60    # floor at 60 % of base variant speed

# ── Instance data ─────────────────────────────────────────────────────────────
var variant_data: Dictionary = {}
var cart_inventory: Array = []
var effective_speed: float = BASE_CAMEL_SPEED
var is_selected: bool = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var label_3d: Label = $NameLabel        # optional UI label above camel
@onready var interact_area: Area2D = $InteractArea

# ── Signals ───────────────────────────────────────────────────────────────────
signal camel_interacted(camel_node)
signal inventory_changed(inventory_array)

func _ready() -> void:
	add_to_group("camel")
	if interact_area:
		interact_area.connect("body_entered", _on_body_entered_interact)
		interact_area.connect("body_exited",  _on_body_exited_interact)

# ── Static factory: generate a random variant ─────────────────────────────────
static func roll_variant() -> Dictionary:
	var roll := randi() % 100
	var cumulative := 0
	for i in VARIANT_WEIGHTS.size():
		cumulative += VARIANT_WEIGHTS[i]
		if roll < cumulative:
			return VARIANTS[i].duplicate()
	return VARIANTS[2].duplicate()  # fallback: brown

func apply_variant(data: Dictionary) -> void:
	variant_data = data
	if sprite:
		sprite.modulate = data.get("color", Color.WHITE)
	if label_3d:
		label_3d.text = data.get("label", "Camel")
	_recalculate_speed()

# ── Physics: auto-march rightward during a run ──────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_selected:
		return
	velocity.x = effective_speed
	velocity.y = 0.0
	move_and_slide()
	GameManager.run_distance += effective_speed * delta

# ── Cart inventory ────────────────────────────────────────────────────────────
func add_to_cart(item: Dictionary) -> bool:
	if cart_inventory.size() >= MAX_CART_SLOTS:
		return false
	cart_inventory.append(item)
	_recalculate_speed()
	emit_signal("inventory_changed", cart_inventory)
	return true

func remove_from_cart(index: int) -> Dictionary:
	if index < 0 or index >= cart_inventory.size():
		return {}
	var item: Dictionary = cart_inventory[index]
	cart_inventory.remove_at(index)
	_recalculate_speed()
	emit_signal("inventory_changed", cart_inventory)
	return item

func _recalculate_speed() -> void:
	if variant_data.is_empty():
		return
	var base := BASE_CAMEL_SPEED * variant_data.get("speed_mod", 1.0)
	var slots := cart_inventory.size()
	var penalty_steps := slots / 5              # integer division: 0–4
	var ratio := 1.0 - (penalty_steps * WEIGHT_PENALTY_PER_5)
	ratio = maxf(MIN_SPEED_RATIO, ratio)
	effective_speed = base * ratio

func get_cart_weight_ratio() -> float:
	return float(cart_inventory.size()) / float(MAX_CART_SLOTS)

# ── Interaction (Stable scene) ────────────────────────────────────────────────
var _player_nearby: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		emit_signal("camel_interacted", self)

func _on_body_entered_interact(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true

func _on_body_exited_interact(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
