# Moki Jetpack Mayhem

A silly, fast, horizontal auto-scrolling jetpack game starring a mischievous Moki.
Built in **Godot 4.6** as a learn-as-we-go project. (Art is still colored-rectangle
placeholders.)

## How to run
Open the folder in Godot 4.6+ and press **F5** (main scene is `Main.tscn`).

**Controls**
- **Space / Left-Click** — fire the jetpack (hold to rise)
- **A / D or ← / →** — move left/right within the screen
- After a crash, **Space** restarts.

---

## The big picture

- The **camera** auto-scrolls the world to the right forever (`camera.gd`). The Moki
  is *carried* along at that speed and flies freely **within the visible screen**.
- The **spawner** (`spawner.gd`) is the brain: it runs a wave system and decides what
  appears — hazards, pickups, and special **events**.
- The **HUD** (`hud.gd`) tracks the run: live distance, coins, multiplier, the
  status line, banners, and the game-over screen.
- **`GameState`** (autoload) saves your best distance, best score, and banked coins
  to disk.

### Scene tree (`Main.tscn`)
```
Main (Node2D)
├── Background (ParallaxBackground)  — black space, 2 star layers, pinned floor
├── Player (CharacterBody2D)         — the Moki  [player.gd]
│   ├── CollisionShape2D / Sprite2D / Jetpack / Flame / Shield (bubble)
├── Camera (Camera2D)                — world scroller  [camera.gd]
├── ObstacleSpawner (Node2D)         — spawns everything  [spawner.gd]
└── HUD (CanvasLayer)                — UI  [hud.gd]
```

---

## Files at a glance

### Core
| File | What it does |
|---|---|
| `player.gd` | Moki movement (gravity, jetpack, free left/right), crash, powerup effects |
| `camera.gd` | Constant world scroll + a temporary **boost gear** (`current_speed()`) |
| `spawner.gd` | Wave/event director: spawns hazards, pickups, and runs all events |
| `hud.gd` | Distance/coins/multiplier, status line, banners, game-over screen |
| `game_state.gd` | **Autoload** — saves high_score / best_distance / coins to `user://save.cfg` |
| `background.gd` | Slowly tints the space color with distance |

### Hazards
| Scene / Script | Hazard |
|---|---|
| `Obstacle.tscn` / `obstacle.gd` | Asteroid (can drift; storm meteors use `extra_speed`) |
| `VerticalLaser.tscn` / `vertical_laser.gd` | Solid full-height laser, screen-locked, charge→fire |
| `HorizontalLaser.tscn` / `horizontal_laser.gd` | Solid full-width laser, charge→fire |
| `BeamObstacle.tscn` / `beam_obstacle.gd` | Floating capped laser bar (H or V) |
| `Missile.tscn` / `missile.gd` | Warns ("!") at the right edge, then strikes left |
| `CaveWall.tscn` / `cave_wall.gd` | One tunnel slice (top+bottom walls + gap) for the Cave event |

### Pickups
| Scene / Script | Pickup |
|---|---|
| `Coin.tscn` / `coin.gd` | Coin — banks currency + builds the end-of-run multiplier |
| `Powerup.tscn` / `powerup.gd` | One scene, `type` picks the effect: shield / magnet / doubler / ghost |
| `BoostRing.tscn` / `ring.gd` | Fly through for a speed boost |

---

## Scoring & coins
- **Distance** (metres) shows live; **Score** = `distance × score_per_meter × multiplier`
  is revealed at game over.
- **Multiplier** is tiered: every `coins_per_tier` (25) coins adds `+0.1`.
- Coins also **bank** as permanent currency (for a future upgrade store).

## Powerups (all 5s)
- **Shield** — absorbs one hit (one-shot). | **Ghost** — fly through everything
  (rainbow pulse) + i-frames after. | **Magnet** — pulls coins in. | **Doubler** —
  coins count double.

---

## The event system
After a calm **breather**, there's an `event_chance` (0.55) to run a special event.
The pick is a **weighted random** among eligible events (unlocked by time), **never
the same one twice in a row**. Calm events (Highway / Coin Rush) are weighted lower.
Each event is a `Phase` in `spawner.gd` with an `_enter_*` + spawn function, a banner,
and (for survival events) a `SURVIVE Ns` countdown.

| Event | Flavor | What happens |
|---|---|---|
| **Laser Frenzy** | hazard | Synchronized laser formations (V / H / combined), one safe lane. 10s. |
| **Asteroid Storm** | hazard | Fast meteors rush in from the right. 8s. |
| **Missile Barrage** | hazard | Telegraphed volleys of missiles, thread the gaps. 8s. |
| **Boost Highway** | reward | Chain of strong boost rings on a sine path. Hit all → "BOOST MASTER!" |
| **Coin Rush** | reward | Stream of coins on a sine path. Grab all → "COIN MASTER!" |
| **Narrow Cave** | environment | Thread a winding tunnel of wall slices. 8s. |

A perfect Highway/Coin Rush, or a cleared Frenzy, drops the shared **reward** (a
powerup + a 10×10 coin block) via `_enter_reward()`.

---

## Pacing & anti-clutter
- **Difficulty** = 0→1 over `ramp_distance` (13000px). Drives spawn speed, laser odds,
  missile frequency, event intensity.
- **Hazard cap**: on-screen asteroids+beams are capped (3 early → 8 deep) so the
  screen never becomes soup. Lasers/events bypass it.
- **Clearance**: pickups never spawn on hazards — `_overlaps()` uses each object's
  `clear_radius()` so even long beams/cave walls keep their whole length clear.

---

## Tuning knobs (all `@export`, edit in the Inspector)
- **Player**: `gravity`, `boost_power`, `move_speed`, powerup durations, `*_invuln_time`
- **Camera**: `scroll_speed`, `boost_multiplier`
- **Spawner**: `ramp_distance`, `min_interval`, `max_hazards_*`, every `*_min_time`
  (when events unlock), `event_chance`, `highway_weight`, and per-event tuning blocks
- **HUD**: `pixels_per_meter`, `score_per_meter`, `coins_per_tier`, `multiplier_per_tier`

---

## Save data
`user://save.cfg` (a `ConfigFile`) under `%APPDATA%/Godot/app_userdata/Moki Jetpack Mayhem/`.
Stores `high_score`, `best_distance`, `coins`. Delete it to reset progress.

## Ideas not yet built
- **Upgrade store** — spend banked coins on permanent boosts (the big next feature).
- More events: **Laser Cannon mini-boss**, **Blackout**.
- Sound/juice (screen shake, particles), real Moki art.
