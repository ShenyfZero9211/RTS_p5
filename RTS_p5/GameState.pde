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
  float fogUpdateBudgetMs = 2.5;
  int fogUnexploredAlpha = 220;
  int fogExploredAlpha = 120;
  /** Higher = faster fog overlay blend toward logical targets (1/s time constant scale). */
  float fogTransitionSpeed = 11;

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
  CombatSystem combatSystem;
  ProductionSystem productionSystem;
  GameFlowController gameFlow;
  EffectsRuntime effectsRuntime;
  UiSettingsLoader uiSettingsLoader;
  DefinitionsLoader definitionsLoader;
  String orderLabel = "";
  boolean attackMoveArmed = false;
  boolean hardCursorLock = false;
  CursorLock cursorLock;
  ArrayList<OrderMarker> orderMarkers = new ArrayList<OrderMarker>();
  boolean debugShowPaths = false;
  boolean debugShowScriptRegions = true;

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
  boolean showRuntimeProfiling = false;
  float profileInputMs = 0;
  float profileBuildMs = 0;
  float profileUnitsMs = 0;
  float profileFogMs = 0;
  float profileCombatMs = 0;
  float profileAiMs = 0;
  float profileScriptMs = 0;
  float profileUiMs = 0;
  float profileFrameMs = 0;
  int profilingSampleFrames = 0;
  int fxDensityLevel = 2;
  String profileStepLabel = "60Hz";
  boolean benchmarkScenarioActive = false;
  float benchmarkOrderPulseTimer = 0;
  float benchmarkReinforceTimer = 0;
  float benchmarkReinforceInterval = 12.0;
  int benchmarkReinforceCount = 10;
  String benchmarkIntensity = "heavy";
  String benchmarkTroopProfile = "balanced";
  int benchmarkWaveSerial = 0;
  int benchmarkLastPlayerReinforce = 0;
  int benchmarkLastEnemyReinforce = 0;
  float benchmarkReinforceFlashTimer = 0;
  ScriptRuntime scriptRuntime;
  int scriptActionsLastTick = 0;
  int scriptActionsTotal = 0;
  int scriptBudgetOverrunCount = 0;

  /** Map JSON in sketch `data/` folder (e.g. exported from the map editor). */
  String defaultMapJson = "map_001.json";

  /**
   * When true, {@link GameEngine} skips the main menu after setup. Set from {@code --DirectEnter},
   * env {@code RTS_DIRECT_ENTER}, or defaults when a launch map is supplied (see {@link #applySketchArguments}).
   */
  boolean autoStartPlayFromLaunch = false;

  /**
   * Sketch args (when forwarded) and env {@code RTS_MAP_FILE} / {@code RTS_DIRECT_ENTER}:
   * map via {@code --map=}, {@code --map}, or bare {@code *.json}; direct enter via {@code --DirectEnter=true|false}.
   * Env is used when args omit the map (typical for {@code cli --run}).
   */
  void applySketchArguments(String[] sketchArgs) {
    autoStartPlayFromLaunch = false;
    String mapArg = null;
    Boolean directEnterArg = null;

    if (sketchArgs != null) {
      for (int i = 0; i < sketchArgs.length; i++) {
        String raw = sketchArgs[i];
        if (raw == null) {
          continue;
        }
        String a = trim(raw);
        if (a.length() <= 0) {
          continue;
        }
        if ((a.charAt(0) == '"' && a.charAt(a.length() - 1) == '"')
          || (a.charAt(0) == '\'' && a.charAt(a.length() - 1) == '\'')) {
          a = a.substring(1, a.length() - 1);
        }
        String aLow = a.toLowerCase();
        if (aLow.startsWith("--directenter=")) {
          directEnterArg = parseDirectEnterTriState(a.substring("--directenter=".length()));
          continue;
        }
        if (aLow.equals("-directenter") || aLow.equals("--directenter")) {
          if (i + 1 < sketchArgs.length) {
            directEnterArg = parseDirectEnterTriState(sketchArgs[i + 1]);
            i++;
          }
          continue;
        }
        if (mapArg == null && a.startsWith("--map=")) {
          String v = trim(a.substring(6));
          if (v.length() > 0) {
            mapArg = v;
          }
          continue;
        }
        if (mapArg == null && (a.equals("-map") || a.equals("--map"))) {
          if (i + 1 < sketchArgs.length) {
            String v = trim(sketchArgs[i + 1]);
            if (v.length() > 0) {
              mapArg = v;
            }
            i++;
          }
          continue;
        }
        if (mapArg == null && a.length() > 5 && a.endsWith(".json") && a.charAt(0) != '-') {
          mapArg = a;
        }
      }
    }

    boolean mapFromArgs = false;
    boolean mapFromEnv = false;
    if (mapArg != null && trim(mapArg).length() > 0) {
      setDefaultMapFromCliValue(mapArg);
      mapFromArgs = true;
    } else {
      String envMap = java.lang.System.getenv("RTS_MAP_FILE");
      if (envMap != null) {
        envMap = trim(envMap);
        if (envMap.length() > 0) {
          setDefaultMapFromCliValue(envMap);
          mapFromEnv = true;
        }
      }
    }

    if (!mapFromArgs && !mapFromEnv) {
      return;
    }

    if (directEnterArg != null) {
      autoStartPlayFromLaunch = directEnterArg.booleanValue();
    } else if (mapFromEnv) {
      autoStartPlayFromLaunch = directEnterFromEnvWantsAutoStart();
    } else {
      autoStartPlayFromLaunch = true;
    }
  }

  /** null = not specified; else parsed boolean. */
  Boolean parseDirectEnterTriState(String raw) {
    if (raw == null) {
      return null;
    }
    String v = trim(raw).toLowerCase();
    if (v.length() <= 0) {
      return null;
    }
    if (v.equals("0") || v.equals("false") || v.equals("no")) {
      return Boolean.FALSE;
    }
    if (v.equals("1") || v.equals("true") || v.equals("yes")) {
      return Boolean.TRUE;
    }
    return null;
  }

  /** When map came from env only: absent/empty RTS_DIRECT_ENTER means true; 0/false/no means false. */
  boolean directEnterFromEnvWantsAutoStart() {
    String d = java.lang.System.getenv("RTS_DIRECT_ENTER");
    if (d == null) {
      return true;
    }
    d = trim(d).toLowerCase();
    if (d.length() <= 0) {
      return true;
    }
    if (d.equals("0") || d.equals("false") || d.equals("no")) {
      return false;
    }
    return true;
  }

  void setDefaultMapFromCliValue(String v) {
    v = trim(v);
    if (v.length() <= 0) {
      return;
    }
    java.io.File asGiven = new java.io.File(v);
    if (asGiven.isAbsolute()) {
      defaultMapJson = asGiven.getAbsolutePath();
      println("[RTS] Map from args (absolute): " + defaultMapJson);
      return;
    }
    String fromSketch = sketchPath(v);
    if (new java.io.File(fromSketch).isFile()) {
      defaultMapJson = fromSketch;
      println("[RTS] Map from args (sketch-relative): " + defaultMapJson);
      return;
    }
    String dataNamed = sketchPath("data" + java.io.File.separator + v);
    if (new java.io.File(dataNamed).isFile()) {
      defaultMapJson = new java.io.File(v).getName();
      println("[RTS] Map from args (data/" + defaultMapJson + ")");
      return;
    }
    defaultMapJson = v;
    println("[RTS] Map from args (data/ name): " + defaultMapJson);
  }

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
    combatSystem = new CombatSystem();
    productionSystem = new ProductionSystem();
    gameFlow = new GameFlowController();
    effectsRuntime = new EffectsRuntime();
    scriptRuntime = new ScriptRuntime();
    uiSettingsLoader = new UiSettingsLoader();
    definitionsLoader = new DefinitionsLoader();
    resetControlGroups();
    orderLabel = tr("order.none");
  }

  /** Full session reset: map, entities, economy, queues. Returns false if map load fails (see lastStartError). */
  boolean startNewGame() {
    lastStartError = "";
    gameEnded = false;
    gameResult = "";
    benchmarkScenarioActive = false;
    benchmarkOrderPulseTimer = 0;
    benchmarkReinforceTimer = 0;
    benchmarkWaveSerial = 0;
    benchmarkLastPlayerReinforce = 0;
    benchmarkLastEnemyReinforce = 0;
    benchmarkReinforceFlashTimer = 0;
    scriptActionsLastTick = 0;
    scriptActionsTotal = 0;
    scriptBudgetOverrunCount = 0;
    profileScriptMs = 0;
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
    if (!map.loadFromJson(defaultMapJson)) {
      lastStartError = "Failed to load " + defaultMapJson;
      println(lastStartError);
      map = null;
      return false;
    }
    JSONObject mapRoot = loadJSONObject(defaultMapJson);
    if (scriptRuntime != null) {
      scriptRuntime.resetForNewGame(this, mapRoot);
    }
    loadMapResources();

    camera = new Camera(worldViewW, screenH, map.worldWidthPx(), map.worldHeightPx());
    camera.wheelZoomStep = wheelZoomStep;
    camera.speed = edgeScrollSpeed;
    fog = new FogSystem(map);
    fog.syncDisplayToTargets(this);
    loadDefinitions();
    buildSystem = new BuildSystem(buildingDefs);
    resources = new ResourcePool(playerStartCredits, creditCapForFaction(Faction.PLAYER));
    enemyResources = new ResourcePool(enemyStartCredits, creditCapForFaction(Faction.ENEMY));
    pathfinder = new Pathfinder(map);
    enemyAi = new EnemyAiController();

    if (map.testMap) {
      seedDemoEntities();
    } else {
      spawnInitialBuildingsFromMapJson();
      spawnInitialUnitsFromMapJson();
    }
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

    if (!spawnInitialUnitsFromMapJson()) {
      spawnInitialUnitNear(playerBasePos, Faction.PLAYER, miner, 2.8f, 3.4f);
      spawnInitialUnitNear(playerBasePos, Faction.PLAYER, miner, 3.7f, 3.8f);
      spawnInitialUnitNear(playerBasePos, Faction.PLAYER, rifle, 4.6f, 4.2f);
      spawnInitialUnitNear(playerBasePos, Faction.PLAYER, rocket, 5.4f, 5.0f);
      spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, miner, -2.8f, -3.2f);
      spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, miner, -3.8f, -3.8f);
      spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, rifle, -4.6f, -4.3f);
      spawnInitialUnitNear(enemyBasePos, Faction.ENEMY, rocket, -5.5f, -5.1f);
    }
  }

  /** Spawn buildings from map JSON `initialBuildings` at exact tile origins (non-test maps). */
  void spawnInitialBuildingsFromMapJson() {
    JSONObject root = loadJSONObject(defaultMapJson);
    if (root == null) {
      return;
    }
    JSONArray arr = root.getJSONArray("initialBuildings");
    if (arr == null || arr.size() <= 0) {
      return;
    }
    float ts = map.tileSize;
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      String type = o.getString("type", "");
      String fid = o.getString("faction", "player");
      Faction fac = "enemy".equals(fid) ? Faction.ENEMY : Faction.PLAYER;
      BuildingDef def = getBuildingDef(type);
      if (def == null) {
        continue;
      }
      int tx = o.getInt("x", -1);
      int ty = o.getInt("y", -1);
      if (tx < 0 || ty < 0 || tx >= map.widthTiles || ty >= map.heightTiles) {
        continue;
      }
      if (!canPlaceBuildingFootprint(def, tx, ty, 0)) {
        println("spawnInitialBuildingsFromMapJson: skipped " + type + " at tile " + tx + "," + ty);
        continue;
      }
      Building b = new Building(tx * ts, ty * ts, def.tileW, def.tileH, fac, def);
      b.completed = true;
      b.buildProgress = b.buildTime;
      buildings.add(b);
    }
  }

  /**
   * If the loaded map JSON lists initialUnits, spawn them with tile-based dedup + radius clearance
   * (mirrors editor free-placement rules). Returns true if map units were used.
   */
  boolean spawnInitialUnitsFromMapJson() {
    JSONObject root = loadJSONObject(defaultMapJson);
    if (root == null) {
      return false;
    }
    JSONArray arr = root.getJSONArray("initialUnits");
    if (arr == null || arr.size() <= 0) {
      return false;
    }
    float ts = map.tileSize;
    ArrayList<String> usedTileKeys = new ArrayList<String>();
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      String fid = o.getString("faction", "player");
      String uid = o.getString("type", "rifleman");
      Faction fac = "enemy".equals(fid) ? Faction.ENEMY : Faction.PLAYER;
      UnitDef def = getUnitDef(uid);
      if (def == null) {
        continue;
      }
      float wcx;
      float wcy;
      if (o.hasKey("worldCX") && o.hasKey("worldCY")) {
        wcx = o.getFloat("worldCX");
        wcy = o.getFloat("worldCY");
      } else {
        int tx = o.getInt("x", 0);
        int ty = o.getInt("y", 0);
        wcx = (tx + 0.5f) * ts;
        wcy = (ty + 0.5f) * ts;
      }
      PVector desired = new PVector(wcx, wcy);
      PVector safe = findNearestOpenSlotForMapUnit(desired, def.radius, usedTileKeys);
      units.add(new Unit(safe.x, safe.y, fac, def));
    }
    return true;
  }

  PVector findNearestOpenSlotForMapUnit(PVector desiredWorld, float unitRadius, ArrayList<String> usedTileKeys) {
    PVector base = findNearestOpenSlot(desiredWorld, usedTileKeys);
    float pad = 3;
    if (isWorldSpawnFreeOfUnits(base.x, base.y, unitRadius, pad)) {
      int tx = map.toTileX(base.x);
      int ty = map.toTileY(base.y);
      usedTileKeys.add(tx + ":" + ty);
      return base;
    }
    float ts = map.tileSize;
    int cx = map.toTileX(desiredWorld.x);
    int cy = map.toTileY(desiredWorld.y);
    for (int r = 0; r < 14; r++) {
      for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
          if (r > 0 && abs(dx) != r && abs(dy) != r) {
            continue;
          }
          int nx = cx + dx;
          int ny = cy + dy;
          if (!pathfinder.isWalkable(nx, ny, buildings)) {
            continue;
          }
          String k = nx + ":" + ny;
          if (usedTileKeys.contains(k)) {
            continue;
          }
          float px = (nx + 0.5f) * ts;
          float py = (ny + 0.5f) * ts;
          if (!isWorldSpawnFreeOfUnits(px, py, unitRadius, pad)) {
            continue;
          }
          usedTileKeys.add(k);
          return new PVector(px, py);
        }
      }
    }
    usedTileKeys.add(map.toTileX(base.x) + ":" + map.toTileY(base.y));
    return base;
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
    if (!buildingFootprintRespectsGoldClearance(def, tx, ty)) {
      return false;
    }
    if (!buildingFootprintClearOfUnits(def, tx, ty)) {
      return false;
    }
    return true;
  }

  boolean circleIntersectsAxisRect(float cx, float cy, float r, float rx, float ry, float rw, float rh) {
    float nx = constrain(cx, rx, rx + rw);
    float ny = constrain(cy, ry, ry + rh);
    float dx = cx - nx;
    float dy = cy - ny;
    return dx * dx + dy * dy < r * r;
  }

  /** Building footprint must not overlap any living unit's collision circle. */
  boolean buildingFootprintClearOfUnits(BuildingDef def, int tx, int ty) {
    if (def == null || map == null || units == null) {
      return true;
    }
    float ts = map.tileSize;
    float rx = tx * ts;
    float ry = ty * ts;
    float rw = def.tileW * ts;
    float rh = def.tileH * ts;
    float pad = 2.0f;
    for (Unit u : units) {
      if (u == null || u.hp <= 0) {
        continue;
      }
      if (circleIntersectsAxisRect(u.pos.x, u.pos.y, u.radius + pad, rx, ry, rw, rh)) {
        return false;
      }
    }
    return true;
  }

  /**
   * No building footprint may overlap an expanded box around any active gold vein tile
   * (vein tile is unwalkable; buffer keeps structures off approach tiles for miners).
   */
  boolean buildingFootprintRespectsGoldClearance(BuildingDef def, int tx, int ty) {
    if (def == null || map == null || goldMines == null || goldMines.size() <= 0) {
      return true;
    }
    return buildingRectRespectsGoldClearance(tx, ty, def.tileW, def.tileH);
  }

  boolean buildingRectRespectsGoldClearance(int tx, int ty, int tw, int th) {
    if (map == null || goldMines == null || goldMines.size() <= 0) {
      return true;
    }
    float ts = map.tileSize;
    float bLeft = tx * ts;
    float bTop = ty * ts;
    float bRight = (tx + tw) * ts;
    float bBottom = (ty + th) * ts;
    float clearance = ts * 2.5f;
    for (GoldMine g : goldMines) {
      if (g.amount <= 0) {
        continue;
      }
      float gLeft = g.tx * ts - clearance;
      float gTop = g.ty * ts - clearance;
      float gRight = (g.tx + 1) * ts + clearance;
      float gBottom = (g.ty + 1) * ts + clearance;
      boolean overlap = !(bRight <= gLeft || bLeft >= gRight || bBottom <= gTop || bTop >= gBottom);
      if (overlap) {
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

  void prepareBenchmarkBattlefield(String intensity, String troopProfile) {
    if (map == null) return;
    String level = intensity == null ? "heavy" : trim(intensity.toLowerCase());
    if (!"medium".equals(level) && !"heavy".equals(level) && !"extreme".equals(level)) {
      level = "heavy";
    }
    String profile = troopProfile == null ? "balanced" : trim(troopProfile.toLowerCase());
    if (!"balanced".equals(profile) && !"anti-armor".equals(profile) && !"swarm".equals(profile)) {
      profile = "balanced";
    }
    units.clear();
    buildings.clear();
    selectedUnits.clear();
    selectedBuilding = null;
    trainQueue.clear();
    buildSystem.queue.clear();
    buildSystem.currentJob = null;
    buildSystem.active = false;
    rockets.clear();
    muzzleFx.clear();
    deliveries.clear();
    orderMarkers.clear();
    gameEnded = false;
    gameResult = "";
    benchmarkScenarioActive = true;
    benchmarkOrderPulseTimer = 0.2;
    benchmarkIntensity = level;
    benchmarkTroopProfile = profile;
    benchmarkReinforceInterval = "medium".equals(level) ? 15.0 : ("extreme".equals(level) ? 7.5 : 11.0);
    benchmarkReinforceCount = "medium".equals(level) ? 6 : ("extreme".equals(level) ? 16 : 10);
    benchmarkReinforceTimer = benchmarkReinforceInterval;
    benchmarkWaveSerial = 0;
    benchmarkLastPlayerReinforce = 0;
    benchmarkLastEnemyReinforce = 0;
    benchmarkReinforceFlashTimer = 0;

    float ts = map.tileSize;
    float centerX = map.worldWidthPx() * 0.5;
    float centerY = map.worldHeightPx() * 0.5;
    PVector pAnchor = new PVector(ts * 7.5, centerY - ts * 3.0);
    PVector eAnchor = new PVector(map.worldWidthPx() - ts * 7.5, centerY + ts * 3.0);

    BuildingDef base = getBuildingDef("base");
    BuildingDef mine = getBuildingDef("mine");
    BuildingDef warehouse = getBuildingDef("warehouse");
    BuildingDef barracks = getBuildingDef("barracks");
    BuildingDef tower = getBuildingDef("tower");
    if (base == null) return;

    // Core bases.
    addInitialBuildingAt(base, Faction.PLAYER, pAnchor.x, pAnchor.y, 1);
    addInitialBuildingAt(base, Faction.ENEMY, eAnchor.x, eAnchor.y, 1);

    int ecoClusters = "medium".equals(level) ? 2 : ("extreme".equals(level) ? 4 : 3);
    int towerHalfLine = "medium".equals(level) ? 3 : ("extreme".equals(level) ? 7 : 4);
    int armyCols = "medium".equals(level) ? 6 : ("extreme".equals(level) ? 11 : 8);
    int armyRows = "medium".equals(level) ? 4 : ("extreme".equals(level) ? 7 : 5);
    float frontOffset = "medium".equals(level) ? 4.0 : ("extreme".equals(level) ? 2.0 : 3.0);

    // Economy and production clusters.
    for (int i = 0; i < ecoClusters; i++) {
      float off = (i - 1) * ts * 6.0;
      if (mine != null) {
        addInitialBuildingAt(mine, Faction.PLAYER, pAnchor.x + ts * 4.0, pAnchor.y + off, 1);
        addInitialBuildingAt(mine, Faction.ENEMY, eAnchor.x - ts * 4.0, eAnchor.y + off, 1);
      }
      if (warehouse != null) {
        addInitialBuildingAt(warehouse, Faction.PLAYER, pAnchor.x + ts * 1.5, pAnchor.y + off + ts * 2.0, 1);
        addInitialBuildingAt(warehouse, Faction.ENEMY, eAnchor.x - ts * 1.5, eAnchor.y + off - ts * 2.0, 1);
      }
      if (barracks != null) {
        addInitialBuildingAt(barracks, Faction.PLAYER, pAnchor.x + ts * 7.0, pAnchor.y + off, 1);
        addInitialBuildingAt(barracks, Faction.ENEMY, eAnchor.x - ts * 7.0, eAnchor.y + off, 1);
      }
    }

    // Forward tower line around the front.
    if (tower != null) {
      for (int i = -towerHalfLine; i <= towerHalfLine; i++) {
        float y = centerY + i * ts * 1.8;
        addInitialBuildingAt(tower, Faction.PLAYER, centerX - ts * 7.0, y, 0);
        addInitialBuildingAt(tower, Faction.ENEMY, centerX + ts * 7.0, y, 0);
      }
    }

    UnitDef miner = getUnitDef("miner");
    UnitDef rifle = getUnitDef("rifleman");
    UnitDef rocket = getUnitDef("rocketeer");
    spawnBenchmarkArmy(Faction.PLAYER, pAnchor, centerX, centerY, miner, rifle, rocket, armyCols, armyRows, frontOffset, profile);
    spawnBenchmarkArmy(Faction.ENEMY, eAnchor, centerX, centerY, miner, rifle, rocket, armyCols, armyRows, frontOffset, profile);

    refreshFactionCaps();
    resources = new ResourcePool(99999, creditCapForFaction(Faction.PLAYER));
    enemyResources = new ResourcePool(99999, creditCapForFaction(Faction.ENEMY));
  }

  void spawnBenchmarkArmy(Faction faction, PVector anchor, float centerX, float centerY, UnitDef miner, UnitDef rifle, UnitDef rocket, int cols, int rows, float frontOffsetTiles, String troopProfile) {
    float ts = map.tileSize;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        int idx = y * cols + x;
        UnitDef def = benchmarkUnitByIndex(idx, 0, faction, miner, rifle, rocket, false, troopProfile);
        if (def == null) continue;
        float ox = (x - cols * 0.5) * ts * 1.15;
        float oy = (y - rows * 0.5) * ts * 1.10;
        PVector desired = new PVector(anchor.x + ox, anchor.y + oy);
        PVector safe = findNearestOpenSlot(desired, new ArrayList<String>());
        Unit u = new Unit(safe.x, safe.y, faction, def);
        units.add(u);
      }
    }
    PVector pushTarget = new PVector(centerX + (faction == Faction.PLAYER ? ts * frontOffsetTiles : -ts * frontOffsetTiles), centerY);
    for (Unit u : units) {
      if (u.faction != faction || u.hp <= 0 || u.canHarvest) continue;
      u.issueAttackMove(pushTarget.copy(), this, false);
    }
  }

  void sustainBenchmarkFrontline(float dt) {
    if (!benchmarkScenarioActive || map == null) return;
    updateBenchmarkReinforcementTimer(dt);
    benchmarkOrderPulseTimer -= dt;
    if (benchmarkOrderPulseTimer > 0) return;
    benchmarkOrderPulseTimer = 1.2;

    PVector playerTarget = factionFrontlineTarget(Faction.PLAYER);
    PVector enemyTarget = factionFrontlineTarget(Faction.ENEMY);
    refreshBenchmarkFactionPush(Faction.PLAYER, playerTarget);
    refreshBenchmarkFactionPush(Faction.ENEMY, enemyTarget);
    if (benchmarkReinforceFlashTimer > 0) {
      refreshBenchmarkFactionPush(Faction.PLAYER, playerTarget);
      refreshBenchmarkFactionPush(Faction.ENEMY, enemyTarget);
    }
  }

  void updateBenchmarkReinforcementTimer(float dt) {
    if (!benchmarkScenarioActive || map == null) return;
    benchmarkReinforceTimer -= dt;
    benchmarkReinforceFlashTimer = max(0, benchmarkReinforceFlashTimer - dt);
    if (benchmarkReinforceTimer <= 0) {
      benchmarkReinforceTimer = benchmarkReinforceInterval;
      spawnBenchmarkReinforcements();
    }
  }

  PVector factionFrontlineTarget(Faction attacker) {
    Faction defender = attacker == Faction.PLAYER ? Faction.ENEMY : Faction.PLAYER;
    Building enemyBase = findMainBaseForFaction(defender);
    if (enemyBase != null) {
      return new PVector(enemyBase.pos.x + enemyBase.tileW * map.tileSize * 0.5, enemyBase.pos.y + enemyBase.tileH * map.tileSize * 0.5);
    }
    Unit bestUnit = null;
    float bestDist = 1e9;
    PVector fallback = new PVector(map.worldWidthPx() * 0.5, map.worldHeightPx() * 0.5);
    for (Unit u : units) {
      if (u.faction != defender || u.hp <= 0) continue;
      float d = PVector.dist(u.pos, fallback);
      if (d < bestDist) {
        bestDist = d;
        bestUnit = u;
      }
    }
    if (bestUnit != null) return bestUnit.pos.copy();
    return fallback;
  }

  void refreshBenchmarkFactionPush(Faction faction, PVector target) {
    if (target == null) return;
    for (Unit u : units) {
      if (u.faction != faction || u.hp <= 0 || u.canHarvest) continue;
      boolean hasPath = u.pathQueue != null && u.pathQueue.size() > 0;
      boolean needsOrder = u.orderType == UnitOrderType.NONE || !hasPath;
      if (!needsOrder && u.moveTarget != null && PVector.dist(u.moveTarget, target) > map.tileSize * 6.0) {
        needsOrder = true;
      }
      if (needsOrder) {
        u.issueAttackMove(target.copy(), this, false);
      }
    }
  }

  void spawnBenchmarkReinforcements() {
    UnitDef rifle = getUnitDef("rifleman");
    UnitDef rocket = getUnitDef("rocketeer");
    UnitDef miner = getUnitDef("miner");
    if (rifle == null && rocket == null) return;
    benchmarkWaveSerial++;
    int p = spawnFactionReinforcementWave(Faction.PLAYER, benchmarkReinforceCount, miner, rifle, rocket, benchmarkWaveSerial, benchmarkTroopProfile);
    int e = spawnFactionReinforcementWave(Faction.ENEMY, benchmarkReinforceCount, miner, rifle, rocket, benchmarkWaveSerial, benchmarkTroopProfile);
    if (p > 0) {
      addOrderMarker(factionFrontlineTarget(Faction.PLAYER), false);
      spawnDeliveryFx(factionFrontlineTarget(Faction.PLAYER), p);
    }
    if (e > 0) {
      addOrderMarker(factionFrontlineTarget(Faction.ENEMY), true);
      spawnDeliveryFx(factionFrontlineTarget(Faction.ENEMY), e);
    }
    benchmarkLastPlayerReinforce = p;
    benchmarkLastEnemyReinforce = e;
    benchmarkReinforceFlashTimer = 2.0;
    println("[BENCH] reinforcement wave player=" + p + " enemy=" + e + " intensity=" + benchmarkIntensity);
  }

  int spawnFactionReinforcementWave(Faction faction, int count, UnitDef miner, UnitDef rifle, UnitDef rocket, int waveSerial, String troopProfile) {
    Building base = findMainBaseForFaction(faction);
    if (base == null || count <= 0) return 0;
    float ts = map.tileSize;
    float baseCx = base.pos.x + base.tileW * ts * 0.5;
    float baseCy = base.pos.y + base.tileH * ts * 0.5;
    float side = faction == Faction.PLAYER ? -1.0 : 1.0;
    float backOffsetTiles = 8.5;
    float lateralOffsetTiles = (waveSerial % 2 == 0) ? 2.0 : -2.0;
    PVector anchor = new PVector(
      baseCx + side * ts * backOffsetTiles,
      baseCy + ts * lateralOffsetTiles
    );
    int cols = max(6, int(ceil(sqrt(count) * 1.35)));
    int spawned = 0;
    ArrayList<String> used = new ArrayList<String>();
    for (int i = 0; i < count; i++) {
      UnitDef def = benchmarkUnitByIndex(i, waveSerial, faction, miner, rifle, rocket, true, troopProfile);
      if (def == null) continue;
      int gx = i % cols;
      int gy = i / cols;
      float ox = (gx - (cols - 1) * 0.5) * ts * 1.15;
      float oy = gy * ts * 0.75;
      float rowShift = (gy % 2 == 0 ? -0.35 : 0.35) * ts;
      PVector desired = new PVector(anchor.x + side * ts * 0.8 + ox, anchor.y + rowShift + oy);
      PVector safe = findNearestOpenSlot(desired, used);
      used.add(tileKeyForWorld(safe));
      Unit u = new Unit(safe.x, safe.y, faction, def);
      units.add(u);
      spawned++;
    }
    if (spawned > 0) {
      refreshFactionCaps();
    }
    return spawned;
  }

  UnitDef benchmarkUnitByIndex(int idx, int waveSerial, Faction faction, UnitDef miner, UnitDef rifle, UnitDef rocket, boolean reinforce, String troopProfile) {
    // Use rotating composition templates so benchmark scenarios are explicit and reproducible.
    int seed = idx + waveSerial * 3 + (faction == Faction.ENEMY ? 2 : 0);
    int bucket = ((seed % 10) + 10) % 10;
    String profile = troopProfile == null ? "balanced" : troopProfile;
    if ("anti-armor".equals(profile)) {
      if (reinforce) {
        if (bucket <= 1 && rifle != null) return rifle;      // 20%
        if (bucket <= 7 && rocket != null) return rocket;     // 60%
        if (miner != null) return miner;                      // 20%
      } else {
        if (bucket <= 2 && rifle != null) return rifle;       // 30%
        if (bucket <= 7 && rocket != null) return rocket;     // 50%
        if (miner != null) return miner;                      // 20%
      }
      return rocket != null ? rocket : rifle;
    }
    if ("swarm".equals(profile)) {
      if (reinforce) {
        if (bucket <= 6 && rifle != null) return rifle;       // 70%
        if (bucket <= 7 && rocket != null) return rocket;     // 10%
        if (miner != null) return miner;                      // 20%
      } else {
        if (bucket <= 6 && rifle != null) return rifle;       // 70%
        if (bucket <= 8 && rocket != null) return rocket;     // 20%
        if (miner != null) return miner;                      // 10%
      }
      return rifle != null ? rifle : rocket;
    }
    // balanced
    if (reinforce) {
      // Reinforcements skew combat-heavy but still keep some miners.
      if (bucket <= 3 && rifle != null) return rifle;      // 40%
      if (bucket <= 7 && rocket != null) return rocket;     // 40%
      if (miner != null) return miner;                      // 20%
      return rifle != null ? rifle : rocket;
    }
    // Initial army: balanced blend.
    if (bucket <= 4 && rifle != null) return rifle;         // 50%
    if (bucket <= 7 && rocket != null) return rocket;       // 30%
    if (miner != null) return miner;                        // 20%
    return rifle != null ? rifle : rocket;
  }

  void loadUiSettings() {
    if (uiSettingsLoader == null) {
      uiSettingsLoader = new UiSettingsLoader();
    }
    uiSettingsLoader.apply(this);
  }

  void loadDefinitions() {
    if (definitionsLoader == null) {
      definitionsLoader = new DefinitionsLoader();
    }
    definitionsLoader.apply(this);
  }

  void loadMapResources() {
    goldMines.clear();
    JSONObject mapRoot = loadJSONObject(defaultMapJson);
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
    if (map != null) {
      map.syncGoldVeinWalkBlocking(goldMines);
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
    long frameStartNanos = System.nanoTime();
    if (map == null) {
      return;
    }
    map.syncGoldVeinWalkBlocking(goldMines);
    if (gameEnded) {
      int t0 = millis();
      input.update(dt);
      profileInputMs = lerp(profileInputMs, millis() - t0, 0.15);
      return;
    }
    int tInput = millis();
    input.update(dt);
    profileInputMs = lerp(profileInputMs, millis() - tInput, 0.15);
    if (scriptRuntime != null) {
      scriptRuntime.tick(dt, this);
    }
    int tBuild = millis();
    buildSystem.update(dt, buildings);
    effectsRuntime.updateOrderMarkers(this, dt);
    profileBuildMs = lerp(profileBuildMs, millis() - tBuild, 0.15);
    int tUnits = millis();
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
    profileUnitsMs = lerp(profileUnitsMs, millis() - tUnits, 0.15);
    int tFog = millis();
    if (fog != null) {
      fog.update(dt, this);
      fog.updateDisplayBlend(dt, this);
    }
    profileFogMs = lerp(profileFogMs, millis() - tFog, 0.15);
    int tCombat = millis();
    updateRockets(dt);
    updateMuzzleFx(dt);
    updateDeliveryFx(dt);
    updateTrainQueue(dt);
    updateTowerDefense(dt);
    profileCombatMs = lerp(profileCombatMs, millis() - tCombat, 0.15);
    int tAi = millis();
    if (enemyAi != null && (scriptRuntime == null || !scriptRuntime.ownsEnemyAi())) {
      enemyAi.update(dt, this);
    }
    profileAiMs = lerp(profileAiMs, millis() - tAi, 0.15);
    if (buildSystem.active && !selectedStructureOffersBuildMenu()) {
      buildSystem.active = false;
      buildSystem.lastFailReason = "";
      ui.clearBuildButtonState();
    }
    refreshFactionCaps();
    checkWinCondition();
    float frameMs = (System.nanoTime() - frameStartNanos) / 1000000.0;
    profileFrameMs = lerp(profileFrameMs, frameMs, 0.15);
    profilingSampleFrames++;
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
    if (debugShowScriptRegions) {
      renderDebugScriptRegions();
    }

    buildSystem.renderPreview(camera, map, buildings, canPlaceSelectedBuildInExploredArea(), this);
    input.renderSelectionBox();
    noClip();
    popMatrix();

    // Render order markers on top of fog/UI-world boundary so they are always visible.
    pushStyle();
    effectsRuntime.renderOrderMarkers(this);
    popStyle();

    renderBenchmarkWaveBanner();

    int tUi = millis();
    ui.render(this);
    profileUiMs = lerp(profileUiMs, millis() - tUi, 0.15);
    if (gameEnded) {
      renderGameEndOverlay();
    }
  }

  void renderBenchmarkWaveBanner() {
    if (!benchmarkScenarioActive || benchmarkReinforceFlashTimer <= 0) return;
    float k = constrain(benchmarkReinforceFlashTimer / 2.0, 0, 1);
    float bw = min(worldViewW * 0.72, 560);
    float bh = 52;
    float bx = worldViewW * 0.5 - bw * 0.5;
    float by = 22;
    pushStyle();
    noStroke();
    fill(10, 12, 16, 185 + 50 * k);
    rect(bx, by, bw, bh, 8);
    stroke(255, 205, 110, 180 + 60 * k);
    strokeWeight(2);
    noFill();
    rect(bx, by, bw, bh, 8);
    fill(255, 225, 140, 220 + 30 * k);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("REINFORCEMENT WAVE  P+" + benchmarkLastPlayerReinforce + "  E+" + benchmarkLastEnemyReinforce, bx + bw * 0.5, by + bh * 0.5);
    popStyle();
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

  // Command boundary methods used by input/UI/AI adapters.
  void setAttackMoveArmed(boolean armed) {
    attackMoveArmed = armed;
    orderLabel = attackMoveArmed ? tr("order.attackMoveArmed") : tr("order.attackMoveCancel");
  }

  void issueMoveCommand(PVector world, boolean queue) {
    if (selectedUnits.size() <= 0 || world == null) return;
    clearSelectedHarvestOrders();
    commandSystem.moveSelected(this, selectedUnits, world, queue);
    orderLabel = queue ? tr("order.queueMove") : tr("order.move");
    addOrderMarker(world.copy(), false);
    attackMoveArmed = false;
  }

  void issueAttackMoveCommand(PVector world, boolean queue) {
    if (selectedUnits.size() <= 0 || world == null) return;
    clearSelectedHarvestOrders();
    commandSystem.attackMoveSelected(this, selectedUnits, world, queue);
    orderLabel = tr("order.attackMove");
    addOrderMarker(world.copy(), true);
    attackMoveArmed = false;
  }

  void issueAttackUnitCommand(Unit target) {
    if (selectedUnits.size() <= 0 || target == null) return;
    clearSelectedHarvestOrders();
    commandSystem.attackSelected(selectedUnits, target);
    orderLabel = tr("order.attack");
    addOrderMarker(target.pos.copy(), true);
    attackMoveArmed = false;
  }

  void issueAttackBuildingCommand(Building target) {
    if (selectedUnits.size() <= 0 || target == null) return;
    clearSelectedHarvestOrders();
    commandSystem.attackSelectedBuilding(selectedUnits, target);
    PVector bc = new PVector(target.pos.x + target.tileW * map.tileSize * 0.5, target.pos.y + target.tileH * map.tileSize * 0.5);
    orderLabel = tr("order.attackBuilding");
    addOrderMarker(bc, true);
    attackMoveArmed = false;
  }

  void cancelBuildPlacement() {
    if (!buildSystem.active) return;
    buildSystem.active = false;
    buildSystem.lastFailReason = "";
    ui.clearBuildButtonState();
    orderLabel = tr("order.buildCancel");
  }

  void setSelectedBuildingRally(PVector world) {
    if (selectedBuilding == null || world == null) return;
    selectedBuilding.rallyPoint = world.copy();
    orderLabel = tr("order.rallySet");
    addOrderMarker(world.copy(), false);
  }

  String profileStepHzLabel() {
    return profileStepLabel;
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
        boolean aMine = a.anchoredDuringMining();
        boolean bMine = b.anchoredDuringMining();
        if (aMine && bMine) {
          continue;
        }
        delta.normalize();
        float gap = minD - d;
        if (aMine) {
          b.pos.add(PVector.mult(delta, gap));
          clampUnitToWorld(b);
        } else if (bMine) {
          a.pos.sub(PVector.mult(delta, gap));
          clampUnitToWorld(a);
        } else {
          boolean sameTeam = a.faction == b.faction;
          float baseIntensity = sameTeam ? 0.5 : 0.14;
          if (a.state == UnitState.ATTACKING || b.state == UnitState.ATTACKING) {
            baseIntensity *= sameTeam ? 0.5 : 0.45;
          }
          float push = gap * baseIntensity;
          PVector pushVec = PVector.mult(delta, push);
          a.pos.sub(pushVec);
          b.pos.add(pushVec);
          clampUnitToWorld(a);
          clampUnitToWorld(b);
        }
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

  void renderDebugScriptRegions() {
    if (scriptRuntime == null || !scriptRuntime.enabled) return;
    if (scriptRuntime.regionTracker == null || scriptRuntime.regionTracker.ctx == null) return;
    if (scriptRuntime.regionTracker.ctx.regionsById == null || scriptRuntime.regionTracker.ctx.regionsById.size() <= 0) return;
    pushStyle();
    textSize(max(10, 11 * camera.zoom));
    textAlign(LEFT, TOP);
    for (ScriptRegionDef r : scriptRuntime.regionTracker.ctx.regionsById.values()) {
      if (r == null) continue;
      float wx = r.x * map.tileSize;
      float wy = r.y * map.tileSize;
      float ww = r.w * map.tileSize;
      float wh = r.h * map.tileSize;
      PVector p = camera.worldToScreen(wx, wy);
      float sw = ww * camera.zoom;
      float sh = wh * camera.zoom;
      noStroke();
      fill(80, 210, 255, 28);
      rect(p.x, p.y, sw, sh);
      stroke(80, 225, 255, 220);
      strokeWeight(max(1, 1.6 * camera.zoom));
      noFill();
      rect(p.x, p.y, sw, sh);
      noStroke();
      fill(190, 245, 255, 245);
      text(r.id + " (" + r.w + "x" + r.h + ")", p.x + 4, p.y + 3);
    }
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
    return productionSystem.activeTrainJobFor(this, trainer);
  }

  void removeTrainingJobsForTrainer(Building trainer) {
    productionSystem.removeTrainingJobsForTrainer(this, trainer);
  }

  boolean isFirstTrainJobForTrainer(Building trainer, int queueIndex) {
    return productionSystem.isFirstTrainJobForTrainer(this, trainer, queueIndex);
  }

  boolean buildingHostsTrainQueue(Building b) {
    return productionSystem.buildingHostsTrainQueue(this, b);
  }

  void updateTrainQueue(float dt) {
    productionSystem.updateTrainQueue(this, dt);
  }

  void updateTowerDefense(float dt) {
    combatSystem.updateTowerDefense(this, dt);
  }

  PVector towerMuzzleWorld(Building b) {
    return combatSystem.towerMuzzleWorld(this, b);
  }

  Unit findTowerHostileUnitInRange(Building tower, float rangePx) {
    return combatSystem.findTowerHostileUnitInRange(this, tower, rangePx);
  }

  Building findTowerHostileBuildingInRange(Building tower, float rangePx) {
    return combatSystem.findTowerHostileBuildingInRange(this, tower, rangePx);
  }

  boolean tryTrainUnitForFaction(Faction faction, String unitId) {
    return productionSystem.tryTrainUnitForFaction(this, faction, unitId);
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
    Building bestDrop = null;
    float bestDDrop = 1e9;
    Building bestBase = null;
    float bestDBase = 1e9;
    for (Building b : buildings) {
      if (b.faction != faction || !b.completed) {
        continue;
      }
      BuildingDef def = getBuildingDef(b.buildingType);
      if (def == null) {
        continue;
      }
      float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
      float d = dist(from.x, from.y, cx, cy);
      if (def.isDropoff && d < bestDDrop) {
        bestDDrop = d;
        bestDrop = b;
      }
      if (def.isMainBase && d < bestDBase) {
        bestDBase = d;
        bestBase = b;
      }
    }
    return bestDrop != null ? bestDrop : bestBase;
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
    effectsRuntime.spawnMuzzleFx(this, shooter, targetPos);
  }

  void updateMuzzleFx(float dt) {
    effectsRuntime.updateMuzzleFx(this, dt);
  }

  void renderMuzzleFx() {
    effectsRuntime.renderMuzzleFx(this);
  }

  void spawnDeliveryFx(PVector worldPos, int amount) {
    effectsRuntime.spawnDeliveryFx(this, worldPos, amount);
  }

  void updateDeliveryFx(float dt) {
    effectsRuntime.updateDeliveryFx(this, dt);
  }

  void renderDeliveryFx() {
    effectsRuntime.renderDeliveryFx(this);
  }

  void spawnRocketProjectile(Unit from, Unit target, float dmg, float speed) {
    combatSystem.spawnRocketProjectile(this, from, target, dmg, speed);
  }

  void spawnRocketProjectile(Unit from, Building target, float dmg, float speed) {
    combatSystem.spawnRocketProjectile(this, from, target, dmg, speed);
  }

  void spawnRocketProjectileFromWorld(PVector worldStart, Unit target, float dmg, float speed) {
    combatSystem.spawnRocketProjectileFromWorld(this, worldStart, target, dmg, speed);
  }

  void spawnRocketProjectileFromWorld(PVector worldStart, Building target, float dmg, float speed) {
    combatSystem.spawnRocketProjectileFromWorld(this, worldStart, target, dmg, speed);
  }

  void updateRockets(float dt) {
    combatSystem.updateRockets(this, dt);
  }

  void renderRockets() {
    combatSystem.renderRockets(this);
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
    gameFlow.checkWinCondition(this);
  }

  void renderGameEndOverlay() {
    gameFlow.renderGameEndOverlay(this);
  }

  void handleGameEndOverlayClick(int mx, int my, int button) {
    gameFlow.handleGameEndOverlayClick(this, mx, my, button);
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
    return productionSystem.trainUnitAtSelectedBuilding(this, unitId);
  }

  PVector findSpawnForTrainer(Building trainer, float unitRadius) {
    return productionSystem.findSpawnForTrainer(this, trainer, unitRadius);
  }

  PVector findConfiguredSpawnNearBuilding(Building b, BuildingDef bdef, float unitRadius) {
    return productionSystem.findConfiguredSpawnNearBuilding(this, b, bdef, unitRadius);
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
    return productionSystem.queuedTrainCountForUnit(this, trainer, unitId);
  }

  float activeTrainProgressForUnit(Building trainer, String unitId) {
    return productionSystem.activeTrainProgressForUnit(this, trainer, unitId);
  }

  boolean cancelOneTrainJobForSelectedBuilding(String unitId) {
    return productionSystem.cancelOneTrainJobForSelectedBuilding(this, unitId);
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



