## player.gd — CharacterBody3D
## Full 3D movement: WASD + virtual joystick, camera-relative input.
## Mounting system: press E near camel to ride/dismount.
## Survival stats, knockback, melee combat.
extends CharacterBody3D

# ── Movement constants ────────────────────────────────────────────────────────
const ACCELERATION   := 32.0   # units/s²
const MAX_SPEED      := 7.0    # units/s walking
const FRICTION       := 14.0   # decel factor
const SPRINT_MULT    := 1.6
const GRAVITY        := 24.0
const KNOCKBACK_DECAY := 9.0

# ── Survival stat maximums ────────────────────────────────────────────────────
const MAX_HP      := 100.0
const MAX_HUNGER  := 100.0
const MAX_THIRST  := 100.0
const MAX_STAMINA := 100.0

# ── Drain / damage rates (per second) ─────────────────────────────────────────
const HUNGER_DRAIN       := 1.6
const THIRST_DRAIN       := 2.4
const STAMINA_SPRINT_USE := 26.0
const STAMINA_REGEN      := 20.0
const HUNGER_DAMAGE      := 5.0
const THIRST_DAMAGE      := 5.0
const LOW_THIRST_STAM_MULT := 2.0

# ── Combat ─────────────────────────────────────────────────────────────────────
const ATTACK_DAMAGE    := 22.0
const ATTACK_RANGE     := 2.8   # units radius
const ATTACK_COOLDOWN  := 0.55
const KNOCKBACK_FORCE  := 14.0  # units/s burst

# ── Camel leash ───────────────────────────────────────────────────────────────
const CAMEL_MAX_DISTANCE := 28.0   # fall this far behind = danger
const CAMEL_LEASH_DAMAGE := 8.0    # HP/s when outside leash

# ── State ──────────────────────────────────────────────────────────────────────
enum State { IDLE, WALKING, SPRINTING, MOUNTED, DEAD }
var state: State = State.IDLE

var hp:      float = MAX_HP
var hunger:  float = MAX_HUNGER
var thirst:  float = MAX_THIRST
var stamina: float = MAX_STAMINA

var knockback_vec: Vector3 = Vector3.ZERO
var attack_timer:  float   = 0.0
var is_dead:       bool    = false

# ── Mounting ───────────────────────────────────────────────────────────────────
var is_mounted:    bool     = false
var mounted_camel: Node3D  = null

# ── Mobile input (set by SurvivalUI signals) ───────────────────────────────────
var mobile_move:   Vector2 = Vector2.ZERO
var mobile_sprint: bool    = false
var mobile_attack: bool    = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal stats_changed(hp, hunger, thirst, stamina)
signal player_died
signal camel_distance_danger(is_danger: bool)

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interact_area: Area3D = $InteractArea
@onready var camera_rig:    Node3D = $CameraRig
@onready var camera:        Camera3D = $CameraRig/Camera3D
@onready var attack_timer_node: Timer = $AttackTimer

func _ready() -> void:
	add_to_group("player")
	attack_timer_node.wait_time = ATTACK_COOLDOWN
	attack_timer_node.one_shot = true
	interact_area.body_entered.connect(_on_interact_area_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_survival(delta)
	if is_mounted:
		_handle_mounted()
	else:
		_handle_gravity(delta)
		_handle_movement(delta)
		_apply_knockback(delta)
		move_and_slide()
	_handle_attack()
	emit_signal("stats_changed", hp, hunger, thirst, stamina)

# ── Gravity ────────────────────────────────────────────────────────────────────
func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

# ── Mounted: lock position to camel's mount point ─────────────────────────────
func _handle_mounted() -> void:
	if not is_instance_valid(mounted_camel):
		dismount()
		return
	var mp: Node3D = mounted_camel.get_node_or_null("MountPoint")
	if mp:
		global_position = mp.global_position
	velocity = Vector3.ZERO

# ── Dismounted movement ────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	var dir := _get_move_dir_3d()
	var can_sprint := stamina > 0.0 and thirst > 0.0
	var sprinting   := (Input.is_action_pressed("sprint") or mobile_sprint) and can_sprint and dir.length() > 0.01

	var target_speed := MAX_SPEED * (SPRINT_MULT if sprinting else 1.0)

	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	if dir.length() > 0.01:
		h_vel = h_vel.move_toward(dir * target_speed, ACCELERATION * target_speed * delta)
		state = State.SPRINTING if sprinting else State.WALKING
		if sprinting:
			_drain_stamina(delta)
		else:
			_regen_stamina(delta)
	else:
		h_vel = h_vel.lerp(Vector3.ZERO, FRICTION * delta)
		state = State.IDLE
		_regen_stamina(delta)

	velocity.x = h_vel.x
	velocity.z = h_vel.z

	# Face movement direction
	if dir.length() > 0.01:
		var target_basis := Basis.looking_at(dir, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, 12.0 * delta)

func _get_move_dir_3d() -> Vector3:
	var raw: Vector2
	if mobile_move.length() > 0.1:
		raw = mobile_move
	else:
		raw = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up",   "move_down")
		)
	if raw.length_squared() < 0.02:
		return Vector3.ZERO
	# Camera-relative horizontal movement
	var cam_fwd := -camera.global_transform.basis.z
	var cam_rgt :=  camera.global_transform.basis.x
	cam_fwd.y = 0.0; cam_fwd = cam_fwd.normalized()
	cam_rgt.y = 0.0; cam_rgt = cam_rgt.normalized()
	return (cam_fwd * -raw.y + cam_rgt * raw.x).normalized()

# ── Stamina ────────────────────────────────────────────────────────────────────
func _drain_stamina(delta: float) -> void:
	var mult := LOW_THIRST_STAM_MULT if thirst < 25.0 else 1.0
	stamina = max(0.0, stamina - STAMINA_SPRINT_USE * mult * delta)

func _regen_stamina(delta: float) -> void:
	stamina = min(MAX_STAMINA, stamina + STAMINA_REGEN * delta)

# ── Survival tick ──────────────────────────────────────────────────────────────
func _tick_survival(delta: float) -> void:
	hunger = max(0.0, hunger - HUNGER_DRAIN * delta)
	thirst = max(0.0, thirst - THIRST_DRAIN * delta)
	if hunger <= 0.0:
		hp = max(0.0, hp - HUNGER_DAMAGE * delta)
	if thirst <= 0.0:
		hp = max(0.0, hp - THIRST_DAMAGE * delta)
	_check_camel_distance(delta)
	if hp <= 0.0 and not is_dead:
		_die()

func _check_camel_distance(delta: float) -> void:
	var camel := get_tree().get_first_node_in_group("camel")
	if not camel:
		return
	var dist := global_position.distance_to(camel.global_position)
	if dist > CAMEL_MAX_DISTANCE:
		hp = max(0.0, hp - CAMEL_LEASH_DAMAGE * delta)
		emit_signal("camel_distance_danger", true)
	else:
		emit_signal("camel_distance_danger", false)

# ── Knockback ──────────────────────────────────────────────────────────────────
func apply_knockback(direction: Vector3, force: float) -> void:
	knockback_vec = direction.normalized() * force
	if state == State.SPRINTING:
		state = State.WALKING

func _apply_knockback(delta: float) -> void:
	if knockback_vec.length_squared() > 0.1:
		velocity += knockback_vec
		knockback_vec = knockback_vec.lerp(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	else:
		knockback_vec = Vector3.ZERO

# ── Attack ─────────────────────────────────────────────────────────────────────
func _handle_attack() -> void:
	var want := Input.is_action_just_pressed("attack") or mobile_attack
	mobile_attack = false
	if not want or not attack_timer_node.is_stopped() or is_mounted:
		return
	attack_timer_node.start()
	_do_melee()
	# Flash white
	if mesh_instance:
		mesh_instance.set_instance_shader_parameter("albedo_override", Color(1.5, 1.5, 1.5))
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(func(): pass)  # material resets on next frame naturally

func _do_melee() -> void:
	var aim_dir := _get_aim_dir_3d()
	for body in interact_area.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			var to_enemy := (body.global_position - global_position)
			if to_enemy.length() <= ATTACK_RANGE:
				var knockback_dir := to_enemy.normalized()
				body.take_damage(ATTACK_DAMAGE)
				body.apply_knockback(knockback_dir, KNOCKBACK_FORCE)

func _get_aim_dir_3d() -> Vector3:
	if mobile_move.length() > 0.1:
		return _get_move_dir_3d()
	# Raycast from camera through mouse to ground plane
	var vp := get_viewport()
	var cam := get_viewport().get_camera_3d()
	if cam:
		var mouse := vp.get_mouse_position()
		var ray_from := cam.project_ray_origin(mouse)
		var ray_dir  := cam.project_ray_normal(mouse)
		if abs(ray_dir.y) > 0.001:
			var t := -ray_from.y / ray_dir.y
			var world_pt := ray_from + ray_dir * t
			var d := (world_pt - global_position)
			d.y = 0.0
			if d.length() > 0.1:
				return d.normalized()
	return -global_transform.basis.z

# ── Mounting / Dismounting ─────────────────────────────────────────────────────
func mount(camel_node: Node3D) -> void:
	if is_mounted:
		return
	is_mounted = true
	mounted_camel = camel_node
	state = State.MOUNTED
	velocity = Vector3.ZERO
	# Disable own collision so we don't push camel
	set_collision_layer_value(1, false)

func dismount() -> void:
	if not is_mounted:
		return
	is_mounted = false
	state = State.IDLE
	# Eject to side of camel
	if is_instance_valid(mounted_camel):
		global_position = mounted_camel.global_position + Vector3(0.0, 0.0, 2.5)
	set_collision_layer_value(1, true)
	mounted_camel = null

# ── Interact area: E near camel mounts, E again dismounts ─────────────────────
func _on_interact_area_body_entered(body: Node) -> void:
	pass  # handled via _unhandled_input in stable; main uses Input polling

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if is_mounted:
			dismount()
			return
		# Try to mount nearby camel
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("camel") and body.has_method("mount"):
				mount(body)
				return

# ── Consumables ────────────────────────────────────────────────────────────────
func consume_item(item: Dictionary) -> void:
	match item.get("type", ""):
		"food":   hunger = min(MAX_HUNGER, hunger + item.get("hunger_restore", 0.0))
		"drink":  thirst = min(MAX_THIRST,  thirst + item.get("thirst_restore", 0.0))
		"medkit": hp     = min(MAX_HP,      hp     + item.get("hp_restore",    0.0))

# ── Damage & death ─────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = max(0.0, hp - amount)
	if mesh_instance:
		mesh_instance.modulate = Color(1.0, 0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(mesh_instance, "modulate", Color.WHITE, 0.25)
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	state = State.DEAD
	velocity = Vector3.ZERO
	emit_signal("player_died")
