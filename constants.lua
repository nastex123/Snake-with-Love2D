local constants = {}

constants.TAMANIO_BLOQUE = 20
constants.VELOCIDAD_INICIAL = 0.15
constants.VELOCIDAD_MINIMA = 0.05
constants.DURACION_FLASH_COMER = 0.6

constants.GAME_STATE_MENU = 0
constants.GAME_STATE_PLAYING = 1
constants.GAME_STATE_DEATH_ANIMATION = 2
constants.GAME_STATE_HIGH_SCORE = 3
constants.GAME_STATE_SHOP = 4
constants.GAME_STATE_PAUSED = 5
constants.GAME_STATE_TRANSITION = 6

constants.HIGH_SCORE_CELEBRATION_DURATION = 1.3

constants.DEATH_ANIMATION_SEGMENT_DELAY = 0.05
constants.SHAKE_DURATION = 0.3
constants.SHAKE_INTENSITY = 4
constants.FADE_SPEED = 3

constants.INTRO_FADE_END = 0.5
constants.INTRO_CARD_RISE = 0.5
constants.INTRO_SPIRAL_START = 1.5
constants.INTRO_FLASH_START = 2.5
constants.INTRO_FLASH_END = 3.0
constants.INTRO_LOGO_START = 3.0
constants.INTRO_MENU_START = 3.5
constants.INTRO_READY = 4.5

constants.SPEED_ADJUST_INCREMENT = 0.01
constants.MIN_BASE_SPEED = 0.05
constants.MAX_BASE_SPEED = 0.30

constants.SHIELD_COST = 30
constants.MAGNET_COST = 20
constants.MAGNET_DURATION = 10
constants.MAGNET_RANGE = 2
constants.SPEED_REDUCER_COST = 15
constants.SPEED_REDUCER_AMOUNT = 0.02
constants.ARMOR_COST = 40
constants.GHOST_COST = 25
constants.GHOST_DURATION = 5
constants.BOMB_COST = 25
constants.BOMB_RADIUS = 3
constants.HUNGER_COST = 15
constants.TURBO_COST = 20
constants.TURBO_MULTIPLIER = 0.7
constants.TURBO_DURATION = 8
constants.SLOW_COST = 25
constants.SLOW_TIMESCALE = 0.5
constants.SLOW_DURATION = 5
constants.DOUBLER_COST = 35
constants.DOUBLER_DURATION = 8
constants.EXTRA_COIN_COST = 20
constants.EXTRA_COIN_DURATION = 10
constants.STAR_COST = 40
constants.STAR_DURATION = 5
constants.COINS_PER_FRUIT = 1

constants.COMBO_WINDOW = 8.0
constants.COMBO_MULTIPLIER = 0.5

constants.FOOD_NORMAL = 1
constants.FOOD_GOLD = 2
constants.FOOD_COIN = 3

constants.OBSTACLE_SPAWN_INTERVAL = 50

constants.COLOR_BG = {0.07, 0.07, 0.12}
constants.COLOR_GRID_A = {0.10, 0.14, 0.22}
constants.COLOR_GRID_B = {0.13, 0.17, 0.26}
constants.COLOR_ACCENT = {0.0, 0.85, 1.0}
constants.COLOR_GRID_HOT_A = {0.22, 0.10, 0.18}
constants.COLOR_GRID_HOT_B = {0.26, 0.13, 0.22}
constants.SHIMMER_SPEED = 2.0
constants.COLOR_GOLD = {1.0, 0.84, 0.0}
constants.COLOR_PANEL = {0.12, 0.12, 0.22, 0.9}
constants.COLOR_RED = {1.0, 0.2, 0.2}
constants.COLOR_GREEN = {0.2, 0.9, 0.3}

constants.FONT_FILE = "PressStart2P-Regular.ttf"
constants.FONT_TITLE = 28
constants.FONT_LARGE = 16
constants.FONT_NORMAL = 11
constants.FONT_SMALL = 8

constants.HUD_HEIGHT = 28
constants.GRID_OFFSET_Y = 28

constants.SCORE_POPUP_LIFETIME = 1.0
constants.SCORE_POPUP_SPEED = 40

constants.PARTICLE_COMER_COUNT = 15
constants.PARTICLE_MUERTE_COUNT = 25
constants.PARTICLE_ENEMY_COUNT = 10

constants.ENEMY_SPAWN_INTERVAL = 50

constants.TRANSITION_DURATION = 0.8

constants.BOSS_TYPE_TELEPORTER = "teleporter"
constants.BOSS_TYPE_SPAWNER   = "spawner_boss"
constants.BOSS_COLORS = {
    teleporter = {1, 0.2, 0.6},
    spawner_boss = {0.8, 0.4, 0.1}
}

constants.ENEMY_CHASER_SPEED = 0.3
constants.ENEMY_PATROLLER_SPEED = 0.2
constants.ENEMY_SPAWNER_INTERVAL = 3

constants.ENEMY_DROP_CHASER = 3
constants.ENEMY_DROP_PATROLLER = 2
constants.ENEMY_DROP_SPAWNER = 1

constants.COLOR_ENEMY_CHASER = {0.9, 0.2, 0.2}
constants.COLOR_ENEMY_PATROLLER = {0.2, 0.4, 0.9}
constants.COLOR_ENEMY_SPAWNER = {0.6, 0.2, 0.8}

return constants
