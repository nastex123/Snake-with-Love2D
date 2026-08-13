# Chaser — Nota de Diseño (12:08:2026)

Rama: `feat/ai-behavior` (basada en `origin/feat/refactor-architecture`)

## Estado del trabajo
- **Completado**: documentación del Chaser en `docs/GDD.md` (sección 3) + TODO + CHANGELOG. Sin cambios de código.
- **Pendiente**: implementación de la IA social (ver `docs/TODO.md` → "Chaser AI (design done, pending implementation)") y elección del diseño visual.

## Decisiones cerradas (diseño social)
1. Cierre del anillo (MANADA) con **60%** de slots ocupados (`RING_CLOSE_FRACTION = 0.6`).
2. Los flankers **pueden golpear** a la serpiente si se cruza (sin distancia mínima a la cabeza).
3. Slowdown de manada confirmado: `CHASER_PACK_SLOWDOWN = 1.15`.

## Diseño visual — elegido
- Propuesta elegida: **06 — Estrella de espinas**.
- Ojo central con pupila rastreadora, estrella de cuatro puntas, párpado IDLE, contorno FLANK,
  pulso ámbar ENCIRCLE y destello de cierre.
- Documentado en GDD sección 3 e implementado en `render/enemiesDraw.lua`.

## Checklist de continuación (en PC)
- [x] Revisar el HTML de propuestas visuales y elegir una: propuesta 06
- [x] Implementar `entities/chaserAI.lua` con estados IDLE/CHASE/FLANK/ENCIRCLE/CIERRE
- [x] Modos sociales: SOLO, DUPLA y MANADA con ciclo de anillo y cierre
- [x] Navegación: evasión de obstáculos, penalización de cuerpo/apilamiento y tie-break shuffle
- [ ] Escalado por etapa (1.10^etapa, clamp 0.15s) + paso de ctx a `enemies.update` (`gamestates.lua:189`)
- [ ] Boss: flank respawn en `pendingRespawns` (lados alternados) + cap fuerza DUPLA
- [x] Visual: diferenciación de estados en `enemiesDraw.lua` (IDLE atenuado, FLANK outline, MANADA tint, cierre flash)
- [x] Config keys `CHASER_*` en `core/config.lua`
- [ ] Verificar `love .` sin errores y log limpio
- [ ] Documentar Patroller, Spawner y Boss en GDD sección 3 (mismo formato)
