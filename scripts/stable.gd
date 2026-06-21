## stable.gd — Node3D (Stable scene root)
## Builds a 3D stable from colored boxes, spawns 3 random-variant camels.
## Player walks up and presses E to select a camel → run begins.
extends Node3D

@export var camel_scene: PackedScene
@export var player_scene: PackedScene

# Camel spawn positions in local space
const CAMEL_SPOTS: Array[Vector3] = [
	Vector3(-5.0, 0.0, 0.0),
	Vector3( 0.0, 0.0, 0.0),
	Vector3( 5.0, 0.0, 0.0),
]

# Colors
const STABLE_WALL  := Color(0.45, 0.30, 0.15)
const STABLE_FLOOR := Color(0.58, 0.46, 0.30)
const STABLE_ROOF  := Color(0.30, 0.18, 0.08)

var _spawned_camels: Array  = []
var _selected:       bool   = false

@onready var start_label: Label = $UI/StartLabel
@onready var tip_label:   Label = $UI/TipLabel

func _ready() -> void:
	_build_stable()
	_spawn_camels()

# ── Build stable geometry ──────────────────────────────────────────────────────
func _build_stable() -> void:
	var w := 22.0; var h := 5.5; var d := 12.0; var t := 0.5
	# Floor
	_sbox(Vector3(0, -0.25, 0), Vector3(w, 0.5, d), STABLE_FLOOR)
	# Back wall
	_sbox(Vector3(0, h*0.5, -d*0.5), Vector3(w, h, t), STABLE_WALL)
	# Left wall
	_sbox(Vector3(-w*0.5, h*0.5, 0), Vector3(t, h, d), STABLE_WALL)
	# Right wall
	_sbox(Vector3( w*0.5, h*0.5, 0), Vector3(t, h, d), STABLE_WALL)
	# Roof
	_sbox(Vector3(0, h + 0.3, 0), Vector3(w + 0.6, 0.6, d + 0.6), STABLE_ROOF)
	# Divider stalls (low fences between camels)
	_sbox(Vector3(-2.5, 0.7, 1.5), Vector3(0.25, 1.4, 5.0), STABLE_WALL)
	_sbox(Vector3( 2.5, 0.7, 1.5), Vector3(0.25, 1.4, 5.0), STABLE_WALL)
	# Hay bales (yellow)
	var hay := Color(0.88, 0.75, 0.20)
	for i in 3:
		_sbox(CAMEL_SPOTS[i] + Vector3(0, 0.3, -3.8), Vector3(1.2, 0.6, 0.8), hay)

func _sbox(pos: Vector3, size: Vector3, color: Color) -> void:
	var sb  := StaticBody3D.new()
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	var cs  := CollisionShape3D.new()
	var bs  := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(mi)
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)

# ── Spawn 3 camels ─────────────────────────────────────────────────────────────
func _spawn_camels() -> void:
	if not camel_scene:
		push_error("stable.gd: camel_scene not assigned")
		return
	for spot in CAMEL_SPOTS:
		var c: CharacterBody3D = camel_scene.instantiate()
		c.position = spot
		var variant := c.roll_variant()
		c.apply_variant(variant)
		c.connect("camel_interacted", _on_camel_selected)
		add_child(c)
		_spawned_camels.append(c)

func _on_camel_selected(camel_node: Node) -> void:
	if _selected:
		return
	_selected = true
	# Highlight selected camel with brighter tint
	if camel_node.has_node("BodyMesh"):
		var mi: MeshInstance3D = camel_node.get_node("BodyMesh")
		var mat := mi.material_override as StandardMaterial3D
		if mat:
			var glow_mat := mat.duplicate() as StandardMaterial3D
			glow_mat.emission_enabled = true
			glow_mat.emission = mat.albedo_color * 0.6
			mi.material_override = glow_mat
	if start_label:
		start_label.text = "Chosen: %s  (Speed ×%.2f)  Saddle up!" % [
			camel_node.variant_data.get("label", "Camel"),
			camel_node.variant_data.get("speed_mod", 1.0)
		]
	await get_tree().create_timer(1.6).timeout
	GameManager.start_run(camel_node.variant_data)
