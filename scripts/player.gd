## player.gd — CharacterBody2D
## Frame-rate-independent physics via move_and_slide() in _physics_process.
## Handles WASD + mobile virtual joystick, survival stats, and knockback decay.
extends CharacterBody2D

# ── Movement constants ────────────────────────────────────────────────────────
const ACCELERATION   := 900.0
const MAX_SPEED      := 220.0
const FRICTION       := 9.0    # lerp factor toward zero when no input
const SPRINT_MULT    := 1.6
const KNOCKBACK_DECAY := 7.0   # lerp factor, higher = faster decay

# ── Survival stat maximums ───────────────────────────────────────────────────
const MAX_HP      := 100.0
const MAX_HUNGER  := 100.0
const MAX_THIRST  := 100.0
const MAX_STAMINA := 100.0

# ── Drain & damage rates (per second) ───────────────────────────────────────
const HUNGER_DRAIN       := 1.8
const THIRST_DRAIN       := 2.7   # 1.5× hunger drain
const STAMINA_SPRINT_USE := 28.0
const STAMINA_REGEN      := 18.0
const HUNGER_DAMAGE      := 5.0
const THIRST_DAMAGE      := 5.0
const LOW_THIRST_STAMINA_PENALTY := 2.0  # extra multiplier when thirst < 25 %

# ── Attack ────────────────────────────────────────────────────────────────────
const ATTACK_RANGE    := 70.0
const ATTACK_DAMAGE   := 20.0
const ATTACK_COOLDOWN := 0.6

# ── State ──────────────────────────────────────────────────────────────────────
enum State { IDLE, WALKING, SPRINTING, DEAD }
var state: State = State.IDLE

var hp:      float = MAX_HP
var hunger:  float = MAX_HUNGER
var thirst:  float = MAX_THIRST
var stamina: float = MAX_STAMINA

var knockback_vec: Vector2 = Vector2.ZERO
var attack_timer:  float   = 0.0
var is_dead:       bool    = false

# ── Mobile input interface (set by SurvivalUI signals) ──────────────────────
var mobile_move:   Vector2 = Vector2.ZERO
var mobile_sprint: bool    = false
var mobile_attack: bool    = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal stats_changed(hp, hunger, thirst, stamina)
signal player_died
signal attacked_at(pos, dir)

# ── Node refs (set by scene) ──────────────────────────────────────────────────
@onready var interact_area: Area2D = $InteractArea
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer

func _ready() -> void:
	add_to_group("player")
	attack_cooldown_timer.wait_time = ATTACK_COOLDOWN
	attack_cooldown_timer.one_shot = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_survival(delta)
	_handle_movement(delta)
	_apply_knockback(delta)
	_handle_attack()
	move_and_slide()
	emit_signal("stats_changed", hp, hunger, thirst, stamina)

# ── Movement ──────────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	var dir := _get_move_dir()
	var can_sprint := stamina > 0.0 and thirst > 0.0
	var want_sprint := (Input.is_action_pressed("sprint") or mobile_sprint) and can_sprint

	# Determine target speed and state
	if dir == Vector2.ZERO:
		state = State.IDLE
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
	elif want_sprint and dir != Vector2.ZERO:
		state = State.SPRINTING
		var target := dir * MAX_SPEED * SPRINT_MULT
		velocity = velocity.move_toward(target, ACCELERATION * delta)
		_drain_stamina(delta)
	else:
		state = State.WALKING
		var target := dir * MAX_SPEED
		velocity = velocity.move_toward(target, ACCELERATION * delta)
		_regen_stamina(delta)

	if state != State.SPRINTING:
		_regen_stamina(delta)

	# Flip sprite
	if dir.x != 0.0 and anim_sprite:
		anim_sprite.flip_h = dir.x < 0.0

	# Animation
	_update_animation()

func _get_move_dir() -> Vector2:
	if mobile_move.length() > 0.1:
		return mobile_move.normalized()
	var d := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	return d.normalized() if d.length() > 0.1 else Vector2.ZERO

func _update_animation() -> void:
	if not anim_sprite:
		return
	match state:
		State.IDLE:     anim_sprite.play("idle")   if anim_sprite.sprite_frames.has_animation("idle")   else anim_sprite.stop()
		State.WALKING:  anim_sprite.play("walk")   if anim_sprite.sprite_frames.has_animation("walk")   else anim_sprite.stop()
		State.SPRINTING:anim_sprite.play("sprint") if anim_sprite.sprite_frames.has_animation("sprint") else anim_sprite.stop()

# ── Stamina management ────────────────────────────────────────────────────────
func _drain_stamina(delta: float) -> void:
	var drain := STAMINA_SPRINT_USE
	if thirst < 25.0:
		drain *= LOW_THIRST_STAMINA_PENALTY
	stamina = max(0.0, stamina - drain * delta)

func _regen_stamina(delta: float) -> void:
	stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN * delta)

# ── Survival tick ─────────────────────────────────────────────────────────────
func _tick_survival(delta: float) -> void:
	hunger = max(0.0, hunger - HUNGER_DRAIN * delta)
	thirst = max(0.0, thirst - THIRST_DRAIN * delta)

	if hunger <= 0.0:
		hp = max(0.0, hp - HUNGER_DAMAGE * delta)
	if thirst <= 0.0:
		hp = max(0.0, hp - THIRST_DAMAGE * delta)

	if hp <= 0.0 and not is_dead:
		_die()

# ── Knockback ─────────────────────────────────────────────────────────────────
func apply_knockback(direction: Vector2, force: float) -> void:
	knockback_vec = direction.normalized() * force
	# Interrupt sprint instantly
	if state == State.SPRINTING:
		state = State.WALKING

func _apply_knockback(delta: float) -> void:
	if knockback_vec.length_squared() > 4.0:
		velocity += knockback_vec * delta * 60.0  # frame-rate normalised impulse
		knockback_vec = knockback_vec.lerp(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	else:
		knockback_vec = Vector2.ZERO

# ── Attack ────────────────────────────────────────────────────────────────────
func _handle_attack() -> void:
	var want_attack := Input.is_action_just_pressed("attack") or mobile_attack
	mobile_attack = false  # consume one-shot mobile flag
	if not want_attack or not attack_cooldown_timer.is_stopped():
		return
	attack_cooldown_timer.start()
	var attack_pos := global_position
	var attack_dir := _get_aim_dir()
	emit_signal("attacked_at", attack_pos, attack_dir)
	_do_melee_attack(attack_dir)

func _get_aim_dir() -> Vector2:
	# Aim toward mouse cursor (desktop) or movement direction (mobile)
	if mobile_move.length() > 0.1:
		return mobile_move.normalized()
	var mouse_world := get_global_mouse_position()
	return (mouse_world - global_position).normalized()

func _do_melee_attack(dir: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + dir * 50.0
	query.collision_mask = 0b0100  # layer 3 = enemies
	query.exclude = [self.get_rid()]
	var hits := space.intersect_point(query, 4)
	for h in hits:
		var body = h.collider
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE)
			body.apply_knockback(dir, 300.0)

# ── Consumables ───────────────────────────────────────────────────────────────
func consume_item(item: Dictionary) -> void:
	match item.get("type", ""):
		"food":
			hunger = min(MAX_HUNGER, hunger + item.get("hunger_restore", 0.0))
		"drink":
			thirst = min(MAX_THIRST, thirst + item.get("thirst_restore", 0.0))
		"medkit":
			hp = min(MAX_HP, hp + item.get("hp_restore", 0.0))

# ── Damage ────────────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = max(0.0, hp - amount)
	# Flash red
	modulate = Color(1.0, 0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.25)
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("player_died")
	if anim_sprite:
		anim_sprite.play("death") if anim_sprite.sprite_frames.has_animation("death") else anim_sprite.stop()
