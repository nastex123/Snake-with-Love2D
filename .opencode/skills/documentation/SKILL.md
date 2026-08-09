---
name: documentation
description: Manage project documentation in docs/ folder: GDD, Roadmap, TDD, Changelog, TODO. Apply project code standards (ECS-style systems, no globals, object pooling, config in config.lua, logger, file size limits). Use when creating, updating, or reviewing project documentation OR when writing/refactoring game code. Always update docs at the end of each task. Always iterate until the program is functional and the log is clean.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: documentation
---

# Documentation Skill

Manage all project documentation in the `docs/` folder and enforce project-wide code architecture rules. This skill defines the structure, format, update rules, and coding standards for the project.

## Documentation Structure

```
docs/
├── GDD.md          # Game Design Document
├── ROADMAP.md      # Project roadmap with phases
├── TDD.md          # Technical Design Document
├── CHANGELOG.md    # Chronological change history
└── TODO.md         # Pending tasks and backlog
```

## When to Use

- At the **end of every task**: update CHANGELOG and TODO
- When starting a **new feature**: update ROADMAP and TDD if architecture changes
- When **game mechanics** change: update GDD
- When **adding/removing modules**: update TDD
- When writing or refactoring game code: apply the Code Architecture Rules below

## Definition of Done

1. **Iterate until functional**: the program must actually run without errors before a task is considered complete. Do not stop at a partial implementation; keep iterating (`love .`) until it works.
2. **Check the log for errors**: after EVERY change, inspect the Love2D log and console output for errors and new runtime warnings. Go through the process without expecting a final chance to check.
3. Only update CHANGELOG/TODO after passing both checks above.

## Changelog Format

```
## DD:MM:YYYY

- **category** (status - HH:MM): Description of the change
```

### Categories
- `feature` - New functionality
- `fix` - Bug fix
- `refactor` - Code restructuring
- `docs` - Documentation changes
- `balance` - Game balance adjustments
- `polish` - Visual/audio/UX improvements

### Status
- `completed` - Finished
- `in_progress` - Started but not finished
- `created` - File/section created
- `updated` - Existing content modified
- `removed` - Feature/content removed

### Example
```
## 08:08:2026

- **refactor** (completed - 16:00): Split main.lua into gamestate/input/transitions modules
- **docs** (updated - 16:00): TDD.md reflects new module layout
```

## Update Rules

1. **CHANGELOG**: Add entry at the top (newest first), use current date/time
2. **TODO**: Mark completed tasks, add tasks discovered during work
3. **ROADMAP**: Update phase status when milestones are reached
4. **TDD**: Update when architecture changes (new modules, renamed systems)
5. **GDD**: Update when game mechanics change

## Cross-References

- Link between documents instead of duplicating information
- AGENTS.md is the source of truth for technical implementation details
- GDD references TDD for technical specifics
- TODO references ROADMAP phases

---

# Code Architecture Rules

Standards for all game code. These rules take priority over pre-existing legacy code — new code must follow them, and refactors should migrate legacy code toward them.

## Systems over Entities

Entities hold state. Systems process entities.

- Entity = data (position, velocity, health, state)
- System = logic (`MovementSystem.dt`), (`AISystem.dt`), (`CollisionSystem`), (`RenderSystem`)

Example:

```
MovementSystem
AISystem
CollisionSystem
RenderSystem
```

## No Global State

Do not use global variables.

Incorrecto:

```lua
player = {}
enemies = {}
```

Correcto:

```lua
local Player = {}
return Player
```

Or managed from a `World`.

## Local Tables

Always use `local`.

```lua
local sqrt = math.sqrt
local random = love.math.random
```

Reduces global lookups.

## Object Reuse

Do not create tables every frame.

Incorrecto:

```lua
function update()
    local temp = {}
end
```

Correcto:

```lua
local temp = {}

function update()
    temp.n = 0
end
```

## Object Pooling

Use object pools for:

- bullets
- particles
- effects
- temporary enemies

Avoids constant create, destroy, and garbage collection.

## Garbage Collector

Minimize allocations:

- Avoid `concatenar` strings in a loop constantly
- Avoid creating temporary vectors per frame
- Avoid creating closures per frame

Example:

```lua
-- mal
text = "HP: " .. hp
-- mejor
ui.hp = hp
```

## Data-Driven Design

Configure entities from data tables instead of hardcoded numbers.

```lua
SLIME = {
    speed = 40,
    hp = 30,
    aggro = 96,
    split = true
}
```

## Explicit States

Use enums, not strings, for state.

```lua
State = {
    IDLE = 1,
    CHASE = 2,
    ATTACK = 3,
    STUN = 4
}
```

## Decoupled Timers

Avoid multiple loose counters. Use a `timer manager`.

```lua
timer:after(1.5, function()
    attackReady = true
end)
```

## Deterministic Update

Keep system order consistent.

Recomendado:

```
Input
AI
Movement
Collision
Damage
Effects
Cleanup
```

## Separate Render

Never mix logic and drawing.

Incorrecto:

```lua
function slime:update(dt)
    self.x = self.x + 10 * dt
    love.graphics.circle(...)
end
```

Correcto:

```lua
slime:update(dt)
slime:draw()
```

## Decoupled Camera

The camera must not live inside the player. It is an independent system.

## Canvas and Resolution

Use a virtual resolution, e.g. `320×180`, `400×225`, `640×360`, with integer scaling when possible.

## Draw Calls

Batch rendering. Prefer `SpriteBatch`, `Canvas`, and sprite atlases. Avoid constant changes of `shader`, `canvas`, and `blend mode`.

## Collisions

Separate broad phase from narrow phase. Use a spatial/grid hash when there are many enemies.

## Modular AI

Enemy AI must not depend directly on the player. Pass context:

```lua
slime:updateAI(dt, world, pack)
```

Never:

```lua
slime:updateAI(player)
```

## Centralized Config

Create `config.lua`.

```lua
Config = {
    canvasWidth = 320,
    canvasHeight = 180,
    tileSize = 16
}
```

## Logging

Create a `logger` and use `Log.info(...)`, `Log.warn(...)`, `Log.error(...)` instead of `print()` scattered across the project.

## Technical Changelog

Every significant code change must update:

- `docs/TDD.md`
- `docs/CHANGELOG.md`

## Naming Conventions

- Files: `slime.lua`, `enemy_manager.lua` (snake_case)
- Variables: `playerSpeed`, `maxHealth`
- Constants: `MAX_ENEMIES`, `TILE_SIZE`

## Golden Rule

If a file exceeds 300–500 lines, evaluate splitting it into smaller modules.

---

# Templates

## GDD Sections
1. Overview (genre, platform, objective)
2. Core Mechanics (movement, collision, scoring)
3. Enemies (types, behaviors)
4. Items (list, effects)
5. Boss (mechanics, attacks)
6. Progression (stages, rooms)
7. Visual Style
8. Audio

## TDD Sections
1. Architecture Overview
2. Module Dependencies
3. State Machine
4. Data Flow
5. Rendering Pipeline
6. Persistence Layer
7. Key Algorithms

## ROADMAP Sections
1. Phase Name
2. Goals
3. Features
4. Status (Not Started / In Progress / Completed)