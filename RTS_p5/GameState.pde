class GameState {
  int screenW;
  int screenH;
  int worldViewW;
  int sidePanelW;
  float sidePanelWidthRatio = 0.24;
  int sidePanelMinW = 300;
  int sidePanelMaxW = 460;
  float wheelZoomStep = 1.08;
  float edgeScrollSpeed = 480;
  boolean fogEnabled = true;
  boolean fogSoftEdges = true;
  int fogEdgeRadius = 2;
  float fogEdgeStrength = 0.52;
  float fogUpdateInterval = 0.10;
  int fogBatchSourcesPerFrame = 18;
  boolean fogAutoAdaptiveInterval = true;
  int fogAutoAdaptiveThreshold = 12;
  float fogAutoAdaptiveStep = 0.004;
  float fogAutoAdaptiveMaxInterval = 0.22;
  int fogUnexploredAlpha = 220;
  int fogExploredAlpha = 120;

  TileMap map;
  Camera camera;
  UISystem ui;
  InputSystem input;
  CommandSystem commandSystem;
  BuildSystem buildSystem;
  Pathfinder pathfinder;
  FogSystem fog;
  UnitDef scoutDef;
  HashMap<String, UnitDef> unitDefsById = new HashMap<String, UnitDef>();
  HashMap<String, BuildingDef> buildingDefsById = new HashMap<String, BuildingDef>();
  ArrayList<BuildingDef> buildingDefs = new ArrayList<BuildingDef>();
  ArrayList<GoldMine> goldMines = new ArrayList<GoldMine>();
  ArrayList<MuzzleFx> muzzleFx = new ArrayList<MuzzleFx>();
  ArrayList<RocketProjectile> rockets = new ArrayList<RocketProjectile>();
  ArrayList<DeliveryFx> deliveries = new ArrayList<DeliveryFx>();
  ArrayList<TrainJob> trainQueue = new ArrayList<TrainJob>();
  ResourcePool resources;
  ResourcePool enemyResources;
  float enemyAiDecisionInterval = 0.22;
  int enemyAiMinersMin = 3;
  int enemyAiMinersMax = 8;
  float enemyAiAttackInterval = 55;
  float enemyAiAttackAdvantage = 1.20;
  int enemyAiAttackMinArmy = 7;
  float enemyAiRifleRatio = 0.52;
  float enemyAiRocketRatio = 0.30;
  boolean enemyAiDebug = false;
  int playerStartCredits = 2000;
  int enemyStartCredits = 100;
  int playerBaseSupplyCap = 8;
  int enemyBaseSupplyCap = 8;
  int warehouseSupplyCapBonus = 20;
  int warehouseCreditCapBonus = 1000;
  int defaultCreditCap = 2000;
  EnemyAiController enemyAi;
  String orderLabel = "";
  boolean attackMoveArmed = false;
  boolean hardCursorLock = false;
  CursorLock cursorLock;
  ArrayList<OrderMarker> orderMarkers = new ArrayList<OrderMarker>();
  boolean debugShowPaths = false;

  ArrayList<Unit> units = new ArrayList<Unit>();
  ArrayList<Building> buildings = new ArrayList<Building>();
  ArrayList<Unit> selectedUnits = new ArrayList<Unit>();
  Building selectedBuilding;
  HashMap<Integer, ArrayList<Unit>> controlGroups = new HashMap<Integer, ArrayList<Unit>>();
  int editingControlGroup = -1;
  Faction activeFaction = Faction.PLAYER;
  String gameResult = "";
  boolean gameEnded = false;
  String lastStartError = "";
  ArrayList<UiHitButton> gameEndHitButtons = new ArrayList<UiHitButton>();
  boolean pendingReturnToMenu = false;

  GameState(int screenW, int screenH) {
    this.screenW = screenW;
    this.screenH = screenH;
    loadUiSettings();
    this.sidePanelW = int(constrain(screenW * sidePanelWidthRatio, sidePanelMinW, sidePanelMaxW));
    this.worldViewW = screenW - sidePanelW;

    ui = new UISystem(worldViewW, screenH);
    commandSystem = new CommandSystem();
    cursorLock = new CursorLock();
    input = new InputSystem(this);
    map = null;
    camera = null;
    fog = null;
    pathfinder = null;
    buildSystem = new BuildSystem(buildingDefs);
    enemyAi = null;
    resetControlGroups();
    orderLabel = tr("order.none");
  }

  /** Full session reset: map, entities, economy, queues. Returns false if map load fails (see lastStartError). */
  boolean startNewGame() {
    lastStartError = "";
    gameEnded = false;
    gameResult = "";
    pendingReturnToMenu = false;
    orderLabel = tr("order.none");
    attackMoveArmed = false;
    trainQueue.clear();
    units.clear();
    buildings.clear();
    selectedUnits.clear();
    selectedBuilding = null;
    resetControlGroups();
    rockets.clear();
    muzzleFx.clear();
    deliveries.clear();
    orderMarkers.clear();
    goldMines.clear();
    buildSystem = new BuildSystem(new ArrayList<BuildingDef>());
    buildSystem.queue.clear();
    buildSystem.currentJob = null;
    buildSystem.active = false;
    buildSystem.lastFailReason = "";

    map = new TileMap();
    if (!map.loadFromJson("map_test.json")) {
      lastStartError = "Failed to load map_test.json";
      println(lastStartError);
      map = null;
      return false;
    }
    loadMapResources();

    camera = new Camera(worldViewW, screenH, map.worldWidthPx(), map.worldHeightPx());
    camera.wheelZoomStep = wheelZoomStep;
    camera.speed = edgeScrollSpeed;
    fog = new FogSystem(map);
    loadDefinitions();
    buildSystem = new BuildSystem(buildingDefs);
    resources = new ResourcePool(playerStartCredits, creditCapForFaction(Faction.PLAYER));
    enemyResources = new ResourcePool(enemyStartCredits, creditCapForFaction(Faction.ENEMY));
    pathfinder = new Pathfinder(map);
    enemyAi = new EnemyAiController();

    seedDemoEntities();
    refreshFactionCaps();
    ui.clearBuildButtonState();
    return true;
  }

  boolean sessionReady() {
    return map != null && camera != null;
  }

  void seedDemoEntities() {
    UnitDef miner = getUnitDef("miner");
    UnitDef rifle = getUnitDef("rifleman");
    UnitDef rocket = getUnitDef("rocketeer");
    if (miner == null) {
      miner = scoutDef;
    }
    if (rifle == null) {
      rifle = scoutDef;
    }
    if (rocket == null) {
      rocket = scoutDef;
    }
    float ts = map.tileSize;
    PVector playerBasePos = new PVector(8 * ts, 8 * ts);
    PVector enemyBasePos = new PVector((map.widthTiles - 12) * ts, (map.heightTiles - 12) * ts);

    BuildingDef base = getBuildingDef("base");
    if (base == null && buildingDefs.size() > 0) {
      base = buildingDefs.get(0);
    }
    if (base == null) {
      return;
    }
    BuildingDef mine = getBuildingDef("mine");
    BuildingDef warehouse = getBuildingDef("warehouse");
    BuildingDef barracks = getBuildingDef("barracks");

    Building p = addInitialBuildingAt(base, Faction.PLAYER, playerBasePos.x, playerBasePos.y, 1);
    Building e = addInitialBuildingAt(base, Faction.ENEMY, enemyBasePos.x, enemyBasePos.y, 1);

    if (mine != null) {
      addInitialBuildingAt(mine, Faction.PLAYER, playerBasePos.x + ts * 5.0, playerBasePos.y + ts * 0.4, 1);
      addInitialBuildingAt(mine, Faction.ENEMY, enemyBasePos.x - ts * 5.2, enemyBasePos.y - ts * 0.6, 1);
    }
    if (warehouse != null) {
      addInitialBuildingAt(warehouse, Faction.PLAYER, playerBasePos.x + ts * 0.2, playerBasePos.y + ts * 5.6, 1);
      addInitialBuildingAt(warehouse, Faction.ENEMY, enemyBasePos.x - ts * 0.4, enemyBasePos.y - ts * 5.8, 1);
    }
    if (barracks != null) {
      addInitialBuildingAt(barracks, Faction.PLAYER, playerBasePos.x + ts * 6.2, playerBasePos.y + ts * 5.8, 1);
      addInitialBuildingAt(barracks, Faction.ENEMY, enemyBasePos.x - ts * 6.5, enemyBasePos.y - ts * 6.0, 1);
    }

    spawnInitialUnitNear(playerBasePos, Faction.PLAYER, miner, 2.8f, 3.4f);
    spawnInitialUnitNear(playerBasePos, Faction.PLAYER, miner, 3.7f, 3.8f);
    spawnInitialUnitNear(playerBasePos, Faction.PLAYER, rifle, 4.6f, 4.2f);
    spawnInitialUnitNear(playerBasePos, Faction.PLAYER, rocket, 5.4f, 5.0f);
    spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, miner, -2.8f, -3.2f);
    spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, miner, -3.8f, -3.8f);
    spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, rifle, -4.6f, -4.3f);
    spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, rocket, -5.5f, -5.1f);
  }

  Building addInitialBuildingAt(BuildingDef def, Faction faction, float desiredX, float desiredY, int paddingTiles) {
    if (def == null) {
      return null;
    }
    PVector placed = findValidBuildingPlacement(def, desiredX, desiredY, paddingTiles);
    Building b = new Building(placed.x, placed.y, def.tileW, def.tileH, faction, def);
    b.completed = true;
    b.buildProgress = b.buildTime;
    buildings.add(b);
    return b;
  }

  PVector findValidBuildingPlacement(BuildingDef def, float desiredX, float desiredY, int paddingTiles) {
    int desiredTx = map.toTileX(desiredX);
    int desiredTy = map.toTileY(desiredY);
    for (int r = 0; r <= 12; r++) {
      for (int oy = -r; oy <= r; oy++) {
        for (int ox = -r; ox <= r; ox++) {
          int tx = desiredTx + ox;
          int ty = desiredTy + oy;
          if (canPlaceBuildingFootprint(def, tx, ty, paddingTiles)) {
            return new PVector(tx * map.tileSize, ty * map.tileSize);
          }
        }
      }
    }
    return new PVector(max(0, desiredTx) * map.tileSize, max(0, desiredTy) * map.tileSize);
  }

  boolean canPlaceBuildingFootprint(BuildingDef def, int tx, int ty, int paddingTiles) {
    if (def == null) {
      return false;
    }
    if (tx < 0 || ty < 0 || tx + def.tileW > map.widthTiles || ty + def.tileH > map.heightTiles) {
      return false;
    }
    for (int y = 0; y < def.tileH; y++) {
      for (int x = 0; x < def.tileW; x++) {
        if (map.isBlockedTile(tx + x, ty + y)) {
          return false;
        }
      }
    }
    float pad = max(0, paddingTiles) * map.tileSize;
    float worldX = tx * map.tileSize - pad;
    float worldY = ty * map.tileSize - pad;
    float w = def.tileW * map.tileSize + pad * 2;
    float h = def.tileH * map.tileSize + pad * 2;
    for (Building b : buildings) {
      if (worldX < b.pos.x + b.tileW * map.tileSize &&
        worldX + w > b.pos.x &&
        worldY < b.pos.y + b.tileH * map.tileSize &&
        worldY + h > b.pos.y) {
        return false;
      }
    }
    return true;
  }

  void spawnInitialUnitNear(PVector anchor, Faction faction, UnitDef def, float oxTile, float oyTile) {
    if (def == null) {
      return;
    }
    PVector desired = new PVector(anchor.x + oxTile * map.tileSize, anchor.y + oyTile * map.tileSize);
    PVector safe = findNearestOpenSlot(desired, new ArrayList<String>());
    units.add(new Unit(safe.x, safe.y, faction, def));
  }

  void loadUiSettings() {
    JSONObject root = loadJSONObject("ui.json");
    if (root == null) {
      return;
    }
    sidePanelWidthRatio = root.getFloat("sidePanelWidthRatio", sidePanelWidthRatio);
    sidePanelMinW = root.getInt("sidePanelMinW", sidePanelMinW);
    sidePanelMaxW = root.getInt("sidePanelMaxW", sidePanelMaxW);
    wheelZoomStep = root.getFloat("wheelZoomStep", wheelZoomStep);
    edgeScrollSpeed = root.getFloat("edgeScrollSpeed", edgeScrollSpeed);
    fogEnabled = root.getBoolean("fogEnabled", fogEnabled);
    fogSoftEdges = root.getBoolean("fogSoftEdges", fogSoftEdges);
    fogEdgeRadius = root.getInt("fogEdgeRadius", fogEdgeRadius);
    fogEdgeStrength = root.getFloat("fogEdgeStrength", fogEdgeStrength);
    fogUpdateInterval = root.getFloat("fogUpdateInterval", fogUpdateInterval);
    fogBatchSourcesPerFrame = root.getInt("fogBatchSourcesPerFrame", fogBatchSourcesPerFrame);
    fogAutoAdaptiveInterval = root.getBoolean("fogAutoAdaptiveInterval", fogAutoAdaptiveInterval);
    fogAutoAdaptiveThreshold = root.getInt("fogAutoAdaptiveThreshold", fogAutoAdaptiveThreshold);
    fogAutoAdaptiveStep = root.getFloat("fogAutoAdaptiveStep", fogAutoAdaptiveStep);
    fogAutoAdaptiveMaxInterval = root.getFloat("fogAutoAdaptiveMaxInterval", fogAutoAdaptiveMaxInterval);
    fogUnexploredAlpha = root.getInt("fogUnexploredAlpha", fogUnexploredAlpha);
    fogExploredAlpha = root.getInt("fogExploredAlpha", fogExploredAlpha);
    enemyAiDecisionInterval = root.getFloat("enemyAiDecisionInterval", enemyAiDecisionInterval);
    enemyAiMinersMin = root.getInt("enemyAiMinersMin", enemyAiMinersMin);
    enemyAiMinersMax = root.getInt("enemyAiMinersMax", enemyAiMinersMax);
    enemyAiAttackInterval = root.getFloat("enemyAiAttackInterval", enemyAiAttackInterval);
    enemyAiAttackAdvantage = root.getFloat("enemyAiAttackAdvantage", enemyAiAttackAdvantage);
    enemyAiAttackMinArmy = root.getInt("enemyAiAttackMinArmy", enemyAiAttackMinArmy);
    enemyAiRifleRatio = root.getFloat("enemyAiRifleRatio", enemyAiRifleRatio);
    enemyAiRocketRatio = root.getFloat("enemyAiRocketRatio", enemyAiRocketRatio);
    enemyAiDebug = root.getBoolean("enemyAiDebug", enemyAiDebug);
    playerStartCredits = root.getInt("playerStartCredits", playerStartCredits);
    enemyStartCredits = root.getInt("enemyStartCredits", enemyStartCredits);
    defaultCreditCap = root.getInt("defaultCreditCap", defaultCreditCap);
    playerBaseSupplyCap = root.getInt("playerBaseSupplyCap", playerBaseSupplyCap);
    enemyBaseSupplyCap = root.getInt("enemyBaseSupplyCap", enemyBaseSupplyCap);
    warehouseSupplyCapBonus = root.getInt("warehouseSupplyCapBonus", warehouseSupplyCapBonus);
    warehouseCreditCapBonus = root.getInt("warehouseCreditCapBonus", warehouseCreditCapBonus);
    sidePanelWidthRatio = constrain(sidePanelWidthRatio, 0.12, 0.45);
    sidePanelMinW = max(180, sidePanelMinW);
    sidePanelMaxW = max(sidePanelMinW, sidePanelMaxW);
    wheelZoomStep = constrain(wheelZoomStep, 1.02, 1.35);
    edgeScrollSpeed = constrain(edgeScrollSpeed, 160, 1800);
    fogEdgeRadius = int(constrain(fogEdgeRadius, 1, 4));
    fogEdgeStrength = constrain(fogEdgeStrength, 0.10, 0.80);
    fogUpdateInterval = constrain(fogUpdateInterval, 0.02, 0.30);
    fogBatchSourcesPerFrame = int(constrain(fogBatchSourcesPerFrame, 2, 128));
    fogAutoAdaptiveThreshold = int(constrain(fogAutoAdaptiveThreshold, 0, 2000));
    fogAutoAdaptiveStep = constrain(fogAutoAdaptiveStep, 0.0, 0.03);
    fogAutoAdaptiveMaxInterval = constrain(fogAutoAdaptiveMaxInterval, fogUpdateInterval, 0.8);
    fogUnexploredAlpha = int(constrain(fogUnexploredAlpha, 80, 255));
    fogExploredAlpha = int(constrain(fogExploredAlpha, 30, 220));
    enemyAiDecisionInterval = constrain(enemyAiDecisionInterval, 0.08, 0.8);
    enemyAiMinersMin = int(constrain(enemyAiMinersMin, 1, 24));
    enemyAiMinersMax = int(constrain(enemyAiMinersMax, enemyAiMinersMin, 32));
    enemyAiAttackInterval = constrain(enemyAiAttackInterval, 12, 180);
    enemyAiAttackAdvantage = constrain(enemyAiAttackAdvantage, 0.7, 2.4);
    enemyAiAttackMinArmy = int(constrain(enemyAiAttackMinArmy, 2, 40));
    enemyAiRifleRatio = constrain(enemyAiRifleRatio, 0.10, 0.80);
    enemyAiRocketRatio = constrain(enemyAiRocketRatio, 0.05, 0.70);
    playerStartCredits = int(constrain(playerStartCredits, 0, 99999));
    enemyStartCredits = int(constrain(enemyStartCredits, 0, 99999));
    defaultCreditCap = int(constrain(defaultCreditCap, 200, 999999));
    playerBaseSupplyCap = int(constrain(playerBaseSupplyCap, 1, 300));
    enemyBaseSupplyCap = int(constrain(enemyBaseSupplyCap, 1, 300));
    warehouseSupplyCapBonus = int(constrain(warehouseSupplyCapBonus, 1, 200));
    warehouseCreditCapBonus = int(constrain(warehouseCreditCapBonus, 50, 100000));
  }

  void loadDefinitions() {
    unitDefsById.clear();
    buildingDefsById.clear();
    scoutDef = new UnitDef();
    scoutDef.id = "scout";
    scoutDef.role = "machinegun";
    scoutDef.speed = 120;
    scoutDef.radius = 11;
    scoutDef.hp = 100;
    unitDefsById.put(scoutDef.id, scoutDef);

    BuildingDef defaultOutpost = new BuildingDef();
    defaultOutpost.id = "base";
    defaultOutpost.category = "core";
    defaultOutpost.tileW = 2;
    defaultOutpost.tileH = 2;
    defaultOutpost.buildTime = 3.0;
    defaultOutpost.cost = 120;
    defaultOutpost.prerequisites = new String[0];
    defaultOutpost.trainableUnits = new String[0];
    buildingDefs.add(defaultOutpost);
    buildingDefsById.put(defaultOutpost.id, defaultOutpost);

    JSONObject unitRoot = loadJSONObject("units.json");
    if (unitRoot != null) {
      JSONArray arr = unitRoot.getJSONArray("units");
      if (arr != null && arr.size() > 0) {
        unitDefsById.clear();
        for (int i = 0; i < arr.size(); i++) {
          JSONObject o = arr.getJSONObject(i);
          UnitDef def = new UnitDef();
          def.id = o.getString("id", "unit_" + i);
          def.role = o.getString("role", "machinegun");
          def.speed = o.getFloat("speed", 120);
          def.radius = o.getFloat("radius", 11);
          def.hp = o.getInt("hp", 100);
          def.attackRange = o.getFloat("attackRange", 95);
          def.attackDamage = o.getFloat("attackDamage", 8);
          def.attackCooldown = o.getFloat("attackCooldown", 0.6);
          def.canAttack = o.getBoolean("canAttack", true);
          def.cost = o.getInt("cost", 60);
          def.trainTime = o.getFloat("trainTime", 2.0);
          def.sightRange = o.getFloat("sightRange", 220);
          def.usesProjectile = o.getBoolean("usesProjectile", false);
          def.projectileSpeed = o.getFloat("projectileSpeed", 260);
          def.canHarvest = o.getBoolean("canHarvest", false);
          def.harvestAmount = o.getInt("harvestAmount", 20);
          def.harvestTime = o.getFloat("harvestTime", 1.2);
          def.autoDefend = o.getBoolean("autoDefend", true);
          def.supplyCost = max(0, o.getInt("supplyCost", 1));
          unitDefsById.put(def.id, def);
        }
        if (unitDefsById.containsKey("rifleman")) {
          scoutDef = unitDefsById.get("rifleman");
        } else {
          for (String key : unitDefsById.keySet()) {
            scoutDef = unitDefsById.get(key);
            break;
          }
        }
      }
    }

    JSONObject buildingRoot = loadJSONObject("buildings.json");
    if (buildingRoot != null) {
      JSONArray arr = buildingRoot.getJSONArray("buildings");
      if (arr != null && arr.size() > 0) {
        buildingDefs.clear();
        buildingDefsById.clear();
        for (int i = 0; i < arr.size(); i++) {
          JSONObject o = arr.getJSONObject(i);
          BuildingDef def = new BuildingDef();
          def.id = o.getString("id", "building_" + i);
          def.category = o.getString("category", "general");
          def.tileW = o.getInt("tileW", 2);
          def.tileH = o.getInt("tileH", 2);
          def.buildTime = o.getFloat("buildTime", 3.0);
          def.cost = o.getInt("cost", 120);
          def.prerequisites = new String[0];
          def.trainableUnits = new String[0];
          JSONArray req = o.getJSONArray("requires");
          if (req != null) {
            def.prerequisites = new String[req.size()];
            for (int r = 0; r < req.size(); r++) {
              def.prerequisites[r] = req.getString(r);
            }
          }
          def.canTrainUnits = o.getBoolean("canTrainUnits", false);
          JSONArray train = o.getJSONArray("trainableUnits");
          if (train != null) {
            def.trainableUnits = new String[train.size()];
            for (int t = 0; t < train.size(); t++) {
              def.trainableUnits[t] = train.getString(t);
            }
          }
          def.isDropoff = o.getBoolean("isDropoff", false);
          def.isMainBase = o.getBoolean("isMainBase", false);
          def.sellRefundRatio = constrain(o.getFloat("sellRefundRatio", 0.5), 0, 1);
          def.isTower = o.getBoolean("isTower", false);
          def.towerAttackRange = o.getFloat("towerAttackRange", def.towerAttackRange);
          def.towerDamage = o.getFloat("towerDamage", def.towerDamage);
          def.towerCooldown = o.getFloat("towerCooldown", def.towerCooldown);
          def.towerProjectileSpeed = o.getFloat("towerProjectileSpeed", def.towerProjectileSpeed);
          def.useLegacySpawnFallback = o.getBoolean("useLegacySpawnFallback", true);
          def.spawnClearancePad = o.getFloat("spawnClearancePad", 3.0);
          int defaultSupplyBonus = "warehouse".equals(def.id) ? warehouseSupplyCapBonus : 0;
          int defaultCreditBonus = "warehouse".equals(def.id) ? warehouseCreditCapBonus : 0;
          def.supplyCapBonus = max(0, o.getInt("supplyCapBonus", defaultSupplyBonus));
          def.creditCapBonus = max(0, o.getInt("creditCapBonus", defaultCreditBonus));
          JSONArray spawnPointsArr = o.getJSONArray("spawnPoints");
          if (spawnPointsArr != null) {
            def.spawnPoints = new SpawnPointDef[spawnPointsArr.size()];
            for (int s = 0; s < spawnPointsArr.size(); s++) {
              JSONObject so = spawnPointsArr.getJSONObject(s);
              SpawnPointDef sp = new SpawnPointDef();
              sp.mode = so.getString("mode", "localTile");
              sp.x = so.getFloat("x", 0);
              sp.y = so.getFloat("y", 0);
              def.spawnPoints[s] = sp;
            }
          } else {
            def.spawnPoints = new SpawnPointDef[0];
          }
          buildingDefs.add(def);
          buildingDefsById.put(def.id, def);
        }
      }
    }
  }

  void loadMapResources() {
    goldMines.clear();
    JSONObject mapRoot = loadJSONObject("map_test.json");
    if (mapRoot == null) {
      return;
    }
    JSONArray arr = mapRoot.getJSONArray("goldMines");
    if (arr == null) {
      return;
    }
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      int tx = o.getInt("x", -1);
      int ty = o.getInt("y", -1);
      int amount = o.getInt("amount", 3000);
      if (tx < 0 || ty < 0 || tx >= map.widthTiles || ty >= map.heightTiles) {
        continue;
      }
      goldMines.add(new GoldMine(tx, ty, amount));
    }
  }

  BuildingDef getBuildingDef(String id) {
    if (buildingDefsById.containsKey(id)) {
      return buildingDefsById.get(id);
    }
    for (BuildingDef def : buildingDefs) {
      if (def.id.equals(id)) {
        return def;
      }
    }
    return null;
  }

  UnitDef getUnitDef(String id) {
    if (unitDefsById.containsKey(id)) {
      return unitDefsById.get(id);
    }
    return scoutDef;
  }

  void update(float dt) {
    if (map == null) {
      return;
    }
    if (gameEnded) {
      input.update(dt);
      return;
    }
    input.update(dt);
    buildSystem.update(dt, buildings);
    for (int i = orderMarkers.size() - 1; i >= 0; i--) {
      OrderMarker m = orderMarkers.get(i);
      m.ttl -= dt;
      if (m.ttl <= 0) {
        orderMarkers.remove(i);
      }
    }
    for (int i = units.size() - 1; i >= 0; i--) {
      Unit u = units.get(i);
      u.update(dt, this);
      resolveUnitAgainstSolids(u);
      if (u.hp <= 0) {
        selectedUnits.remove(u);
        units.remove(i);
      }
    }
    for (int i = buildings.size() - 1; i >= 0; i--) {
      Building b = buildings.get(i);
      if (b.hp <= 0) {
        if (selectedBuilding == b) {
          selectedBuilding = null;
        }
        removeTrainingJobsForTrainer(b);
        buildings.remove(i);
      }
    }
    applyUnitSeparation();
    for (int i = 0; i < units.size(); i++) {
      resolveUnitAgainstSolids(units.get(i));
    }
    if (fog != null) {
      fog.update(dt, this);
    }
    updateRockets(dt);
    updateMuzzleFx(dt);
    updateDeliveryFx(dt);
    updateTrainQueue(dt);
    updateTowerDefense(dt);
    if (enemyAi != null) {
      enemyAi.update(dt, this);
    }
    if (buildSystem.active && !selectedStructureOffersBuildMenu()) {
      buildSystem.active = false;
      buildSystem.lastFailReason = "";
      ui.clearBuildButtonState();
    }
    refreshFactionCaps();
    checkWinCondition();
  }

  void render() {
    background(0);
    if (map == null || camera == null) {
      return;
    }
    pushMatrix();
    clip(0, 0, worldViewW, screenH);
    map.render(camera, worldViewW, screenH);
    renderGoldMines();

    for (Building b : buildings) {
      if (isBuildingVisibleToPlayer(b)) {
        b.render(camera, map.tileSize);
      }
    }

    renderRallyPoints();

    for (Unit u : units) {
      if (isUnitVisibleToPlayer(u)) {
        u.render(camera);
      }
    }
    renderRockets();
    renderMuzzleFx();
    renderDeliveryFx();

    if (fog != null) {
      fog.renderOverlay(this);
    }

    renderWorldHudResources();

    if (debugShowPaths) {
      renderDebugPaths();
    }

    buildSystem.renderPreview(camera, map, buildings, canPlaceSelectedBuildInExploredArea());
    input.renderSelectionBox();
    noClip();
    popMatrix();

    // Render order markers on top of fog/UI-world boundary so they are always visible.
    pushStyle();
    for (OrderMarker m : orderMarkers) {
      m.render(camera);
    }
    popStyle();

    ui.render(this);
    if (gameEnded) {
      renderGameEndOverlay();
    }
  }

  void clearSelection() {
    for (Unit u : units) {
      u.selected = false;
    }
    for (Building b : buildings) {
      b.selected = false;
    }
    selectedBuilding = null;
    selectedUnits.clear();
  }

  void resetControlGroups() {
    controlGroups.clear();
    for (int i = 0; i <= 9; i++) {
      controlGroups.put(i, new ArrayList<Unit>());
    }
    editingControlGroup = -1;
  }

  ArrayList<Unit> controlGroupFor(int idx) {
    idx = constrain(idx, 0, 9);
    ArrayList<Unit> g = controlGroups.get(idx);
    if (g == null) {
      g = new ArrayList<Unit>();
      controlGroups.put(idx, g);
    }
    return g;
  }

  void pruneControlGroups() {
    for (int idx = 0; idx <= 9; idx++) {
      ArrayList<Unit> g = controlGroupFor(idx);
      for (int i = g.size() - 1; i >= 0; i--) {
        Unit u = g.get(i);
        if (u == null || u.hp <= 0 || u.faction != activeFaction || !units.contains(u)) {
          g.remove(i);
        }
      }
    }
    if (editingControlGroup < 0 || editingControlGroup > 9) {
      editingControlGroup = -1;
    }
  }

  int assignSelectionToControlGroup(int idx) {
    idx = constrain(idx, 0, 9);
    pruneControlGroups();
    ArrayList<Unit> g = controlGroupFor(idx);
    g.clear();
    for (Unit u : selectedUnits) {
      if (u != null && u.hp > 0 && u.faction == activeFaction && !g.contains(u)) {
        g.add(u);
      }
    }
    editingControlGroup = idx;
    return g.size();
  }

  int recallControlGroup(int idx) {
    idx = constrain(idx, 0, 9);
    pruneControlGroups();
    ArrayList<Unit> g = controlGroupFor(idx);
    clearSelection();
    for (Unit u : g) {
      if (u == null || u.hp <= 0 || u.faction != activeFaction) {
        continue;
      }
      u.selected = true;
      selectedUnits.add(u);
    }
    editingControlGroup = idx;
    return selectedUnits.size();
  }

  int toggleUnitInEditingControlGroup(Unit u) {
    if (u == null || u.hp <= 0 || u.faction != activeFaction || editingControlGroup < 0 || editingControlGroup > 9) {
      return 0;
    }
    pruneControlGroups();
    ArrayList<Unit> g = controlGroupFor(editingControlGroup);
    if (g.contains(u)) {
      g.remove(u);
      return -1;
    }
    g.add(u);
    return 1;
  }

  void renderWorldHudResources() {
    ResourcePool pool = activeFaction == Faction.ENEMY ? enemyResources : resources;
    int usedSupply = usedSupplyForFaction(activeFaction);
    int capSupply = supplyCapForFaction(activeFaction);
    int hudPadX = 14;
    int hudY = 14;
    int textX = worldViewW - hudPadX;
    String line = "$ " + pool.credits + "/" + pool.creditCap + "    SUP " + usedSupply + "/" + capSupply;
    pushStyle();
    textAlign(RIGHT, TOP);
    textSize(18);
    fill(0, 0, 0, 170);
    text(line, textX + 2, hudY + 2);
    fill(255, 228, 140);
    text(line, textX, hudY);
    textAlign(LEFT, TOP);
    popStyle();
  }

  boolean canSellSelectedBuilding() {
    if (gameEnded || buildSystem == null || selectedBuilding == null || selectedBuilding.faction != activeFaction) {
      return false;
    }
    if (!selectedBuilding.completed || selectedBuilding.hp <= 0) {
      return false;
    }
    BuildingDef d = getBuildingDef(selectedBuilding.buildingType);
    if (d == null || d.isMainBase) {
      return false;
    }
    if (buildSystem.currentJob != null && buildSystem.currentJob.target == selectedBuilding) {
      return false;
    }
    return true;
  }

  boolean trySellSelectedBuilding() {
    if (!canSellSelectedBuilding()) {
      return false;
    }
    Building b = selectedBuilding;
    BuildingDef d = getBuildingDef(b.buildingType);
    int refund = max(0, int(d.cost * d.sellRefundRatio));
    ResourcePool pool = resourcePoolForFaction(activeFaction);
    if (pool != null) {
      pool.addCredits(refund);
    }
    b.selected = false;
    removeTrainingJobsForTrainer(b);
    buildings.remove(b);
    selectedBuilding = null;
    orderLabel = tr("order.sold") + " +" + refund;
    return true;
  }

  /** Command Post / main base: sidebar shows structure build palette (StarCraft / Generals style). */
  boolean selectedStructureOffersBuildMenu() {
    if (selectedBuilding == null || selectedBuilding.faction != activeFaction || !selectedBuilding.completed) {
      return false;
    }
    BuildingDef d = getBuildingDef(selectedBuilding.buildingType);
    return d != null && d.isMainBase;
  }

  /** Barracks-style producer: sidebar shows only this building's trainable units. */
  boolean selectedStructureOffersTrainMenu() {
    if (selectedBuilding == null || selectedBuilding.faction != activeFaction || !selectedBuilding.completed) {
      return false;
    }
    BuildingDef d = getBuildingDef(selectedBuilding.buildingType);
    return d != null && d.canTrainUnits && d.trainableUnits != null && d.trainableUnits.length > 0;
  }

  void tryTrainHotkey(int slot) {
    if (!selectedStructureOffersTrainMenu()) {
      return;
    }
    BuildingDef bd = getBuildingDef(selectedBuilding.buildingType);
    if (bd == null || slot < 0 || slot >= bd.trainableUnits.length) {
      return;
    }
    trainUnitAtSelectedBuilding(bd.trainableUnits[slot]);
  }

  void onMousePressed(int mx, int my, int button) {
    input.onMousePressed(mx, my, button);
  }

  void onMouseDragged(int mx, int my, int button) {
    input.onMouseDragged(mx, my, button);
  }

  void onMouseReleased(int mx, int my, int button) {
    input.onMouseReleased(mx, my, button);
  }

  void onKeyPressed(char key, int keyCode) {
    input.onKeyPressed(key, keyCode);
  }

  void onMouseWheel(float amount, int mx, int my) {
    input.onMouseWheel(amount, mx, my);
  }

  void pathfinderRepath(Unit u, PVector worldTarget, boolean append) {
    ArrayList<PVector> path = pathfinder.findPath(u.pos.copy(), worldTarget, buildings);
    if (!append) {
      u.pathQueue.clear();
    }
    if (path.size() > 0) {
      if (path.size() > 1) {
        for (int i = 1; i < path.size(); i++) {
          u.pathQueue.add(path.get(i));
        }
      } else {
        u.pathQueue.add(path.get(0));
      }
    }
  }

  Unit findNearestUnitAt(PVector worldPos, float radiusPx) {
    Unit best = null;
    float bestD = 1e9;
    for (Unit u : units) {
      if (!isUnitVisibleToPlayer(u)) {
        continue;
      }
      float d = PVector.dist(u.pos, worldPos);
      if (d <= radiusPx && d < bestD) {
        bestD = d;
        best = u;
      }
    }
    return best;
  }

  Building findNearestBuildingAt(PVector worldPos, float radiusPx, boolean onlyVisible) {
    Building best = null;
    float bestD = 1e9;
    for (Building b : buildings) {
      if (b.hp <= 0) {
        continue;
      }
      if (onlyVisible && !isBuildingVisibleToPlayer(b)) {
        continue;
      }
      float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
      float d = dist(worldPos.x, worldPos.y, cx, cy);
      float catchRange = radiusPx + max(b.tileW, b.tileH) * map.tileSize * 0.5;
      if (d <= catchRange && d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  void applyUnitSeparation() {
    float padding = 4;
    for (int i = 0; i < units.size(); i++) {
      Unit a = units.get(i);
      for (int j = i + 1; j < units.size(); j++) {
        Unit b = units.get(j);
        PVector delta = PVector.sub(b.pos, a.pos);
        float d = max(0.0001, delta.mag());
        float minD = a.radius + b.radius + padding;
        if (d >= minD) {
          continue;
        }
        boolean sameTeam = a.faction == b.faction;
        float baseIntensity = sameTeam ? 0.5 : 0.14;
        if (a.state == UnitState.ATTACKING || b.state == UnitState.ATTACKING) {
          baseIntensity *= sameTeam ? 0.5 : 0.45;
        }
        float push = (minD - d) * baseIntensity;
        delta.normalize();
        PVector pushVec = PVector.mult(delta, push);
        a.pos.sub(pushVec);
        b.pos.add(pushVec);
        clampUnitToWorld(a);
        clampUnitToWorld(b);
      }
    }
  }

  void renderDebugPaths() {
    pushStyle();
    strokeWeight(1);
    for (Unit u : units) {
      if (u.pathQueue.size() == 0) {
        continue;
      }
      boolean sel = u.selected;
      stroke(sel ? color(255, 230, 80, 220) : color(120, 200, 255, 140));
      PVector prev = camera.worldToScreen(u.pos.x, u.pos.y);
      for (int k = 0; k < u.pathQueue.size(); k++) {
        PVector wp = u.pathQueue.get(k);
        PVector next = camera.worldToScreen(wp.x, wp.y);
        line(prev.x, prev.y, next.x, next.y);
        noFill();
        ellipse(next.x, next.y, 4 * camera.zoom, 4 * camera.zoom);
        prev = next;
      }
    }
    noStroke();
    popStyle();
  }

  void clampUnitToWorld(Unit u) {
    u.pos.x = constrain(u.pos.x, u.radius, map.worldWidthPx() - u.radius);
    u.pos.y = constrain(u.pos.y, u.radius, map.worldHeightPx() - u.radius);
  }

  float movementSpeedFactorAt(PVector worldPos) {
    int tx = map.toTileX(worldPos.x);
    int ty = map.toTileY(worldPos.y);
    int t = map.terrainAt(tx, ty);
    if (t == 1) {
      return 0.72;
    }
    return 1.0;
  }

  void resolveUnitAgainstSolids(Unit u) {
    clampUnitToWorld(u);

    int minTx = map.toTileX(u.pos.x - u.radius) - 1;
    int maxTx = map.toTileX(u.pos.x + u.radius) + 1;
    int minTy = map.toTileY(u.pos.y - u.radius) - 1;
    int maxTy = map.toTileY(u.pos.y + u.radius) + 1;

    for (int ty = minTy; ty <= maxTy; ty++) {
      for (int tx = minTx; tx <= maxTx; tx++) {
        if (!map.isBlockedTile(tx, ty)) {
          continue;
        }
        float rx = tx * map.tileSize;
        float ry = ty * map.tileSize;
        resolveCircleVsRect(u, rx, ry, map.tileSize, map.tileSize);
      }
    }

    for (Building b : buildings) {
      float rx = b.pos.x;
      float ry = b.pos.y;
      float rw = b.tileW * map.tileSize;
      float rh = b.tileH * map.tileSize;
      resolveCircleVsRect(u, rx, ry, rw, rh);
    }
    clampUnitToWorld(u);
  }

  void resolveCircleVsRect(Unit u, float rx, float ry, float rw, float rh) {
    float cx = constrain(u.pos.x, rx, rx + rw);
    float cy = constrain(u.pos.y, ry, ry + rh);
    float dx = u.pos.x - cx;
    float dy = u.pos.y - cy;
    float d2 = dx * dx + dy * dy;
    float r = u.radius + 0.6;
    if (d2 >= r * r) {
      return;
    }

    if (d2 > 1e-6) {
      float d = sqrt(d2);
      float push = r - d;
      u.pos.x += (dx / d) * push;
      u.pos.y += (dy / d) * push;
      return;
    }

    float left = abs(u.pos.x - rx);
    float right = abs(rx + rw - u.pos.x);
    float top = abs(u.pos.y - ry);
    float bottom = abs(ry + rh - u.pos.y);
    float m = min(min(left, right), min(top, bottom));
    if (m == left) {
      u.pos.x = rx - r;
    } else if (m == right) {
      u.pos.x = rx + rw + r;
    } else if (m == top) {
      u.pos.y = ry - r;
    } else {
      u.pos.y = ry + rh + r;
    }
  }

  Unit findPriorityEnemy(Unit self, float radiusPx) {
    Unit best = null;
    float bestScore = 1e9;
    for (Unit u : units) {
      if (u == self || u.faction == self.faction || u.hp <= 0) {
        continue;
      }
      if (self.faction == Faction.PLAYER && !isUnitVisibleToPlayer(u)) {
        continue;
      }
      float d = PVector.dist(self.pos, u.pos);
      if (d > radiusPx) {
        continue;
      }
      float score = d + u.hp * 0.35;
      if (score < bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  Unit findHostileInRange(Unit self, float radiusPx, GameState gs) {
    Unit best = null;
    float bestScore = 1e9;
    for (Unit u : units) {
      if (u == self || u.hp <= 0 || !isHostile(self.faction, u.faction)) {
        continue;
      }
      if (gs != null && self.faction == Faction.PLAYER && !isUnitVisibleToPlayer(u)) {
        continue;
      }
      float d = PVector.dist(self.pos, u.pos);
      if (d > radiusPx) {
        continue;
      }
      if (!pathfinder.hasLineOfSight(self.pos, u.pos, buildings)) {
        continue;
      }
      float score = d + u.hp * 0.25;
      if (score < bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  Building findNearestHostileBuilding(Unit self, float rangePx) {
    if (self == null || rangePx <= 0) {
      return null;
    }
    Building best = null;
    float bestD = 1e9;
    for (Building b : buildings) {
      if (b.hp <= 0 || !b.completed || !isHostile(self.faction, b.faction)) {
        continue;
      }
      float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
      float d = PVector.dist(self.pos, new PVector(cx, cy));
      if (d > rangePx) {
        continue;
      }
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  boolean isHostile(Faction a, Faction b) {
    if (a == b) {
      return false;
    }
    if (a == Faction.NEUTRAL || b == Faction.NEUTRAL) {
      return a != b;
    }
    return true;
  }

  String tileKeyForWorld(PVector worldPos) {
    int tx = map.toTileX(worldPos.x);
    int ty = map.toTileY(worldPos.y);
    return tx + ":" + ty;
  }

  PVector findNearestOpenSlot(PVector desiredWorld, ArrayList<String> usedTileKeys) {
    int tx = map.toTileX(desiredWorld.x);
    int ty = map.toTileY(desiredWorld.y);
    PVector walkable = pathfinder.findClosestWalkable(tx, ty, buildings);
    int wx = int(walkable.x);
    int wy = int(walkable.y);
    String key = wx + ":" + wy;
    if (!usedTileKeys.contains(key)) {
      return new PVector((wx + 0.5) * map.tileSize, (wy + 0.5) * map.tileSize);
    }
    for (int r = 1; r < 6; r++) {
      for (int y = -r; y <= r; y++) {
        for (int x = -r; x <= r; x++) {
          int nx = wx + x;
          int ny = wy + y;
          String k = nx + ":" + ny;
          if (usedTileKeys.contains(k)) {
            continue;
          }
          if (pathfinder.isWalkable(nx, ny, buildings)) {
            return new PVector((nx + 0.5) * map.tileSize, (ny + 0.5) * map.tileSize);
          }
        }
      }
    }
    return new PVector((wx + 0.5) * map.tileSize, (wy + 0.5) * map.tileSize);
  }

  boolean isWorldSpawnFreeOfUnits(float wx, float wy, float unitRadius, float pad) {
    for (Unit u : units) {
      if (u.hp <= 0) {
        continue;
      }
      if (dist(wx, wy, u.pos.x, u.pos.y) < unitRadius + u.radius + pad) {
        return false;
      }
    }
    return true;
  }

  PVector findSpawnNearBuildingAvoidingUnits(Building b, float unitRadius, ArrayList<String> usedTileKeys) {
    if (usedTileKeys == null) {
      usedTileKeys = new ArrayList<String>();
    }
    float ts = map.tileSize;
    float cx = b.pos.x + b.tileW * ts * 0.5;
    float cy = b.pos.y + b.tileH * ts * 0.5;
    float pad = 3;
    PVector[] seeds = {
      new PVector(cx + ts * 2.2, cy + ts * 0.6),
      new PVector(cx - ts * 1.2, cy + ts * 2.0),
      new PVector(cx + ts * 0.5, cy - ts * 2.0),
      new PVector(cx - ts * 2.5, cy - ts * 0.4)
    };
    for (int s = 0; s < seeds.length; s++) {
      int tx = map.toTileX(seeds[s].x);
      int ty = map.toTileY(seeds[s].y);
      PVector walkable = pathfinder.findClosestWalkable(tx, ty, buildings);
      int wx = int(walkable.x);
      int wy = int(walkable.y);
      for (int ring = 0; ring < 22; ring++) {
        for (int dy = -ring; dy <= ring; dy++) {
          for (int dx = -ring; dx <= ring; dx++) {
            if (ring > 0 && abs(dx) != ring && abs(dy) != ring) {
              continue;
            }
            int nx = wx + dx;
            int ny = wy + dy;
            String k = nx + ":" + ny;
            if (usedTileKeys.contains(k)) {
              continue;
            }
            if (!pathfinder.isWalkable(nx, ny, buildings)) {
              continue;
            }
            float px = (nx + 0.5) * ts;
            float py = (ny + 0.5) * ts;
            if (!isWorldSpawnFreeOfUnits(px, py, unitRadius, pad)) {
              continue;
            }
            usedTileKeys.add(k);
            return new PVector(px, py);
          }
        }
      }
    }
    return findNearestOpenSlot(new PVector(cx + ts * 1.2, cy + ts * 0.6), usedTileKeys);
  }

  void addOrderMarker(PVector pos, boolean attackStyle) {
    orderMarkers.add(new OrderMarker(pos.copy(), attackStyle));
  }

  GoldMine findNearestAvailableMine(PVector from, Faction faction) {
    GoldMine best = null;
    float bestD = 1e9;
    for (GoldMine g : goldMines) {
      if (g.amount <= 0) {
        continue;
      }
      float d = PVector.dist(from, g.worldCenter(map));
      if (d < bestD) {
        bestD = d;
        best = g;
      }
    }
    return best;
  }

  GoldMine findNearestMineAt(PVector worldPos, float radiusPx) {
    GoldMine best = null;
    float bestD = 1e9;
    for (GoldMine g : goldMines) {
      if (g.amount <= 0) {
        continue;
      }
      PVector c = g.worldCenter(map);
      float d = dist(worldPos.x, worldPos.y, c.x, c.y);
      if (d <= radiusPx && d < bestD) {
        bestD = d;
        best = g;
      }
    }
    return best;
  }

  void clearSelectedHarvestOrders() {
    for (Unit u : selectedUnits) {
      if (!u.canHarvest) {
        continue;
      }
      u.manualHarvestOrder = false;
      u.assignedMine = null;
      u.assignedDropoff = null;
      u.harvestMode = 0;
      u.harvestTimer = 0;
    }
  }

  boolean issueHarvestOrderToSelectedMiners(PVector worldPos) {
    GoldMine targetMine = findNearestMineAt(worldPos, max(18, map.tileSize * 0.75));
    if (targetMine == null) {
      return false;
    }
    int issued = 0;
    for (Unit u : selectedUnits) {
      if (u.faction != activeFaction || !u.canHarvest) {
        continue;
      }
      u.issueHarvest(targetMine, this);
      issued++;
    }
    if (issued > 0) {
      orderLabel = tr("order.harvest");
      addOrderMarker(targetMine.worldCenter(map), false);
      return true;
    }
    return false;
  }

  ResourcePool resourcePoolForFaction(Faction faction) {
    if (faction == Faction.ENEMY) {
      return enemyResources;
    }
    return resources;
  }

  int baseSupplyCapForFaction(Faction faction) {
    return faction == Faction.ENEMY ? enemyBaseSupplyCap : playerBaseSupplyCap;
  }

  int supplyCapForFaction(Faction faction) {
    int cap = baseSupplyCapForFaction(faction);
    for (Building b : buildings) {
      if (b.faction != faction || b.hp <= 0 || !b.completed) {
        continue;
      }
      BuildingDef def = getBuildingDef(b.buildingType);
      if (def == null) {
        continue;
      }
      cap += max(0, def.supplyCapBonus);
    }
    return max(1, cap);
  }

  int usedSupplyForFaction(Faction faction) {
    int used = 0;
    for (Unit u : units) {
      if (u.faction != faction || u.hp <= 0) {
        continue;
      }
      UnitDef def = getUnitDef(u.unitType);
      used += max(0, def == null ? 1 : def.supplyCost);
    }
    return used;
  }

  int creditCapForFaction(Faction faction) {
    int cap = defaultCreditCap;
    for (Building b : buildings) {
      if (b.faction != faction || b.hp <= 0 || !b.completed) {
        continue;
      }
      BuildingDef def = getBuildingDef(b.buildingType);
      if (def == null) {
        continue;
      }
      cap += max(0, def.creditCapBonus);
    }
    return max(100, cap);
  }

  void refreshFactionCaps() {
    if (resources != null) {
      resources.setCreditCap(creditCapForFaction(Faction.PLAYER));
    }
    if (enemyResources != null) {
      enemyResources.setCreditCap(creditCapForFaction(Faction.ENEMY));
    }
  }

  int countFactionUnitsByType(Faction faction, String unitId) {
    int c = 0;
    for (Unit u : units) {
      if (u.faction == faction && u.hp > 0 && u.unitType.equals(unitId)) {
        c++;
      }
    }
    return c;
  }

  int countFactionCombatUnits(Faction faction) {
    int c = 0;
    for (Unit u : units) {
      if (u.faction != faction || u.hp <= 0) {
        continue;
      }
      if (!u.canHarvest) {
        c++;
      }
    }
    return c;
  }

  int countFactionBuildingsByType(Faction faction, String buildingType, boolean completedOnly) {
    int c = 0;
    for (Building b : buildings) {
      if (b.faction != faction) {
        continue;
      }
      if (completedOnly && !b.completed) {
        continue;
      }
      if (b.buildingType.equals(buildingType)) {
        c++;
      }
    }
    return c;
  }

  Building findMainBaseForFaction(Faction faction) {
    Building first = null;
    for (Building b : buildings) {
      if (b.faction != faction || !b.completed) {
        continue;
      }
      BuildingDef def = getBuildingDef(b.buildingType);
      if (def == null) {
        continue;
      }
      if (first == null) {
        first = b;
      }
      if (def.isMainBase) {
        return b;
      }
    }
    return first;
  }

  boolean tryQueueBuildingForFaction(Faction faction, String buildingId, PVector anchorWorld) {
    BuildingDef def = getBuildingDef(buildingId);
    if (def == null) {
      return false;
    }
    ResourcePool pool = resourcePoolForFaction(faction);
    if (pool == null || !pool.canAfford(def.cost)) {
      return false;
    }
    if (!buildSystem.hasRequiredBuildings(def, buildings, faction)) {
      return false;
    }
    PVector anchor = anchorWorld == null ? new PVector(map.worldWidthPx() * 0.5, map.worldHeightPx() * 0.5) : anchorWorld;
    int desiredTx = map.toTileX(anchor.x);
    int desiredTy = map.toTileY(anchor.y);
    for (int r = 0; r <= 20; r++) {
      for (int oy = -r; oy <= r; oy++) {
        for (int ox = -r; ox <= r; ox++) {
          int tx = desiredTx + ox;
          int ty = desiredTy + oy;
          if (!canPlaceBuildingFootprint(def, tx, ty, 1)) {
            continue;
          }
          if (!pool.spend(def.cost)) {
            return false;
          }
          BuildJob job = new BuildJob(tx * map.tileSize, ty * map.tileSize, faction, def);
          buildSystem.queue.add(job);
          return true;
        }
      }
    }
    return false;
  }

  Building pickTrainerForUnit(Faction faction, String unitId) {
    Building best = null;
    int bestDepth = 999999;
    for (Building b : buildings) {
      if (b.faction != faction || !b.completed || b.hp <= 0) {
        continue;
      }
      BuildingDef bdef = getBuildingDef(b.buildingType);
      if (bdef == null || !bdef.canTrainUnits || bdef.trainableUnits == null) {
        continue;
      }
      boolean allowed = false;
      for (int i = 0; i < bdef.trainableUnits.length; i++) {
        if (bdef.trainableUnits[i].equals(unitId)) {
          allowed = true;
          break;
        }
      }
      if (!allowed) {
        continue;
      }
      int d = pendingTrainCountFor(b);
      if (d < bestDepth) {
        bestDepth = d;
        best = b;
      }
    }
    return best;
  }

  int pendingTrainCountFor(Building trainer) {
    int c = 0;
    for (TrainJob j : trainQueue) {
      if (j.trainer == trainer) {
        c++;
      }
    }
    return c;
  }

  TrainJob activeTrainJobFor(Building trainer) {
    for (TrainJob j : trainQueue) {
      if (j.trainer == trainer) {
        return j;
      }
    }
    return null;
  }

  void removeTrainingJobsForTrainer(Building trainer) {
    for (int i = trainQueue.size() - 1; i >= 0; i--) {
      if (trainQueue.get(i).trainer == trainer) {
        trainQueue.remove(i);
      }
    }
  }

  boolean isFirstTrainJobForTrainer(Building trainer, int queueIndex) {
    for (int k = 0; k < queueIndex; k++) {
      if (trainQueue.get(k).trainer == trainer) {
        return false;
      }
    }
    return true;
  }

  boolean buildingHostsTrainQueue(Building b) {
    if (b == null) {
      return false;
    }
    for (int i = 0; i < buildings.size(); i++) {
      if (buildings.get(i) == b) {
        return true;
      }
    }
    return false;
  }

  void updateTrainQueue(float dt) {
    if (gameEnded) {
      return;
    }
    for (int i = trainQueue.size() - 1; i >= 0; i--) {
      TrainJob j = trainQueue.get(i);
      if (j.trainer == null || j.trainer.hp <= 0 || !j.trainer.completed || !buildingHostsTrainQueue(j.trainer)) {
        trainQueue.remove(i);
      }
    }
    for (int i = 0; i < trainQueue.size(); i++) {
      TrainJob j = trainQueue.get(i);
      if (!isFirstTrainJobForTrainer(j.trainer, i)) {
        continue;
      }
      j.timeRemaining -= dt;
      if (j.timeRemaining <= 0) {
        UnitDef def = getUnitDef(j.unitId);
        if (def != null && j.trainer != null && buildingHostsTrainQueue(j.trainer)) {
          PVector spawn = findSpawnForTrainer(j.trainer, def.radius);
          Unit nu = new Unit(spawn.x, spawn.y, j.faction, def);
          units.add(nu);
          if (j.trainer.rallyPoint != null && j.trainer.completed) {
            nu.issueMove(j.trainer.rallyPoint.copy(), this, false);
          }
        }
        trainQueue.remove(i);
        i--;
      }
    }
  }

  void updateTowerDefense(float dt) {
    if (gameEnded) {
      return;
    }
    for (Building b : buildings) {
      if (!b.completed || b.hp <= 0) {
        continue;
      }
      BuildingDef ddef = getBuildingDef(b.buildingType);
      if (ddef == null || !ddef.isTower) {
        continue;
      }
      b.towerCooldown = max(0, b.towerCooldown - dt);
      if (b.towerCooldown > 0) {
        continue;
      }
      float range = ddef.towerAttackRange;
      Unit tgt = findTowerHostileUnitInRange(b, range);
      Building bt = null;
      if (tgt == null) {
        bt = findTowerHostileBuildingInRange(b, range);
        if (bt == null) {
          continue;
        }
      }
      PVector muzzle = towerMuzzleWorld(b);
      float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
      if (tgt != null) {
        b.turretAimAngle = atan2(tgt.pos.y - cy, tgt.pos.x - cx);
        spawnRocketProjectileFromWorld(muzzle, tgt, ddef.towerDamage, ddef.towerProjectileSpeed);
      } else {
        PVector bc = new PVector(bt.pos.x + bt.tileW * map.tileSize * 0.5, bt.pos.y + bt.tileH * map.tileSize * 0.5);
        b.turretAimAngle = atan2(bc.y - cy, bc.x - cx);
        spawnRocketProjectileFromWorld(muzzle, bt, ddef.towerDamage, ddef.towerProjectileSpeed);
      }
      b.towerCooldown = ddef.towerCooldown;
    }
  }

  PVector towerMuzzleWorld(Building b) {
    float ts = map.tileSize;
    float cx = b.pos.x + b.tileW * ts * 0.5;
    float cy = b.pos.y + b.tileH * ts * 0.5;
    return new PVector(cx, cy - ts * 0.20);
  }

  Unit findTowerHostileUnitInRange(Building tower, float rangePx) {
    float cx = tower.pos.x + tower.tileW * map.tileSize * 0.5;
    float cy = tower.pos.y + tower.tileH * map.tileSize * 0.5;
    Unit best = null;
    float bestScore = 1e9;
    for (Unit u : units) {
      if (u.hp <= 0 || !isHostile(tower.faction, u.faction)) {
        continue;
      }
      float d = dist(cx, cy, u.pos.x, u.pos.y);
      if (d > rangePx) {
        continue;
      }
      if (tower.faction == Faction.PLAYER && !isUnitVisibleToPlayer(u)) {
        continue;
      }
      float score = d + u.hp * 0.2;
      if (score < bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  Building findTowerHostileBuildingInRange(Building tower, float rangePx) {
    float cx = tower.pos.x + tower.tileW * map.tileSize * 0.5;
    float cy = tower.pos.y + tower.tileH * map.tileSize * 0.5;
    Building best = null;
    float bestScore = 1e9;
    for (Building b : buildings) {
      if (b == null || b.hp <= 0 || !isHostile(tower.faction, b.faction)) {
        continue;
      }
      float bx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float by = b.pos.y + b.tileH * map.tileSize * 0.5;
      float d = dist(cx, cy, bx, by);
      if (d > rangePx) {
        continue;
      }
      if (tower.faction == Faction.PLAYER && !isBuildingVisibleToPlayer(b)) {
        continue;
      }
      float score = d + b.hp * 0.1;
      if (score < bestScore) {
        bestScore = score;
        best = b;
      }
    }
    return best;
  }

  boolean tryTrainUnitForFaction(Faction faction, String unitId) {
    UnitDef def = getUnitDef(unitId);
    if (def == null) {
      return false;
    }
    ResourcePool pool = resourcePoolForFaction(faction);
    if (pool == null || !pool.canAfford(def.cost)) {
      return false;
    }
    int needSupply = max(0, def.supplyCost);
    if (usedSupplyForFaction(faction) + needSupply > supplyCapForFaction(faction)) {
      return false;
    }
    Building trainer = pickTrainerForUnit(faction, unitId);
    if (trainer == null) {
      return false;
    }
    if (!pool.spend(def.cost)) {
      return false;
    }
    trainQueue.add(new TrainJob(trainer, unitId, def.trainTime, faction));
    return true;
  }

  PVector enemyRallyPoint() {
    Building base = findMainBaseForFaction(Faction.ENEMY);
    if (base == null) {
      return new PVector(map.worldWidthPx() * 0.7, map.worldHeightPx() * 0.7);
    }
    float cx = base.pos.x + base.tileW * map.tileSize * 0.5;
    float cy = base.pos.y + base.tileH * map.tileSize * 0.5;
    return findNearestOpenSlot(new PVector(cx - map.tileSize * 5.0, cy - map.tileSize * 3.0), new ArrayList<String>());
  }

  PVector playerAttackTarget() {
    Building playerBase = findMainBaseForFaction(Faction.PLAYER);
    if (playerBase != null) {
      return new PVector(playerBase.pos.x + playerBase.tileW * map.tileSize * 0.5, playerBase.pos.y + playerBase.tileH * map.tileSize * 0.5);
    }
    if (units.size() > 0) {
      for (Unit u : units) {
        if (u.faction == Faction.PLAYER && u.hp > 0) {
          return u.pos.copy();
        }
      }
    }
    return new PVector(map.worldWidthPx() * 0.25, map.worldHeightPx() * 0.25);
  }

  float armyValueForFaction(Faction faction) {
    float v = 0;
    for (Unit u : units) {
      if (u.faction != faction || u.hp <= 0 || u.canHarvest) {
        continue;
      }
      UnitDef def = getUnitDef(u.unitType);
      if (def != null) {
        v += max(20, def.cost);
      } else {
        v += 60;
      }
    }
    return v;
  }

  Building findNearestDropoffBuilding(PVector from, Faction faction) {
    Building best = null;
    float bestD = 1e9;
    for (Building b : buildings) {
      if (b.faction != faction || !b.completed) {
        continue;
      }
      BuildingDef def = getBuildingDef(b.buildingType);
      if (def == null || !def.isDropoff) {
        continue;
      }
      float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
      float d = dist(from.x, from.y, cx, cy);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best;
  }

  void renderGoldMines() {
    for (GoldMine g : goldMines) {
      g.render(camera, map);
    }
  }

  void renderRallyPoints() {
    for (Building b : buildings) {
      if (b == null || b.rallyPoint == null || b.hp <= 0 || !b.completed) {
        continue;
      }
      BuildingDef bd = getBuildingDef(b.buildingType);
      if (bd == null || !bd.canTrainUnits) {
        continue;
      }
      if (b.faction == Faction.PLAYER && !isBuildingVisibleToPlayer(b)) {
        continue;
      }
      PVector from = camera.worldToScreen(
        b.pos.x + b.tileW * map.tileSize * 0.5,
        b.pos.y + b.tileH * map.tileSize * 0.5
        );
      PVector rallyScreen = camera.worldToScreen(b.rallyPoint.x, b.rallyPoint.y);
      pushStyle();
      stroke(120, 220, 255, 170);
      strokeWeight(max(1, 1.2 * camera.zoom));
      line(from.x, from.y, rallyScreen.x, rallyScreen.y);
      noFill();
      stroke(120, 255, 180, 200);
      ellipse(rallyScreen.x, rallyScreen.y, 10 * camera.zoom, 10 * camera.zoom);
      popStyle();
    }
  }

  void spawnMuzzleFx(Unit shooter, PVector targetPos) {
    muzzleFx.add(new MuzzleFx(shooter.pos.copy(), targetPos));
  }

  void updateMuzzleFx(float dt) {
    for (int i = muzzleFx.size() - 1; i >= 0; i--) {
      MuzzleFx fx = muzzleFx.get(i);
      fx.ttl -= dt;
      if (fx.ttl <= 0) {
        muzzleFx.remove(i);
      }
    }
  }

  void renderMuzzleFx() {
    for (MuzzleFx fx : muzzleFx) {
      fx.render(camera);
    }
  }

  void spawnDeliveryFx(PVector worldPos, int amount) {
    if (amount <= 0) {
      return;
    }
    deliveries.add(new DeliveryFx(worldPos.copy(), amount));
  }

  void updateDeliveryFx(float dt) {
    for (int i = deliveries.size() - 1; i >= 0; i--) {
      DeliveryFx fx = deliveries.get(i);
      fx.ttl -= dt;
      if (fx.ttl <= 0) {
        deliveries.remove(i);
      }
    }
  }

  void renderDeliveryFx() {
    for (DeliveryFx fx : deliveries) {
      fx.render(camera);
    }
  }

  void spawnRocketProjectile(Unit from, Unit target, float dmg, float speed) {
    if (target == null || target.hp <= 0) {
      return;
    }
    rockets.add(new RocketProjectile(from.pos.copy(), target, dmg, speed));
  }

  void spawnRocketProjectile(Unit from, Building target, float dmg, float speed) {
    if (from == null || target == null || target.hp <= 0 || map == null) {
      return;
    }
    PVector center = new PVector(
      target.pos.x + target.tileW * map.tileSize * 0.5,
      target.pos.y + target.tileH * map.tileSize * 0.5
      );
    rockets.add(new RocketProjectile(from.pos.copy(), target, center, dmg, speed));
  }

  void spawnRocketProjectileFromWorld(PVector worldStart, Unit target, float dmg, float speed) {
    if (worldStart == null || target == null || target.hp <= 0) {
      return;
    }
    rockets.add(new RocketProjectile(worldStart.copy(), target, dmg, speed));
  }

  void spawnRocketProjectileFromWorld(PVector worldStart, Building target, float dmg, float speed) {
    if (worldStart == null || target == null || target.hp <= 0 || map == null) {
      return;
    }
    PVector center = new PVector(
      target.pos.x + target.tileW * map.tileSize * 0.5,
      target.pos.y + target.tileH * map.tileSize * 0.5
      );
    rockets.add(new RocketProjectile(worldStart.copy(), target, center, dmg, speed));
  }

  void updateRockets(float dt) {
    for (int i = rockets.size() - 1; i >= 0; i--) {
      RocketProjectile p = rockets.get(i);
      if (p.update(dt)) {
        rockets.remove(i);
      }
    }
  }

  void renderRockets() {
    for (RocketProjectile p : rockets) {
      p.render(camera);
    }
  }

  int countFactionUnits(Faction f) {
    int c = 0;
    for (Unit u : units) {
      if (u.faction == f && u.hp > 0) {
        c++;
      }
    }
    return c;
  }

  int countFactionBuildings(Faction f) {
    int c = 0;
    for (Building b : buildings) {
      if (b.faction == f && b.hp > 0) {
        c++;
      }
    }
    return c;
  }

  void checkWinCondition() {
    if (gameEnded || map == null) {
      return;
    }
    boolean playerAlive = countFactionUnits(Faction.PLAYER) + countFactionBuildings(Faction.PLAYER) > 0;
    boolean enemyAlive = countFactionUnits(Faction.ENEMY) + countFactionBuildings(Faction.ENEMY) > 0;
    if (!playerAlive || !enemyAlive) {
      gameEnded = true;
      if (!playerAlive && !enemyAlive) {
        gameResult = "DRAW";
      } else if (!playerAlive) {
        gameResult = "DEFEAT";
      } else {
        gameResult = "VICTORY";
      }
      orderLabel = tr("order.gameOver");
      buildSystem.active = false;
    }
  }

  void renderGameEndOverlay() {
    gameEndHitButtons.clear();
    fill(0, 0, 0, 140);
    rect(0, 0, worldViewW, screenH);

    float cx = worldViewW * 0.5;
    float boxW = min(440, worldViewW - 36);
    float boxH = 210;
    float bx = cx - boxW * 0.5;
    float by = screenH * 0.5 - boxH * 0.5;

    ui.uiWidgets.drawChamferFill(bx, by, boxW, boxH, 10, color(28, 30, 34));
    ui.uiWidgets.drawChamferStroke(bx, by, boxW, boxH, 10, color(130, 140, 155), 2);
    ui.uiWidgets.drawCornerRivets(bx, by, boxW, boxH, 10);

    fill(255);
    textAlign(CENTER, CENTER);
    textSize(26);
    String title = gameResult;
    if ("DEFEAT".equals(gameResult)) {
      title = tr("overlay.defeat");
    } else if ("VICTORY".equals(gameResult)) {
      title = tr("overlay.victory");
    } else if ("DRAW".equals(gameResult)) {
      title = tr("overlay.draw");
    }
    text(title, cx, by + 38);
    textSize(13);
    fill(200);
    text(tr("overlay.desc"), cx, by + 74);

    float btnW = 148;
    float btnH = 42;
    float gap = 16;
    float btnY = by + boxH - 58;
    UiHitButton replay = new UiHitButton();
    replay.x = cx - btnW - gap * 0.5;
    replay.y = btnY;
    replay.w = btnW;
    replay.h = btnH;
    replay.chamfer = 5;
    replay.label = tr("overlay.replay");
    replay.sublabel = tr("overlay.replay");
    replay.actionId = "end:replay";
    replay.style = 3;
    replay.enabled = true;
    replay.hovered = mouseX >= replay.x && mouseX <= replay.x + replay.w && mouseY >= replay.y && mouseY <= replay.y + replay.h;
    gameEndHitButtons.add(replay);
    ui.uiWidgets.drawHitButton(replay);

    UiHitButton menu = new UiHitButton();
    menu.x = gap * 0.5 + cx;
    menu.y = btnY;
    menu.w = btnW;
    menu.h = btnH;
    menu.chamfer = 5;
    menu.label = tr("overlay.menu");
    menu.sublabel = tr("overlay.menu");
    menu.actionId = "end:menu";
    menu.style = 3;
    menu.enabled = true;
    menu.hovered = mouseX >= menu.x && mouseX <= menu.x + menu.w && mouseY >= menu.y && mouseY <= menu.y + menu.h;
    gameEndHitButtons.add(menu);
    ui.uiWidgets.drawHitButton(menu);

    textAlign(LEFT, TOP);
  }

  void handleGameEndOverlayClick(int mx, int my, int button) {
    if (button != LEFT) {
      return;
    }
    for (int i = gameEndHitButtons.size() - 1; i >= 0; i--) {
      UiHitButton b = gameEndHitButtons.get(i);
      if (!b.enabled || !ui.uiWidgets.hitContains(b, mx, my)) {
        continue;
      }
      if ("end:replay".equals(b.actionId)) {
        startNewGame();
        return;
      }
      if ("end:menu".equals(b.actionId)) {
        pendingReturnToMenu = true;
        gameEnded = false;
        shutdownSessionForMenu();
        return;
      }
    }
  }

  void shutdownSessionForMenu() {
    map = null;
    camera = null;
    fog = null;
    pathfinder = null;
    enemyAi = null;
    trainQueue.clear();
    units.clear();
    buildings.clear();
    rockets.clear();
    muzzleFx.clear();
    deliveries.clear();
    orderMarkers.clear();
    goldMines.clear();
    selectedUnits.clear();
    selectedBuilding = null;
    resetControlGroups();
    buildSystem = new BuildSystem(new ArrayList<BuildingDef>());
    buildSystem.lastFailReason = "";
    gameResult = "";
    orderLabel = tr("order.none");
    ui.clearBuildButtonState();
  }

  boolean trainUnitAtSelectedBuilding(String unitId) {
    if (gameEnded) {
      return false;
    }
    if (selectedUnits.size() > 0) {
      return false;
    }
    if (selectedBuilding == null || selectedBuilding.faction != activeFaction || !selectedBuilding.completed) {
      orderLabel = tr("order.selectProducer");
      return false;
    }
    BuildingDef bdef = getBuildingDef(selectedBuilding.buildingType);
    if (bdef == null || !bdef.canTrainUnits || bdef.trainableUnits == null) {
      orderLabel = tr("order.noTrainHere");
      return false;
    }
    boolean allowed = false;
    for (int i = 0; i < bdef.trainableUnits.length; i++) {
      if (bdef.trainableUnits[i].equals(unitId)) {
        allowed = true;
        break;
      }
    }
    if (!allowed) {
      orderLabel = tr("order.unitNotInRoster");
      return false;
    }
    UnitDef def = getUnitDef(unitId);
    if (def == null) {
      return false;
    }
    if (!resources.canAfford(def.cost)) {
      orderLabel = tr("order.needCredits");
      return false;
    }
    int needSupply = max(0, def.supplyCost);
    if (usedSupplyForFaction(activeFaction) + needSupply > supplyCapForFaction(activeFaction)) {
      orderLabel = tr("order.needSupply");
      return false;
    }
    if (!resources.spend(def.cost)) {
      return false;
    }
    trainQueue.add(new TrainJob(selectedBuilding, unitId, def.trainTime, activeFaction));
    orderLabel = tr("order.train") + ":" + unitId;
    return true;
  }

  PVector findSpawnForTrainer(Building trainer, float unitRadius) {
    if (trainer == null) {
      return new PVector(0, 0);
    }
    BuildingDef bdef = getBuildingDef(trainer.buildingType);
    if (bdef != null && bdef.spawnPoints != null && bdef.spawnPoints.length > 0) {
      PVector configured = findConfiguredSpawnNearBuilding(trainer, bdef, unitRadius);
      if (configured != null) {
        return configured;
      }
    }
    return findSpawnNearBuildingAvoidingUnits(trainer, unitRadius, new ArrayList<String>());
  }

  PVector findConfiguredSpawnNearBuilding(Building b, BuildingDef bdef, float unitRadius) {
    float ts = map.tileSize;
    float pad = max(0, bdef.spawnClearancePad);
    for (int i = 0; i < bdef.spawnPoints.length; i++) {
      SpawnPointDef sp = bdef.spawnPoints[i];
      PVector seed = null;
      if ("localWorld".equals(sp.mode)) {
        seed = new PVector(b.pos.x + sp.x * ts, b.pos.y + sp.y * ts);
      } else {
        seed = new PVector(b.pos.x + (sp.x + 0.5) * ts, b.pos.y + (sp.y + 0.5) * ts);
      }
      int tx = map.toTileX(seed.x);
      int ty = map.toTileY(seed.y);
      PVector walkable = pathfinder.findClosestWalkable(tx, ty, buildings);
      int wx = int(walkable.x);
      int wy = int(walkable.y);
      if (!pathfinder.isWalkable(wx, wy, buildings)) {
        continue;
      }
      float worldX = (wx + 0.5) * ts;
      float worldY = (wy + 0.5) * ts;
      if (isWorldSpawnFreeOfUnits(worldX, worldY, unitRadius, pad)) {
        return new PVector(worldX, worldY);
      }
    }
    if (bdef.useLegacySpawnFallback) {
      return findSpawnNearBuildingAvoidingUnits(b, unitRadius, new ArrayList<String>());
    }
    return null;
  }

  PVector findSpawnAroundBuilding(Building b) {
    float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
    float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
    UnitDef ud = scoutDef != null ? scoutDef : getUnitDef("rifleman");
    float r = ud != null ? ud.radius : 11;
    return findSpawnNearBuildingAvoidingUnits(b, r, new ArrayList<String>());
  }

  boolean isUnitVisibleToPlayer(Unit u) {
    if (!fogEnabled || fog == null) {
      return true;
    }
    if (u.faction == activeFaction) {
      return true;
    }
    return fog.isWorldVisible(map, u.pos.x, u.pos.y);
  }

  boolean isBuildingVisibleToPlayer(Building b) {
    if (!fogEnabled || fog == null) {
      return true;
    }
    if (b.faction == activeFaction) {
      return true;
    }
    float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
    float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
    return fog.isWorldVisible(map, cx, cy);
  }

  boolean canPlaceSelectedBuildInExploredArea() {
    if (buildSystem == null || map == null) {
      return false;
    }
    BuildingDef def = buildSystem.selectedDef();
    if (def == null) {
      return false;
    }
    if (!fogEnabled || fog == null) {
      return true;
    }
    for (int y = 0; y < def.tileH; y++) {
      for (int x = 0; x < def.tileW; x++) {
        float wx = (buildSystem.previewTileX + x + 0.5) * map.tileSize;
        float wy = (buildSystem.previewTileY + y + 0.5) * map.tileSize;
        if (!fog.isWorldExplored(map, wx, wy)) {
          return false;
        }
      }
    }
    return true;
  }

  int queuedBuildCountForDef(String defId, Faction faction) {
    if (buildSystem == null || defId == null) {
      return 0;
    }
    int c = 0;
    if (buildSystem.currentJob != null && buildSystem.currentJob.def != null
      && buildSystem.currentJob.faction == faction
      && defId.equals(buildSystem.currentJob.def.id)) {
      c++;
    }
    for (BuildJob j : buildSystem.queue) {
      if (j == null || j.def == null) {
        continue;
      }
      if (j.faction == faction && defId.equals(j.def.id)) {
        c++;
      }
    }
    return c;
  }

  float activeBuildProgressForDef(String defId, Faction faction) {
    if (buildSystem == null || buildSystem.currentJob == null || buildSystem.currentJob.target == null || defId == null) {
      return -1;
    }
    BuildJob job = buildSystem.currentJob;
    if (job.faction != faction || job.def == null || !defId.equals(job.def.id)) {
      return -1;
    }
    if (job.target.buildTime <= 1e-6) {
      return 1;
    }
    return constrain(job.target.buildProgress / job.target.buildTime, 0, 1);
  }

  int queuedTrainCountForUnit(Building trainer, String unitId) {
    if (trainer == null || unitId == null) {
      return 0;
    }
    int c = 0;
    for (TrainJob j : trainQueue) {
      if (j.trainer == trainer && unitId.equals(j.unitId)) {
        c++;
      }
    }
    return c;
  }

  float activeTrainProgressForUnit(Building trainer, String unitId) {
    if (trainer == null || unitId == null) {
      return -1;
    }
    for (int i = 0; i < trainQueue.size(); i++) {
      TrainJob j = trainQueue.get(i);
      if (j.trainer == trainer && unitId.equals(j.unitId) && isFirstTrainJobForTrainer(trainer, i)) {
        return j.progress01();
      }
    }
    return -1;
  }

  boolean cancelOneTrainJobForSelectedBuilding(String unitId) {
    if (selectedBuilding == null || unitId == null || unitId.length() == 0) {
      return false;
    }
    UnitDef def = getUnitDef(unitId);
    if (def == null) {
      return false;
    }
    // Prefer cancelling queued (later) jobs first.
    for (int i = trainQueue.size() - 1; i >= 0; i--) {
      TrainJob j = trainQueue.get(i);
      if (j.trainer == selectedBuilding && unitId.equals(j.unitId)) {
        trainQueue.remove(i);
        ResourcePool pool = resourcePoolForFaction(activeFaction);
        if (pool != null) {
          pool.addCredits(def.cost);
        }
        orderLabel = tr("order.trainCancel") + ":" + unitId;
        return true;
      }
    }
    return false;
  }

  boolean cancelOneBuildJobByDef(String defId, Faction faction) {
    if (defId == null || defId.length() == 0 || buildSystem == null) {
      return false;
    }
    BuildingDef def = getBuildingDef(defId);
    if (def == null) {
      return false;
    }
    for (int i = buildSystem.queue.size() - 1; i >= 0; i--) {
      BuildJob j = buildSystem.queue.get(i);
      if (j != null && j.def != null && j.faction == faction && defId.equals(j.def.id)) {
        buildSystem.queue.remove(i);
        ResourcePool pool = resourcePoolForFaction(faction);
        if (pool != null) {
          pool.addCredits(def.cost);
        }
        orderLabel = tr("order.buildQueueMinus");
        return true;
      }
    }
    if (buildSystem.currentJob != null && buildSystem.currentJob.def != null
      && buildSystem.currentJob.faction == faction
      && defId.equals(buildSystem.currentJob.def.id)) {
      Building target = buildSystem.currentJob.target;
      if (target != null) {
        buildings.remove(target);
      }
      buildSystem.currentJob = null;
      ResourcePool pool = resourcePoolForFaction(faction);
      if (pool != null) {
        pool.addCredits(def.cost);
      }
      orderLabel = tr("order.buildCancel");
      return true;
    }
    return false;
  }
}

class TrainJob {
  Building trainer;
  String unitId;
  float timeRemaining;
  float totalTime;
  Faction faction;

  TrainJob(Building trainer, String unitId, float trainTime, Faction faction) {
    this.trainer = trainer;
    this.unitId = unitId;
    this.totalTime = max(0.05, trainTime);
    this.timeRemaining = this.totalTime;
    this.faction = faction;
  }

  float progress01() {
    if (totalTime <= 1e-6) {
      return 1;
    }
    return constrain(1.0 - timeRemaining / totalTime, 0, 1);
  }
}

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

    if (enemyMines < 1 || enemyMiners < gs.enemyAiMinersMin) {
      phase = ECO;
    } else if (enemyWarehouses < 1 || enemyBarracks < 1) {
      phase = TECH;
    } else if (enemyCombat < gs.enemyAiAttackMinArmy) {
      phase = MUSTER;
    } else {
      phase = ATTACK;
    }

    runEconomy(gs, enemyMines, enemyMiners);
    runTech(gs, enemyWarehouses, enemyBarracks);
    runDefense(gs, enemyTowers);
    runProduction(gs, enemyMiners, enemyCombat);

    PVector strategicTarget = chooseStrategicTarget(gs);
    boolean readyByTime = attackTimer >= gs.enemyAiAttackInterval;
    boolean readyByAdv = enemyArmyValue >= playerArmyValue * gs.enemyAiAttackAdvantage;
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
    if ("base".equals(type)) {
      return 0;
    }
    if ("barracks".equals(type)) {
      return 1;
    }
    if ("tower".equals(type)) {
      return 2;
    }
    if ("mine".equals(type)) {
      return 3;
    }
    return 4;
  }

  PVector chooseStrategicTarget(GameState gs) {
    KnownEnemyBuilding best = null;
    int bestP = 999;
    float bestD = 1e9;
    Building eb = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector from = eb == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75) :
      new PVector(eb.pos.x + eb.tileW * gs.map.tileSize * 0.5, eb.pos.y + eb.tileH * gs.map.tileSize * 0.5);
    for (KnownEnemyBuilding kb : knownEnemyBuildings) {
      int p = buildingPriority(kb.type);
      float d = PVector.dist(from, kb.pos);
      if (p < bestP || (p == bestP && d < bestD)) {
        bestP = p;
        bestD = d;
        best = kb;
      }
    }
    if (best != null) {
      return best.pos.copy();
    }
    if (lastSeenEnemyUnitPos != null) {
      return lastSeenEnemyUnitPos.copy();
    }
    return null;
  }

  void runEconomy(GameState gs, int enemyMines, int enemyMiners) {
    Building base = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector anchor = base == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75) : base.pos.copy();
    if (enemyMines < 1) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "mine", anchor)) {
        lastAction = "build:mine";
        return;
      }
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
    if (base == null) {
      return;
    }
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
    if (!underPressure && enemyTowers >= 2) {
      return;
    }
    if (gs.enemyResources.credits < 180) {
      return;
    }
    if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "tower", PVector.add(base.pos, new PVector(-gs.map.tileSize * 3.0, gs.map.tileSize * 2.0)))) {
      lastAction = "build:tower";
    }
  }

  void runProduction(GameState gs, int enemyMiners, int enemyCombat) {
    int targetMiners = int(constrain(gs.enemyAiMinersMin + enemyCombat / 6, gs.enemyAiMinersMin, gs.enemyAiMinersMax));
    if (enemyMiners < targetMiners) {
      if (gs.tryTrainUnitForFaction(Faction.ENEMY, "miner")) {
        lastAction = "train:miner";
        return;
      }
    }

    int rifleCount = gs.countFactionUnitsByType(Faction.ENEMY, "rifleman");
    int rocketCount = gs.countFactionUnitsByType(Faction.ENEMY, "rocketeer");
    int combatCount = max(1, rifleCount + rocketCount);
    float rifleShare = rifleCount / float(combatCount);
    float rocketShare = rocketCount / float(combatCount);
    if (rocketShare < gs.enemyAiRocketRatio) {
      if (gs.tryTrainUnitForFaction(Faction.ENEMY, "rocketeer")) {
        lastAction = "train:rocketeer";
        return;
      }
    }
    if (rifleShare < gs.enemyAiRifleRatio) {
      if (gs.tryTrainUnitForFaction(Faction.ENEMY, "rifleman")) {
        lastAction = "train:rifleman";
        return;
      }
    }
    if (!gs.tryTrainUnitForFaction(Faction.ENEMY, "rifleman")) {
      gs.tryTrainUnitForFaction(Faction.ENEMY, "rocketeer");
    }
  }

  void runExploration(GameState gs) {
    if (exploreWaypoints.size() == 0) {
      buildExploreWaypoints(gs);
    }
    if (exploreWaypoints.size() == 0) {
      return;
    }
    if (exploreTarget == null || exploreRetargetTimer <= 0) {
      exploreWaypointIndex = (exploreWaypointIndex + 1) % exploreWaypoints.size();
      exploreTarget = exploreWaypoints.get(exploreWaypointIndex).copy();
      exploreRetargetTimer = random(5.5, 8.5);
    }
    int nearby = 0;
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) {
        continue;
      }
      if (PVector.dist(u.pos, exploreTarget) < gs.map.tileSize * 2.2) {
        nearby++;
      }
    }
    if (nearby >= 2) {
      exploreRetargetTimer = 0;
    }
    for (Unit u : gs.units) {
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) {
        continue;
      }
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
    // Simple deterministic shuffle-like zigzag for better coverage.
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
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) {
        continue;
      }
      if (u.orderType == UnitOrderType.ATTACK || u.orderType == UnitOrderType.ATTACK_MOVE) {
        continue;
      }
      if (u.moveTarget != null && PVector.dist(u.moveTarget, rally) < 24 && u.pathQueue.size() > 0) {
        continue;
      }
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
      if (u.faction != Faction.ENEMY || u.hp <= 0 || u.canHarvest) {
        continue;
      }
      u.issueAttackMove(target.copy(), gs, false);
    }
    lastAction = "attack-wave-" + waveSerial;
  }

  String phaseLabel() {
    if (phase == ECO) {
      return "ECO";
    }
    if (phase == TECH) {
      return "TECH";
    }
    if (phase == MUSTER) {
      return "MUSTER";
    }
    if (phase == ATTACK) {
      return "ATTACK";
    }
    return "BOOTSTRAP";
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

class GoldMine {
  int tx;
  int ty;
  int amount;

  GoldMine(int tx, int ty, int amount) {
    this.tx = tx;
    this.ty = ty;
    this.amount = amount;
  }

  PVector worldCenter(TileMap map) {
    return new PVector((tx + 0.5) * map.tileSize, (ty + 0.5) * map.tileSize);
  }

  void render(Camera camera, TileMap map) {
    if (amount <= 0) {
      return;
    }
    float wx = tx * map.tileSize;
    float wy = ty * map.tileSize;
    PVector s = camera.worldToScreen(wx, wy);
    float ss = map.tileSize * camera.zoom;
    noStroke();
    fill(210, 165, 50);
    rect(s.x, s.y, ss, ss);
    fill(255, 215, 90);
    ellipse(s.x + ss * 0.5, s.y + ss * 0.48, ss * 0.45, ss * 0.45);
    fill(40, 30, 10, 170);
    rect(s.x + ss * 0.08, s.y + ss * 0.73, ss * 0.84, ss * 0.16);
  }
}

class MuzzleFx {
  PVector startPos;
  PVector endPos;
  float ttl = 0.07;

  MuzzleFx(PVector startPos, PVector endPos) {
    this.startPos = startPos;
    this.endPos = endPos;
  }

  void render(Camera camera) {
    float k = constrain(ttl / 0.07, 0, 1);
    PVector a = camera.worldToScreen(startPos.x, startPos.y);
    PVector b = camera.worldToScreen(endPos.x, endPos.y);
    PVector d = PVector.sub(b, a);
    if (d.magSq() < 1e-6) {
      return;
    }
    d.normalize();
    PVector m = PVector.add(a, PVector.mult(d, 12 * camera.zoom));
    stroke(255, 225, 130, 230 * k);
    strokeWeight(max(1, 2 * camera.zoom));
    line(a.x, a.y, m.x, m.y);
    noStroke();
    fill(255, 250, 160, 220 * k);
    ellipse(a.x, a.y, 5 * camera.zoom, 5 * camera.zoom);
  }
}

class DeliveryFx {
  PVector pos;
  int amount;
  float ttl = 0.9;

  DeliveryFx(PVector pos, int amount) {
    this.pos = pos;
    this.amount = amount;
  }

  void render(Camera camera) {
    float k = constrain(ttl / 0.9, 0, 1);
    float up = (1 - k) * 22;
    PVector s = camera.worldToScreen(pos.x, pos.y - up);
    noFill();
    stroke(255, 225, 120, 200 * k);
    strokeWeight(max(1, 1.6 * camera.zoom));
    ellipse(s.x, s.y, (10 + (1 - k) * 18) * camera.zoom, (10 + (1 - k) * 18) * camera.zoom);
    fill(255, 235, 140, 230 * k);
    noStroke();
    textAlign(CENTER, TOP);
    textSize(11);
    text("+ " + amount, s.x, s.y - 14 * camera.zoom);
    textAlign(LEFT, TOP);
  }
}

class RocketProjectile {
  PVector pos;
  Unit target;
  Building buildingTarget;
  PVector fixedTargetPos;
  float damage;
  float speed;
  PVector vel = new PVector();
  ArrayList<RocketSmoke> smokeTrail = new ArrayList<RocketSmoke>();
  int maxTrail = 44;
  float ttl = 3.0;
  boolean impactDone = false;

  RocketProjectile(PVector pos, Unit target, float damage, float speed) {
    this.pos = pos.copy();
    this.target = target;
    this.damage = damage;
    this.speed = speed;
    fixedTargetPos = target != null ? target.pos.copy() : pos.copy();
    PVector aim = fixedTargetPos.copy();
    PVector initial = PVector.sub(aim, this.pos);
    if (initial.magSq() < 1e-6) {
      initial.set(1, 0);
    } else {
      initial.normalize();
    }
    vel = initial.mult(max(60, speed * 0.62));
  }

  RocketProjectile(PVector pos, Building target, PVector targetPos, float damage, float speed) {
    this.pos = pos.copy();
    this.buildingTarget = target;
    this.fixedTargetPos = targetPos == null ? pos.copy() : targetPos.copy();
    this.damage = damage;
    this.speed = speed;
    PVector initial = PVector.sub(this.fixedTargetPos, this.pos);
    if (initial.magSq() < 1e-6) {
      initial.set(1, 0);
    } else {
      initial.normalize();
    }
    vel = initial.mult(max(60, speed * 0.60));
  }

  PVector liveTargetPos() {
    if (target != null && target.hp > 0) {
      fixedTargetPos = target.pos.copy();
      return fixedTargetPos.copy();
    }
    if (fixedTargetPos != null) {
      return fixedTargetPos.copy();
    }
    return null;
  }

  void applyImpact() {
    if (impactDone) {
      return;
    }
    impactDone = true;
    if (target != null && target.hp > 0) {
      target.hp -= int(damage);
      return;
    }
    if (buildingTarget != null && buildingTarget.hp > 0) {
      buildingTarget.hp -= int(damage);
    }
  }

  boolean update(float dt) {
    for (int i = smokeTrail.size() - 1; i >= 0; i--) {
      RocketSmoke rs = smokeTrail.get(i);
      rs.age += dt;
      if (rs.age >= rs.ttl) {
        smokeTrail.remove(i);
      }
    }
    if (impactDone) {
      return smokeTrail.size() == 0;
    }

    ttl -= dt;
    if (ttl <= 0) {
      impactDone = true;
      return smokeTrail.size() == 0;
    }
    PVector aim = liveTargetPos();
    if (aim == null) {
      impactDone = true;
      return smokeTrail.size() == 0;
    }
    PVector delta = PVector.sub(aim, pos);
    float dist = delta.mag();
    if (dist < 10) {
      applyImpact();
      return smokeTrail.size() == 0;
    }
    if (delta.magSq() < 1e-6) {
      delta.set(1, 0);
    } else {
      delta.normalize();
    }
    PVector desiredVel = PVector.mult(delta, speed);
    float steer = constrain(0.95 * dt + 0.10, 0.10, 0.42);
    vel.lerp(desiredVel, steer);
    PVector step = PVector.mult(vel, dt);
    if (step.mag() >= dist) {
      pos.set(aim);
      applyImpact();
      return smokeTrail.size() == 0;
    }
    pos.add(step);
    smokeTrail.add(new RocketSmoke(pos.copy(), random(0.22, 0.44), random(2.0, 5.2)));
    while (smokeTrail.size() > maxTrail) {
      smokeTrail.remove(0);
    }
    return false;
  }

  void render(Camera camera) {
    if (camera == null) {
      return;
    }
    PVector s = camera.worldToScreen(pos.x, pos.y);
    noStroke();
    for (int i = 0; i < smokeTrail.size(); i++) {
      RocketSmoke rs = smokeTrail.get(i);
      float life = constrain(1.0 - rs.age / max(0.001, rs.ttl), 0, 1);
      PVector wp = rs.pos;
      PVector sp = camera.worldToScreen(wp.x, wp.y);
      float r = rs.size * life * camera.zoom;
      fill(80, 85, 95, 165 * life);
      ellipse(sp.x, sp.y, r * 2, r * 2);
    }

    if (impactDone) {
      return;
    }
    noStroke();
    // Head spark: one bright dot only (no straight tail line).
    fill(255, 225, 170, 245);
    ellipse(s.x, s.y, 6 * camera.zoom, 6 * camera.zoom);
  }
}

class RocketSmoke {
  PVector pos;
  float ttl;
  float age = 0;
  float size;

  RocketSmoke(PVector pos, float ttl, float size) {
    this.pos = pos;
    this.ttl = ttl;
    this.size = size;
  }
}

class OrderMarker {
  PVector pos;
  boolean attackStyle;
  float ttl = 0.6;

  OrderMarker(PVector pos, boolean attackStyle) {
    this.pos = pos;
    this.attackStyle = attackStyle;
  }

  void render(Camera camera) {
    PVector s = camera.worldToScreen(pos.x, pos.y);
    float k = constrain(ttl / 0.6, 0, 1);
    float r = 8 + (1 - k) * 14;
    noFill();
    strokeWeight(2);
    if (attackStyle) {
      stroke(255, 90, 90, 220 * k);
      ellipse(s.x, s.y, r * 2, r * 2);
      line(s.x - r, s.y - r, s.x + r, s.y + r);
      line(s.x - r, s.y + r, s.x + r, s.y - r);
    } else {
      stroke(120, 255, 120, 220 * k);
      ellipse(s.x, s.y, r * 2, r * 2);
    }
  }
}
