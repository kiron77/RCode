## survival_ui.gd — CanvasLayer
## HUD bars, inventory, death screen, and full mobile touch overlay.
## Also shows camel-distance danger warning.
extends CanvasLayer

# ── Stat bars ──────────────────────────────────────────────────────────────────
@onready var hp_bar:      ProgressBar = $HUD/StatsPanel/VBox/HPRow/HPBar
@onready var hunger_bar:  ProgressBar = $HUD/StatsPanel/VBox/HungerRow/HungerBar
@onready var thirst_bar:  ProgressBar = $HUD/StatsPanel/VBox/ThirstRow/ThirstBar
@onready var stamina_bar: ProgressBar = $HUD/StatsPanel/VBox/StaminaRow/StaminaBar
@onready var hp_lbl:      Label       = $HUD/StatsPanel/VBox/HPRow/HPLabel
@onready var hunger_lbl:  Label       = $HUD/StatsPanel/VBox/HungerRow/HungerLabel
@onready var thirst_lbl:  Label       = $HUD/StatsPanel/VBox/ThirstRow/ThirstLabel
@onready var stamina_lbl: Label       = $HUD/StatsPanel/VBox/StaminaRow/StaminaLabel

# ── Run info ───────────────────────────────────────────────────────────────────
@onready var dist_lbl:   Label = $HUD/RunInfo/DistLabel
@onready var kills_lbl:  Label = $HUD/RunInfo/KillsLabel
@onready var camel_lbl:  Label = $HUD/RunInfo/CamelLabel
@onready var weight_lbl: Label = $HUD/RunInfo/WeightLabel
@onready var mount_lbl:  Label = $HUD/RunInfo/MountLabel

# ── Interact prompt & danger banner ───────────────────────────────────────────
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var danger_banner:   Label = $HUD/DangerBanner

# ── Inventory ─────────────────────────────────────────────────────────────────
@onready var inv_panel:  Control      = $HUD/InventoryPanel
@onready var inv_grid:   GridContainer = $HUD/InventoryPanel/VBox/Grid
@onready var inv_toggle: Button       = $HUD/InventoryToggleBtn

# ── Death screen ───────────────────────────────────────────────────────────────
@onready var death_screen: Control = $DeathScreen
@onready var death_dist:   Label   = $DeathScreen/VBox/DistLabel
@onready var death_kills:  Label   = $DeathScreen/VBox/KillsLabel
@onready var restart_btn:  Button  = $DeathScreen/VBox/RestartBtn

# ── Mobile overlay ─────────────────────────────────────────────────────────────
@onready var mobile_overlay: Control = $MobileOverlay
@onready var joy_base:       Control = $MobileOverlay/JoystickBase
@onready var joy_knob:       Control = $MobileOverlay/JoystickBase/Knob
@onready var sprint_btn:     Button  = $MobileOverlay/SprintBtn
@onready var attack_btn:     Button  = $MobileOverlay/AttackBtn
@onready var interact_btn:   Button  = $MobileOverlay/InteractBtn
@onready var inv_btn:        Button  = $MobileOverlay/InventoryBtn
@onready var mount_btn:      Button  = $MobileOverlay/MountBtn

const JOY_RADIUS := 80.0

var _joy_idx:    int     = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _inv_open:   bool    = false

# ── Signals ────────────────────────────────────────────────────────────────────
signal mobile_move_changed(v: Vector2)
signal mobile_sprint_changed(active: bool)
signal mobile_attack_pressed
signal mobile_interact_pressed
signal restart_requested

func _ready() -> void:
	death_screen.visible  = false
	inv_panel.visible     = false
	interact_prompt.visible = false
	danger_banner.visible = false
	_setup_mobile()
	_wire_buttons()

# ── Public API ─────────────────────────────────────────────────────────────────
func update_stats(hp: float, hunger: float, thirst: float, stamina: float) -> void:
	_set_bar(hp_bar,      hp_lbl,      hp,      "HP",      Color(0.90, 0.15, 0.15), 100.0)
	_set_bar(hunger_bar,  hunger_lbl,  hunger,  "Hunger",  Color(0.85, 0.60, 0.10), 100.0)
	_set_bar(thirst_bar,  thirst_lbl,  thirst,  "Thirst",  Color(0.15, 0.55, 0.90), 100.0)
	_set_bar(stamina_bar, stamina_lbl, stamina, "Stamina", Color(0.20, 0.85, 0.35), 100.0)

func update_run_info(dist: float, kills: int, camel_text: String, weight_ratio: float, is_mounted: bool) -> void:
	dist_lbl.text   = "Distance: %d m" % int(dist)
	kills_lbl.text  = "Kills: %d" % kills
	camel_lbl.text  = camel_text
	weight_lbl.text = "Load: %d%%" % int(weight_ratio * 100.0)
	mount_lbl.text  = "[MOUNTED]" if is_mounted else "[E] to Mount"
	mount_lbl.modulate = Color(0.4, 1.0, 0.4) if is_mounted else Color.WHITE
	if mount_btn:
		mount_btn.text = "DISMOUNT" if is_mounted else "MOUNT"

func set_camel_danger(is_danger: bool) -> void:
	danger_banner.visible = is_danger
	if is_danger:
		danger_banner.text = "RETURN TO CAMEL  — taking damage!"

func show_interact_prompt(text: String) -> void:
	interact_prompt.text    = text
	interact_prompt.visible = true

func hide_interact_prompt() -> void:
	interact_prompt.visible = false

func show_death_screen(dist: float, kills: int) -> void:
	death_screen.visible = true
	death_dist.text  = "Distance Survived: %d m" % int(dist)
	death_kills.text = "Enemies Slain: %d" % kills

func refresh_inventory(inventory: Array) -> void:
	for ch in inv_grid.get_children():
		ch.queue_free()
	for i in inventory.size():
		var item: Dictionary = inventory[i]
		var btn := Button.new()
		btn.text         = item.get("name", "???")
		btn.tooltip_text = "Use %s" % btn.text
		var idx := i
		btn.pressed.connect(func(): _use_item(idx))
		inv_grid.add_child(btn)
	for _i in range(inventory.size(), 20):
		var ph := Panel.new()
		ph.custom_minimum_size = Vector2(60, 60)
		inv_grid.add_child(ph)

# ── Internal ────────────────────────────────────────────────────────────────────
func _set_bar(bar: ProgressBar, lbl: Label, val: float, name_str: String, ok_color: Color, max_v: float) -> void:
	bar.value    = val
	bar.max_value = max_v
	lbl.text     = "%s: %d" % [name_str, int(val)]
	bar.modulate = Color(1.0, 0.3, 0.3) if val < 20.0 else ok_color

func _wire_buttons() -> void:
	inv_toggle.pressed.connect(_toggle_inv)
	restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	sprint_btn.button_down.connect(func(): emit_signal("mobile_sprint_changed", true))
	sprint_btn.button_up.connect(func():   emit_signal("mobile_sprint_changed", false))
	attack_btn.pressed.connect(func():   emit_signal("mobile_attack_pressed"))
	interact_btn.pressed.connect(func(): emit_signal("mobile_interact_pressed"))
	mount_btn.pressed.connect(func():    emit_signal("mobile_interact_pressed"))
	inv_btn.pressed.connect(_toggle_inv)

func _toggle_inv() -> void:
	_inv_open        = not _inv_open
	inv_panel.visible = _inv_open

func _use_item(idx: int) -> void:
	var camel  := get_tree().get_first_node_in_group("camel")
	var player := get_tree().get_first_node_in_group("player")
	if camel and camel.has_method("remove_from_cart"):
		var item: Dictionary = camel.remove_from_cart(idx)
		if not item.is_empty() and player and player.has_method("consume_item"):
			player.consume_item(item)

func _setup_mobile() -> void:
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("web") or OS.has_feature("mobile")
	mobile_overlay.visible = touch

func _input(event: InputEvent) -> void:
	if not mobile_overlay.visible:
		return
	_handle_joystick(event)

func _handle_joystick(event: InputEvent) -> void:
	var joy_rect: Rect2 = joy_base.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed and joy_rect.has_point(event.position) and _joy_idx == -1:
			_joy_idx    = event.index
			_joy_origin = event.position
		elif not event.pressed and event.index == _joy_idx:
			_joy_idx = -1
			joy_knob.position = Vector2.ZERO
			emit_signal("mobile_move_changed", Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _joy_idx:
		var delta    := event.position - _joy_origin
		var clamped  := delta.limit_length(JOY_RADIUS)
		joy_knob.position = clamped
		emit_signal("mobile_move_changed", clamped / JOY_RADIUS)
