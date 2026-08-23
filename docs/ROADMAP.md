# Roadmap — Snake Dungeon Crawler

## Phase 1: Core Foundation ✅ Completed
**Goal**: Basic playable snake in dungeon environment

- [x] 18-module architecture
- [x] Game loop with 7 states
- [x] Grid-based movement
- [x] Collision detection
- [x] Food system (3 types)
- [x] Room generation (BSP dungeon)

## Phase 2: Enemies & Combat ✅ Completed
**Goal**: Enemy variety and boss encounter

- [x] Chaser enemy
- [x] Patroller enemy
- [x] Spawner enemy
- [x] Boss with 4 attack patterns
- [x] Boss defeat by food mechanic
- [x] Enemy caps during boss

## Phase 3: Items & Shop ✅ Completed
**Goal**: Item system and progression

- [x] 12 items (6 active, 6 passive)
- [x] Shop with 4x3 pagination
- [x] Item slots (1-3)
- [x] Coin economy

## Phase 4: Progression Systems ✅ Completed
**Goal**: Persistence and replayability

- [x] Profile system (max 3)
- [x] Per-profile stats
- [x] High score persistence
- [x] 11 achievements
- [x] Passive unlocks

## Phase 5: Visual & Audio Polish ✅ Completed
**Goal**: Aesthetic enhancement

- [x] Bloom shader
- [x] CRT effect
- [x] Shadow blur
- [x] Heat distortion
- [x] Particle system
- [x] Segmented music with crossfade
- [x] Procedural SFX

## Phase 6: UI & UX ✅ Completed
**Goal**: Polished user experience

- [x] Balatro-style intro
- [x] HUD with score/combo/health
- [x] Debug menu (Tab)
- [x] Settings panel (mouse-only)
- [x] Shop UI
- [x] Profile creation/selection UI

## Phase 7: Documentation ✅ Completed
**Goal**: Complete project documentation

- [x] AGENTS.md for AI agents
- [x] README.md for users
- [x] Documentation skill
- [x] GDD (Game Design Document)
- [x] TDD (Technical Design Document)
- [x] Roadmap
- [x] Changelog
- [x] TODO tracking
- [x] File reorganization (8 system folders)

## Phase 8: Gameplay & Combat Evolution 🔄 In Progress
**Goal**: Deepen combat mechanics, survival tension, stage biomes, and replayability

- [x] Asymmetric Main Menu UI Redesign & Procedural Cyan Isometric Title 2.5D (Left vertical panel 40% with Dot Matrix #14 procedural background and rotating novice pixel art Alchemy Sigil #17, 4 centered Cyber-Step #03 buttons, central diamond emblem at w/2,h/2, right procedural cyan neon logo 2.5D #00F0FF via ui/menuLogo.lua with real-time F2 calibrator systems/debugLogo.lua, and Chunky Profile & High Score #11 card via ui/menuCard.lua).
- [ ] Combat & Survival Package (Held-Key Tactical Slither paradigm, survival streak multiplier, interactive revive/death, Constrictor loop, Autotomy, Reverse Slither, Tail Snap, 4 special foods + 5 dynamic fruits)
- [ ] Extended Items Arsenal (Items 51-60: Tail Spike, Hourglass, Orbital Beam, Decoy, Light Boots, Golden Tooth, Emergency Battery, Double Harvest, Lottery, Refractor Prism)
- [ ] Stage Biomes & Hazards (Catacombs, Frozen Crypt ice floor, Volcanic lava fissures, Toxic Hive slime, Void Sanctuary, Pressure Spikes)
- [ ] Elite Encounters & 5 Mini-Bosses (Mid-stage room 3 challenges with guaranteed golden rewards)
- [ ] Boss Enrage Phase & Laser Perimeter Attack (3-food enrage threshold and dividing laser beam attacks)
- [ ] Room Modifiers, Curses & Blessings (10 mutators: Zero Gravity, Midas Curse, Phoenix Blessing, Tunnel Vision, etc.)
- [ ] Stage Tarot Draft System (12 fate cards drafted on rooms 1, 2, 4)
- [ ] Special Mystery Rooms (Gambler's Den, Doppelgänger Mirror, Gold Rush, Trial of Triads)
- [ ] Status Effects Engine (Overdrive on combo x6, Medusa Tail, Venom Spore, Cryo-Stasis)
- [ ] Meta-Progression Shrine (8 permanent talents with 3 tiers in Menu/Profiles)
- [ ] Daily Challenges, Lore Codex & Bounty Board (Deterministic daily runs & bounty contracts)
- [ ] Master Snake Skin Catalog (200+ variants, 5 primitive render engines, Zero-GC vertex buffers)
- [ ] 10 Unlockable Game Modes (Endless, Rush, Pacifist, Boss Rush, Colossal Arena, Micro-Snake, Weekly Seed, Draft, Sudden Death, Maze Runner)
- [ ] 80 Engineering & Gameplay Improvements Suite (Input ramp-up, corner buffering, AABB ray-cast pre-filter, half-res FBO reflections, Voronoi fracture, fixed timestep)

## Phase 9: Final Polish & Release ⏳ Not Started
**Goal**: Release-ready quality, sensorial polish, visual style evolution, accessibility and packaging

- [ ] 100 Visual Style & Rendering Evolution Proposals (GDD §20 / TDD §10.24: Dynamic lighting & 2D drop shadows, procedural autotiling, GLSL bloom threshold, squish/stretch micro-animations, specular floor reflections, directional shake, 50ms hitstop, reactive layered music, enemy telegraphs, particle fluids, stone HUD, volumetric fog)
- [ ] Accessibility & QoL Suite (GDD §21.4 / TDD §10.21: Colorblind filters, FX sliders, training mode, run history, record PNG export, full keybind mapping, HUD performance overlay, Alt+Tab auto-pause, HD vibration)
- [ ] Balance tuning (Boss food target & economy curves)
- [ ] Bug fixes & performance profiling (Zero-GC memory audit, 60s zero-allocation test)
- [ ] Full Gamepad / Controller integration & vibration
- [x] Create LICENSE file (MIT)
- [ ] Final testing & Release packaging
- [x] Curación e integración de las 80 propuestas del socio técnico (GDD §21 / TDD §10.25): resolución de duplicados contra §20, priorización y consolidación de arquitectura completada (17:08:2026)

---

## Legend
- ✅ Completed
- 🔄 In Progress
- ⏳ Not Started
