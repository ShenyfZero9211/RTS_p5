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
  int playerStartCredits = 100;
  int enemyStartCredits = 100;
  EnemyAiController enemyAi;
  String orderLabel = "None";
  boolean attackMoveArmed = false;
  boolean hardCursorLock = false;
  CursorLock cursorLock;
  ArrayList<OrderMarker> orderMarkers = new ArrayList<OrderMarker>();
  boolean debugShowPaths = false;

  ArrayList<Unit> units = new ArrayList<Unit>();
  ArrayList<Building> buildings = new ArrayList<Building>();
  ArrayList<Unit> selectedUnits = new ArrayList<Unit>();
  Building selectedBuilding;
  Faction activeFaction = Faction.PLAYER;
  String gameResult = "";
  boolean gameEnded = false;

  GameState(int screenW, int screenH) {
    this.screenW = screenW;
    this.screenH = screenH;
    loadUiSettings();
    this.sidePanelW = int(constrain(screenW * sidePanelWidthRatio, sidePanelMinW, sidePanelMaxW));
    this.worldViewW = screenW - sidePanelW;

    map = new TileMap();
    if (!map.loadFromJson("map_test.json")) {
      println("Failed to load map_test.json");
      exit();
      return;
    }
    loadMapResources();

    camera = new Camera(worldViewW, screenH, map.worldWidthPx(), map.worldHeightPx());
    camera.wheelZoomStep = wheelZoomStep;
    camera.speed = edgeScrollSpeed;
    fog = new FogSystem(map);
    ui = new UISystem(worldViewW, screenH);
    commandSystem = new CommandSystem();
    loadDefinitions();
    buildSystem = new BuildSystem(buildingDefs);
    resources = new ResourcePool(playerStartCredits);
    enemyResources = new ResourcePool(enemyStartCredits);
    cursorLock = new CursorLock();
    pathfinder = new Pathfinder(map);
    input = new InputSystem(this);
    enemyAi = new EnemyAiController();

    seedDemoEntities();
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
    BuildingDef depot = getBuildingDef("depot");
    BuildingDef barracks = getBuildingDef("barracks");

    Building p = addInitialBuildingAt(base, Faction.PLAYER, playerBasePos.x, playerBasePos.y, 1);
    Building e = addInitialBuildingAt(base, Faction.ENEMY, enemyBasePos.x, enemyBasePos.y, 1);

    if (mine != null) {
      addInitialBuildingAt(mine, Faction.PLAYER, playerBasePos.x + ts * 5.0, playerBasePos.y + ts * 0.4, 1);
      addInitialBuildingAt(mine, Faction.ENEMY, enemyBasePos.x - ts * 5.2, enemyBasePos.y - ts * 0.6, 1);
    }
    if (depot != null) {
      addInitialBuildingAt(depot, Faction.PLAYER, playerBasePos.x + ts * 0.2, playerBasePos.y + ts * 5.6, 1);
      addInitialBuildingAt(depot, Faction.ENEMY, enemyBasePos.x - ts * 0.4, enemyBasePos.y - ts * 5.8, 1);
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
          def.cost = o.getInt("cost", 60);
          def.trainTime = o.getFloat("trainTime", 2.0);
          def.sightRange = o.getFloat("sightRange", 220);
          def.usesProjectile = o.getBoolean("usesProjectile", false);
          def.projectileSpeed = o.getFloat("projectileSpeed", 260);
          def.canHarvest = o.getBoolean("canHarvest", false);
          def.harvestAmount = o.getInt("harvestAmount", 20);
          def.harvestTime = o.getFloat("harvestTime", 1.2);
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
    if (gameEnded) {
      input.update(dt);
      return;
    }
    input.update(dt);
    if (fog != null) {
      fog.update(dt, this);
    }
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
        buildings.remove(i);
      }
    }
    applyUnitSeparation();
    for (int i = 0; i < units.size(); i++) {
      resolveUnitAgainstSolids(units.get(i));
    }
    updateRockets(dt);
    updateMuzzleFx(dt);
    updateDeliveryFx(dt);
    if (enemyAi != null) {
      enemyAi.update(dt, this);
    }
    checkWinCondition();
  }

  void render() {
    background(0);
    pushMatrix();
    clip(0, 0, worldViewW, screenH);
    map.render(camera, worldViewW, screenH);
    renderGoldMines();

    for (Building b : buildings) {
      if (isBuildingVisibleToPlayer(b)) {
        b.render(camera, map.tileSize);
      }
    }

    for (Unit u : units) {
      if (isUnitVisibleToPlayer(u)) {
        u.render(camera);
      }
    }
    for (OrderMarker m : orderMarkers) {
      m.render(camera);
    }
    renderRockets();
    renderMuzzleFx();
    renderDeliveryFx();

    if (fog != null) {
      fog.renderOverlay(this);
    }

    if (debugShowPaths) {
      renderDebugPaths();
    }

    buildSystem.renderPreview(camera, map, buildings);
    input.renderSelectionBox();
    noClip();
    popMatrix();

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

  Unit findHostileInRange(Unit self, float radiusPx) {
    Unit best = null;
    float bestScore = 1e9;
    for (Unit u : units) {
      if (u == self || u.hp <= 0 || !isHostile(self.faction, u.faction)) {
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
      orderLabel = "Harvest";
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

  boolean tryTrainUnitForFaction(Faction faction, String unitId) {
    UnitDef def = getUnitDef(unitId);
    if (def == null) {
      return false;
    }
    ResourcePool pool = resourcePoolForFaction(faction);
    if (pool == null || !pool.canAfford(def.cost)) {
      return false;
    }
    Building trainer = null;
    for (Building b : buildings) {
      if (b.faction != faction || !b.completed) {
        continue;
      }
      BuildingDef bdef = getBuildingDef(b.buildingType);
      if (bdef == null || !bdef.canTrainUnits || bdef.trainableUnits == null) {
        continue;
      }
      for (int i = 0; i < bdef.trainableUnits.length; i++) {
        if (bdef.trainableUnits[i].equals(unitId)) {
          trainer = b;
          break;
        }
      }
      if (trainer != null) {
        break;
      }
    }
    if (trainer == null) {
      return false;
    }
    if (!pool.spend(def.cost)) {
      return false;
    }
    PVector spawn = findSpawnAroundBuilding(trainer);
    units.add(new Unit(spawn.x, spawn.y, faction, def));
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
      // Only mining facility accepts mineral drop-off.
      if (def == null || !def.id.equals("mine")) {
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
    if (gameEnded) {
      return;
    }
    boolean playerAlive = countFactionUnits(Faction.PLAYER) + countFactionBuildings(Faction.PLAYER) > 0;
    boolean enemyAlive = countFactionUnits(Faction.ENEMY) + countFactionBuildings(Faction.ENEMY) > 0;
    if (!playerAlive || !enemyAlive) {
      gameEnded = true;
      gameResult = playerAlive ? "BLUE WINS" : "RED WINS";
      orderLabel = "GameOver";
      buildSystem.active = false;
    }
  }

  void renderGameEndOverlay() {
    fill(0, 0, 0, 140);
    rect(0, 0, worldViewW, screenH);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(36);
    text(gameResult, worldViewW * 0.5, screenH * 0.48);
    textSize(16);
    text("All units and buildings destroyed", worldViewW * 0.5, screenH * 0.55);
    textAlign(LEFT, TOP);
  }

  boolean trainUnitAtSelectedBuilding(String unitId) {
    if (gameEnded) {
      return false;
    }
    if (selectedUnits.size() > 0) {
      return false;
    }
    if (buildings.size() == 0) {
      return false;
    }
    UnitDef def = getUnitDef(unitId);
    if (def == null) {
      return false;
    }
    if (!resources.canAfford(def.cost)) {
      orderLabel = "NeedCredits";
      return false;
    }
    Building barracks = null;
    for (Building b : buildings) {
      if (b.faction != activeFaction || !b.completed) {
        continue;
      }
      if (b.buildingType.equals("barracks")) {
        barracks = b;
        break;
      }
    }
    if (barracks == null) {
      orderLabel = "NeedBarracks";
      return false;
    }
    if (!resources.spend(def.cost)) {
      return false;
    }
    PVector spawn = findSpawnAroundBuilding(barracks);
    units.add(new Unit(spawn.x, spawn.y, activeFaction, def));
    orderLabel = "Train:" + unitId;
    return true;
  }

  PVector findSpawnAroundBuilding(Building b) {
    float cx = b.pos.x + b.tileW * map.tileSize * 0.5;
    float cy = b.pos.y + b.tileH * map.tileSize * 0.5;
    PVector seed = findNearestOpenSlot(new PVector(cx + map.tileSize * 1.2, cy + map.tileSize * 0.6), new ArrayList<String>());
    return seed;
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

  void update(float dt, GameState gs) {
    decisionTimer -= dt;
    attackTimer += dt;
    if (decisionTimer > 0) {
      return;
    }
    decisionTimer = gs.enemyAiDecisionInterval;
    tick(gs);
  }

  void tick(GameState gs) {
    int enemyMines = gs.countFactionBuildingsByType(Faction.ENEMY, "mine", false);
    int enemyDepots = gs.countFactionBuildingsByType(Faction.ENEMY, "depot", false);
    int enemyBarracks = gs.countFactionBuildingsByType(Faction.ENEMY, "barracks", false);
    int enemyMiners = gs.countFactionUnitsByType(Faction.ENEMY, "miner");
    int enemyCombat = gs.countFactionCombatUnits(Faction.ENEMY);

    float enemyArmyValue = gs.armyValueForFaction(Faction.ENEMY);
    float playerArmyValue = max(1, gs.armyValueForFaction(Faction.PLAYER));
    lastEnemyArmyValue = enemyArmyValue;

    if (enemyMines < 1 || enemyMiners < gs.enemyAiMinersMin) {
      phase = ECO;
    } else if (enemyDepots < 1 || enemyBarracks < 1) {
      phase = TECH;
    } else if (enemyCombat < gs.enemyAiAttackMinArmy) {
      phase = MUSTER;
    } else {
      phase = ATTACK;
    }

    runEconomy(gs, enemyMines, enemyMiners);
    runTech(gs, enemyDepots, enemyBarracks);
    runProduction(gs, enemyMiners, enemyCombat);

    boolean readyByTime = attackTimer >= gs.enemyAiAttackInterval;
    boolean readyByAdv = enemyArmyValue >= playerArmyValue * gs.enemyAiAttackAdvantage;
    boolean readyByCount = enemyCombat >= gs.enemyAiAttackMinArmy + 2;
    if (phase == ATTACK && (readyByTime || readyByAdv || readyByCount)) {
      launchAttackWave(gs);
      attackTimer = 0;
    } else {
      rallyArmy(gs);
    }
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

  void runTech(GameState gs, int enemyDepots, int enemyBarracks) {
    Building base = gs.findMainBaseForFaction(Faction.ENEMY);
    PVector anchor = base == null ? new PVector(gs.map.worldWidthPx() * 0.75, gs.map.worldHeightPx() * 0.75) : base.pos.copy();
    if (enemyDepots < 1) {
      if (gs.tryQueueBuildingForFaction(Faction.ENEMY, "depot", PVector.add(anchor, new PVector(-gs.map.tileSize * 2.0, -gs.map.tileSize * 4.0)))) {
        lastAction = "build:depot";
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
    // Fallback production.
    if (!gs.tryTrainUnitForFaction(Faction.ENEMY, "rifleman")) {
      gs.tryTrainUnitForFaction(Faction.ENEMY, "rocketeer");
    }
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

  void launchAttackWave(GameState gs) {
    waveSerial++;
    PVector target = gs.playerAttackTarget();
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
  float damage;
  float speed;
  float ttl = 3.0;

  RocketProjectile(PVector pos, Unit target, float damage, float speed) {
    this.pos = pos.copy();
    this.target = target;
    this.damage = damage;
    this.speed = speed;
  }

  boolean update(float dt) {
    ttl -= dt;
    if (ttl <= 0 || target == null || target.hp <= 0) {
      return true;
    }
    PVector delta = PVector.sub(target.pos, pos);
    float dist = delta.mag();
    if (dist < 8) {
      target.hp -= int(damage);
      return true;
    }
    delta.normalize().mult(speed * dt);
    if (delta.mag() >= dist) {
      pos.set(target.pos);
      target.hp -= int(damage);
      return true;
    }
    pos.add(delta);
    return false;
  }

  void render(Camera camera) {
    if (target == null) {
      return;
    }
    PVector s = camera.worldToScreen(pos.x, pos.y);
    PVector dir = PVector.sub(target.pos, pos);
    if (dir.magSq() < 1e-6) {
      dir.set(1, 0);
    } else {
      dir.normalize();
    }
    float tailLen = max(10, 24 * camera.zoom);
    PVector tailWorld = PVector.sub(pos, PVector.mult(dir, tailLen));
    PVector tail = camera.worldToScreen(tailWorld.x, tailWorld.y);
    stroke(255, 140, 90, 190);
    strokeWeight(max(1, 1.6 * camera.zoom));
    line(tail.x, tail.y, s.x, s.y);
    noStroke();
    fill(255, 210, 140);
    ellipse(s.x, s.y, 6 * camera.zoom, 6 * camera.zoom);
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
