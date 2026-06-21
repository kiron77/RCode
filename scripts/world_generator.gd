## world_generator.gd — Node2D
## Procedural world: scrolling desert background tiles, roadside structure
## spawning, and enemy wave management. Attached to WorldGenerator node.
extends Node2D

# ── Timing ────────────────────────────────────────────────────────────────────
const ENEMY_WAVE_INTERVAL   := 9.0    # seconds between waves
const STRUCTURE_INTERVAL    := 22.0   # seconds between structures
const BACKGROUND_TILE_WIDTH := 128.0  # px width of one desert tile
const TILES_ON_SCREEN       := 12     # how many tiles to keep visible

# ── Spawn offsets from player (right-side screen edge) ────────────────────────
const STRUCTURE_SPAWN_X_OFFSET := 750.0
const ENEMY_SPAWN_X_OFFSET     := 500.0
const STRUCTURE_Y_SPREAD       := 260.0
const ENEMY_Y_SPREAD           := 220.0

# ── Enemy density ramp (scales with distance) ─────────────────────────────────
const ENEMY_COUNT_MIN := 1
const ENEMY_COUNT_MAX := 4
const RAMP_DISTANCE   := 2000.0  # after this distance, spawn max enemies

# ── Scenes ────────────────────────────────────────────────────────────────────
@export var enemy_scene:    PackedScene
@export var barn_scene:     PackedScene
@export var oasis_scene:    PackedScene

# ── Runtime ───────────────────────────────────────────────────────────────────
var _enemy_timer:     float = ENEMY_WAVE_INTERVAL * 0.5  # first wave sooner
var _structure_timer: float = STRUCTURE_INTERVAL  * 0.4
var _bg_tiles:        Array = []
var _player:          Node2D = null
var _enemy_container: Node = null
var _struct_container: Node = null

func _ready() -> void:
	_player          = get_tree().get_first_node_in_group("player")
	_enemy_container  = get_node_or_null("EnemyContainer")  or get_parent().get_node_or_null("EnemyContainer")
	_struct_container = get_node_or_null("StructContainer") or get_parent().get_node_or_null("StructContainer")
	_init_background_tiles()

func _physics_process(delta: float) -> void:
	if not _player:
		return
	_scroll_tiles()
	_enemy_timer -= delta
	_structure_timer -= delta

	if _enemy_timer <= 0.0:
		_enemy_timer = ENEMY_WAVE_INTERVAL
		_spawn_enemy_wave()

	if _structure_timer <= 0.0:
		_structure_timer = STRUCTURE_INTERVAL
		_spawn_structure()

# ── Endless desert background ─────────────────────────────────────────────────
func _init_background_tiles() -> void:
	for i in TILES_ON_SCREEN:
		var tile := ColorRect.new()
		tile.size = Vector2(BACKGROUND_TILE_WIDTH, 800.0)
		tile.position = Vector2(i * BACKGROUND_TILE_WIDTH - 256.0, -400.0)
		# Alternate sand shades for visual interest
		tile.color = Color(0.85 + (i % 2) * 0.05, 0.72 + (i % 3) * 0.02, 0.42, 1.0)
		add_child(tile)
		_bg_tiles.append(tile)

func _scroll_tiles() -> void:
	if not _player:
		return
	var cam_x := _player.global_position.x
	for tile: ColorRect in _bg_tiles:
		# Wrap tiles to the right when they scroll off screen left
		if tile.global_position.x + BACKGROUND_TILE_WIDTH < cam_x - 640.0:
			tile.global_position.x += BACKGROUND_TILE_WIDTH * TILES_ON_SCREEN

# ── Enemy spawning ─────────────────────────────────────────────────────────────
func _spawn_enemy_wave() -> void:
	if not _player or not enemy_scene:
		return
	var t := clampf(GameManager.run_distance / RAMP_DISTANCE, 0.0, 1.0)
	var count := int(lerp(float(ENEMY_COUNT_MIN), float(ENEMY_COUNT_MAX), t))
	var container := _enemy_container if _enemy_container else self
	for _i in count:
		var e: Node2D = enemy_scene.instantiate()
		var side := 1.0 if randf() > 0.5 else -1.0
		e.global_position = Vector2(
			_player.global_position.x + ENEMY_SPAWN_X_OFFSET + randf_range(0.0, 200.0),
			_player.global_position.y + side * randf_range(40.0, ENEMY_Y_SPREAD)
		)
		container.add_child(e)

# ── Structure spawning ─────────────────────────────────────────────────────────
func _spawn_structure() -> void:
	if not _player:
		return
	var is_oasis := randf() < 0.18  # 18 % chance for rare oasis
	var scene := oasis_scene if (is_oasis and oasis_scene) else barn_scene
	if not scene:
		return
	var container := _struct_container if _struct_container else self
	var structure: Node2D = scene.instantiate()
	var side := 1.0 if randf() > 0.5 else -1.0
	structure.global_position = Vector2(
		_player.global_position.x + STRUCTURE_SPAWN_X_OFFSET,
		_player.global_position.y + side * randf_range(120.0, STRUCTURE_Y_SPREAD)
	)
	container.add_child(structure)

# ── Cleanup off-screen nodes (memory management) ──────────────────────────────
func cull_offscreen(container: Node, margin: float = 800.0) -> void:
	if not _player:
		return
	var cam_left := _player.global_position.x - margin
	for child in container.get_children():
		if child is Node2D and child.global_position.x < cam_left:
			child.queue_free()
