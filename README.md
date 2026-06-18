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
| `camera.gd` | Constant world scroll + a temporary **boost gear** (`current_speed()`) + screen `shake()` |
| `spawner.gd` | Wave/event director: spawns hazards, pickups, events; runs progression + celebrations |
| `hud.gd` | Distance/coins/multiplier, status line, banners, boss bar, screen `flash()`, game-over screen |
| `fireworks.gd` / `Fireworks.tscn` | One-shot `CPUParticles2D` spark burst, popped on the HUD when you clear an event / beat a boss |
| `game_state.gd` | **Autoload** — saves high_score / best_distance / coins; also holds runtime `blackout` (0→1) |
| `background.gd` | Slowly tints the space color with distance |
| `darkness.gd` | On a `CanvasModulate` — dims the world by `GameState.blackout` (the Blackout event) |

### Hazards
| Scene / Script | Hazard |
|---|---|
| `Obstacle.tscn` / `obstacle.gd` | Asteroid (can drift; storm meteors use `extra_speed`) |
| `VerticalLaser.tscn` / `vertical_laser.gd` | Solid full-height laser, screen-locked, charge→fire |
| `HorizontalLaser.tscn` / `horizontal_laser.gd` | Solid full-width laser, charge→fire |
| `BeamObstacle.tscn` / `beam_obstacle.gd` | Floating capped laser bar (H or V) |
| `Missile.tscn` / `missile.gd` | Warns ("!") at the right edge, then strikes left |
| `CaveWall.tscn` / `cave_wall.gd` | One tunnel slice (top+bottom walls + gap) for the Cave event |
| `BounceOrb.tscn` / `bounce_orb.gd` | Ball that drifts left while bouncing roof↔floor (a zig-zag) |
| `Crusher.tscn` / `crusher.gd` | A gate whose two blocks slam open/shut on a cycle — time the gap |
| `Drone.tscn` / `drone.gd` | Small enemy that slowly homes your height, then commits once it passes |
| `Boss.tscn` / `boss.gd` | Every boss (one scene, `kind` picks which); reuses the hazards as its attacks |

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
| **Blackout** | environment | Lights out + **fog of war**: coins/hazards only glow when near the Moki. Survive 7s. |

A perfect Highway/Coin Rush, or a cleared Frenzy, drops the shared **reward** (a
powerup + a 10×10 coin block) via `_enter_reward()`.

### How the Blackout lighting works (the 2D-lighting trick)
Godot's 2D lighting has two halves, and Blackout uses both:
- A **`CanvasModulate`** (the `Darkness` nodes) multiplies the whole world's colour.
  At white it does nothing; we tween it toward near-black to "turn off the lights."
  It does **not** touch the HUD (separate `CanvasLayer`) or 2D lights.
- A **`PointLight2D`** (a "Glow") on each coin, asteroid, and the Moki is *added back*
  on top of the darkness — so in the dark, those glows are the only thing you see.

**Fog of war (the difficulty knob):** a coin/asteroid glow doesn't just switch on in
the dark — its brightness also fades with **distance to the Moki** (`_vision()` in
`coin.gd` / `obstacle.gd`: `1.0` within `VISION_NEAR`, ramping to `0.0` by `VISION_FAR`).
So far-off things stay hidden and only loom into view as they approach — it's a reaction
test, not a read-the-whole-board test. Hazards use a *larger* radius than coins so
dodging stays fair; shrink these consts to make it harder.

One shared number, **`GameState.blackout`** (0 = lights on, 1 = full dark), drives it
all: `darkness.gd` reads it for the dim; each glow reads it for its brightness. The
spawner tweens it 0→1 on `_enter_blackout()` and 1→0 when the event ends, and resets it
to 0 in `_ready()` (it's an autoload value, so it must be cleared each run). Note:
`ParallaxBackground` is its own `CanvasLayer`, so it needs its **own** `CanvasModulate`
(there are two `Darkness` nodes — one for the world, one for the background).

### Bosses — the every-3rd-event progression
Not a random pick: the spawner counts events and makes **every `boss_every` (3)** one a
boss (`Phase.BOSS`, `_enter_boss()`), after `boss_min_time`. The Moki has no weapon, so
every boss is the same dodge-then-punish loop in `boss.gd` — only the attack and looks
change, switched by **`kind`** (the "one scene, a `kind` picks behaviour" pattern):

- **INTRO** — announcement banner plays while the boss waits off-screen, then it drops in
  (`arrive_delay`) and the HUD HP bar appears (with the boss's name).
- **ATTACK** — fires a telegraphed pattern (per kind, below); the core is sealed.
- **OVERHEAT** — the attack stops, the **core** glows and becomes touchable; fly the Moki
  into it (`Core.body_entered`) for −1 HP (short `hit_cooldown`).
- Loop until **HP 0 → destroyed** (→ reward) or **`max_time` → retreat** (no reward).

Only a boss's **attack** is deadly — the housing is scenery and the core is *beneficial*
(no cheap "touched it = dead"). Attacks all reuse existing hazards: **cannon** = sweep/lane
beams; **frigate** = telegraphed missile volleys; **golem** = fast asteroid waves; **main
(DREADNOUGHT)** round-robins the **Laser-Frenzy walls** (vertical / horizontal / combined
safe-pocket) + missiles + meteors.

**Progression (per-run, in `spawner.gd`):** the three mini-bosses (`cannon`, `frigate`,
`golem`) appear in turn; the gate is **defeat**, not encounter (`_bosses_defeated`) — a
failed mini recurs until beaten. Once all three are down, the next boss slot is the
**main boss**. Beating it (`boss_defeated("main")`) grants the **huge bonus** — a big coin
payout (`hud.add_coin`), a run-long score-mult bump (`hud.add_bonus_multiplier`), and a
free shield — and flips on **overdrive** (`_overdrive()`, ramps from `_main_defeat_x`).
Overdrive makes regular play escalate past the normal cap (shorter spawn gaps, higher
hazard cap, more events/missiles) **and** keeps bosses recurring, buffed (`+HP`, faster).
Key knobs: `boss_every`, `boss_min_time`, `main_recur_every`, `boss_bonus_coins`,
`boss_bonus_mult`; per-boss stats live in `boss.gd`'s `_configure_for_kind()`.

### Milestone progression (earned unlocks)
Obstacles/events aren't unlocked on a clock — they're **earned**. A per-run `_progress`
counter rises as you clear challenges: **+1 per event survived**, **+2 (a surge) per boss
beaten**. Each thing has a level in the `UNLOCK_LEVEL` dict and is gated by `_unlocked(key)`
(`_progress >= level`). So the run starts on basics (asteroids/beams/coins/rings + Storm +
Coin Rush) and opens up — orbs/missiles → lasers/Frenzy → drones/Highway → Barrage → Cave →
Crushers → Blackout — with **boss kills surging several unlocks at once**. Distance still
drives *intensity* (`_difficulty()`); a mini-boss kill also bumps `_boss_power`, folded with
post-main overdrive into `_surge()` (faster spawns / higher cap). All per-run.

### Celebration / juice (the payoff)
Clearing an event or beating a boss fires `_celebrate(big)`: a **speed boost** (camera boost
gear), a **screen shake** (`camera.shake()`), **symmetric fireworks** (`Fireworks.tscn`,
popped on the HUD — one from each side for an event; both sides + middle for a boss), and a
banner ("EVENT CLEARED!"; bosses add a gold `hud.flash()`). Coin Rush also speeds the whole
world up (`coinrush_speed_mult`) for a real challenge, and the reward block always drops a
**Magnet** so you can vacuum the coins behind it.

---

## Pacing & anti-clutter
- **Difficulty** = 0→1 over `ramp_distance` (13000px). Drives spawn speed, laser odds,
  missile frequency, event intensity.
- **Hazard cap**: on-screen asteroids+beams are capped (3 early → 8 deep) so the
  screen never becomes soup. Lasers/events bypass it.
- **Clearance**: pickups never spawn on hazards — `_overlaps()` uses each object's
  `clear_radius()` so even long beams/cave walls keep their whole length clear.
- **Extra obstacles**: bouncing orbs and homing drones mix into the normal hazard pick
  (`_spawn_something`, unlocked by `orb_min_time`/`drone_min_time`, so they share the cap).
  **Crusher gates** run on their own timer and get a **clear lane**: while one is passing,
  other hazards/missiles pause (`_crusher_clear`) and no second gate spawns, so you can
  hover and time the gap fairly.

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
- More events: **Wind Gusts**, **Reverse-gravity zone**; more mini-bosses.
- Sound/juice (screen shake, particles), real Moki art.
