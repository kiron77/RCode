## main.gd — Node2D (Main gameplay scene root)
## Orchestrates: camel movement, world generation, UI wiring, player death/restart.
extends Node2D

# ── Scene references (assign in Inspector or auto-found via groups) ─────────
@export var enemy_scene:    PackedScene
@export var barn_scene:     PackedScene
@export var oasis_scene:    PackedScene

# ── Node paths (must match scene tree) ───────────────────────────────────────
@onready var player:          CharacterBody2D = $Player
@onready var camel:           CharacterBody2D = $Camel
@onready var camera:          Camera2D        = $Player/Camera2D
@onready var survival_ui:     CanvasLayer     = $SurvivalUI
@onready var world_gen:       Node2D          = $WorldGenerator
@onready var enemy_container: Node            = $EnemyContainer
@onready var struct_container:Node            = $StructContainer

# ── Camel follow offset (player trails camel) ────────────────────────────────
const PLAYER_CAMEL_LEASH := 300.0   # max distance before camera re-centres
const CAMEL_PLAYER_OFFSET := Vector2(-120.0, 0.0)  # player starts left of camel

func _ready() -> void:
	_apply_selected_camel()
	_wire_ui_signals()
	_wire_player_signals()
	_init_world_gen()
	# Position player near camel
	player.global_position = camel.global_position + CAMEL_PLAYER_OFFSET

func _physics_process(delta: float) -> void:
	_update_run_info()
	_cull_offscreen_nodes()

# ── Initialisation helpers ────────────────────────────────────────────────────
func _apply_selected_camel() -> void:
	var data := GameManager.selected_camel
	if data.is_empty():
		# Fallback: brown camel for direct scene testing
		data = {"id": "brown", "color": Color(0.6, 0.4, 0.2), "speed_mod": 1.0, "label": "Brown Camel", "rarity": "Common"}
	camel.apply_variant(data)
	camel.is_selected = true
	# Restore any inventory from GameManager (e.g. future run-carry feature)
	for item in GameManager.current_inventory:
		camel.add_to_cart(item)

func _wire_ui_signals() -> void:
	# SurvivalUI → Player
	survival_ui.connect("mobile_move_changed",   _on_mobile_move)
	survival_ui.connect("mobile_sprint_changed",  _on_mobile_sprint)
	survival_ui.connect("mobile_attack_pressed",  _on_mobile_attack)
	survival_ui.connect("mobile_interact_pressed",_on_mobile_interact)
	survival_ui.connect("restart_requested",      _on_restart_requested)
	# Camel → UI inventory refresh
	camel.connect("inventory_changed", survival_ui.refresh_inventory)

func _wire_player_signals() -> void:
	player.connect("stats_changed", _on_player_stats_changed)
	player.connect("player_died",   _on_player_died)

func _init_world_gen() -> void:
	if world_gen:
		if enemy_scene:   world_gen.enemy_scene  = enemy_scene
		if barn_scene:    world_gen.barn_scene   = barn_scene
		if oasis_scene:   world_gen.oasis_scene  = oasis_scene

# ── Per-frame HUD update ──────────────────────────────────────────────────────
func _update_run_info() -> void:
	var camel_lbl: String = camel.variant_data.get("label", "Camel") if not camel.variant_data.is_empty() else "Camel"
	survival_ui.update_run_info(
		GameManager.run_distance,
		GameManager.run_kills,
		camel_lbl,
		camel.get_cart_weight_ratio()
	)

# ── Offscreen culling (keeps memory lean on long runs) ────────────────────────
var _cull_timer: float = 0.0
const CULL_INTERVAL := 5.0

func _cull_offscreen_nodes() -> void:
	_cull_timer += get_physics_process_delta_time()
	if _cull_timer < CULL_INTERVAL:
		return
	_cull_timer = 0.0
	if world_gen:
		world_gen.cull_offscreen(enemy_container,  900.0)
		world_gen.cull_offscreen(struct_container, 1000.0)

# ── Signal handlers: mobile input ─────────────────────────────────────────────
func _on_mobile_move(vec: Vector2) -> void:
	player.mobile_move = vec

func _on_mobile_sprint(active: bool) -> void:
	player.mobile_sprint = active

func _on_mobile_attack() -> void:
	player.mobile_attack = true

func _on_mobile_interact() -> void:
	# Simulate 'interact' action press for one frame
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")

# ── Signal handlers: player stats ─────────────────────────────────────────────
func _on_player_stats_changed(hp: float, hunger: float, thirst: float, stamina: float) -> void:
	survival_ui.update_stats(hp, hunger, thirst, stamina)

func _on_player_died() -> void:
	camel.is_selected = false  # stop camel march
	GameManager.current_inventory = camel.cart_inventory.duplicate(true)
	survival_ui.show_death_screen(GameManager.run_distance, GameManager.run_kills)

func _on_restart_requested() -> void:
	GameManager.go_to_stable()
