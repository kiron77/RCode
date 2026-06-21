## main.gd — Node3D (Main gameplay scene root)
## Wires all 3D systems: camel march, player mounting, world gen, UI, camera.
extends Node3D

@export var enemy_scene:  PackedScene
@export var barn_scene:   PackedScene
@export var oasis_scene:  PackedScene
@export var cactus_scene: PackedScene
@export var rock_scene:   PackedScene

@onready var player:       CharacterBody3D = $Player
@onready var camel:        CharacterBody3D = $Camel
@onready var survival_ui:  CanvasLayer     = $SurvivalUI
@onready var world_gen:    Node3D          = $WorldGenerator
@onready var enemy_cont:   Node            = $EnemyContainer
@onready var struct_cont:  Node            = $StructContainer
@onready var prop_cont:    Node            = $PropContainer
@onready var sun:          DirectionalLight3D = $Sun
@onready var camera:       Camera3D        = $CameraRig/Camera3D
@onready var camera_rig:   Node3D          = $CameraRig

# Camera follows this smoothed position (between player and camel)
var _cam_target: Vector3 = Vector3.ZERO
const CAM_OFFSET := Vector3(-10.0, 18.0, 0.0)
const CAM_SMOOTH := 7.0

func _ready() -> void:
	_apply_selected_camel()
	_wire_signals()
	_init_world_gen()
	# Start camera at camel position
	_cam_target = camel.global_position

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_run_info()

func _update_camera(delta: float) -> void:
	# Smoothly track midpoint between player and camel
	var mid := player.global_position.lerp(camel.global_position, 0.45)
	_cam_target = _cam_target.lerp(mid, CAM_SMOOTH * delta)
	camera_rig.global_position = _cam_target + CAM_OFFSET
	camera_rig.look_at(_cam_target + Vector3(5.0, 0.0, 0.0), Vector3.UP)

func _update_run_info() -> void:
	var camel_text := camel.variant_data.get("label", "Camel") if not camel.variant_data.is_empty() else "Camel"
	survival_ui.update_run_info(
		GameManager.run_distance,
		GameManager.run_kills,
		camel_text,
		camel.get_cart_weight_ratio(),
		player.is_mounted
	)

# ── Initialisation ─────────────────────────────────────────────────────────────
func _apply_selected_camel() -> void:
	var data := GameManager.selected_camel
	if data.is_empty():
		data = {"id": "brown", "color": Color(0.6, 0.4, 0.2),
				"speed_mod": 1.0, "label": "Brown Camel", "rarity": "Common"}
	camel.apply_variant(data)
	camel.is_selected = true
	# Restore saved cart from prior run (future feature hook)
	for item in GameManager.current_inventory:
		camel.add_to_cart(item)

func _wire_signals() -> void:
	# Player stats → UI
	player.connect("stats_changed", survival_ui.update_stats)
	player.connect("player_died",   _on_player_died)
	player.connect("camel_distance_danger", survival_ui.set_camel_danger)
	# Mobile input → player
	survival_ui.connect("mobile_move_changed",    func(v): player.mobile_move = v)
	survival_ui.connect("mobile_sprint_changed",  func(a): player.mobile_sprint = a)
	survival_ui.connect("mobile_attack_pressed",  func():  player.mobile_attack = true)
	survival_ui.connect("mobile_interact_pressed",_on_mobile_interact)
	survival_ui.connect("restart_requested",      _on_restart)
	# Camel inventory → UI
	camel.connect("inventory_changed", survival_ui.refresh_inventory)

func _init_world_gen() -> void:
	if world_gen:
		world_gen.enemy_scene  = enemy_scene
		world_gen.barn_scene   = barn_scene
		world_gen.oasis_scene  = oasis_scene
		world_gen.cactus_scene = cactus_scene
		world_gen.rock_scene   = rock_scene

# ── Signal handlers ────────────────────────────────────────────────────────────
func _on_player_died() -> void:
	camel.is_selected = false
	GameManager.current_inventory = camel.cart_inventory.duplicate(true)
	survival_ui.show_death_screen(GameManager.run_distance, GameManager.run_kills)

func _on_mobile_interact() -> void:
	if player.is_mounted:
		player.dismount()
	else:
		# Simulate interact action for one physics frame
		Input.action_press("interact")
		await get_tree().physics_frame
		Input.action_release("interact")

func _on_restart() -> void:
	GameManager.go_to_stable()
