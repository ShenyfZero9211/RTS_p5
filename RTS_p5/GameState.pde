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
  String orderLabel = "None";
  boolean attackMoveArmed = false;
  boolean hardCursorLock = false;
  CursorLock cursorLock;
  ArrayList<OrderMarker> orderMarkers = new ArrayList<OrderMarker>();
  boolean debugShowPaths = false;

  ArrayList<Unit> units = new ArrayList<Unit>();
  ArrayList<Building> buildings = new ArrayList<Building>();
  ArrayList<Unit> selectedUnits = new ArrayList<Unit>();
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
    resources = new ResourcePool(1000);
    cursorLock = new CursorLock();
    pathfinder = new Pathfinder(map);
    input = new InputSystem(this);

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
    applyUnitSeparation();
    for (int i = 0; i < units.size(); i++) {
      resolveUnitAgainstSolids(units.get(i));
    }
    updateRockets(dt);
    updateMuzzleFx(dt);
    updateDeliveryFx(dt);
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
    strokeWeight(max(1, camera.zoom * 0.12));
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
      if (b.faction == f) {
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
    PVector t = camera.worldToScreen(target.pos.x, target.pos.y);
    stroke(255, 140, 90, 180);
    strokeWeight(max(1, 1.6 * camera.zoom));
    line(s.x, s.y, t.x, t.y);
    noStroke();
    fill(255, 200, 120);
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
