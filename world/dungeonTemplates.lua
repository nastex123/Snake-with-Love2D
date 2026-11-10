local Templates = {}
Templates.stageModifiers = {
    [1] = {biome = "catacumbas", name = "Catacumbas de Piedra", wallWrap = true, spawnRate = 1.0, enemySpeed = 1.0, chaserWeight = 0.40, patrollerWeight = 0.35, spawnerWeight = 0.25, targetMult = 1.0, bossVida = 3},
    [2] = {biome = "hielo", name = "Cripta Helada", wallWrap = true, isIce = true, spawnRate = 1.2, enemySpeed = 1.15, chaserWeight = 0.50, patrollerWeight = 0.30, spawnerWeight = 0.20, targetMult = 1.3, bossVida = 4},
    [3] = {biome = "volcan", name = "Caverna Volcanica", wallWrap = true, hazardLava = true, spawnRate = 1.4, enemySpeed = 1.3, chaserWeight = 0.35, patrollerWeight = 0.30, spawnerWeight = 0.35, targetMult = 1.6, bossVida = 5},
    [4] = {biome = "colmena", name = "Colmena Toxica", wallWrap = true, isSlime = true, spawnRate = 1.6, enemySpeed = 1.5, chaserWeight = 0.50, patrollerWeight = 0.20, spawnerWeight = 0.30, targetMult = 2.0, bossVida = 6},
    [5] = {biome = "vacio", name = "Santuario del Vacio", wallWrap = false, spawnRate = 2.0, enemySpeed = 1.8, chaserWeight = 0.40, patrollerWeight = 0.25, spawnerWeight = 0.35, targetMult = 2.5, bossVida = 8},
}
Templates.stageMod = {
    [1] = {countMult = 1.0, hpMult = 1.0, objMult = 1.0, bossHP = 3},
    [2] = {countMult = 1.2, hpMult = 1.15, objMult = 1.3, bossHP = 4},
    [3] = {countMult = 1.4, hpMult = 1.3, objMult = 1.6, bossHP = 5},
    [4] = {countMult = 1.7, hpMult = 1.6, objMult = 2.0, bossHP = 6},
    [5] = {countMult = 2.0, hpMult = 2.2, objMult = 2.5, bossHP = 8},
}
Templates.roomTemplates = {
    corridor = {id = "corridor", name = "Pasillo", weight = 0.25, objectiveBase = 30, constraints = {minW = 5, minH = 5}, spawnRules = {enemies = {{type = "patroller", baseCount = 1, weight = 0.5}}, food = {baseCount = 1, goldChance = 0.10, coinChance = 0.15}, obstacles = {baseCount = 0}, items = {chance = 0}}},
    arena = {id = "arena", name = "Arena", weight = 0.30, objectiveBase = 60, constraints = {minW = 7, minH = 7}, spawnRules = {enemies = {{type = "chaser", baseCount = 3, weight = 1.0}, {type = "patroller", baseCount = 1, weight = 0.4}}, food = {baseCount = 1, goldChance = 0.20, coinChance = 0.10}, obstacles = {baseCount = 3}, items = {chance = 0.15, possible = {"extraCoin"}}}},
    choke = {id = "choke", name = "Embudo", weight = 0.15, objectiveBase = 50, constraints = {minW = 5, minH = 5}, spawnRules = {enemies = {{type = "chaser", baseCount = 2, weight = 1.0}, {type = "spawner", baseCount = 1, weight = 0.3}}, food = {baseCount = 1, goldChance = 0.10, coinChance = 0.10}, obstacles = {baseCount = 4}, items = {chance = 0}}},
    hub = {id = "hub", name = "Encrucijada", weight = 0.10, objectiveBase = 80, constraints = {minW = 9, minH = 7}, spawnRules = {enemies = {{type = "chaser", baseCount = 2, weight = 1.0}, {type = "patroller", baseCount = 2, weight = 0.6}, {type = "spawner", baseCount = 1, weight = 0.2}}, food = {baseCount = 2, goldChance = 0.25, coinChance = 0.20}, obstacles = {baseCount = 2}, items = {chance = 0.30, possible = {"extraCoin", "speedReducer"}}}},
    treasure = {id = "treasure", name = "Tesoro", weight = 0.08, objectiveBase = 30, constraints = {minW = 5, minH = 5}, spawnRules = {enemies = {{type = "chaser", baseCount = 1, weight = 0.3}}, food = {baseCount = 1, goldChance = 0.60, coinChance = 0.30}, obstacles = {baseCount = 1}, items = {chance = 0.80, possible = {"extraCoin", "speedReducer", "hunger"}}}},
    spawner = {id = "spawner", name = "Nido", weight = 0.07, objectiveBase = 70, constraints = {minW = 6, minH = 6}, spawnRules = {enemies = {{type = "spawner", baseCount = 2, weight = 1.0}, {type = "chaser", baseCount = 1, weight = 0.5}}, food = {baseCount = 1, goldChance = 0.10, coinChance = 0.10}, obstacles = {baseCount = 3}, items = {chance = 0}}},
    boss = {id = "boss", name = "Jefe", weight = 0, objectiveBase = 100, constraints = {minW = 8, minH = 8}, spawnRules = {enemies = {}, food = {baseCount = 0}, obstacles = {baseCount = 0}, items = {chance = 0}, boss = {baseHP = 3, dropCoins = 5}}},
    cruz = {id = "cruz", name = "Cruz", weight = 0.12, objectiveBase = 70, constraints = {minW = 7, minH = 7}, wallPattern = "cruz", spawnRules = {enemies = {{type = "chaser", baseCount = 2, weight = 1.0}, {type = "patroller", baseCount = 1, weight = 0.5}}, food = {baseCount = 1, goldChance = 0.20, coinChance = 0.10}, obstacles = {baseCount = 0}, items = {chance = 0.10, possible = {"extraCoin"}}}},
    espiral = {id = "espiral", name = "Espiral", weight = 0.10, objectiveBase = 60, constraints = {minW = 7, minH = 7}, wallPattern = "espiral", spawnRules = {enemies = {{type = "chaser", baseCount = 1, weight = 1.0}, {type = "patroller", baseCount = 1, weight = 0.5}}, food = {baseCount = 2, goldChance = 0.25, coinChance = 0.15}, obstacles = {baseCount = 0}, items = {chance = 0.15, possible = {"extraCoin"}}}},
    laberinto = {id = "laberinto", name = "Laberinto", weight = 0.08, objectiveBase = 80, constraints = {minW = 8, minH = 8}, wallPattern = "laberinto", spawnRules = {enemies = {{type = "chaser", baseCount = 2, weight = 1.0}, {type = "spawner", baseCount = 1, weight = 0.4}}, food = {baseCount = 1, goldChance = 0.15, coinChance = 0.10}, obstacles = {baseCount = 0}, items = {chance = 0.10, possible = {"extraCoin"}}}},
}
Templates.templateIds = {"corridor", "arena", "choke", "hub", "treasure", "spawner", "cruz", "espiral", "laberinto"}
return Templates
