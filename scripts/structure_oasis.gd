## structure_oasis.gd — Node3D
## Rare oasis: water pool + sandstone temple ruins + palm trees.
## Built procedurally from colored boxes + cylinders. 3 guards.
extends Node3D

@export var chest_count:  int   = 3
@export var guard_count:  int   = 3
@export var water_amount: float = 80.0
@export var chest_scene:  PackedScene
@export var guard_scene:  PackedScene

# Colors
const WATER_COLOR   := Color(0.15, 0.55, 0.90, 0.85)
const TEMPLE_COLOR  := Color(0.72, 0.62, 0.45)
const PALM_TRUNK_C  := Color(0.55, 0.38, 0.18)
const PALM_LEAF_C   := Color(0.12, 0.58, 0.12)

var _water_used:    bool = false
var _water_area:    Area3D = null

func _ready() -> void:
	_build_oasis()
	_build_temple()
	_place_chests()
	_spawn_guards()
	_setup_water_interaction()

func _build_oasis() -> void:
	# Water pool — flat blue box at ground level
	var pool := _make_static_box(Vector3(0, -0.08, 0), Vector3(8.0, 0.18, 8.0), WATER_COLOR)
	add_child(pool)
	# Palm trees around the pool
	for i in 5:
		var angle := (float(i) / 5.0) * TAU + 0.3
		var r     := 6.5
		var pos   := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		_add_palm(pos)

func _build_temple() -> void:
	# Sandstone ruins offset to the +X side of the water
	var base := Vector3(12.0, 0.0, 0.0)
	var t    := 0.6
	# Outer walls (U-shape — open toward water)
	_add_ruin_wall(base + Vector3(0, 2.5, -5.0), Vector3(10.0, 5.0, t))   # back wall
	_add_ruin_wall(base + Vector3(-5.0, 2.5, 0), Vector3(t, 5.0, 10.0))  # left wall
	_add_ruin_wall(base + Vector3( 5.0, 2.5, 0), Vector3(t, 5.0, 10.0))  # right wall
	# Broken pillars
	for i in 4:
		var px := -3.5 + i * 2.3
		_add_ruin_wall(base + Vector3(px, 1.5, 4.5), Vector3(0.5, 3.0 + randf(), 0.5))
	# Floor tiles
	_add_ruin_wall(base + Vector3(0, -0.15, 0), Vector3(10.0, 0.3, 10.0))

func _add_ruin_wall(pos: Vector3, size: Vector3) -> void:
	var box := _make_static_box(pos, size, TEMPLE_COLOR)
	add_child(box)

func _add_palm(pos: Vector3) -> void:
	# Trunk
	var trunk := MeshInstance3D.new()
	var tm    := CylinderMesh.new()
	tm.top_radius    = 0.18
	tm.bottom_radius = 0.25
	tm.height        = 3.8
	trunk.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = PALM_TRUNK_C
	trunk.material_override = tmat
	trunk.position = pos + Vector3(0, 1.9, 0)
	add_child(trunk)
	# Leaf crown (flattened sphere)
	var leaves := MeshInstance3D.new()
	var sm     := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 0.9
	leaves.mesh = sm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = PALM_LEAF_C
	leaves.material_override = lmat
	leaves.position = pos + Vector3(0, 4.2, 0)
	add_child(leaves)

func _make_static_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var sb  := StaticBody3D.new()
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mi.material_override = mat
	var cs  := CollisionShape3D.new()
	var bs  := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(mi)
	sb.add_child(cs)
	sb.position = pos
	return sb

func _place_chests() -> void:
	if not chest_scene:
		return
	var base := Vector3(12.0, 0.1, 0.0)
	var offsets := [Vector3(0,0,-2), Vector3(-2,0,1), Vector3(2,0,1)]
	for i in min(chest_count, offsets.size()):
		var c: Node3D = chest_scene.instantiate()
		c.position    = base + offsets[i]
		c.loot_source = "oasis"
		add_child(c)

func _spawn_guards() -> void:
	if not guard_scene:
		return
	for i in guard_count:
		var g:    Node3D = guard_scene.instantiate()
		var angle := (float(i) / float(guard_count)) * TAU
		get_parent().add_child(g)
		g.global_position = global_position + Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 6.0)

func _setup_water_interaction() -> void:
	_water_area = Area3D.new()
	var cs  := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.0
	cyl.height = 2.0
	cs.shape = cyl
	_water_area.add_child(cs)
	_water_area.position = Vector3(0, 1.0, 0)
	_water_area.collision_mask = 1  # detect player
	_water_area.body_entered.connect(_on_water_entered)
	add_child(_water_area)

func _on_water_entered(body: Node) -> void:
	if _water_used or not body.is_in_group("player"):
		return
	# Show prompt via Label3D (simple approach)
	_water_used = true
	if body.has_method("consume_item"):
		body.consume_item({"type": "drink", "thirst_restore": water_amount})
	# Add water flask to cart
	var camel := get_tree().get_first_node_in_group("camel")
	if camel and camel.has_method("add_to_cart"):
		camel.add_to_cart({"id": "oasis_water", "name": "Oasis Water", "type": "drink", "thirst_restore": 60.0})
