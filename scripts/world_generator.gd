## world_generator.gd — Node3D
## Scrolling desert with procedural structure + enemy spawning.
## Scatters cacti (green) and rocks (grey) as environmental props.
extends Node3D

# ── Timing ─────────────────────────────────────────────────────────────────────
const ENEMY_INTERVAL     := 10.0
const STRUCTURE_INTERVAL := 24.0
const PROP_INTERVAL      := 3.5
const CULL_INTERVAL      := 6.0

# ── Spawn parameters ───────────────────────────────────────────────────────────
const STRUCT_SPAWN_AHEAD  := 55.0   # units ahead of player
const ENEMY_SPAWN_AHEAD   := 40.0
const LATERAL_SPREAD      := 18.0   # ±Z spread for structures
const ENEMY_LATERAL       := 14.0
const PROP_AHEAD          := 30.0
const PROP_LATERAL        := 20.0
const CULL_BEHIND         := 80.0

# ── Difficulty ramp ────────────────────────────────────────────────────────────
const MIN_ENEMIES := 1
const MAX_ENEMIES := 5
const RAMP_AT     := 2500.0   # units until max difficulty

# ── Scene references (assigned by Main.tscn or main.gd) ─────────────────────
@export var enemy_scene:   PackedScene
@export var barn_scene:    PackedScene
@export var oasis_scene:   PackedScene
@export var cactus_scene:  PackedScene
@export var rock_scene:    PackedScene

# ── Internal ───────────────────────────────────────────────────────────────────
var _enemy_t:    float = ENEMY_INTERVAL * 0.4
var _struct_t:   float = STRUCTURE_INTERVAL * 0.5
var _prop_t:     float = 0.5
var _cull_t:     float = 0.0
var _player:     Node3D = null
var _enemy_cont: Node   = null
var _struct_cont:Node   = null
var _prop_cont:  Node   = null

# ── Endless ground tiles ───────────────────────────────────────────────────────
const TILE_W    := 40.0
const TILE_D    := 60.0
const TILE_COUNT := 8
const GROUND_COLOR := Color(0.82, 0.70, 0.42)   # sand
var _ground_tiles: Array[MeshInstance3D] = []

func _ready() -> void:
	_player     = get_tree().get_first_node_in_group("player")
	_enemy_cont = get_node_or_null("../EnemyContainer")
	_struct_cont= get_node_or_null("../StructContainer")
	_prop_cont  = get_node_or_null("../PropContainer")
	_init_ground()

func _physics_process(delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return
	_scroll_ground()
	_enemy_t  -= delta
	_struct_t -= delta
	_prop_t   -= delta
	_cull_t   -= delta
	if _enemy_t  <= 0.0: _enemy_t  = ENEMY_INTERVAL;     _spawn_enemies()
	if _struct_t <= 0.0: _struct_t = STRUCTURE_INTERVAL;  _spawn_structure()
	if _prop_t   <= 0.0: _prop_t   = PROP_INTERVAL;       _spawn_prop()
	if _cull_t   <= 0.0: _cull_t   = CULL_INTERVAL;       _cull_all()

# ── Endless scrolling ground (X-axis wrap) ─────────────────────────────────────
func _init_ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	for i in TILE_COUNT:
		var mi  := MeshInstance3D.new()
		var bm  := BoxMesh.new()
		bm.size  = Vector3(TILE_W, 0.3, TILE_D)
		mi.mesh  = bm
		mi.material_override = mat
		mi.position = Vector3(i * TILE_W - TILE_W * 2, -0.15, 0.0)
		add_child(mi)
		_ground_tiles.append(mi)

func _scroll_ground() -> void:
	var px := _player.global_position.x
	for tile in _ground_tiles:
		if tile.global_position.x + TILE_W < px - TILE_W:
			tile.global_position.x += TILE_W * TILE_COUNT

# ── Enemy spawning ─────────────────────────────────────────────────────────────
func _spawn_enemies() -> void:
	if not enemy_scene or not _player:
		return
	var t   := clampf(GameManager.run_distance / RAMP_AT, 0.0, 1.0)
	var cnt := int(lerp(float(MIN_ENEMIES), float(MAX_ENEMIES), t))
	var c   := _enemy_cont if _enemy_cont else self
	for _i in cnt:
		var e: Node3D = enemy_scene.instantiate()
		e.global_position = Vector3(
			_player.global_position.x + ENEMY_SPAWN_AHEAD + randf_range(0.0, 12.0),
			0.0,
			_player.global_position.z + randf_range(-ENEMY_LATERAL, ENEMY_LATERAL)
		)
		c.add_child(e)

# ── Structure spawning ─────────────────────────────────────────────────────────
func _spawn_structure() -> void:
	if not _player:
		return
	var is_oasis := randf() < 0.18 and oasis_scene != null
	var scene    := oasis_scene if is_oasis else barn_scene
	if not scene:
		return
	var side := 1.0 if randf() > 0.5 else -1.0
	var s: Node3D = scene.instantiate()
	s.global_position = Vector3(
		_player.global_position.x + STRUCT_SPAWN_AHEAD,
		0.0,
		_player.global_position.z + side * randf_range(10.0, LATERAL_SPREAD)
	)
	var c := _struct_cont if _struct_cont else self
	c.add_child(s)

# ── Prop scatter: cacti + rocks ────────────────────────────────────────────────
func _spawn_prop() -> void:
	if not _player:
		return
	var pc := _prop_cont if _prop_cont else self
	var count := randi_range(1, 3)
	for _i in count:
		var is_cactus := randf() < 0.55  # slightly more cacti than rocks
		var scene := cactus_scene if is_cactus else rock_scene
		if not scene:
			continue
		var side := 1.0 if randf() > 0.5 else -1.0
		var p: Node3D = scene.instantiate()
		p.global_position = Vector3(
			_player.global_position.x + randf_range(8.0, PROP_AHEAD),
			0.0,
			_player.global_position.z + side * randf_range(5.0, PROP_LATERAL)
		)
		# Random scale variation
		var s := randf_range(0.7, 1.4)
		p.scale = Vector3(s, s, s)
		pc.add_child(p)

# ── Off-screen culling ─────────────────────────────────────────────────────────
func _cull_all() -> void:
	if not _player:
		return
	for cont in [_enemy_cont, _struct_cont, _prop_cont]:
		if cont:
			_cull_container(cont, CULL_BEHIND)

func _cull_container(container: Node, margin: float) -> void:
	var behind_x := _player.global_position.x - margin
	for child in container.get_children():
		if child is Node3D and child.global_position.x < behind_x:
			child.queue_free()
