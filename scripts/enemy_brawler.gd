## enemy_brawler.gd — CharacterBody2D
## Desert Brawler: melee AI enemy that tracks and punches the player.
## State machine: PATROL → CHASE → ATTACK → STUNNED
extends CharacterBody2D

# ── Stats ──────────────────────────────────────────────────────────────────────
const MAX_HP           := 60.0
const MOVE_SPEED       := 85.0
const DETECTION_RANGE  := 320.0
const ATTACK_RANGE     := 48.0
const ATTACK_DAMAGE    := 15.0
const KNOCKBACK_FORCE  := 420.0   # pixels/sec burst applied to player
const ATTACK_COOLDOWN  := 1.6     # seconds between punches
const PATROL_SPEED     := 40.0
const PATROL_RANGE     := 80.0    # wander distance from spawn
const FRICTION         := 8.0

# ── State machine ─────────────────────────────────────────────────────────────
enum AIState { PATROL, CHASE, ATTACK, DEAD }
var ai_state: AIState = AIState.PATROL

var hp:           float   = MAX_HP
var attack_timer: float   = 0.0
var is_dead:      bool    = false
var spawn_pos:    Vector2 = Vector2.ZERO
var patrol_dir:   Vector2 = Vector2.RIGHT
var patrol_timer: float   = 0.0

# ── Target ────────────────────────────────────────────────────────────────────
var target: Node2D = null

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim:   AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

# ── Signals ───────────────────────────────────────────────────────────────────
signal died(world_position)
signal dealt_damage(amount, target_node)

func _ready() -> void:
	add_to_group("enemy")
	spawn_pos = global_position
	hp_bar.max_value = MAX_HP
	hp_bar.value = MAX_HP
	_find_target()
	# Random patrol direction
	patrol_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	attack_timer = maxf(0.0, attack_timer - delta)
	_refresh_target()
	_run_ai(delta)
	move_and_slide()

# ── Target acquisition ────────────────────────────────────────────────────────
func _find_target() -> void:
	target = get_tree().get_first_node_in_group("player")

func _refresh_target() -> void:
	if target == null or not is_instance_valid(target):
		_find_target()

# ── AI state machine ──────────────────────────────────────────────────────────
func _run_ai(delta: float) -> void:
	if target == null:
		_patrol(delta)
		return

	var dist := global_position.distance_to(target.global_position)

	match ai_state:
		AIState.PATROL:
			_patrol(delta)
			if dist <= DETECTION_RANGE:
				_enter_chase()

		AIState.CHASE:
			_chase(delta, dist)
			if dist > DETECTION_RANGE * 1.2:
				ai_state = AIState.PATROL

		AIState.ATTACK:
			velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
			if dist > ATTACK_RANGE * 1.5:
				ai_state = AIState.CHASE
			elif attack_timer <= 0.0:
				_punch()

func _patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		patrol_timer = randf_range(1.5, 3.5)

	var target_pos := spawn_pos + patrol_dir * PATROL_RANGE
	var dir := (target_pos - global_position).normalized()
	if global_position.distance_to(target_pos) < 8.0:
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(dir * PATROL_SPEED, 400.0 * delta)

func _enter_chase() -> void:
	ai_state = AIState.CHASE
	if anim:
		anim.play("run") if anim.sprite_frames.has_animation("run") else null

func _chase(delta: float, dist: float) -> void:
	if dist <= ATTACK_RANGE:
		ai_state = AIState.ATTACK
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * MOVE_SPEED, 500.0 * delta)
	# Flip sprite
	if sprite and dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

func _punch() -> void:
	attack_timer = ATTACK_COOLDOWN
	if target == null or not is_instance_valid(target):
		return
	# Visual punch wind-up flash
	modulate = Color(1.0, 0.6, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)

	if target.has_method("take_damage"):
		target.take_damage(ATTACK_DAMAGE)
		emit_signal("dealt_damage", ATTACK_DAMAGE, target)

	if target.has_method("apply_knockback"):
		var knockback_dir := (target.global_position - global_position).normalized()
		target.apply_knockback(knockback_dir, KNOCKBACK_FORCE)

# ── Receiving damage ──────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = maxf(0.0, hp - amount)
	hp_bar.value = hp

	# Hit flash
	modulate = Color(1.0, 0.25, 0.25)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)

	if hp <= 0.0:
		_die()

## Apply knockback FROM player attack
func apply_knockback(direction: Vector2, force: float) -> void:
	velocity += direction.normalized() * force

func _die() -> void:
	is_dead = true
	ai_state = AIState.DEAD
	set_collision_layer_value(3, false)  # disable enemy collision layer
	emit_signal("died", global_position)
	GameManager.run_kills += 1

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
