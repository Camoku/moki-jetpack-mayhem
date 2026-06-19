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
├── Background (ParallaxBackground)  — parallax city skyline + scrolling tech floor
├── Player (CharacterBody2D)         — the Moki  [player.gd]
│   ├── CollisionShape2D / Moki (AnimatedSprite2D, + Flame particles child) / Shield / Glow
├── Camera (Camera2D)                — world scroller  [camera.gd]
├── ObstacleSpawner (Node2D)         — spawns everything  [spawner.gd]
└── HUD (CanvasLayer)                — UI  [hud.gd]
```

---

## Files at a glance

### Core
| File | What it does |
|---|---|
| `player.gd` | Moki movement (gravity, jetpack, free left/right), crash, powerup effects, sprite animation + tilt |
| `jet_flame.gd` | The jetpack exhaust — a `CPUParticles2D` (configured in code) that streams down while boosting |
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
| `Obstacle.tscn` / `obstacle.gd` | Asteroid — animated rock sprite (random tumble); can drift; storm meteors use `extra_speed` |
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
| `Coin.tscn` / `coin.gd` | Coin — animated spinning gold coin; banks currency + builds the end-of-run multiplier |
| `Powerup.tscn` / `powerup.gd` | One scene, `type` picks the effect: shield / magnet / doubler / ghost / dash / tiny / secondchance |
| `BoostRing.tscn` / `ring.gd` | Fly through for a speed boost |
| `Chest.tscn` / `chest.gd` | Reward chest — fly over it to bank coins + a powerup (every reward drops one) |
| `SpinToken.tscn` / `spin_token.gd` | Rare violet token — banks one **slot-machine spin** for this run (use-it-or-lose-it) |

---

## Scoring & coins
- **Distance** (metres) shows live; **Score** = `distance × score_per_meter × multiplier`
  is revealed at game over.
- **Multiplier** is tiered: every `coins_per_tier` (25) coins adds `+0.1`.
- Coins also **bank** as permanent currency (for a future upgrade store).

## Powerups
One `Powerup.tscn`; `type` picks the look (`powerup.gd`) + effect (`player.gain_powerup()`).
- **Shield** — absorbs one hit (one-shot). | **Ghost** — fly through everything (rainbow
  pulse) + i-frames after. | **Magnet** — pulls coins in. | **Doubler** — coins count double.
- **Dash** (`>>`) — an **invincible rocket burst**: i-frames + a strong camera boost (~2s),
  blast straight through hazards (reuses the boost gear, so no screen-edge clamp).
- **Tiny Moki** (`T`) — lerps the **Player node's `scale`** down (~0.55) for a few seconds so
  you slip through tighter gaps.
- **Second Chance** (`+1`) — a *held* revive token: in `crash()`, after shield, it's consumed
  to revive you once (banner + flash + i-frames) instead of game over. Spawns **rare** via
  the weighted `_pick_powerup_type()` (`powerup_weights`).
- The timed ones (magnet/doubler/ghost/tiny) live in the `timers` dict; Shield/Second Chance
  are held bools. A **perfect Highway / Coin Rush** sweep grants `sweep_bonus_coins` (+50) +
  a free Shield, on top of the reward block.

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
world up (`coinrush_speed_mult`) for a real challenge.

### Rewards & the Choice Gate
Every reward is now a **chest** (`Chest.tscn`/`chest.gd`) you fly over to claim — it banks
`coins`, grants a `powerup_type`, and (for the grand one) a run-long `bonus_mult`. A chest
drops after a **Laser Frenzy**, a perfect **Highway/Coin Rush** sweep (`_enter_reward(coins,
powerup)` → the REWARD window), and the Choice Gate.

The **Choice Gate** *replaces* the post-boss reward (`boss_defeated()` → `_enter_choice()`,
`Phase.CHOICE`):
- **Decide (~3s):** a faint, non-deadly divider line splits the screen — fly **above** for
  RISK, **below** for SAFE; your side locks in when the timer ends and the line vanishes.
- **RISK:** ~10s of full-screen chaos (asteroids + orbs + missiles). A hit **fails the event**
  (`player.protected` → `choice_failed()`, no reward) but does **not** end the run (a Shield /
  Second Chance still absorbs it and you keep going). Survive untouched → the screen clears and
  a reward **chest** drops to fly over.
- **SAFE:** the world speeds up and scattered coins rush by — scramble to grab them, no danger.
- The **DREADNOUGHT** flags `_choice_is_main`, so its survival chest is a **GRAND chest**
  (double coins + a Ghost + a score-multiplier bump) — bigger and gold/purple.

### Spin tokens & the slot machine
A **spin token** (`SpinToken.tscn` / `spin_token.gd`) is a rare violet pickup that drifts in
on its own slow timer in the spawner (`spin_token_interval_min/max`, ~20–32s; available from
the start). It scrolls and self-cleans like a coin, and reuses the **Blackout glow + fog-of-war**
trick so it's visible in the dark. Grabbing one calls `hud.add_spin_token()`, which bumps
`run_spins` (shown live on the `SpinLabel`). Spins are **use-it-or-lose-it**: per-run only,
never saved to disk.

When the Moki crashes, `player.crash()` hands off to **`hud.player_crashed()`** (instead of
straight to game over). If `run_spins > 0`, it opens the **slot machine** (`SlotPanel`) and
pauses the game — reusing the HUD's existing "process while paused" trick (the HUD is
`process_mode = Always`, which is also how the game-over retry key works). Each **Space** press
spends one token and rolls a flickering reel (animated in `hud._process`) for
`slot_spin_duration` seconds, then lands on a **weighted-random** reward (`_pick_slot_reward()`,
weights are `@export`):

| Reward | What it does |
|---|---|
| Small / Medium / Mega coin win | Banks coins straight to `GameState.coins` (saved immediately) |
| Shield next run | Sets `GameState.start_with_shield`; `player._ready()` consumes it into a free shield |
| **Revive** | `player.revive()` — un-pauses and resumes *this* run where you fell, with i-frames |

A revive does **not** clear `run_spins`, so leftover tokens stay usable if you crash again the
same run. When the spins run out, the next Space press calls `_finish_slots()` → the normal
`show_game_over()` (which banks `run_coins` and saves). With **no** tokens at all, a crash skips
the slot entirely and goes straight to game over, exactly as before.

The "shield next run" carry reuses the same **autoload-survives-reload** idea as
`GameState.blackout`: a runtime-only flag (not in `save_game`/`load_game`) that outlives
`reload_current_scene()` and is consumed once on the next `player._ready()`.

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

## Art & animation (sprites)
Real art lives in `res://sprites/`. We slice/play it with **`AnimatedSprite2D` + `SpriteFrames`**
(the beginner-friendly way to do frame animation — no `AnimationPlayer` needed):
- **The Moki** — `sprites/moki_0653_sprite_sheet.png` is one row of 24 frames (128×97).
  `sprites/moki_frames.tres` slices it into three looping animations: **`idle`** (0–15, standing),
  **`boost`** and **`run`** (both the 16–23 arms-out/striding cycle). `player.gd`'s
  `_update_moki_look()` picks: **boost** while the jetpack fires, **run** when resting on the
  floor (carried along), else **idle** gliding. It also **tilts the sprite** (`max_tilt`/
  `tilt_ref_speed`/`tilt_smooth`) nose-up rising / nose-down falling (flat when grounded). We
  tilt the *sprite*, not the Player, so the collision box stays square. `texture_filter = Nearest`
  keeps the pixel art crisp. (Scaled ~1.2× for presence; the flame child is counter-scaled so its
  tuning is unaffected.)
- **The jetpack flame** — `jet_flame.gd` on a `CPUParticles2D` under the Moki: soft round sparks
  streaming downward, tilting with the body, drawn *behind* it. `player.gd` toggles `emitting`
  with the boost button.
- **Coins** — `sprites/coins/coin_rot_anim.png` is a 6-frame 32×32 spin sheet;
  `sprites/coins/coin_frames.tres` slices it into the looping `spin`. `Coin.tscn`'s `Sprite`
  plays it (pixel art → Nearest filter, scaled ~1.7× to coin size); `coin.gd` randomises each
  coin's start frame + speed so a row doesn't spin in lock-step.
- **Asteroids** — `sprites/asteroid_brown.png` (single 160×160 pixel-art rock). `Obstacle.tscn`'s
  `Sprite` shows it (Nearest, ~0.52×); `obstacle.gd` gives each copy a random angle, flip, and slow
  tumble (rotating the *sprite* only, so the square hitbox is unchanged). Also covers Storm meteors
  and the Meteor Golem boss (same scene).

- **City background + floor** — in `res://sprites/backgrounds/`. `city_bg.png` is a green
  cyberpunk skyline shown on a slow parallax `CityLayer` (`motion_scale 0.4`); `city_floor.png`
  is a tech-panel strip on a `FloorTexLayer` that scrolls at world speed. Both source images
  don't tile on their own, so each is **mirror-doubled** (`image + its flip`) into a seamless
  loop, then repeated with the layer's `motion_mirroring` (kept wider than the screen so the
  wrap stays off-screen). The floor's surface was **raised** for a better view: the art top sits
  at y610, `player.gd`'s `floor_y` is 578 (so the Moki rests on it), and the bottom spawn limits
  (`max_y`, `coin_max_y`, storm/missile/orb/drone ranges) plus full-height hazards
  (`vertical_laser`/`cave_wall` `area_bottom`, `bounce_orb` `bounce_bottom`) were nudged to match.
  (The old starfield layers are still in the scene but hidden behind the opaque city.)

- **Powerup art (Magnet, Doubler)** — `sprites/powerups/`. `Powerup.tscn` is still "one scene,
  a `type` styles it": most powerups are coloured letter badges, but a type listed in
  `powerup.gd`'s **`SPRITE_ART`** table (data-driven: SpriteFrames + anim + glow colour + scale)
  hides the badge and shows the art on an `AnimatedSprite2D`, plus a dark contrast **disc**
  (`Backing`) and a **glow** (`PointLight2D`) so it pops off the green city. The sprite's
  `light_mask = 2` keeps the glow from tinting the art itself (the halo only lights the
  disc/background). **Magnet** = `magnet_frames.tres` (4-frame `shimmer`); **Doubler** =
  `x2_frames.tres` (a single static `idle` icon). Adding more powerup art = one row in
  `SPRITE_ART`. (Both source files were JPEGs with a baked checkerboard "transparency": the
  magnet's gray was keyed out by colour; the x2's white text had to be kept, so its background
  was removed by a **flood-fill from the image edges** instead.)

Adding more art later follows the same recipe: drop PNGs in `res://sprites/`, set the filter,
build a `SpriteFrames` (or just a `Sprite2D` for a single image), point a node at it. Beams,
lasers, the other powerups, the HUD, and bosses are still placeholder rectangles.

---

## Save data
`user://save.cfg` (a `ConfigFile`) under `%APPDATA%/Godot/app_userdata/Moki Jetpack Mayhem/`.
Stores `high_score`, `best_distance`, `coins`. Delete it to reset progress.

## Ideas not yet built
- **Upgrade store** — spend banked coins on permanent boosts (the big next feature).
- More events: **Wind Gusts**, **Reverse-gravity zone**; more mini-bosses.
- Sound/audio. (The Moki, its jetpack flame, and coins now have real art + animation;
  asteroids/beams/powerups/HUD are still placeholder rectangles.)
