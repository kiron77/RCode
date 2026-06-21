## enemy_brawler.gd — CharacterBody3D
## Desert Brawler: PATROL → CHASE → ATTACK state machine.
## Tracks player in 3D, melee punch with velocity-based knockback + stagger.
extends CharacterBody3D

# ── Stats ──────────────────────────────────────────────────────────────────────
const MAX_HP          := 65.0
const MOVE_SPEED      := 4.5
const PATROL_SPEED    := 2.0
const PATROL_RANGE    := 5.0
const DETECT_RANGE    := 22.0
const CHASE_LOSE_DIST := 28.0
const ATTACK_RANGE    := 1.9
const ATTACK_DAMAGE   := 15.0
const KNOCKBACK_FORCE := 12.0   # units/s burst
const ATTACK_COOLDOWN := 1.5
const GRAVITY         := 24.0
const FRICTION        := 11.0

# ── AI states ─────────────────────────────────────────────────────────────────
enum AIState { PATROL, CHASE, ATTACK, STAGGER, DEAD }
var ai_state: AIState = AIState.PATROL

var hp:           float   = MAX_HP
var attack_timer: float   = 0.0
var stagger_timer:float   = 0.0
var patrol_timer: float   = 0.0
var patrol_dir:   Vector3 = Vector3.RIGHT
var spawn_pos:    Vector3 = Vector3.ZERO
var is_dead:      bool    = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hp_label:      Label3D        = $HPLabel3D

# ── Target ────────────────────────────────────────────────────────────────────
var target: Node3D = null

# ── Signals ───────────────────────────────────────────────────────────────────
signal died(pos: Vector3)

func _ready() -> void:
	add_to_group("enemy")
	spawn_pos   = global_position
	patrol_dir  = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_refresh_target()
	if hp_label:
		hp_label.text = "HP: %d" % int(MAX_HP)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.lerp(Vector3.ZERO, FRICTION * delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	attack_timer  = maxf(0.0, attack_timer - delta)
	stagger_timer = maxf(0.0, stagger_timer - delta)
	_refresh_target()
	_run_ai(delta)
	move_and_slide()

func _refresh_target() -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")

func _run_ai(delta: float) -> void:
	match ai_state:
		AIState.PATROL:
			_do_patrol(delta)
			if target and _flat_dist(target) <= DETECT_RANGE:
				_enter_state(AIState.CHASE)

		AIState.CHASE:
			if not target:
				_enter_state(AIState.PATROL)
				return
			var d := _flat_dist(target)
			if d <= ATTACK_RANGE:
				_enter_state(AIState.ATTACK)
			elif d > CHASE_LOSE_DIST:
				_enter_state(AIState.PATROL)
			else:
				_move_toward(target.global_position, MOVE_SPEED, delta)

		AIState.ATTACK:
			_brake(delta)
			if not target or _flat_dist(target) > ATTACK_RANGE * 1.6:
				_enter_state(AIState.CHASE)
				return
			if attack_timer <= 0.0:
				_punch()

		AIState.STAGGER:
			_brake(delta)
			if stagger_timer <= 0.0:
				_enter_state(AIState.CHASE)

func _do_patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_dir  = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		patrol_timer = randf_range(1.8, 3.5)
	var dst := spawn_pos + patrol_dir * PATROL_RANGE
	if global_position.distance_to(dst) < 0.5:
		_brake(delta)
	else:
		_move_toward(dst, PATROL_SPEED, delta)

func _move_toward(pos: Vector3, spd: float, delta: float) -> void:
	var dir := (pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	var h := Vector3(velocity.x, 0.0, velocity.z)
	h = h.move_toward(dir * spd, spd * 6.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	# Face target
	if dir.length() > 0.01:
		global_transform.basis = global_transform.basis.slerp(Basis.looking_at(dir, Vector3.UP), 12.0 * delta)

func _brake(delta: float) -> void:
	var h := Vector3(velocity.x, 0.0, velocity.z)
	h = h.lerp(Vector3.ZERO, FRICTION * delta)
	velocity.x = h.x
	velocity.z = h.z

func _enter_state(s: AIState) -> void:
	ai_state = s

func _punch() -> void:
	attack_timer = ATTACK_COOLDOWN
	if not target or not is_instance_valid(target):
		return
	# Wind-up flash orange
	if mesh_instance:
		mesh_instance.modulate = Color(1.2, 0.6, 0.1)
		var tw := create_tween()
		tw.tween_property(mesh_instance, "modulate", Color.WHITE, 0.2)
	if target.has_method("take_damage"):
		target.take_damage(ATTACK_DAMAGE)
	if target.has_method("apply_knockback"):
		var dir := (target.global_position - global_position)
		dir.y = 0.0
		target.apply_knockback(dir.normalized(), KNOCKBACK_FORCE)

func _flat_dist(node: Node3D) -> float:
	var d := global_position - node.global_position
	d.y = 0.0
	return d.length()

# ── Receiving damage & knockback ───────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	if hp_label:
		hp_label.text = "HP: %d" % int(hp)
	if mesh_instance:
		mesh_instance.modulate = Color(1.0, 0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(mesh_instance, "modulate", Color.WHITE, 0.18)
	if hp <= 0.0:
		_die()

func apply_knockback(dir: Vector3, force: float) -> void:
	if is_dead:
		return
	var kd := dir
	kd.y = 0.0
	velocity += kd.normalized() * force
	# Enter stagger
	_enter_state(AIState.STAGGER)
	stagger_timer = 0.35

func _die() -> void:
	is_dead = true
	set_collision_layer_value(3, false)
	emit_signal("died", global_position)
	GameManager.run_kills += 1
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.5)
	tw.tween_callback(queue_free)
