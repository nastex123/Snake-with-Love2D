# Snake Love2D — Dungeon Crawler

Un juego de acción táctica y sigilo estilo *Dungeon Crawler* desarrollado en el motor **Love2D (Lua)**, fusionando la mecánica clásica de la serpiente con combate en mazmorras, IA social de enemigos, jefes con ataques telegrafiados, tienda de objetos, shaders CRT/Bloom procedurales y un menú principal asimétrico de estética arcade cyberpunk.

---

## ✨ Características Principales

- **🎮 5 Etapas & 25 Salas Generadas Proceduralmente**: Mazmorras con árboles BSP, corredores tácticos y modificadores por bioma.
- **👾 IA Social de Enemigos**:
  - **Chasers**: Comportamiento adaptativo según número de unidades (**SOLO**, **DUPLA** con flanqueo lateral, **MANADA** con anillo de cerco y compresión).
  - **Patrollers**: Patrullaje lineal con rebote suave en paredes/obstáculos y detección de colisión.
  - **Spawners**: Generadores de unidades con intervalos adaptativos.
  - **Jefe (Food-Based Defeat)**: Jefe invulnerable por impacto directo; se derrota recolectando 15 comidas no-moneda mientras esquivas 4 ataques telegrafiados (*projectile spread*, *spawn adds*, *radial pulse*, *teleport*).
- **🕹️ Menú Principal Asimétrico Cyberpunk**:
  - **Panel Lateral Izquierdo (40% ancho)**: Fondo procedural de Matriz de Puntos HUD con ondas senoidales expansivas y Círculo Alquímico de Invocación rotatorio a 60 FPS con bloom glow.
  - **Botones Cyber-Step #03**: 4 botones arcade con zarpazos a 45°, micro-nodos de relojería y animación de elevación.
  - **Logotipo SNAKE 2.5D Isométrico Cian Neón**: Renderizado procedural en tiempo real con 5 capas de profundidad isométrica a 45°, bisel platino y barrido especular continuo.
  - **Tarjeta Chunky de Perfil & High Score #11**: Marco reforzado con condensadores 6x6, medalla bicolor y moneda circular 3D con rotación elipsoidal.
- **🛠️ Herramienta de Calibración en Vivo (`F2`)**: Calibrador visual interactivo para posicionar, escalar y ajustar la profundidad del logotipo con guardado persistente en `config/settings.dat`.
- **🎒 Sistema de Objetos & Tienda**: 12 ítems (activos y pasivos) equipables en slots 1–3 y tienda con paginación 4x3.
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

El proyecto está estructurado en 45 módulos desacoplados con límites estrictos de $<300$–$500$ líneas por archivo:
- **`core/`**: Configuración central (`config.lua`), logger (`logger.lua`), timers con pooling (`timers.lua`), estado global encapsulado (`world.lua`), helpers matemáticos (`helpers.lua`) e input táctil (`touch.lua`).
- **`entities/`**: Lógica de serpiente (`snake.lua`), enemigos (`enemies.lua`), ataques de jefe (`bossAttacks.lua`), IA social de chasers (`chaserAI.lua`), comida (`food.lua`) y obstáculos (`obstacles.lua`).
- **`world/`**: Fachada del mundo (`world.lua`), generador BSP (`dungeonGen.lua`) y poblador de salas (`populate.lua`).
- **`systems/`**: Objetos (`items.lua`), tienda (`shop.lua`), persistencia (`persistence.lua`), ajustes (`settings.lua`, `settingsDraw.lua`), perfiles (`profiles.lua`, `profilesDraw.lua`), logros (`achievements.lua`), jugador (`player.lua`), flujo de juego (`gameflow.lua`), estados (`gamestates.lua`), menú debug (`debugTools.lua`) y calibrador de logo (`debugLogo.lua`).
- **`ui/`**: Fachada de interfaz (`ui.lua`), cinemática Balatro (`introUI.lua`), menú principal (`menuUI.lua`, `menuLogo.lua`, `menuCard.lua`), HUD (`hudUI.lua`), toasts (`toastsUI.lua`), popups (`popupsUI.lua`) y overlays (`overlaysUI.lua`).
- **`render/`**: Shaders GLSL (`shaders.lua`), partículas procedurales (`particles.lua`), escena principal (`renderMain.lua`) y render de enemigos (`enemiesDraw.lua`).
- **`audio/`**: SFX procedurales y gestor de streaming OpenAL (`sound.lua`).

---

## 📜 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [`LICENSE`](LICENSE) para más detalles.