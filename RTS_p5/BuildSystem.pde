class BuildSystem {
  boolean active = false;
  int previewTileX;
  int previewTileY;
  ArrayList<BuildingDef> defs;
  int selectedIndex = 0;
  ArrayList<BuildJob> queue = new ArrayList<BuildJob>();
  BuildJob currentJob;
  String lastFailReason = "";

  BuildSystem(ArrayList<BuildingDef> defs) {
    this.defs = defs;
  }

  void toggle() {
    active = !active;
  }

  void updatePreview(PVector worldPos, TileMap map) {
    previewTileX = map.toTileX(worldPos.x);
    previewTileY = map.toTileY(worldPos.y);
  }

  BuildingDef selectedDef() {
    if (defs == null || defs.size() == 0) {
      return null;
    }
    selectedIndex = constrain(selectedIndex, 0, defs.size() - 1);
    return defs.get(selectedIndex);
  }

  void selectIndex(int idx) {
    if (defs == null || defs.size() == 0) {
      return;
    }
    selectedIndex = constrain(idx, 0, defs.size() - 1);
  }

  int selectedCost() {
    BuildingDef def = selectedDef();
    return def == null ? 0 : def.cost;
  }

  boolean canPlace(TileMap map, ArrayList<Building> buildings) {
    BuildingDef def = selectedDef();
    if (def == null) {
      return false;
    }
    for (int y = 0; y < def.tileH; y++) {
      for (int x = 0; x < def.tileW; x++) {
        int tx = previewTileX + x;
        int ty = previewTileY + y;
        if (map.isBlockedTile(tx, ty)) {
          return false;
        }
      }
    }
    float worldX = previewTileX * map.tileSize;
    float worldY = previewTileY * map.tileSize;
    for (Building b : buildings) {
      if (rectOverlap(
        worldX, worldY, def.tileW * map.tileSize, def.tileH * map.tileSize,
        b.pos.x, b.pos.y, b.tileW * map.tileSize, b.tileH * map.tileSize
        )) {
        return false;
      }
    }
    return true;
  }

  boolean queueBuildIfValid(TileMap map, ArrayList<Building> buildings, Faction faction, ResourcePool resources) {
    BuildingDef def = selectedDef();
    if (def == null) {
      lastFailReason = "No blueprint";
      return false;
    }
    if (!resources.canAfford(def.cost)) {
      lastFailReason = "Not enough credits";
      return false;
    }
    if (!canPlace(map, buildings)) {
      lastFailReason = "Invalid placement";
      return false;
    }
    if (!resources.spend(def.cost)) {
      lastFailReason = "Spend failed";
      return false;
    }
    float worldX = previewTileX * map.tileSize;
    float worldY = previewTileY * map.tileSize;
    BuildJob job = new BuildJob(worldX, worldY, faction, def);
    queue.add(job);
    lastFailReason = "";
    return true;
  }

  void update(float dt, ArrayList<Building> buildings) {
    if (currentJob == null && queue.size() > 0) {
      currentJob = queue.remove(0);
      Building underConstruction = new Building(
        currentJob.worldX, currentJob.worldY,
        currentJob.def.tileW, currentJob.def.tileH,
        currentJob.faction, currentJob.def
        );
      underConstruction.completed = false;
      underConstruction.buildProgress = 0;
      underConstruction.buildTime = currentJob.def.buildTime;
      buildings.add(underConstruction);
      currentJob.target = underConstruction;
    }

    if (currentJob == null || currentJob.target == null) {
      return;
    }

    currentJob.target.buildProgress += dt;
    if (currentJob.target.buildProgress >= currentJob.target.buildTime) {
      currentJob.target.buildProgress = currentJob.target.buildTime;
      currentJob.target.completed = true;
      currentJob = null;
    }
  }

  int queuedCount() {
    return queue.size() + (currentJob == null ? 0 : 1);
  }

  float currentProgress01() {
    if (currentJob == null || currentJob.target == null) {
      return 0;
    }
    return constrain(currentJob.target.buildProgress / currentJob.target.buildTime, 0, 1);
  }

  void renderPreview(Camera camera, TileMap map, ArrayList<Building> buildings) {
    if (!active) {
      return;
    }
    boolean ok = canPlace(map, buildings);
    PVector screen = camera.worldToScreen(previewTileX * map.tileSize, previewTileY * map.tileSize);
    noFill();
    strokeWeight(2);
    if (ok) {
      stroke(60, 255, 120);
    } else {
      stroke(255, 80, 80);
    }
    BuildingDef def = selectedDef();
    if (def != null) {
      rect(screen.x, screen.y, def.tileW * map.tileSize * camera.zoom, def.tileH * map.tileSize * camera.zoom);
    }
  }

  boolean rectOverlap(float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }
}

class BuildJob {
  float worldX;
  float worldY;
  Faction faction;
  BuildingDef def;
  Building target;

  BuildJob(float worldX, float worldY, Faction faction, BuildingDef def) {
    this.worldX = worldX;
    this.worldY = worldY;
    this.faction = faction;
    this.def = def;
  }
}
