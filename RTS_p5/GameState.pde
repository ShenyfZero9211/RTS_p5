class GameState {
  int screenW;
  int screenH;
  int worldViewW;
  int sidePanelW;
  float sidePanelWidthRatio = 0.24;
  int sidePanelMinW = 300;
  int sidePanelMaxW = 460;

  TileMap map;
  Camera camera;
  UISystem ui;
  InputSystem input;
  CommandSystem commandSystem;
  BuildSystem buildSystem;
  Pathfinder pathfinder;
  UnitDef scoutDef;
  ArrayList<BuildingDef> buildingDefs = new ArrayList<BuildingDef>();
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

    camera = new Camera(worldViewW, screenH, map.worldWidthPx(), map.worldHeightPx());
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
    units.add(new Unit(220, 180, Faction.PLAYER, scoutDef));
    units.add(new Unit(260, 220, Faction.PLAYER, scoutDef));
    units.add(new Unit(320, 260, Faction.PLAYER, scoutDef));
    units.add(new Unit(540, 400, Faction.ENEMY, scoutDef));
    Unit wanderer = new Unit(640, 300, Faction.NEUTRAL, scoutDef);
    wanderer.aiPatrolPoints = new ArrayList<PVector>();
    wanderer.aiPatrolPoints.add(new PVector(520, 220));
    wanderer.aiPatrolPoints.add(new PVector(720, 380));
    wanderer.aiPatrolPoints.add(new PVector(560, 480));
    units.add(wanderer);

    BuildingDef outpost = getBuildingDef("outpost");
    if (outpost == null && buildingDefs.size() > 0) {
      outpost = buildingDefs.get(0);
    }
    if (outpost == null) {
      return;
    }

    Building p = new Building(400, 280, outpost.tileW, outpost.tileH, Faction.PLAYER, outpost);
    p.completed = true;
    p.buildProgress = p.buildTime;
    buildings.add(p);

    Building e = new Building(760, 520, outpost.tileW, outpost.tileH, Faction.ENEMY, outpost);
    e.completed = true;
    e.buildProgress = e.buildTime;
    buildings.add(e);
  }

  void loadUiSettings() {
    JSONObject root = loadJSONObject("ui.json");
    if (root == null) {
      return;
    }
    sidePanelWidthRatio = root.getFloat("sidePanelWidthRatio", sidePanelWidthRatio);
    sidePanelMinW = root.getInt("sidePanelMinW", sidePanelMinW);
    sidePanelMaxW = root.getInt("sidePanelMaxW", sidePanelMaxW);
    sidePanelWidthRatio = constrain(sidePanelWidthRatio, 0.12, 0.45);
    sidePanelMinW = max(180, sidePanelMinW);
    sidePanelMaxW = max(sidePanelMinW, sidePanelMaxW);
  }

  void loadDefinitions() {
    scoutDef = new UnitDef();
    scoutDef.id = "scout";
    scoutDef.speed = 120;
    scoutDef.radius = 11;
    scoutDef.hp = 100;

    BuildingDef defaultOutpost = new BuildingDef();
    defaultOutpost.id = "outpost";
    defaultOutpost.tileW = 2;
    defaultOutpost.tileH = 2;
    defaultOutpost.buildTime = 3.0;
    defaultOutpost.cost = 120;
    buildingDefs.add(defaultOutpost);

    JSONObject unitRoot = loadJSONObject("units.json");
    if (unitRoot != null) {
      JSONArray arr = unitRoot.getJSONArray("units");
      if (arr != null && arr.size() > 0) {
        JSONObject o = arr.getJSONObject(0);
        scoutDef.id = o.getString("id", scoutDef.id);
        scoutDef.speed = o.getFloat("speed", scoutDef.speed);
        scoutDef.radius = o.getFloat("radius", scoutDef.radius);
        scoutDef.hp = o.getInt("hp", scoutDef.hp);
      }
    }

    JSONObject buildingRoot = loadJSONObject("buildings.json");
    if (buildingRoot != null) {
      JSONArray arr = buildingRoot.getJSONArray("buildings");
      if (arr != null && arr.size() > 0) {
        buildingDefs.clear();
        for (int i = 0; i < arr.size(); i++) {
          JSONObject o = arr.getJSONObject(i);
          BuildingDef def = new BuildingDef();
          def.id = o.getString("id", "building_" + i);
          def.tileW = o.getInt("tileW", 2);
          def.tileH = o.getInt("tileH", 2);
          def.buildTime = o.getFloat("buildTime", 3.0);
          def.cost = o.getInt("cost", 120);
          buildingDefs.add(def);
        }
      }
    }
  }

  BuildingDef getBuildingDef(String id) {
    for (BuildingDef def : buildingDefs) {
      if (def.id.equals(id)) {
        return def;
      }
    }
    return null;
  }

  void update(float dt) {
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
    applyUnitSeparation();
    for (int i = 0; i < units.size(); i++) {
      resolveUnitAgainstSolids(units.get(i));
    }
  }

  void render() {
    background(0);
    pushMatrix();
    clip(0, 0, worldViewW, screenH);
    map.render(camera, worldViewW, screenH);

    for (Building b : buildings) {
      b.render(camera, map.tileSize);
    }

    for (Unit u : units) {
      u.render(camera);
    }
    for (OrderMarker m : orderMarkers) {
      m.render(camera);
    }

    if (debugShowPaths) {
      renderDebugPaths();
    }

    buildSystem.renderPreview(camera, map, buildings);
    input.renderSelectionBox();
    noClip();
    popMatrix();

    ui.render(this);
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
