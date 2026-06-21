## structure_barn.gd — Node3D
## Procedurally builds an abandoned barn from colored boxes in _ready().
## Layout: 4 walls + roof + floor + 1-3 gold loot chests inside.
## Spawns 1 enemy guard outside.
extends Node3D

@export var chest_count: int = 2
@export var guard_count: int = 1
@export var chest_scene: PackedScene
@export var guard_scene: PackedScene

# Colors
const WALL_COLOR  := Color(0.48, 0.30, 0.14)  # dark wood brown
const ROOF_COLOR  := Color(0.30, 0.18, 0.08)  # darker brown
const FLOOR_COLOR := Color(0.62, 0.52, 0.38)  # dusty wood

func _ready() -> void:
	_build_barn()
	_place_chests()
	_spawn_guards()

func _build_barn() -> void:
	# Barn dimensions: 8×5×6 (W×H×D in XYZ)
	var w := 8.0; var h := 5.0; var d := 6.0; var t := 0.4  # wall thickness

	# Floor
	_add_box(Vector3(0, -t * 0.5, 0), Vector3(w, t, d), FLOOR_COLOR)
	# North wall
	_add_box(Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, t), WALL_COLOR)
	# South wall (open gap in middle for doorway)
	_add_box(Vector3(-w * 0.25, h * 0.5,  d * 0.5), Vector3(w * 0.35, h, t), WALL_COLOR)
	_add_box(Vector3( w * 0.25, h * 0.5,  d * 0.5), Vector3(w * 0.35, h, t), WALL_COLOR)
	_add_box(Vector3(0, h - 0.8,           d * 0.5), Vector3(w * 0.28, 1.6, t), WALL_COLOR)  # transom
	# West wall
	_add_box(Vector3(-w * 0.5, h * 0.5, 0), Vector3(t, h, d), WALL_COLOR)
	# East wall
	_add_box(Vector3( w * 0.5, h * 0.5, 0), Vector3(t, h, d), WALL_COLOR)
	# Roof (wider to overhang)
	_add_box(Vector3(0, h + 0.4, 0), Vector3(w + 1.0, 0.5, d + 1.0), ROOF_COLOR)
	# Roof ridge
	_add_box(Vector3(0, h + 1.0, 0), Vector3(0.6, 1.2, d + 1.2), ROOF_COLOR)

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(mi)
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)

func _place_chests() -> void:
	if not chest_scene:
		return
	var positions := [Vector3(-2.0, 0.0, -1.5), Vector3(2.0, 0.0, -1.5), Vector3(0.0, 0.0, -1.5)]
	for i in min(chest_count, positions.size()):
		var c: Node3D = chest_scene.instantiate()
		c.position = positions[i]
		c.loot_source = "barn"
		add_child(c)

func _spawn_guards() -> void:
	if not guard_scene:
		return
	for i in guard_count:
		var g: Node3D = guard_scene.instantiate()
		var angle := (float(i) / float(guard_count)) * TAU
		g.position = Vector3(cos(angle) * 7.0, 0.0, sin(angle) * 5.0)
		get_parent().add_child(g)
		g.global_position = global_position + g.position
