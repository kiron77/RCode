# DeadRails Desert Survival — Godot 4 (3D) Setup Guide

## Requirements
- **Godot Engine 4.2+** — download from godotengine.org
- Web export templates (Project → Export → Manage Export Templates)

---

## Placeholder Color Key
Every entity is a colored capsule/box. Swap for real meshes later.

| Color | Hex approx | Entity |
|-------|-----------|--------|
| **Cyan-Blue** `#2E8CFF` | Player |
| **Tan/Brown** `#996633` | Brown Camel (Common 50%) |
| **Ivory** `#F2F2E6` | White Camel (Rare 10%) |
| **Near-Black** `#1F1A1A` | Black Camel (Uncommon 25%) |
| **Burnt Orange** `#E6800F` | Orange Camel (Common 15%) |
| **Dark Red** `#CC1A1A` | Desert Brawler Enemy |
| **Cactus Green** `#269426` | Cacti props |
| **Mid Grey** `#858585` | Rock props |
| **Sand** `#D1B36B` | Ground tiles (endless scrolling) |
| **Gold** `#FFBf00` | Loot Chests (openable) |
| **Dark Wood** `#59360F` | Barn walls, roof, cart body |
| **Sandstone** `#B89E73` | Oasis temple ruins |
| **Pale Blue** `#2A8CE6` | Oasis water pool |
| **Palm Green** `#1E941E` | Palm tree leaves |
| **Tan Trunk** `#8C6033` | Palm tree trunks |
| **Yellow** `#E0BF33` | Hay bales (stable) |

---

## Scene Tree (3D)

### `Stable.tscn` (entry point)
```
Stable (Node3D)              ← stable.gd (builds geometry in _ready)
├── Sun (DirectionalLight3D)
├── WorldEnvironment
├── Player (CharacterBody3D) ← Player.tscn
└── UI (CanvasLayer)
    ├── StartLabel / TipLabel / TitleLabel
```
**Inspector**: assign `camel_scene = Camel.tscn`, `player_scene = Player.tscn`
Stable walls, floor, roof, hay bales, and stall dividers are built in code.
Three random-variant camels are spawned at X offsets -5, 0, +5.

---

### `Main.tscn` (gameplay)
```
Main (Node3D)                ← main.gd
├── Sun (DirectionalLight3D)
├── WorldEnvironment
├── CameraRig (Node3D)       ← follows midpoint of player+camel
│   └── Camera3D             (FOV 55, angled down ~40°)
├── WorldGenerator (Node3D)  ← world_generator.gd
├── EnemyContainer (Node3D)
├── StructContainer (Node3D)
├── PropContainer (Node3D)
├── Camel (CharacterBody3D)  ← Camel.tscn, starts at X=3
├── Player (CharacterBody3D) ← Player.tscn, starts at X=-1.5
└── SurvivalUI (CanvasLayer) ← ui/SurvivalUI.tscn
```
**Inspector export vars on Main node**:
- `enemy_scene`  → `EnemyBrawler.tscn`
- `barn_scene`   → `structures/Barn.tscn`
- `oasis_scene`  → `structures/Oasis.tscn`
- `cactus_scene` → `props/Cactus.tscn`
- `rock_scene`   → `props/Rock.tscn`

---

### `Player.tscn` (CharacterBody3D, layer 1)
```
Player
├── MeshInstance3D     (CapsuleMesh, CYAN-BLUE — the player)
├── CollisionShape3D   (CapsuleShape3D)
├── InteractArea       (Area3D, radius 2.8 — mount/loot range)
│   └── CollisionShape3D
├── AttackTimer        (Timer, 0.55s one-shot)
└── CameraRig          (Node3D — Camera3D added here by Main scene)
```

### `Camel.tscn` (CharacterBody3D, layer 2)
```
Camel
├── BodyMesh    (CapsuleMesh, variant color)
├── NeckMesh    (CapsuleMesh, variant color)
├── HeadMesh    (SphereMesh, variant color)
├── HumpMesh    (SphereMesh, variant color)
├── CollisionShape3D
├── MountPoint  (Node3D at Y=2.55 — player sits here when mounted)
├── CartAnchor  (Node3D at X=-1.8)
│   ├── CartMesh  (BoxMesh, dark wood)
│   ├── WheelL / WheelR (BoxMesh, darker brown)
├── NameLabel3D (Label3D above camel showing variant info)
└── InteractArea (Area3D, radius 3.5 — player presses E to mount)
```

### `EnemyBrawler.tscn` (CharacterBody3D, layer 4)
```
EnemyBrawler
├── MeshInstance3D  (CapsuleMesh, RED)
├── CollisionShape3D
└── HPLabel3D       (Label3D above head)
```

### Props
```
Cactus (StaticBody3D, layer 8)
├── TrunkMesh   (CylinderMesh, GREEN)
├── ArmLeft / ArmRight  (CylinderMesh, GREEN, rotated)
└── CollisionShape3D

Rock (StaticBody3D, layer 8)
├── MeshInstance3D  (BoxMesh, GREY)
└── CollisionShape3D

LootChest (StaticBody3D, layer 8)  ← loot_chest.gd
├── BaseMesh        (BoxMesh, GOLD)
├── LidPivot (Node3D)  ← lid rotates on X when opened
│   ├── LidMesh     (BoxMesh, GOLD)
│   └── LatchMesh   (BoxMesh, darker gold)
├── CollisionShape3D
├── InteractArea    (Area3D)
└── PromptLabel3D   (Label3D "[E] Open Chest")
```

---

## Mounting System
- Walk near camel → its `InteractArea` overlaps player
- Press **E** → `player.mount(camel)` called
  - `is_mounted = true`, player's collision layer disabled
  - Every physics frame: `player.global_position = camel.MountPoint.global_position`
  - Player rides on top of the camel while it marches
- Press **E** again → `player.dismount()` → ejected 2.5 units to the side
- **Mobile**: MOUNT/DISMOUNT button in the bottom-right cluster

## Camel Leash / Distance System
If the player gets more than **28 units** behind the camel, they take **8 HP/sec** damage
and a red "RETURN TO CAMEL" banner flashes at the top of the HUD. Sprint to catch up!

---

## Collision Layers (3D)
| Layer | Bit | Entity |
|-------|-----|--------|
| 1  | 0001 | Player |
| 2  | 0010 | Camel |
| 3  | 0100 | Enemies |
| 4  | 1000 | Static environment |

Player mask = 14 (0b1110) → camel + enemies + statics  
Enemy mask  =  3 (0b0011) → player + camel  
Statics mask= 0 (blocks only, no active detection)  

---

## Input Map
| Action | Key |
|--------|-----|
| move_left / right / up / down | WASD |
| sprint | Left Shift |
| interact | E (mount/dismount/loot) |
| attack | Left Mouse Button |
| inventory_toggle | I |

---

## Camel Variant Table
| Variant | Roll | Speed | Cart at 20 slots |
|---------|------|-------|-----------------|
| White (Rare 10%) | 0–9 | ×1.30 | ×0.78 effective |
| Black (Uncommon 25%) | 10–34 | ×1.15 | ×0.69 effective |
| Brown (Common 50%) | 35–84 | ×1.00 | ×0.60 effective |
| Orange (Common 15%) | 85–99 | ×0.85 | ×0.51 → clamped to ×0.60 |

Cart penalty: –10% per 5 items, minimum 60% of base.

---

## Web Export
1. Project → Export → Add Preset → Web
2. Install templates if prompted
3. Export All → `exports/web/index.html`
4. Serve via HTTPS or localhost only (SharedArrayBuffer requirement)
   ```
   python3 -m http.server 8080
   ```
   Then visit `http://localhost:8080/exports/web/`

---

## Replacing Placeholder Meshes
To swap in real art later:
1. Open the relevant `.tscn` in Godot editor
2. Select the `MeshInstance3D` node
3. Replace `mesh` property with your `GLB/GLTF` mesh
4. Remove `material_override` (use the mesh's own materials)
The scripts are mesh-agnostic — only groups and node paths matter.
