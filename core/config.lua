local config = {}

-- Canvas / resolution (virtual, integer-scaled)
config.canvasWidth = 640
config.canvasHeight = 360
config.tileSize = 20

-- Compatibility aliases
config.GRID_SIZE = config.tileSize
config.ANCHO = config.canvasWidth
config.ALTO = config.canvasHeight

config.TAMANIO_BLOQUE = 20
config.VELOCIDAD_INICIAL = 0.13
config.VELOCIDAD_MINIMA = 0.05
config.DURACION_FLASH_COMER = 0.6
config.CORNER_BUFFER_RATIO = 0.75
config.INPUT_BUFFER_MAX = 2

config.GAME_STATE_MENU = 0
config.GAME_STATE_PLAYING = 1
config.GAME_STATE_DEATH_ANIMATION = 2
config.GAME_STATE_HIGH_SCORE = 3
config.GAME_STATE_SHOP = 4
config.GAME_STATE_PAUSED = 5
config.GAME_STATE_TRANSITION = 6

config.HIGH_SCORE_CELEBRATION_DURATION = 1.3

config.DEATH_ANIMATION_SEGMENT_DELAY = 0.05
config.SHAKE_DURATION = 0.3
config.SHAKE_INTENSITY = 4
config.FADE_SPEED = 3

config.INTRO_FADE_END = 0.5
config.INTRO_CARD_RISE = 0.5
config.INTRO_SPIRAL_START = 1.5
config.INTRO_FLASH_START = 2.5
config.INTRO_FLASH_END = 3.0
config.INTRO_LOGO_START = 3.0
config.INTRO_MENU_START = 3.5
config.INTRO_READY = 4.5

config.SPEED_ADJUST_INCREMENT = 0.01
config.MIN_BASE_SPEED = 0.05
config.MAX_BASE_SPEED = 0.30

config.SHIELD_COST = 30
config.MAGNET_COST = 20
config.MAGNET_DURATION = 10
config.MAGNET_RANGE = 2
config.SPEED_REDUCER_COST = 15
config.SPEED_REDUCER_AMOUNT = 0.02
config.ARMOR_COST = 40
config.GHOST_COST = 25
config.GHOST_DURATION = 5
config.BOMB_COST = 25
config.BOMB_RADIUS = 3
config.HUNGER_COST = 15
config.TURBO_COST = 20
config.TURBO_MULTIPLIER = 0.7
config.TURBO_DURATION = 8
config.SLOW_COST = 25
config.SLOW_TIMESCALE = 0.5
config.SLOW_DURATION = 5
config.DOUBLER_COST = 35
config.DOUBLER_DURATION = 8
config.EXTRA_COIN_COST = 20
config.EXTRA_COIN_DURATION = 10
config.STAR_COST = 40
config.STAR_DURATION = 5
config.COINS_PER_FRUIT = 1

config.COMBO_WINDOW = 8.0
config.COMBO_MULTIPLIER = 0.5

config.FOOD_NORMAL = 1
config.FOOD_GOLD = 2
config.FOOD_COIN = 3

config.OBSTACLE_SPAWN_INTERVAL = 50

config.COLOR_BG = {0.07, 0.07, 0.12}
config.COLOR_GRID_A = {0.10, 0.14, 0.22}
config.COLOR_GRID_B = {0.13, 0.17, 0.26}
config.COLOR_ACCENT = {0.0, 0.85, 1.0}
config.COLOR_GRID_HOT_A = {0.22, 0.10, 0.18}
config.COLOR_GRID_HOT_B = {0.26, 0.13, 0.22}
config.SHIMMER_SPEED = 2.0
config.COLOR_GOLD = {1.0, 0.84, 0.0}
config.COLOR_PANEL = {0.12, 0.12, 0.22, 0.9}
config.COLOR_RED = {1.0, 0.2, 0.2}
config.COLOR_GREEN = {0.2, 0.9, 0.3}

config.FONT_FILE = "PressStart2P-Regular.ttf"
config.FONT_TITLE = 28
config.FONT_LARGE = 16
config.FONT_NORMAL = 11
config.FONT_SMALL = 8

config.HUD_HEIGHT = 28
config.GRID_OFFSET_Y = 28

config.SCORE_POPUP_LIFETIME = 1.0
config.SCORE_POPUP_SPEED = 40

config.PARTICLE_COMER_COUNT = 15
config.PARTICLE_MUERTE_COUNT = 25
config.PARTICLE_ENEMY_COUNT = 10

config.ENEMY_SPAWN_INTERVAL = 50

config.TOAST_SHOW_DURATION = 1.5
config.TOAST_FADE = 0.25
config.TOAST_MAX_WIDTH = 600
config.TOAST_PADDING = 12
config.TOAST_ICON_SIZE = 28
config.TOAST_BG_COLOR = {0.06, 0.06, 0.10, 0.95}
config.TOAST_SLIDE = 14
config.TOAST_SCHEDULE_DELAY = 0.5

config.DUNGEON_TARGET_ROOMS = 5
config.DUNGEON_VIRTUAL_W = 800
config.DUNGEON_VIRTUAL_H = 600
config.DUNGEON_MIN_ROOM_W = 120
config.DUNGEON_MIN_ROOM_H = 90
config.DUNGEON_MAX_ROOM_W = 250
config.DUNGEON_MAX_ROOM_H = 200
config.DUNGEON_BSP_MIN_LEAF = 180
config.DUNGEON_CORRIDOR_WIDTH = 20
config.DUNGEON_ROOM_PADDING = 15

config.ROOM_CORRIDOR = "corridor"
config.ROOM_ARENA = "arena"
config.ROOM_CHOKE = "choke"
config.ROOM_HUB = "hub"
config.ROOM_TREASURE = "treasure"
config.ROOM_SPAWNER = "spawner"
config.ROOM_BOSS = "boss"

config.TRANSITION_DURATION = 0.8

config.BOSS_TYPE_TELEPORTER = "teleporter"
config.BOSS_TYPE_SPAWNER   = "spawner_boss"
config.BOSS_COLORS = {
    teleporter = {1, 0.2, 0.6},
    spawner_boss = {0.8, 0.4, 0.1}
}

config.ENEMY_CHASER_SPEED = 0.3
config.ENEMY_PATROLLER_SPEED = 0.2
config.ENEMY_SPAWNER_INTERVAL = 3

config.ENEMY_DROP_CHASER = 3
config.ENEMY_DROP_PATROLLER = 2
config.ENEMY_DROP_SPAWNER = 1

config.COLOR_ENEMY_CHASER = {0.9, 0.2, 0.2}
config.COLOR_ENEMY_PATROLLER = {0.2, 0.4, 0.9}
config.COLOR_ENEMY_SPAWNER = {0.6, 0.2, 0.8}

config.BOSS_MAX_RED = 3
config.BOSS_MAX_BLUE = 4
config.BOSS_ENEMY_LIFETIME = 15
config.BOSS_RESPAWN_DELAY = 5
config.BOSS_RESPAWN_RETRY = 40

-- Chaser AI social (GDD seccion 3)
config.CHASER_AGGRO_RADIUS = 8
config.CHASER_PACK_SLOWDOWN = 1.15
config.CHASER_SPREAD_PENALTY = 1.5
config.CHASER_RING_CYCLE = 8
config.CHASER_IDLE_SPIN = 0.7
config.CHASER_CLOSE_SPIN = 10
config.CHASER_ROT_LERP = 7

config.BOSS_FOOD_TARGET = 15
config.MAX_GRID_COLS = 40
config.MAX_GRID_ROWS = 28

config.BOSS_HEALTH_BAR = {
    width = 96,
    height = 8,
    yOffset = -24,
    bgColor = {0.12, 0.12, 0.12, 1},
    fgColor = {0.88, 0.2, 0.2, 1},
    borderColor = {0, 0, 0, 1},
    lerpSpeed = 6.0,
}

-- Fase 8: Combate y Supervivencia (Combat & Survival Package)
config.AUTOTOMY_COOLDOWN = 8.0
config.AUTOTOMY_GHOST_DURATION = 1.5
config.AUTOTOMY_DECOY_DURATION = 4.0
config.CONSTRICTOR_BUFF_DURATION = 5.0
config.REVIVE_COIN_COST = 30
config.REVIVE_GHOST_DURATION = 3.0
config.SURVIVAL_STREAK_INCREMENT = 0.1

config.FIRE_PEPPER_DURATION = 3.5
config.FIRE_TRAIL_LIFETIME = 1.8
config.FROST_BERRY_DURATION = 2.5
config.SLIMMING_MIN_LENGTH = 12
config.SLIMMING_FACTOR = 0.5

config.REVERSE_SLITHER_DURATION = 3.0
config.REVERSE_SLITHER_COOLDOWN = 10.0
config.TAIL_SNAP_STUN_DURATION = 0.8
config.TAIL_SNAP_PUSH_DIST = 1

config.REPELLING_MOVE_INTERVAL = 1.5
config.FOOD_COUNTDOWN_TIMER = 5.0
config.FOOD_TWIN_TIMER = 4.0
config.FOOD_TWIN_WINDOW = 4.0

-- Parámetros de Biomas y Peligros Ambientales (Fase 8)
config.ICE_SLIP_DISTANCE = 1
config.MAGMA_WARNING_TIME = 1.2
config.MAGMA_ACTIVE_TIME = 1.5
config.MAGMA_COOLDOWN_TIME = 2.5
config.SLIME_SPEED_PENALTY = 0.80 -- -20% velocidad de paso
config.PRESSURE_SPIKE_TRIGGER_DELAY = 0.5
config.PRESSURE_SPIKE_ACTIVE_DURATION = 1.2

-- Registro de Biomas de Mazmorra (Fase 8)
config.BIOMES = {
    [1] = {
        id = "catacumbas",
        name = "Catacumbas de Piedra",
        subtitle = "Muros Sólidos & Mazmorra Clásica",
        wallWrap = true,
        gridColor = {0.18, 0.22, 0.30},
        gridAccent = {0.0, 0.85, 1.0},
        bgTint = {0.05, 0.07, 0.11},
        wallColor = {0.45, 0.48, 0.55},
        isIce = false,
        hazardLava = false,
        isSlime = false
    },
    [2] = {
        id = "hielo",
        name = "Cripta Helada",
        subtitle = "Suelo Resbaladizo & Escarcha",
        wallWrap = true,
        gridColor = {0.15, 0.35, 0.50},
        gridAccent = {0.20, 0.90, 1.0},
        bgTint = {0.04, 0.08, 0.14},
        wallColor = {0.30, 0.60, 0.80},
        isIce = true,
        hazardLava = false,
        isSlime = false
    },
    [3] = {
        id = "volcan",
        name = "Caverna Volcánica",
        subtitle = "Fisuras de Magma & Baldosas Ardientes",
        wallWrap = true,
        gridColor = {0.35, 0.15, 0.10},
        gridAccent = {1.0, 0.45, 0.10},
        bgTint = {0.10, 0.04, 0.04},
        wallColor = {0.55, 0.25, 0.15},
        isIce = false,
        hazardLava = true,
        isSlime = false
    },
    [4] = {
        id = "colmena",
        name = "Colmena Tóxica",
        subtitle = "Suelo Viscoso & Enjambre Ácido",
        wallWrap = true,
        gridColor = {0.20, 0.35, 0.15},
        gridAccent = {0.20, 0.90, 0.40},
        bgTint = {0.05, 0.09, 0.04},
        wallColor = {0.40, 0.55, 0.25},
        isIce = false,
        hazardLava = false,
        isSlime = true
    },
    [5] = {
        id = "vacio",
        name = "Santuario del Vacío",
        subtitle = "Abismo Cósmico - Caída Mortal Sin Wall-Wrap",
        wallWrap = false,
        gridColor = {0.25, 0.10, 0.35},
        gridAccent = {0.85, 0.30, 1.0},
        bgTint = {0.03, 0.02, 0.06},
        wallColor = {0.60, 0.40, 0.80},
        isIce = false,
        hazardLava = false,
        isSlime = false
    }
}

return config