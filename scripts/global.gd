## global.gd - Autoloaded GameManager singleton
## Persists run state across scene transitions and acts as central event bus.
extends Node

# ── Camel run data ──────────────────────────────────────────────────────────
var selected_camel: Dictionary = {}
var run_distance: float = 0.0
var run_kills: int = 0
var current_inventory: Array = []

# ── Scene routing ────────────────────────────────────────────────────────────
enum GameScene { STABLE, RUNNING, DEATH, VICTORY }
var current_scene: GameScene = GameScene.STABLE

# ── Signals (cross-scene event bus) ─────────────────────────────────────────
signal game_scene_changed(scene)
signal run_started(camel_data)
signal player_died_signal
signal enemy_killed(position)

# ── Loot tables ─────────────────────────────────────────────────────────────
const BARN_LOOT_TABLE: Array[Dictionary] = [
	{"id": "canned_ration",  "name": "Canned Ration",  "type": "food",   "hunger_restore": 35.0, "weight": 1},
	{"id": "dates",          "name": "Dates",          "type": "food",   "hunger_restore": 15.0, "weight": 1},
	{"id": "scrap_metal",    "name": "Scrap Metal",    "type": "scrap",  "hunger_restore": 0.0,  "weight": 2},
	{"id": "bandage",        "name": "Bandage",        "type": "medkit", "hp_restore": 25.0,     "weight": 1},
	{"id": "rope",           "name": "Rope",           "type": "scrap",  "hunger_restore": 0.0,  "weight": 1},
]
const OASIS_LOOT_TABLE: Array[Dictionary] = [
	{"id": "oasis_water",   "name": "Oasis Water",   "type": "drink", "thirst_restore": 60.0, "weight": 2},
	{"id": "cactus_water",  "name": "Cactus Water",  "type": "drink", "thirst_restore": 30.0, "weight": 1},
	{"id": "gold_idol",     "name": "Gold Idol",     "type": "loot",  "hunger_restore": 0.0,  "weight": 3},
]

func start_run(camel_data: Dictionary) -> void:
	selected_camel = camel_data.duplicate(true)
	current_inventory.clear()
	run_distance = 0.0
	run_kills = 0
	current_scene = GameScene.RUNNING
	emit_signal("run_started", selected_camel)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func go_to_stable() -> void:
	selected_camel = {}
	current_inventory.clear()
	current_scene = GameScene.STABLE
	get_tree().change_scene_to_file("res://scenes/Stable.tscn")

func random_barn_loot() -> Dictionary:
	return BARN_LOOT_TABLE[randi() % BARN_LOOT_TABLE.size()].duplicate()

func random_oasis_loot() -> Dictionary:
	return OASIS_LOOT_TABLE[randi() % OASIS_LOOT_TABLE.size()].duplicate()
