class EnemyAiController {
  static final int BOOTSTRAP = 0;
  static final int ECO = 1;
  static final int TECH = 2;
  static final int MUSTER = 3;
  static final int ATTACK = 4;

  int phase = BOOTSTRAP;
  float decisionTimer = 0;
  float attackTimer = 0;
  float lastEnemyArmyValue = 0;
  int waveSerial = 0;
  String lastAction = "init";
  ArrayList<KnownEnemyBuilding> knownEnemyBuildings = new ArrayList<KnownEnemyBuilding>();
  PVector lastSeenEnemyUnitPos;
  float exploreRetargetTimer = 0;
  PVector exploreTarget;
  ArrayList<PVector> exploreWaypoints = new ArrayList<PVector>();
  int exploreWaypointIndex = 0;
  static final int ATTACK_SQUAD_MIN = 8;
  String profile = "balanced";
  float profileAttackIntervalMul = 1.0;
  float profileAttackAdvantageMul = 1.0;
  float profileMinersMul = 1.0;
  float profileTowerBias = 1.0;
  float profileRocketBias = 1.0;

  void update(float dt, GameState gs) {
    rememberSeenEnemies(gs, dt);
    decisionTimer -= dt;
    attackTimer += dt;
    exploreRetargetTimer -= dt;
    if (decisionTimer > 0) {
      return;
    }
    decisionTimer = gs.enemyAiDecisionInterval;
    tick(gs);
  }

  void tick(GameState gs) {
    int enemyMines = gs.countFactionBuildingsByType(Faction.ENEMY, "mine", false);
    int enemyWarehouses = gs.countFactionBuildingsByType(Faction.ENEMY, "warehouse", false);
    int enemyBarracks = gs.countFactionBuildingsByType(Faction.ENEMY, "barracks", false);
    int enemyMiners = gs.countFactionUnitsByType(Faction.ENEMY, "miner");
    int enemyCombat = gs.countFactionCombatUnits(Faction.ENEMY);
    int enemyTowers = gs.countFactionBuildingsByType(Faction.ENEMY, "tower", false);

    float enemyArmyValue = gs.armyValueForFaction(Faction.ENEMY);
    float playerArmyValue = max(1, gs.armyValueForFaction(Faction.PLAYER));
    lastEnemyArmyValue = enemyArmyValue;

    int targetMinersFloor = max(1, int(gs.enemyAiMinersMin * profileMinersMul));
    if (enemyMines < 1 || enemyMiners < targetMinersFloor) {
      phase = ECO;
    } else if (enemyWarehouses < 1 || enemyBarracks < 1) {
      phase = TECH;
    } else if (enemyCombat < gs.enemyAiAttackMinArmy) {
      phase = MUSTER;
    } else {
      phase = ATTACK;
    }

    // Benchmark owns base layout; skip AI building queues so destroyed structures are not replaced.
    if (!gs.benchmarkScenarioActive) {
      runEconomy(gs, enemyMines, enemyMiners);
      runTech(gs, enemyWarehouses, enemyBarracks);
      runDefense(gs, enemyTowers);
    }
    runProduction(gs, enemyMiners, enemyCombat);

    PVector strategicTarget = chooseStrategicTarget(gs);
    boolean readyByTime = attackTimer >= gs.enemyAiAttackInterval * profileAttackIntervalMul;
    boolean readyByAdv = enemyArmyValue >= playerArmyValue * gs.enemyAiAttackAdvantage * profileAttackAdvantageMul;
    boolean readyByCount = enemyCombat >= gs.enemyAiAttackMinArmy + 2;
    boolean readyToCommit = readyByTime || readyByAdv || readyByCount || phase == ATTACK;
    if (strategicTarget != null) {
      if (enemyCombat >= ATTACK_SQUAD_MIN && readyToCommit) {
        launchAttackWave(gs, strategicTarget);
        attackTimer = 0;
      } else {
        rallyArmy(gs);
        lastAction = "hold-muster-" + enemyCombat + "/" + ATTACK_SQUAD_MIN;
      }
      return;
    }
    runExploration(gs);
  }

  void rememberSeenEnemies(GameState gs, float dt) {
    for (int i = knownEnemyBuildings.size() - 1; i >= 0; i--) {
      KnownEnemyBuilding kb = knownEnemyBuildings.get(i);
      kb.ttl -= dt;
      if (kb.ttl <= 0) {
        knownEnemyBuildings.remove(i);
      }
    }
    for (Building b : gs.buildings) {
      if (b.faction != Faction.PLAYER || b.hp <= 0) {
        continue;
      }
      PVector bc = new PVector(b.pos.x + b.tileW * gs.map.tileSize * 0.5, b.pos.y + b.tileH * gs.map.tileSize * 0.5);
      if (!enemyCanSee(gs, bc)) {
        continue;
      }
      upsertKnownBuilding(b.buildingType, bc);
    }
    for (Unit u : gs.units) {
      if (u.faction != Faction.PLAYER || u.hp <= 0) {
        continue;
      }
      if (enemyCanSee(gs, u.pos)) {
        lastSeenEnemyUnitPos = u.pos.copy();
      }
    }
  }

  boolean enemyCanSee(GameState gs, PVector p) {
    for (Unit eu : gs.units) {
      if (eu.faction != Faction.ENEMY || eu.hp <= 0) {
        continue;
      }
      float vis = max(eu.sightRange, 120);
      if (PVector.dist(eu.pos, p) <= vis && gs.pathfinder.hasLineOfSight(eu.pos, p, gs.buildings)) {
        return true;
      }
    }
    return false;
  }

  void upsertKnownBuilding(String type, PVector pos) {
    for (KnownEnemyBuilding kb : knownEnemyBuildings) {
      if (PVector.dist(kb.pos, pos) < 28) {
        kb.type = type;
        kb.pos = pos.copy();
        kb.ttl = 35;
        return;
      }
    }
    knownEnemyBuildings.add(new KnownEnemyBuilding(type, pos.copy(), 35));
  }

  int buildingPriority(String type) {
    if ("base".equals(type)) return 0;
    if ("barracks".equals(type)) return 1;
    if ("tower".equals(type)) return 2;
    if ("mine".equals(type)) return 3;
    return 4;
  }

  PVector chooseStrategicTarget(GameState gs) {
    KnownEnemyBuilding best = null;
    int bestP = 999;
    float bestD = 1e9;
    Building eb = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector from = eb == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75)
      : new PVector(eb.pos.x + eb.tileW * gs.map.tileSize * 0.5, eb.pos.y + eb.tileH * gs.map.tileSize * 0.5);
    for (KnownEnemyBuilding kb : knownEnemyBuildings) {
      int p = buildingPriority(kb.type);
      float d = PVector.dist(from, kb.pos);
      if (p < bestP || (p == bestP && d < bestD)) {
        bestP = p;
        bestD = d;
        best = kb;
      }
    }
    if (best != null) return best.pos.copy();
    if (lastSeenEnemyUnitPos != null) return lastSeenEnemyUnitPos.copy();
    return null;
  }

  void runEconomy(GameState gs, int enemyMines, int enemyMiners) {
    Building base = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector anchor = base == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75) : base.pos.copy();
    if (enemyMines < 1 && gs.tryQueueBuildingForFaction(Faction.ENEMY, "mine", anchor)) {
      lastAction = "build:mine";
      return;
    }
    if (enemyMines < 2 && gs.enemyResources.credits > 280 && enemyMiners >= gs.enemyAiMinersMin + 1) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "mine", anchor)) {
        lastAction = "expand:mine";
      }
    }
  }

  void runTech(GameState gs, int enemyWarehouses, int enemyBarracks) {
    Building base = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector anchor = base == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75) : base.pos.copy();
    if (enemyWarehouses < 1) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "warehouse", PVector.add(anchor, new PVector(-gs.map.tileSize * 2.0, -gs.map.tileSize * 4.0)))) {
        lastAction = "build:warehouse";
        return;
      }
    }
    if (enemyBarracks < 1) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "barracks", PVector.add(anchor, new PVector(-gs.map.tileSize * 5.0, -gs.map.tileSize * 3.0)))) {
        lastAction = "build:barracks";
        return;
      }
    }
    if (enemyBarracks < 2 && gs.enemyResources.credits > 420 && gs.countFactionCombatUnits(Faction.ENEMY) >= 8) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "barracks", PVector.add(anchor, new PVector(-gs.map.tileSize * 8.0, -gs.map.tileSize * 5.0)))) {
        lastAction = "expand:barracks";
      }
    }
  }

  void runDefense(GameState gs, int enemyTowers) {
    Building base = gs.findMainBaseForFaction(Faction.ENEMY);
    if (base == null) return;
    boolean underPressure = false;
    PVector bc = new PVector(base.pos.x + base.tileW * gs.map.tileSize * 0.5, base.pos.y + base.tileH * gs.map.tileSize * 0.5);
    for (Unit pu : gs.units) {
      if (pu.faction == Faction.PLAYER && pu.hp > 0 && !pu.canHarvest) {
        if (PVector.dist(pu.pos, bc) < gs.map.tileSize * 14) {
          underPressure = true;
          break;
        }
      }
    }
    int towerCap = max(1, int(2 * profileTowerBias));
    if (!underPressure && enemyTowers >= towerCap) return;
    if (gs.enemyResources.credits < 180) return;
    if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "tower", PVector.add(base.pos, new PVector(-gs.map.tileSize * 3.0, gs.map.tileSize * 2.0)))) {
      lastAction = "build:tower";
    }
  }

  void runProduction(GameState gs, int enemyMiners, int enemyCombat) {
    int baseMin = max(1, int(gs.enemyAiMinersMin * profileMinersMul));
    int baseMax = max(baseMin, int(gs.enemyAiMinersMax * profileMinersMul));
    int targetMiners = int(constrain(baseMin + enemyCombat / 6, baseMin, baseMax));
    if (enemyMiners < targetMiners && gs.tryTrainUnitForFaction(Faction.ENEMY, "miner")) {
      lastAction = "train:miner";
      return;
    }
    int rifleCount = gs.countFactionUnitsByType(Faction.ENEMY, "rifleman");
    int rocketCount = gs.countFactionUnitsByType(Faction.ENEMY, "rocketeer");
    int combatCount = max(1, rifleCount + rocketCount);
    float rifleShare = rifleCount / float(combatCount);
    float rocketShare = rocketCount / float(combatCount);
    float rocketTargetRatio = constrain(gs.enemyAiRocketRatio * profileRocketBias, 0.05, 0.90);
    if (rocketShare < rocketTargetRatio && gs.tryTrainUnitForFaction(Faction.ENEMY, "rocketeer")) {
      lastAction = "train:rocketeer";
      return;
    }
    if (rifleShare < gs.enemyAiRifleRatio && gs.tryTrainUnitForFaction(Faction.ENEMY, "rifleman")) {
      lastAction = "train:rifleman";
      return;
    }
    if (!gs.tryTrainUnitForFaction(Faction.ENEMY, "rifleman")) {
      gs.tryTrainUnitForFaction(Faction.ENEMY, "rocketeer");
    }
  }

  void runExploration(GameState gs) {
    if (exploreWaypoints.size() == 0) buildExploreWaypoints(gs);
    if (exploreWaypoints.size() == 0) return;
    if (exploreTarget == null || exploreRetargetTimer <= 0) {
      exploreWaypointIndex = (exploreWaypointIndex + 1) % exploreWaypoints.size();
      exploreTarget = exploreWaypoints.get(exploreWaypointIndex).copy();
      exploreRetargetTimer = random(5.5, 8.5);
    }
    int nearby = 0;
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) continue;
      if (PVector.dist(u.pos, exploreTarget) < gs.map.tileSize * 2.2) nearby++;
    }
    if (nearby >= 2) exploreRetargetTimer = 0;
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) continue;
      if (u.orderType != UnitOrderType.ATTACK || u.attackTarget == null) {
        u.issueAttackMove(exploreTarget.copy(), gs, false);
      }
    }
    lastAction = "explore";
  }

  void buildExploreWaypoints(GameState gs) {
    exploreWaypoints.clear();
    float ts = gs.map.tileSize;
    int cols = max(4, gs.map.widthTiles / 14);
    int rows = max(4, gs.map.heightTiles / 14);
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        float tx = cols <= 1 ? 0.5 : x / float(cols - 1);
        float ty = rows <= 1 ? 0.5 : y / float(rows - 1);
        float gx = lerp(ts * 2.5, gs.map.worldWidthPx() - ts * 2.5, tx);
        float gy = lerp(ts * 2.5, gs.map.worldHeightPx() - ts * 2.5, ty);
        PVector desired = new PVector(gx, gy);
        PVector openPos = gs.findNearestOpenSlot(desired, new ArrayList<String>());
        exploreWaypoints.add(openPos);
      }
    }
    for (int i = 0; i < exploreWaypoints.size(); i += 2) {
      int j = exploreWaypoints.size() - 1 - i;
      if (j > i) {
        PVector t = exploreWaypoints.get(i);
        exploreWaypoints.set(i, exploreWaypoints.get(j));
        exploreWaypoints.set(j, t);
      }
    }
    exploreWaypointIndex = int(random(exploreWaypoints.size()));
  }

  void rallyArmy(GameState gs) {
    PVector rally = gs.enemyRallyPoint();
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) continue;
      if (u.orderType == UnitOrderType.ATTACK || u.orderType == UnitOrderType.ATTACK_MOVE) continue;
      if (u.moveTarget != null && PVector.dist(u.moveTarget, rally) < 24 && u.pathQueue.size() > 0) continue;
      u.issueMove(rally.copy(), gs, false);
    }
    lastAction = "muster";
  }

  void launchAttackWave(GameState gs, PVector target) {
    int readyUnits = gs.countFactionCombatUnits(Faction.ENEMY);
    if (readyUnits < ATTACK_SQUAD_MIN) {
      lastAction = "hold-muster-" + readyUnits + "/" + ATTACK_SQUAD_MIN;
      return;
    }
    waveSerial++;
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) continue;
      u.issueAttackMove(target.copy(), gs, false);
    }
    lastAction = "attack-wave-" + waveSerial;
  }

  String phaseLabel() {
    if (phase == ECO) return "ECO";
    if (phase == TECH) return "TECH";
    if (phase == MUSTER) return "MUSTER";
    if (phase == ATTACK) return "ATTACK";
    return "BOOTSTRAP";
  }

  void applyProfile(String profileName, GameState gs) {
    profile = profileName == null ? "balanced" : trim(profileName.toLowerCase());
    profileAttackIntervalMul = 1.0;
    profileAttackAdvantageMul = 1.0;
    profileMinersMul = 1.0;
    profileTowerBias = 1.0;
    profileRocketBias = 1.0;
    if ("rush".equals(profile)) {
      profileAttackIntervalMul = 0.72;
      profileAttackAdvantageMul = 0.88;
      profileMinersMul = 0.85;
      profileTowerBias = 0.8;
      profileRocketBias = 0.9;
    } else if ("greed".equals(profile)) {
      profileAttackIntervalMul = 1.18;
      profileAttackAdvantageMul = 1.08;
      profileMinersMul = 1.25;
      profileTowerBias = 0.9;
      profileRocketBias = 0.85;
    } else if ("turtle".equals(profile)) {
      profileAttackIntervalMul = 1.28;
      profileAttackAdvantageMul = 1.22;
      profileMinersMul = 1.05;
      profileTowerBias = 1.6;
      profileRocketBias = 1.2;
    } else {
      profile = "balanced";
    }
    if (gs != null && gs.enemyAiDebug) {
      println("Enemy AI profile: " + profile);
    }
  }
}

class KnownEnemyBuilding {
  String type;
  PVector pos;
  float ttl;

  KnownEnemyBuilding(String type, PVector pos, float ttl) {
    this.type = type;
    this.pos = pos;
    this.ttl = ttl;
  }
}
