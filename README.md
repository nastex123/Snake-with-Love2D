# Snake Love2D — Dungeon Crawler

Un juego de acción táctica y sigilo estilo *Dungeon Crawler* desarrollado en el motor **Love2D (Lua)**, fusionando la mecánica clásica de la serpiente con combate en mazmorras, IA social de enemigos, jefes con ataques telegrafiados, tienda de objetos, shaders CRT/Bloom procedurales y un menú principal asimétrico de estética arcade cyberpunk.

---

## ✨ Características Principales

- **🎮 5 Etapas & 25 Salas Generadas Proceduralmente**: Mazmorras con árboles BSP, corredores tácticos y modificadores por bioma.
- **👾 Enemigos con Sprites Pixel-Art e IA Táctica**:
  - **Chasers (Shuriken Plasma Hyper 7x7)**: Aspas con rotación continua a 60 FPS acelerada por estado de combate y ojo giroscópico estabilizado que rastrea a la serpiente. IA social adaptativa (**SOLO**, **DUPLA** con flanqueo lateral, **MANADA** con cerco orbital).
  - **Patrollers (Interceptor Delta 5x5)**: Dron de patrullaje con blindaje cobalto, orientación continua según vector de avance, núcleo fotónico pulsante y micro-llama de plasma.
  - **Spawners**: Generadores estáticos de unidades y obstáculos.
  - **Jefe (Food-Based Defeat)**: Jefe invulnerable por impacto directo; se derrota recolectando 15 comidas no-moneda esquivando 5 ataques telegrafiados (*projectile spread*, *spawn adds*, *radial pulse*, *teleport*, *laser perimeter*) con fase de furia a 12/15. Mini-jefes en sala 3 de cada etapa.
- **🌋 5 Biomas con Peligros Ambientales Dinámicos**:
  - *Catacumbas de Piedra (1)*: Entorno base con muros estándar.
  - *Cripta Helada (2)*: Losetas de hielo resbaladizas con inercia de deslizamiento `+1`.
  - *Caverna Volcánica (3)*: Fisuras de magma con ciclo autónomo de advertencia y erupción letal.
  - *Colmena Tóxica (4)*: Charcos viscosos con penalización de -20% de velocidad de paso.
  - *Santuario del Vacío (5)*: Sin wall-wrap (caída libre mortal al cruzar los bordes) y placas de pinchos de presión temporizadas.
- **🕹️ Menú Principal Asimétrico Cyberpunk**:
  - **Panel Lateral Izquierdo (40% ancho)**: Fondo procedural de Matriz de Puntos HUD con ondas senoidales expansivas y Círculo Alquímico de Invocación rotatorio a 60 FPS con bloom glow.
  - **Botones Cyber-Step #03**: 4 botones arcade con zarpazos a 45°, micro-nodos de relojería y animación de elevación.
  - **Logotipo SNAKE 2.5D Isométrico Cian Neón**: Renderizado procedural en tiempo real con 5 capas de profundidad isométrica a 45°, bisel platino y barrido especular continuo.
  - **Tarjeta Chunky de Perfil & High Score #11**: Marco reforzado con condensadores 6x6, medalla bicolor y moneda circular 3D con rotación elipsoidal.
- **🛠️ Herramienta de Calibración en Vivo (`F2`)**: Calibrador visual interactivo para posicionar, escalar y ajustar la profundidad del logotipo con guardado persistente en `config/settings.dat`.
- **⛪ Tienda "El Santuario Arcano de las Ánimas" (Dungeon Crawler)**: Cripta subterránea gótica con 3 hornacinas de arcos ojivales biselados, relicarios sacros, vitrales de plomo para las Cartas del Destino, cáliz sagrado de ofrenda y plegaria (`[R] OFRENDA`), retablo mayor con la espina dorsal ósea del dragón ancestral y llamas de alma en vértebras consagradas, más el altar inferior de los 3 cálices de poder activo.
- **🃏 Tarot por Etapa**: Draft de 3 cartas al completar las salas 1, 2 y 4 (máx 3 activas por etapa) con 12 cartas de destino y texturas pixel-art 20x20.
- **🎲 Mutadores de Sala**: 10 modificadores (gravedad cero, Midas, pluma, velo, sombra, contrarreloj, fénix, túnel, dualidad, titán) con banner y badge en HUD.
- **🚪 Salas de Misterio**: 4 salas especiales (apostador, espejo, fiebre del oro, sellos) con reglas y premios propios.
- **✨ Pipeline de Shaders GLSL**: Bloom aditivo multietapa (glow + blurH + blurV), CRT scanlines con curvatura, sombras dinámicas y heat distortion.
- **💾 Persistencia & Perfiles**: Gestor de hasta 3 perfiles locales con estadísticas detalladas (kills, boss kills, récord, monedas) y panel de ajustes (Audio, Gráficos, Accesibilidad).
- **🏆 11 Logros del Sistema**: Desbloqueo progresivo por hitos de combate, economía, combo y avance de etapas.

---

## 🎮 Controles de Juego

| Tecla | Acción |
| :--- | :--- |
| **`WASD` / Flechas** | Movimiento de la serpiente |
| **`1`, `2`, `3`** | Activar ítem en el slot correspondiente |
| **`Espacio` / `Esc`** | Pausar / Reanudar partida |
| **`+` / `-`** | Aumentar / Disminuir velocidad de la serpiente |
| **`Tab`** | Abrir / Cerrar Menú de Depuración Táctico (Inmunidad, Saltos, Monedas) |
| **`F2`** | Abrir Calibrador del Logotipo SNAKE en el Menú Principal |
| **`L`** | *(Debug)* Añadir +10 Monedas |
| **`K`** | *(Debug)* Saltar a la siguiente sala |

---

## 🚀 Instalación y Ejecución

1. **Requisitos**: Instalar [Love2D](https://love2d.org/) (versión 11.4 o superior).
2. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/nastex123/Snake-with-Love2D.git
   cd Snake-with-Love2D
   ```
3. **Ejecutar el juego**:
   ```bash
   love .
   ```
   *(Nota: Siempre ejecutar `love .` desde el directorio raíz del proyecto).*

---

## 🏗️ Arquitectura del Proyecto

El proyecto está estructurado en 65 módulos juego (104 con 37 tests) con límites estrictos de $<300$–$500$ líneas por archivo (residuales `persistence.lua` 862L y crecidos Fase 8 —`playing.lua` 999L, `settingsDraw.lua` 647L, `player.lua` 622L, `dungeonGen.lua` 530L— pendientes de split futuro):
- **`core/`**: Configuración central (`config.lua` + `KEYBINDS`), logger (`logger.lua`), timers único pooled (`timers.lua`), estado dot-notation + `SCHEMA`/`validate()` (`world.lua` 369L), Event Bus (`events.lua` 134L), input centralizado (`input.lua` 89L), asset manager cache (`assets.lua` 144L), helpers (`helpers.lua`) e input táctil (`touch.lua`).
- **`entities/`**: Serpiente fachada + `snake/` 4 (`snake.lua` 257L), enemigos fachada + 3 (`enemies.lua` 431L, `enemyAttackRegistry.lua` 247L pools), `bossAttacks.lua` (5 ataques), `chaserAI.lua`, `patrollerAI.lua`, `enemyHelpers.lua`, `enemyMiniBoss.lua` (5 mini-jefes), comida (`food.lua`) y obstáculos fachada 495L (`obstacles.lua` delega a `world/biomeHazards.lua`).
- **`world/`**: Fachada del mundo (`world.lua`), peligros `biomeHazards.lua` 254L, generador BSP (`dungeonGen.lua`) y poblador de salas (`populate.lua`).
- **`systems/`**: Objetos (`items.lua`, 22 ítems), tienda (`shop.lua`), persistencia (`persistence.lua`), ajustes (`settings.lua`, `settingsDraw.lua`), perfiles (`profiles.lua`, `profilesDraw.lua`), logros (`achievements.lua`), jugador (`player.lua`), flujo de juego (`gameflow.lua`), estados (`gamestates.lua`), menú debug (`debugTools.lua`) y calibrador de logo (`debugLogo.lua`), tarot (`tarot.lua`, `tarotArt.lua`), mutadores (`roomMutators.lua`) y misterio (`mystery.lua`).
- **`ui/`**: Fachada de interfaz (`ui.lua`), cinemática Balatro (`introUI.lua`), menú principal (`menuUI.lua`, `menuLogo.lua`, `menuCard.lua`), HUD (`hudUI.lua`), toasts (`toastsUI.lua`), popups (`popupsUI.lua`) y overlays (`overlaysUI.lua`).
- **`render/`**: Shaders GLSL (`shaders.lua`), partículas procedurales (`particles.lua`), escena principal (`renderMain.lua`) y render de enemigos (`enemiesDraw.lua`).
- **`audio/`**: SFX procedurales y gestor de streaming OpenAL (`sound.lua`).

---

## 📜 Licencia & Derechos de Distribución

Este proyecto es de **Código Propietario — Todos los Derechos Reservados** (All Rights Reserved). Se prohíbe la redistribución, republicación, venta o uso comercial del código fuente y recursos asociados sin autorización expresa por escrito. Consulta el archivo [`LICENSE`](LICENSE) para los términos completos.