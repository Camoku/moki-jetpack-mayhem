# Moki Jetpack Mayhem — PRD & Checklist

> **This is the living source-of-truth document.** Update it after every feature:
> tick the checklist, move ideas out of the Parking Lot, jot decisions. Keep it
> honest about what's actually built and tested.
>
> Technical "how it works" map lives in `README.md`. This doc is the *what & why & next*.

---

## 1. Vision

A fast, silly, replayable **auto-scrolling jetpack runner** starring a mischievous
Moki. You weave through an escalating gauntlet of hazards, grab coins and powerups,
survive special **events**, and chase a high score / best distance. Short runs, instant
restart, "one more go" energy.

**The feel we're chasing:** always fair (every danger is telegraphed), always fresh
(the run keeps changing), increasingly tense (smooth difficulty ramp), with satisfying
reward beats so it's not pure stress.

## 2. Design pillars (rules we hold to)

1. **Fair, never cheap** — every hazard has a tell (charge-up, "!" warning, intro beat).
   Safe routes are guaranteed by construction (leave-one-out gaps), not luck.
2. **Variety = freshness** — mix hazard / reward / environmental events; no event twice
   in a row; events stay ≤10s.
3. **Smooth, time-appropriate escalation** — difficulty ramps gradually; on-screen
   density is capped so it never becomes soup.
4. **Tension *and* reward** — calm breathers, reward events, and clean-sweep bonuses
   balance the pressure.
5. **Everything tunable** — gameplay values are `@export` knobs, not magic numbers.
6. **Beginner-readable code** — clean, well-commented GDScript; explain concepts.

## 3. Current status (2026-06-18)

Core loop, movement, scoring, save system, 8 hazard types, 7 powerups, coins, a
7-event rotation, a full **boss progression** (3 mini-bosses → a main boss → endless
overdrive), **milestone-gated unlocks**, and a **celebration/juice layer** (speed burst +
shake + flash + fireworks) are **built and compile-clean**. Biggest gap: **no upgrade store
yet** (coins bank but can't be spent), and no audio. **Real art has started**: the Moki
(animated, with idle/boost + tilt), its particle jetpack flame, and the coins now use real
sprites; everything else is still placeholder rectangles. Balance is unverified by real
playtesting in places (noted per item).

---

## 4. Feature checklist

### ✅ Done
- [x] **Core loop** — gravity + jetpack, auto-scroll, crash → game over → restart
- [x] **Free movement** — Moki flies up/down *and* left/right within the screen
- [x] **Camera** — decoupled constant scroller; vertical view locked; pinned floor
- [x] **Background** — black starfield (parallax) that tints with distance
- [x] **Scoring** — live Distance (m); end-of-run Score = distance × mult; tiered coin multiplier
- [x] **Persistence** — `GameState` autoload saves high_score / best_distance / coins to disk
- [x] **HUD** — distance, multiplier, coins, best, status line, banners, game-over panel
- [x] **Hazards** — asteroids (+drift), vertical laser, horizontal laser, beam gates, missiles,
      **bouncing orbs** (zig-zag), **crusher gates** (timing; clear lane while passing), **homing drones**
- [x] **Pickups** — coins (bank + multiplier), **spin tokens** (rare; spent on the end-of-run slot machine)
- [x] **Powerups (7)** — Shield, Ghost, Magnet, Doubler, **Dash** (invincible rocket burst),
      **Tiny Moki** (shrink to slip through), **Second Chance** (held revive, rare spawn via
      `powerup_weights`). Clean-sweep Highway/Coin Rush now also grant +coins + a free shield.
- [x] **Pacing** — wave system (busy/breather), difficulty ramp, scaling hazard cap
- [x] **Spawn clearance** — pickups never overlap hazards (radius-based)
- [x] **Events (7):** Laser Frenzy, Asteroid Storm, Missile Barrage, Boost Highway,
      Coin Rush, Narrow Cave, **Blackout** — fair weighted rotation, no repeats, clean-sweep rewards
- [x] **2D lighting** — `CanvasModulate` darkness + per-object `PointLight2D` glows
      (coins/asteroids/Moki), driven by `GameState.blackout` (for the Blackout event)
- [x] **Bosses** — one `Boss.tscn`/`boss.gd` driven by `kind`; the boss slot is every 3rd
      event. Dodge the telegraphed attack, fly into the exposed core during OVERHEAT to
      deplete HP (kill → reward, time out → retreat). HUD boss health bar (per-boss name).
  - [x] **3 mini-bosses:** Laser Cannon (beams), Missile Frigate (missile volleys),
        Meteor Golem (asteroid waves) — appear in turn.
  - [x] **Main boss: DREADNOUGHT** — unlocked once all 3 minis are defeated; bigger, 8 HP,
        cycles Laser-Frenzy walls + missiles + meteors. Beating it grants a **huge bonus**
        (big coin payout + run-long score-mult bump + free shield).
  - [x] **Endless overdrive** — after the main boss, regular events escalate past the cap
        and the boss rotation recurs (buffed). All per-run.
- [x] **Milestone progression** — obstacles/events unlock by *earned progress* (`_progress`),
      not a clock: +1 per event survived, +2 surge per boss beaten (which also bumps intensity
      via `_surge()`). Run starts on basics, opens up as you clear challenges. Per-run.
- [x] **Celebration / juice** — clearing an event (small) or beating a boss (big) fires a
      burst: speed boost (camera) + screen shake + symmetric **fireworks** (`Fireworks.tscn`)
      + an "EVENT CLEARED!" banner (boss adds a gold screen-flash).
- [x] **Reward chests** — all rewards are now a **chest** (`Chest.tscn`/`chest.gd`) you fly
      over to claim (coins + a powerup): after a Frenzy, a perfect Highway/Coin Rush sweep,
      and the Choice Gate.
- [x] **Choice Gate** (post-boss) — a 3s split-screen decision (`Phase.CHOICE`): **RISK**
      (above) = ~10s of full-screen chaos; a hit *fails the event* (no reward) but doesn't end
      the run — survive → a chest. **SAFE** (below) = a sped-up scramble for scattered coins.
      The **DREADNOUGHT** drops a **GRAND chest** (double coins + Ghost + run-long mult).
- [x] **Spin tokens + slot machine** — a rare violet **spin token** pickup
      (`SpinToken.tscn`/`spin_token.gd`, scrolls like a coin, glows in Blackout) banks one
      *spin* for the run (use-it-or-lose-it, never saved). On a crash *with* spins, the HUD
      opens a **slot machine** (`hud.gd`) instead of game-over: each Space press spends a token
      and rolls a weighted reel landing on **small / medium / mega coin win**, **shield next
      run** (`GameState.start_with_shield`, consumed in `player._ready`), or **REVIVE** —
      which resumes the very same run where you fell (`player.revive()`, i-frames). Out of
      spins → on to the normal game-over screen. Coin wins bank immediately.

### 🔜 To build (roughly in priority order)
- [ ] **Upgrade Store** *(next — the big one)*. End-of-run shop to spend banked coins on
      permanent upgrades. Suggested sub-tasks:
  - [ ] Store data model in `GameState` (owned upgrades + levels, saved to disk)
  - [ ] Store UI screen (reachable from game-over; show coins, items, buy buttons)
  - [ ] Apply purchased upgrades at run start (read in `player.gd` / `spawner.gd`)
  - [ ] Starter upgrade set: e.g. *Start with a Shield*, *+base multiplier*,
        *longer powerups*, *bigger magnet*, *coin value +*
  - [ ] Balance upgrade costs vs coin income
- [ ] **More juice/feel** — *(celebration bursts + shake + fireworks done)*; still want crash
      shake + crash particle burst + jetpack trail, and a **combo/streak** meter
- [ ] **Audio** — jetpack whoosh, coin ding, crash boom, event stingers, music
- [~] **Real art** — *in progress.* Done: the **Moki** (24-frame `AnimatedSprite2D`,
      idle/run/boost + velocity tilt), a **particle jetpack flame** (`jet_flame.gd`),
      **spinning coins** (6-frame 32×32 sheet, desynced), **asteroids** (rock sprite +
      random tumble; also Storm meteors / Golem boss), and a **parallax city background +
      scrolling tech floor** (mirror-doubled seamless tiles; floor raised for a better view,
      with `floor_y`/spawn-limits/hazard-floors realigned), and the **6 powerups with art** (Magnet, Doubler, Shield, Tiny, Dash, Ghost; only Second Chance is still a badge)
      (data-driven `SPRITE_ART`: sprite + dark disc + glow to pop). Still rectangles: beams, lasers,
      the other powerups, bosses' bodies, HUD. (Art lives in `res://sprites/`; see README "Art & animation".)
- [ ] **Disk-persist owned upgrades** (part of store, but call it out)

### 🅿️ Parking lot (ideas, not committed)
- More events: **Wind Gusts**, **Reverse-gravity zone**
- More mini-bosses (the cannon is the first; the fight framework can host others)
- Daily challenge / seed runs
- Cosmetic Moki skins (bought with coins)
- Combo/streak scoring; near-miss bonus
- Settings menu (volume, controls), pause screen
- Mobile/touch controls

---

## 5. Next up

**Upgrade Store** — coins already bank permanently; this gives them a purpose and adds
the meta-progression hook. Start a fresh session in plan mode targeting the sub-tasks
above.

## 6. Workflow (how we build)

1. Pick the next checklist item → **new session, plan mode** for just that feature.
2. Approve the plan → implement (fresh context) → **test** (run via godot MCP, watch for
   errors; user playtests feel).
3. **Update this doc** (tick the box, note decisions/balance) and `README.md` if the
   structure changed.
4. **Commit** with a clear message. Repeat.

*Caveat that always applies:* the assistant can't see the running game — it verifies
compile/runtime cleanliness, but **feel and balance need a human playtest.**
