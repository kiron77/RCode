## survival_ui.gd — CanvasLayer
## Renders all HUD elements: stat bars, distance, kill count, inventory panel,
## interaction prompt, and the full mobile touch overlay.
extends CanvasLayer

# ── HUD stat bar references ────────────────────────────────────────────────────
@onready var hp_bar:      ProgressBar = $HUD/StatsPanel/VBox/HPRow/HPBar
@onready var hunger_bar:  ProgressBar = $HUD/StatsPanel/VBox/HungerRow/HungerBar
@onready var thirst_bar:  ProgressBar = $HUD/StatsPanel/VBox/ThirstRow/ThirstBar
@onready var stamina_bar: ProgressBar = $HUD/StatsPanel/VBox/StaminaRow/StaminaBar

@onready var hp_label:      Label = $HUD/StatsPanel/VBox/HPRow/HPLabel
@onready var hunger_label:  Label = $HUD/StatsPanel/VBox/HungerRow/HungerLabel
@onready var thirst_label:  Label = $HUD/StatsPanel/VBox/ThirstRow/ThirstLabel
@onready var stamina_label: Label = $HUD/StatsPanel/VBox/StaminaRow/StaminaLabel

# ── Run info labels ────────────────────────────────────────────────────────────
@onready var distance_label: Label = $HUD/RunInfo/DistanceLabel
@onready var kills_label:    Label = $HUD/RunInfo/KillsLabel
@onready var camel_label:    Label = $HUD/RunInfo/CamelLabel
@onready var weight_label:   Label = $HUD/RunInfo/WeightLabel

# ── Interact prompt ────────────────────────────────────────────────────────────
@onready var interact_prompt: Label = $HUD/InteractPrompt

# ── Inventory panel ────────────────────────────────────────────────────────────
@onready var inventory_panel:    Control = $HUD/InventoryPanel
@onready var inventory_grid:     GridContainer = $HUD/InventoryPanel/Grid
@onready var inventory_toggle:   Button = $HUD/InventoryToggleBtn

# ── Death screen ───────────────────────────────────────────────────────────────
@onready var death_screen:       Control = $DeathScreen
@onready var death_distance_lbl: Label   = $DeathScreen/VBox/DistLabel
@onready var death_kills_lbl:    Label   = $DeathScreen/VBox/KillsLabel
@onready var restart_btn:        Button  = $DeathScreen/VBox/RestartBtn

# ── Mobile overlay ─────────────────────────────────────────────────────────────
@onready var mobile_overlay:    Control      = $MobileOverlay
@onready var joystick_base:     Control      = $MobileOverlay/JoystickBase
@onready var joystick_knob:     Control      = $MobileOverlay/JoystickBase/Knob
@onready var sprint_btn:        Button       = $MobileOverlay/SprintBtn
@onready var interact_btn:      Button       = $MobileOverlay/InteractBtn
@onready var attack_btn:        Button       = $MobileOverlay/AttackBtn
@onready var inventory_btn:     Button       = $MobileOverlay/InventoryBtn

const JOYSTICK_MAX_RADIUS := 80.0

# ── Joystick touch tracking ────────────────────────────────────────────────────
var _joy_touch_idx:  int     = -1
var _joy_origin:     Vector2 = Vector2.ZERO
var _mobile_vec:     Vector2 = Vector2.ZERO
var _inventory_open: bool    = false

# ── Signals → Player / Main ────────────────────────────────────────────────────
signal mobile_move_changed(vec: Vector2)
signal mobile_sprint_changed(active: bool)
signal mobile_interact_pressed
signal mobile_attack_pressed
signal restart_requested

func _ready() -> void:
	death_screen.visible = false
	inventory_panel.visible = false
	interact_prompt.visible = false
	_setup_mobile_visibility()
	_wire_buttons()

# ── Public API ─────────────────────────────────────────────────────────────────
func update_stats(hp: float, hunger: float, thirst: float, stamina: float) -> void:
	_set_bar(hp_bar,      hp_label,      hp,      "HP",      Color(0.9, 0.15, 0.15), 100.0)
	_set_bar(hunger_bar,  hunger_label,  hunger,  "Hunger",  Color(0.85, 0.60, 0.10), 100.0)
	_set_bar(thirst_bar,  thirst_label,  thirst,  "Thirst",  Color(0.15, 0.55, 0.90), 100.0)
	_set_bar(stamina_bar, stamina_label, stamina, "Stamina", Color(0.20, 0.85, 0.35), 100.0)

func update_run_info(distance: float, kills: int, camel_label_text: String, weight_ratio: float) -> void:
	distance_label.text = "Distance: %d m" % int(distance)
	kills_label.text    = "Kills: %d" % kills
	camel_label.text    = camel_label_text
	weight_label.text   = "Load: %d%%" % int(weight_ratio * 100.0)

func show_interact_prompt(text: String) -> void:
	interact_prompt.text = text
	interact_prompt.visible = true

func hide_interact_prompt() -> void:
	interact_prompt.visible = false

func show_death_screen(distance: float, kills: int) -> void:
	death_screen.visible = true
	death_distance_lbl.text = "Distance Survived: %d m" % int(distance)
	death_kills_lbl.text    = "Enemies Slain: %d" % kills

func refresh_inventory(inventory: Array) -> void:
	# Clear existing slots
	for child in inventory_grid.get_children():
		child.queue_free()
	# Populate
	for i in inventory.size():
		var item: Dictionary = inventory[i]
		var btn := Button.new()
		btn.text = item.get("name", "???")
		btn.tooltip_text = "Use %s" % btn.text
		var idx := i
		btn.pressed.connect(func(): _on_item_used(idx))
		inventory_grid.add_child(btn)
	# Empty slots
	for _i in range(inventory.size(), 20):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(64, 64)
		inventory_grid.add_child(empty)

# ── Internal helpers ───────────────────────────────────────────────────────────
func _set_bar(bar: ProgressBar, lbl: Label, value: float, name_str: String, ok_color: Color, max_val: float) -> void:
	bar.value = value
	bar.max_value = max_val
	lbl.text = "%s: %d" % [name_str, int(value)]
	# Pulse red when critical
	var crit := value < 20.0
	bar.modulate = Color(1.0, 0.3, 0.3) if crit else ok_color

func _wire_buttons() -> void:
	inventory_toggle.pressed.connect(_toggle_inventory)
	restart_btn.pressed.connect(func(): emit_signal("restart_requested"))
	sprint_btn.button_down.connect(func(): emit_signal("mobile_sprint_changed", true))
	sprint_btn.button_up.connect(func(): emit_signal("mobile_sprint_changed", false))
	interact_btn.pressed.connect(func(): emit_signal("mobile_interact_pressed"))
	attack_btn.pressed.connect(func(): emit_signal("mobile_attack_pressed"))
	inventory_btn.pressed.connect(_toggle_inventory)

func _toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	inventory_panel.visible = _inventory_open

func _setup_mobile_visibility() -> void:
	# Show mobile overlay on touch-capable or web platforms
	var is_touch := DisplayServer.is_touchscreen_available() or OS.has_feature("web") or OS.has_feature("mobile")
	mobile_overlay.visible = is_touch

# ── Touch input: virtual joystick ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not mobile_overlay.visible:
		return
	_handle_joystick(event)

func _handle_joystick(event: InputEvent) -> void:
	var joy_rect: Rect2 = joystick_base.get_global_rect()

	if event is InputEventScreenTouch:
		if event.pressed and joy_rect.has_point(event.position) and _joy_touch_idx == -1:
			_joy_touch_idx = event.index
			_joy_origin     = event.position
		elif not event.pressed and event.index == _joy_touch_idx:
			_joy_touch_idx = -1
			_mobile_vec    = Vector2.ZERO
			joystick_knob.position = Vector2.ZERO
			emit_signal("mobile_move_changed", Vector2.ZERO)

	elif event is InputEventScreenDrag and event.index == _joy_touch_idx:
		var delta_vec := event.position - _joy_origin
		var clamped   := delta_vec.limit_length(JOYSTICK_MAX_RADIUS)
		joystick_knob.position = clamped
		_mobile_vec = clamped / JOYSTICK_MAX_RADIUS
		emit_signal("mobile_move_changed", _mobile_vec)
