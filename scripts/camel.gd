## camel.gd — CharacterBody3D
## Auto-marches in +X during a run. Player can mount it (rides on MountPoint).
## Speed driven by variant RNG + cart load weight penalty.
extends CharacterBody3D

# ── Variant definitions (probability table sums to 100) ──────────────────────
const BASE_SPEED := 5.5   # units/s

const VARIANTS: Array[Dictionary] = [
	{"id": "white",  "color": Color(0.95, 0.95, 0.90), "speed_mod": 1.30, "label": "White Camel",  "rarity": "Rare"},
	{"id": "black",  "color": Color(0.12, 0.10, 0.10), "speed_mod": 1.15, "label": "Black Camel",  "rarity": "Uncommon"},
	{"id": "brown",  "color": Color(0.60, 0.40, 0.20), "speed_mod": 1.00, "label": "Brown Camel",  "rarity": "Common"},
	{"id": "orange", "color": Color(0.90, 0.50, 0.08), "speed_mod": 0.85, "label": "Orange Camel", "rarity": "Common"},
]
const VARIANT_WEIGHTS: Array[int] = [10, 25, 50, 15]  # must sum to 100

# ── Cart weight system ────────────────────────────────────────────────────────
const MAX_CART_SLOTS       := 20
const WEIGHT_PENALTY_PER_5 := 0.10
const MIN_SPEED_RATIO      := 0.60

# ── Runtime state ─────────────────────────────────────────────────────────────
var variant_data:     Dictionary = {}
var cart_inventory:   Array      = []
var effective_speed:  float      = BASE_SPEED
var is_selected:      bool       = false  # set true when run starts
var _player_nearby:   bool       = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var body_mesh:     MeshInstance3D = $BodyMesh
@onready var head_mesh:     MeshInstance3D = $HeadMesh
@onready var neck_mesh:     MeshInstance3D = $NeckMesh
@onready var hump_mesh:     MeshInstance3D = $HumpMesh
@onready var cart_mesh:     MeshInstance3D = $CartAnchor/CartMesh
@onready var name_label:    Label3D        = $NameLabel3D
@onready var interact_area: Area3D         = $InteractArea
# MountPoint is where the player sits
# CartAnchor is the visual cart behind the camel

# ── Signals ───────────────────────────────────────────────────────────────────
signal inventory_changed(inv: Array)
signal camel_interacted(camel_node: Node)

func _ready() -> void:
	add_to_group("camel")
	if interact_area:
		interact_area.body_entered.connect(_on_interact_body_entered)
		interact_area.body_exited.connect(_on_interact_body_exited)

# ── Variant rolling ────────────────────────────────────────────────────────────
static func roll_variant() -> Dictionary:
	var roll := randi() % 100
	var cum  := 0
	for i in VARIANT_WEIGHTS.size():
		cum += VARIANT_WEIGHTS[i]
		if roll < cum:
			return VARIANTS[i].duplicate()
	return VARIANTS[2].duplicate()

func apply_variant(data: Dictionary) -> void:
	variant_data = data
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.get("color", Color(0.6, 0.4, 0.2))
	for mesh_node in [body_mesh, head_mesh, neck_mesh, hump_mesh]:
		if mesh_node:
			mesh_node.material_override = mat
	if name_label:
		name_label.text = "%s\n×%.2f [%s]" % [
			data.get("label", "Camel"),
			data.get("speed_mod", 1.0),
			data.get("rarity", "Common")
		]
	_recalculate_speed()

# ── Physics: auto-march in +X during run ──────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_selected:
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	velocity.x = effective_speed
	velocity.z = 0.0
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
	var base       := BASE_SPEED * variant_data.get("speed_mod", 1.0)
	var steps      := cart_inventory.size() / 5
	var ratio      := maxf(MIN_SPEED_RATIO, 1.0 - steps * WEIGHT_PENALTY_PER_5)
	effective_speed = base * ratio
	# Update cart color to reflect fullness (darker when heavier)
	if cart_mesh:
		var fill := float(cart_inventory.size()) / float(MAX_CART_SLOTS)
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.35 - fill * 0.1, 0.22 - fill * 0.05, 0.10, 1.0)
		cart_mesh.material_override = mat2

func get_cart_weight_ratio() -> float:
	return float(cart_inventory.size()) / float(MAX_CART_SLOTS)

# ── Interaction: stable scene mount / stable E-press ─────────────────────────
func _on_interact_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true

func _on_interact_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false

func _unhandled_input(event: InputEvent) -> void:
	# Stable scene: E selects this camel for the run
	if _player_nearby and event.is_action_pressed("interact") and not is_selected:
		emit_signal("camel_interacted", self)
