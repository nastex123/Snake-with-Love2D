# Chaser — Nota de Diseño (12:08:2026)

Rama: `feat/ai-behavior` (basada en `origin/feat/refactor-architecture`)

## Estado del trabajo
- **Completado**: documentación del Chaser en `docs/GDD.md` (sección 3) + TODO + CHANGELOG. Sin cambios de código.
- **Pendiente**: implementación de la IA social (ver `docs/TODO.md` → "Chaser AI (design done, pending implementation)") y elección del diseño visual.

## Decisiones cerradas (diseño social)
1. Cierre del anillo (MANADA) con **60%** de slots ocupados (`RING_CLOSE_FRACTION = 0.6`).
2. Los flankers **pueden golpear** a la serpiente si se cruza (sin distancia mínima a la cabeza).
3. Slowdown de manada confirmado: `CHASER_PACK_SLOWDOWN = 1.15`.

## Diseño visual — pendiente de revisar en PC
- Existe un **HTML de previsualización con 6 propuestas de diseño animadas** (generado con otra IA) que debe revisarse desde el PC.
- Próximo paso: elegir una propuesta, documentarla en GDD sección 3 y anotar los cambios visuales a implementar en `render/enemiesDraw.lua`.

## Checklist de continuación (en PC)
- [ ] Revisar el HTML de propuestas visuales y elegir una
- [ ] Implementar `entities/chaserAI.lua` (buildPack + update, 4 estados: IDLE/CHASE/FLANK/ENCIRCLE)
- [ ] Modos sociales: SOLO (predictor), DUPLA (hunter+flankers), MANADA (anillo + cierre 60%)
- [ ] Navegación: evasión suave (obstáculos/cuerpo), tie-break shuffle, spread penalty, stuck counter
- [ ] Escalado por etapa (1.10^etapa, clamp 0.15s) + paso de ctx a `enemies.update` (`gamestates.lua:189`)
- [ ] Boss: flank respawn en `pendingRespawns` (lados alternados) + cap fuerza DUPLA
- [ ] Visual: diferenciación de estados en `enemiesDraw.lua` (IDLE atenuado, FLANK outline, MANADA tint, cierre flash)
- [ ] Config keys `CHASER_*` en `core/config.lua` (valores propuestos en GDD sección 3)
- [ ] Verificar `love .` sin errores y log limpio
- [ ] Documentar Patroller, Spawner y Boss en GDD sección 3 (mismo formato)
