# Game Design Document — Snake Dungeon Crawler

## 1. Overview

| Field | Value |
|-------|-------|
| **Genre** | Snake / Dungeon Crawler |
| **Platform** | Windows (Love2D 11.4+) |
| **Language** | Lua |
| **Objective** | Survive 25 rooms across 5 stages, defeat the boss |

## 2. Core Mechanics

### Movement
- Grid-based snake movement (WASD/Arrow keys)
- Speed adjustable in real-time (+/- keys)
- Snake grows when eating food

### Collision System
Order: Body → Obstacles → Boss → Projectiles → Enemies

Returns 5 values: `vivo, comio, enemyKilled, bossResult, attackHit`

### Scoring
- Points from food and enemy kills
- Combo system for consecutive kills
- High score persistence per profile

## 3. Enemies

| Type | Behavior |
|------|----------|
| **Chaser** | Pursues player directly |
| **Patroller** | Follows predetermined path |
| **Spawner** | Generates additional enemies |
| **Boss** | Multi-attack pattern, food-based defeat |

### Enemy Caps (during boss)
- Red (Chasers): max 3
- Blue (Patrollers): max 4

## 4. Items (12 total)

### Active Items (slots 1-3)
| Item | Effect |
|------|--------|
| Shield | Blocks one hit |
| Armor | Reduces damage |
| Ghost | Phase through enemies |
| Bomb | Destroys nearby enemies |
| Magnet | Attracts food |
| Hunger | Eat enemies for health |

### Passive Items
| Item | Effect |
|------|--------|
| SpeedReducer | Slows game speed |
| Turbo | Temporary speed boost |
| Slow | Slows enemies |
| Doubler | Double points |
| ExtraCoin | Bonus coins |
| Star | Invincibility |

## 5. Boss Mechanics

### Core Concept
- Boss is **invulnerable** to direct attacks
- Only defeated by collecting **15 non-coin foods** during encounter

### Attacks
| Attack | Description |
|--------|-------------|
| Projectile Spread | Radial projectiles |
| Spawn Adds | Summons patrollers |
| Radial Pulse | Shockwave damage |
| Teleport | Random repositioning |

### Boss Health Bar
- World-space display
- Smooth fill via lerp (6.0/s)
- Depletes as food is collected

## 6. Progression

```
5 Stages × 5 Rooms = 25 Rooms Total
```

### Room Types
- Corridor
- Arena
- Choke
- Hub
- Treasure
- Spawner
- Boss

### Flow
```
MENU → PLAYING → TRANSITION → SHOP → PLAYING → ...
PLAYING → DEATH_ANIMATION → HIGH_SCORE/SHOP → MENU
```

## 7. Visual Style

- Pixel art aesthetic (PressStart2P font)
- Procedural particle effects (4x4 texture)
- Post-processing shaders:
  - Bloom (glow → blurH → blurV)
  - CRT effect
  - Shadow blur
  - Heat distortion (menu)

## 8. Audio

- Single .ogg file with 4 segments:
  - Intro (1-9s)
  - Combo Enter (10-17s)
  - Combo Loop (13-17s)
  - Boss (18-24s)
- Seamless crossfade between combo segments
- Procedural SFX: eat, death, buy, shieldBreak, highScore, enemyKill, boss_food_tick, boss_defeated

## 9. Profiles System

- Max 3 profiles
- Per-profile stats: kills, bossesKilled, highestStage, highestScore, totalCoins
- Persistence in `config/profiles.dat`

## 10. Achievements (11 total)

| ID | Condition |
|----|-----------|
| first_kill | Kill first enemy |
| enemy_25 | Kill 25 enemies |
| enemy_100 | Kill 100 enemies |
| combo_5 | 5x combo |
| combo_10 | 10x combo |
| coins_100 | Collect 100 coins |
| coins_500 | Collect 500 coins |
| stage_3 | Reach stage 3 |
| boss_kill | Defeat boss |
| score_1000 | Score 1000 points |
| score_5000 | Score 5000 points |
