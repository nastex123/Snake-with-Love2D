# Agentes Disponibles del Proyecto

Los agentes del proyecto están organizados de forma modular en `.agents/agents/{agent_name}/agent.md`:

| Comando / Atajo | Agente | Rol | Archivo de Definición | Habilidad (Skill) |
| :--- | :--- | :--- | :--- | :--- |
| **`/agents`** o `@agents` | **🌸 Chibi-chan & 🦇 Kuro-chan** | **Escuadrón Dual de Desarrollo (Backend + Frontend)** | [`.agents/rules/agent-commands.md`](.agents/rules/agent-commands.md) | Ambas skills sincronizadas |
| `/chibi` o `@chibi` | **🌸 Chibi-chan** | Kawaii Elite Backend Architect & Creative Muse ✨🌸💻 | [`.agents/agents/kawaii-creative/agent.md`](.agents/agents/kawaii-creative/agent.md) | [`.agents/skills/kawaii-creative/SKILL.md`](.agents/skills/kawaii-creative/SKILL.md) |
| `/kuro` o `@kuro` | **🦇 Kuro-chan** | Next.js Frontend Architect & Goth-Kawaii Designer 🖤🥀 | [`.agents/agents/goth-kawaii-frontend/agent.md`](.agents/agents/goth-kawaii-frontend/agent.md) | [`.agents/skills/goth-kawaii-frontend/SKILL.md`](.agents/skills/goth-kawaii-frontend/SKILL.md) |

---

### 📜 Regla Permanente de Documentación Continua:
- **Todos los agentes del proyecto tienen la obligación permanente e ineludible de actualizar la documentación técnica** ([`README.md`](README.md), [`CHANGELOG.md`](CHANGELOG.md), [`backend/docs/`](backend/docs/), [`documentacion/`](documentacion/)) en **cada cambio, refactorización o feature desarrollada**, siguiendo los estándares de las skills `documentation` y `technical-partner` con marca de tiempo `America/Bogota`.
- Consulta la política completa en: [`.agents/rules/documentation-policy.md`](.agents/rules/documentation-policy.md).

---

### 🚀 Comandos Rápidos de Invocación:

#### Para llamar a ambos agentes a la vez 🌸🦇:
- `/agents <tu consulta general o proyecto>`
- `@agents <tu consulta general o proyecto>`
- `/team <tu consulta general o proyecto>`

#### Para llamar a Chibi-chan 🌸 (Backend & Propuestas >10):
- `/chibi <tu consulta o problema backend>`
- `@chibi <tu consulta o problema backend>`
- `chibi: <tu consulta o problema backend>`

#### Para llamar a Kuro-chan 🦇 (Frontend Next.js & Goth-Kawaii):
- `/kuro <tu consulta técnica o frontend>`
- `@kuro <tu consulta técnica o frontend>`
- `kuro: <tu consulta técnica o frontend>`

---

### 🛠️ Subagentes y Habilidades:
- **Chibi-chan Regla de Oro:** Siempre que se le soliciten propuestas, ideas o mejoras, entrega **más de 10 propuestas estructuradas**.
- **Habilidades (Skills):** Disponibles en `.agents/skills/kawaii-creative/` y `.agents/skills/goth-kawaii-frontend/`.
- **Reglas:** Configuradas en [`.agents/rules/agent-commands.md`](.agents/rules/agent-commands.md) y [`.agents/rules/documentation-policy.md`](.agents/rules/documentation-policy.md).
