# Guia de Instalacion y Referencia: Software Architecture Suite

Suite Integral de Arquitectura de Software e Ingenieria de Sistemas para agentes autonomos de programacion (Google Antigravity, OpenCode) y modelos de lenguaje conversacionales (Gemini Web, Gems).

---

## 1. Descripcion General y Capacidades
Esta suite consolida:
- **Perfil Profesional:** Ingeniero de Sistemas Senior y Arquitecto de Software. Tono formal, analitico y riguroso. Prohibicion absoluta de emojis.
- **Protocolo de Arranque e Inspeccion Documental:** Lectura y revision obligatoria linea por linea de toda la documentacion del proyecto (`README.md`, `docs/`, `TDD.md`, `ROADMAP.md`, `CHANGELOG.md`, `TODO.md`) antes de tocar codigo fuente.
- **Protocolo de Ambigüedad:** Interrogacion interactiva mandatoria mediante `/grill-me` (o `ask_question`) en Antigravity y `Questions` en OpenCode.
- **Diccionario Exhaustivo de Commits:** Taxonomia de mas de 20 tipos de commits con distincion estricta entre cambios de estilo (`style` para CSS/apariencia) y nuevas funciones (`feat`).
- **Actualizacion Continua de TODO (`writetodo`):** Sincronizacion ineludible del backlog en cada turno.
- **Mandato de Entrega Completa Absoluta:** Prohibicion de codigo truncado o comentarios de omision (`// ...`).
- **Marco Universal y Stacks de Referencia:** Python 3.12+ SOLID, Next.js 15, PixiJS WebGL shaders, GSAP, FastAPI, DuckDB/Parquet, Redis, Qdrant y arquitecturas ECS de alto rendimiento.
- **Frontend Interactivo y Animaciones de Scroll Obligatorias:** Toda interfaz web debe incorporar dinamismo basado en scroll: revelación progresiva al bajar (*reveal-on-scroll*), transiciones de aparición escalonadas (*staggered fade/slide*) y animaciones aceleradas por hardware respetando `prefers-reduced-motion`.
- **Directiva Multiplataforma (Windows y Linux):** Diseño nativo interoperable obligatorio (`pathlib.Path`, `utf-8`) y estructura mandatoria de dos scripts Python en la raíz de cada proyecto: `setup_resources.py` (instalador de recursos y dependencias) y `launcher.py` (iniciador del proyecto resiliente).
- **Formato APA y Tablas Multilínea:** Exportacion limpia a PDF sin desbordamiento horizontal en celdas.

---

## 2. Contenido del Paquete

```text
software_architecture_suite_bundle/
├── README.md                                    # Esta guia de instalacion y referencia
├── GEMINI_WEB/
│   └── directiva_operativa_gemini_web.md       # Prompt monolítico para Gemini Web / Gems
├── ANTIGRAVITY_CONFIG/
│   ├── skills/
│   │   ├── architect/                           # Habilita el comando /architect
│   │   │   └── SKILL.md
│   │   ├── audit/                               # Habilita el comando /audit
│   │   │   └── SKILL.md
│   │   ├── review/                              # Habilita el comando /review
│   │   │   └── SKILL.md
│   │   └── software-architecture-suite/         # Suite maestra y referencias técnicas
│   │       ├── SKILL.md
│   │       └── references/
│   │           ├── backend-and-data.md          # FastAPI, Python 3.12, Redis, DuckDB, Qdrant
│   │           ├── commit-taxonomy-dictionary.md# Diccionario exhaustivo de Conventional Commits
│   │           ├── frontend-engineering.md      # Next.js 15, Design DNA, PixiJS, GSAP, Scroll
│   │           ├── git-and-documentation-standards.md # Git DoD, estructura docs/, normas APA
│   │           └── high-performance-systems.md  # ECS, Zero-allocation, pooling, optimizacion
│   └── rules/
│       ├── agent-commands.md                    # Comandos /architect, /review, /audit
│       ├── agents-directory.md                  # Mapeo de disciplinas y suites
│       └── documentation-policy.md              # Politica obligatoria de actualizacion continua
├── ORIGINAL_INPUT/
│   └── directiva_operativa_de_agente_de_software.md # Directiva base provista por el usuario
└── LEGACY_ARCHIVE/                              # Respaldo historico de skills previas archivadas
```

---

## 3. Metodo 1: Instalacion Automatizada por la Propia IA (Prompt de Auto-Instalacion)

Copia y pega el siguiente prompt directamente en tu sesion con la IA (Antigravity, OpenCode, Cursor o similar) para que el propio agente realice la instalacion de forma autonoma:

```markdown
INSTRUCCION DE AUTO-INSTALACION DE LA SUITE DE ARQUITECTURA:

Por favor, instala la suite de arquitectura de software en mi entorno global de configuracion siguiendo estos pasos:
1. Si existe un archivo comprimido o carpeta extraida de "software_architecture_suite_bundle":
   - Copia el directorio "ANTIGRAVITY_CONFIG/skills/software-architecture-suite" dentro de "~/.gemini/config/skills/software-architecture-suite".
   - Copia todos los archivos de "ANTIGRAVITY_CONFIG/rules/" dentro de "~/.gemini/config/rules/".
2. Si existen habilidades obsoletas previas con personajes informales (como chibi o kuro), muevelas a "~/.gemini/config/_archive_legacy/".
3. Verifica la existencia de "SKILL.md" y de la carpeta "references/" con sus 5 modulos tecnicos.
4. Confirma cuando la suite este activa e instalada mostrando la lista de archivos verificados.
```

---

## 4. Metodo 2: Instalacion Manual (Paso a Paso)

### A. En Windows (PowerShell)
Abre PowerShell y ejecuta los siguientes comandos:

```powershell
# 1. Crear las carpetas de destino en la configuracion global de Gemini
$destSkills = "$HOME\.gemini\config\skills\software-architecture-suite"
$destRules  = "$HOME\.gemini\config\rules"
New-Item -ItemType Directory -Force -Path $destSkills, $destRules | Out-Null

# 2. Descomprimir el bundle descargado (asumiendo que se encuentra en Descargas)
$zipPath = "$HOME\Downloads\software_architecture_suite_bundle.zip"
$tempDir = "$HOME\Downloads\temp_suite_install"
Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

# 3. Copiar la skill y sus referencias tecnicas
Copy-Item -Path "$tempDir\ANTIGRAVITY_CONFIG\skills\software-architecture-suite\*" -Destination $destSkills -Recurse -Force

# 4. Copiar las reglas operativas
Copy-Item -Path "$tempDir\ANTIGRAVITY_CONFIG\rules\*" -Destination $destRules -Force

# 5. Limpiar archivos temporales de extraccion
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "Instalacion completada exitosamente en $HOME\.gemini\config\" -ForegroundColor Green
```

### B. En Linux / macOS (Bash)
Abre una terminal y ejecuta:

```bash
# 1. Crear directorios de destino
mkdir -p ~/.gemini/config/skills/software-architecture-suite
mkdir -p ~/.gemini/config/rules

# 2. Descomprimir bundle
unzip -q ~/Downloads/software_architecture_suite_bundle.zip -d /tmp/suite_install

# 3. Copiar archivos
cp -r /tmp/suite_install/ANTIGRAVITY_CONFIG/skills/software-architecture-suite/* ~/.gemini/config/skills/software-architecture-suite/
cp -r /tmp/suite_install/ANTIGRAVITY_CONFIG/rules/* ~/.gemini/config/rules/

# 4. Limpiar temporales
rm -rf /tmp/suite_install

echo "Instalacion completada en ~/.gemini/config/"
```

---

## 5. Instalacion en Gemini de Navegador (Gemini Web o Gems)

1. Abre el archivo: `GEMINI_WEB/directiva_operativa_gemini_web.md` (o copia su contenido).
2. En la interfaz web de Google Gemini (gemini.google.com):
   - **Opcion A (Gem Personalizado):** Ve a la seccion **Gems** -> **Nuevo Gem**. Asigna el nombre `Senior Software Architect` y en el campo de **Instrucciones** pega la totalidad del contenido del archivo. Guarda los cambios.
   - **Opcion B (Sesion Individual):** Pega el contenido al inicio de tu conversacion como mensaje de contexto de sistema.

---

## 6. Comandos Disponibles y Protocolo de Uso

| Comando | Descripcion Operativa |
| :--- | :--- |
| **`/architect <instruccion>`** | Inicia evaluacion de alto nivel, tablas Big-O ($O(n)$ tiempo/espacio, memoria y computo), arquitectura limpia y seleccion de patrones. |
| **`/review <archivo o modulo>`** | Auditoria estricta de codigo completo (sin omisiones), comentarios de una sola linea, ausencia de emojis y validacion de tipos de commit. |
| **`/audit <sistema>`** | Diagnostico integral de riesgos, cuota obligatoria de 5 propuestas categorizadas (`CRITICO`, `RECOMENDADO`, `OPCIONAL`, `FUTURO`) y roadmap de siguientes pasos. |

> **Nota Operativa:** Ante cualquier ejecucion, el agente realizara como primer paso ineludible la lectura completa de la documentacion del proyecto (`README.md`, `docs/`) y canalizara las preguntas de aclaracion mediante `/grill-me` o `Questions`.
