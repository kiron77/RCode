# DeadRails Desert Survival — Godot 4 Setup Guide

## Requirements
- **Godot Engine 4.2+** (download from godotengine.org)
- Web export template installed (Project → Export → Manage Export Templates)

---

## Scene Tree Reference

### `Stable.tscn` (entry point)
```
Stable (Node2D)          ← stable.gd
├── Background           (ColorRect — sandy floor)
├── StableFloor          (ColorRect — darker dirt)
├── StableWalls          (ColorRect)
├── Player               (instance: Player.tscn)
└── UI (CanvasLayer)
    ├── StartLabel       (Label)
    ├── TipLabel         (Label)
    └── TitleLabel       (Label)
```
`camel_scene` export var → assign **Camel.tscn** in Inspector.
Camels are spawned procedurally at runtime at positions `[-160, 0, 160]` on the X axis.

---

### `Main.tscn` (gameplay)
```
Main (Node2D)             ← main.gd
├── WorldGenerator        (Node2D) ← world_generator.gd
│   └── StructContainer / EnemyContainer (Node2D, children)
├── StructContainer       (Node2D)  ← structure instances go here
├── EnemyContainer        (Node2D)  ← enemy instances go here
├── Camel                 (instance: Camel.tscn)
│   └── CartAnchor        (Node2D — visual cart attachment point)
├── Player                (instance: Player.tscn)
│   └── Camera2D          (follows player, zoom 1.5×)
└── SurvivalUI            (instance: ui/SurvivalUI.tscn)
```
**Export vars on Main node** (set in Inspector):
- `enemy_scene` → `EnemyBrawler.tscn`
- `barn_scene`  → `structures/Barn.tscn`
- `oasis_scene` → `structures/Oasis.tscn`

---

### `Player.tscn`
```
Player (CharacterBody2D)  ← player.gd
│  collision_layer = 1 | collision_mask = 6 (camel + enemy)
├── CollisionShape2D      (CapsuleShape2D r=14 h=28)
├── Sprite2D              (placeholder blue rect — swap with spritesheet)
├── AnimatedSprite2D      (animations: idle, walk, sprint, death)
├── InteractArea (Area2D) mask=4 (structs/camels)
│   └── CollisionShape2D  (CircleShape2D r=55)
├── AttackCooldownTimer   (Timer, one_shot=true, 0.6s)
└── Camera2D              (zoom 1.5×, position smoothing 6.0)
```

---

### `Camel.tscn`
```
Camel (CharacterBody2D)   ← camel.gd
│  collision_layer = 2 | collision_mask = 5
├── CollisionShape2D      (CapsuleShape2D r=22 h=50)
├── Sprite2D              (tinted by variant color at runtime)
├── NameLabel             (Label — shows variant name above camel)
├── InteractArea (Area2D) (radius 70, detects player)
│   └── CollisionShape2D
└── CartAnchor            (Node2D — visual harness point)
```

---

### `EnemyBrawler.tscn`
```
EnemyBrawler (CharacterBody2D)  ← enemy_brawler.gd
│  collision_layer = 4 | collision_mask = 3
├── CollisionShape2D      (CapsuleShape2D r=14 h=26)
├── Sprite2D              (red tint)
├── AnimatedSprite2D
├── HPBar                 (ProgressBar, offset above head)
└── DetectionArea         (Area2D, r=320)
    └── CollisionShape2D
```

---

## Collision Layers
| Layer | Bit | Used by |
|-------|-----|---------|
| 1 | 0b0001 | Player |
| 2 | 0b0010 | Camel |
| 3 | 0b0100 | Structures / interactive areas |
| 4 | 0b1000 | Enemies |

Player mask = 6 (0b0110) → collides with camel + enemies  
Enemy mask  = 3 (0b0011) → collides with player + camel  

---

## Input Map (project.godot)
| Action | Key |
|--------|-----|
| move_left  | A |
| move_right | D |
| move_up    | W |
| move_down  | S |
| sprint     | Left Shift |
| interact   | E |
| attack     | Left Mouse Button |
| inventory_toggle | I |

---

## Camel Variant Probability Table
| Variant | Weight | Cumulative | Speed Mod |
|---------|--------|------------|-----------|
| White   | 10     | 0–9        | ×1.30 (Fastest) |
| Black   | 25     | 10–34      | ×1.15 |
| Brown   | 50     | 35–84      | ×1.00 (Normal) |
| Orange  | 15     | 85–99      | ×0.85 (Slowest) |

---

## Cart Weight Penalty
| Items in cart | Speed penalty |
|---------------|--------------|
| 0–4  | 0%  (full variant speed) |
| 5–9  | –10% |
| 10–14 | –20% |
| 15–19 | –30% |
| 20 (full) | –40% → clamped at 60% of base |

---

## Web Export Steps
1. Open project in Godot 4
2. Project → Export → Add → Web
3. Install export templates if prompted
4. Set output path: `exports/web/index.html`
5. Export All (or use `export_presets.cfg` already committed)
6. Serve `exports/web/` via any HTTP server (e.g. `python3 -m http.server`)
   - **Must use HTTPS or localhost** — SharedArrayBuffer requires cross-origin isolation

---

## Adding Sprite Sheets
Replace placeholder `Sprite2D` nodes with `AnimatedSprite2D` sheets:
- Player: 4-dir walk cycle, idle, sprint, death
- Camel: walk right (auto-march) + idle
- Enemy: walk + attack wind-up

The scripts already call `anim_sprite.play("idle"|"walk"|"sprint"|"death"|"run")` —
just ensure your `SpriteFrames` resource uses those exact animation names.

---

## Mobile Controls
The `SurvivalUI.tscn` mobile overlay auto-shows when:
```gdscript
DisplayServer.is_touchscreen_available() or OS.has_feature("web") or OS.has_feature("mobile")
```
Virtual joystick bottom-left → routes to `player.mobile_move`  
Sprint / Attack / [E] / CART buttons → bottom-right cluster
