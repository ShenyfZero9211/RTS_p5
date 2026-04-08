class FogSystem {
  boolean[][] explored;
  boolean[][] visible;
  boolean[][] visibleWork;
  float updateTimer = 0;
  boolean rebuilding = false;
  int rebuildCursor = 0;
  ArrayList<FogVisionSource> activeSources = new ArrayList<FogVisionSource>();
  ArrayList<FogVisionSource> lastSources = new ArrayList<FogVisionSource>();
  int dirtyMinX = 0;
  int dirtyMinY = 0;
  int dirtyMaxX = -1;
  int dirtyMaxY = -1;
  float adaptiveIntervalCached = 0.10;

  FogSystem(TileMap map) {
    explored = new boolean[map.heightTiles][map.widthTiles];
    visible = new boolean[map.heightTiles][map.widthTiles];
    visibleWork = new boolean[map.heightTiles][map.widthTiles];
  }

  void update(float dt, GameState gs) {
    if (!gs.fogEnabled) {
      return;
    }
    if (!rebuilding) {
      updateTimer -= dt;
      if (updateTimer > 0) {
        return;
      }
      beginRebuild(gs);
      if (!rebuilding) {
        return;
      }
    }
    processRebuildBatch(gs);
  }

  void beginRebuild(GameState gs) {
    TileMap map = gs.map;
    adaptiveIntervalCached = computeAdaptiveInterval(gs);
    activeSources.clear();
    collectVisionSources(gs, activeSources);

    dirtyMinX = map.widthTiles;
    dirtyMinY = map.heightTiles;
    dirtyMaxX = -1;
    dirtyMaxY = -1;
    for (FogVisionSource s : lastSources) {
      expandDirty(s.minTx, s.minTy, s.maxTx, s.maxTy, map);
    }
    for (FogVisionSource s : activeSources) {
      expandDirty(s.minTx, s.minTy, s.maxTx, s.maxTy, map);
    }

    if (dirtyMaxX < dirtyMinX || dirtyMaxY < dirtyMinY) {
      updateTimer = adaptiveIntervalCached;
      rebuilding = false;
      return;
    }

    // Keep non-dirty regions untouched; only rebuild changed regions.
    for (int ty = dirtyMinY; ty <= dirtyMaxY; ty++) {
      for (int tx = dirtyMinX; tx <= dirtyMaxX; tx++) {
        visibleWork[ty][tx] = false;
      }
    }

    rebuildCursor = 0;
    rebuilding = true;
  }

  void processRebuildBatch(GameState gs) {
    int batch = max(1, gs.fogBatchSourcesPerFrame);
    int processed = 0;
    TileMap map = gs.map;
    while (processed < batch && rebuildCursor < activeSources.size()) {
      FogVisionSource s = activeSources.get(rebuildCursor++);
      markCircleSource(s, map);
      processed++;
    }

    if (rebuildCursor < activeSources.size()) {
      return;
    }

    for (int ty = dirtyMinY; ty <= dirtyMaxY; ty++) {
      for (int tx = dirtyMinX; tx <= dirtyMaxX; tx++) {
        if (visibleWork[ty][tx]) {
          explored[ty][tx] = true;
        }
      }
    }

    boolean[][] tmp = visible;
    visible = visibleWork;
    visibleWork = tmp;

    lastSources.clear();
    for (FogVisionSource s : activeSources) {
      lastSources.add(s.copy());
    }
    rebuilding = false;
    updateTimer = adaptiveIntervalCached;
  }

  float computeAdaptiveInterval(GameState gs) {
    float base = gs.fogUpdateInterval;
    if (!gs.fogAutoAdaptiveInterval) {
      return base;
    }
    int sourceCount = countVisionSources(gs);
    int extra = max(0, sourceCount - gs.fogAutoAdaptiveThreshold);
    float interval = base + extra * gs.fogAutoAdaptiveStep;
    return min(interval, gs.fogAutoAdaptiveMaxInterval);
  }

  int countVisionSources(GameState gs) {
    int c = 0;
    for (Unit u : gs.units) {
      if (u.hp > 0 && u.faction == Faction.PLAYER) {
        c++;
      }
    }
    for (Building b : gs.buildings) {
      if (b.faction == Faction.PLAYER) {
        c++;
      }
    }
    return c;
  }

  void collectVisionSources(GameState gs, ArrayList<FogVisionSource> out) {
    TileMap map = gs.map;
    for (Unit u : gs.units) {
      if (u.hp <= 0 || u.faction != Faction.PLAYER) {
        continue;
      }
      out.add(new FogVisionSource(u.pos.copy(), max(70, u.sightRange), map));
    }
    for (Building b : gs.buildings) {
      if (b.faction != Faction.PLAYER) {
        continue;
      }
      float r = max(b.tileW, b.tileH) * map.tileSize * 0.95 + 80;
      PVector c = new PVector(b.pos.x + b.tileW * map.tileSize * 0.5, b.pos.y + b.tileH * map.tileSize * 0.5);
      out.add(new FogVisionSource(c, r, map));
    }
  }

  void expandDirty(int minTx, int minTy, int maxTx, int maxTy, TileMap map) {
    minTx = constrain(minTx, 0, map.widthTiles - 1);
    minTy = constrain(minTy, 0, map.heightTiles - 1);
    maxTx = constrain(maxTx, 0, map.widthTiles - 1);
    maxTy = constrain(maxTy, 0, map.heightTiles - 1);
    dirtyMinX = min(dirtyMinX, minTx);
    dirtyMinY = min(dirtyMinY, minTy);
    dirtyMaxX = max(dirtyMaxX, maxTx);
    dirtyMaxY = max(dirtyMaxY, maxTy);
  }

  void markCircleSource(FogVisionSource s, TileMap map) {
    float r2 = s.radiusPx * s.radiusPx;
    int minTx = max(dirtyMinX, s.minTx);
    int maxTx = min(dirtyMaxX, s.maxTx);
    int minTy = max(dirtyMinY, s.minTy);
    int maxTy = min(dirtyMaxY, s.maxTy);
    for (int ty = minTy; ty <= maxTy; ty++) {
      for (int tx = minTx; tx <= maxTx; tx++) {
        float cx = (tx + 0.5) * map.tileSize;
        float cy = (ty + 0.5) * map.tileSize;
        float dx = cx - s.center.x;
        float dy = cy - s.center.y;
        if (dx * dx + dy * dy <= r2) {
          visibleWork[ty][tx] = true;
        }
      }
    }
  }

  void renderOverlay(GameState gs) {
    if (!gs.fogEnabled) {
      return;
    }
    TileMap map = gs.map;
    Camera camera = gs.camera;
    int startX = max(0, int(camera.x / map.tileSize));
    int startY = max(0, int(camera.y / map.tileSize));
    int endX = min(map.widthTiles - 1, int((camera.x + camera.visibleWorldW()) / map.tileSize) + 1);
    int endY = min(map.heightTiles - 1, int((camera.y + camera.visibleWorldH()) / map.tileSize) + 1);

    noStroke();
    for (int ty = startY; ty <= endY; ty++) {
      for (int tx = startX; tx <= endX; tx++) {
        int alpha = -1;
        if (!explored[ty][tx]) {
          alpha = gs.fogUnexploredAlpha;
        } else if (!visible[ty][tx]) {
          alpha = gs.fogExploredAlpha;
          if (gs.fogSoftEdges) {
            alpha = int(alpha * edgeFadeFactor(tx, ty, gs.map, gs.fogEdgeRadius, gs.fogEdgeStrength));
          }
        }
        if (alpha <= 0) {
          continue;
        }
        fill(0, 0, 0, alpha);
        float sx = (tx * map.tileSize - camera.x) * camera.zoom;
        float sy = (ty * map.tileSize - camera.y) * camera.zoom;
        float s = map.tileSize * camera.zoom;
        rect(sx, sy, s, s);
      }
    }
  }

  boolean isWorldVisible(TileMap map, float wx, float wy) {
    int tx = map.toTileX(wx);
    int ty = map.toTileY(wy);
    if (tx < 0 || ty < 0 || tx >= map.widthTiles || ty >= map.heightTiles) {
      return false;
    }
    return visible[ty][tx];
  }

  boolean isWorldExplored(TileMap map, float wx, float wy) {
    int tx = map.toTileX(wx);
    int ty = map.toTileY(wy);
    if (tx < 0 || ty < 0 || tx >= map.widthTiles || ty >= map.heightTiles) {
      return false;
    }
    return explored[ty][tx];
  }

  float edgeFadeFactor(int tx, int ty, TileMap map, int r, float strength) {
    int visibleNeighbors = 0;
    int total = 0;
    for (int oy = -r; oy <= r; oy++) {
      for (int ox = -r; ox <= r; ox++) {
        if (ox == 0 && oy == 0) {
          continue;
        }
        if (ox * ox + oy * oy > r * r) {
          continue;
        }
        int nx = tx + ox;
        int ny = ty + oy;
        if (nx < 0 || ny < 0 || nx >= map.widthTiles || ny >= map.heightTiles) {
          continue;
        }
        total++;
        if (visible[ny][nx]) {
          visibleNeighbors++;
        }
      }
    }
    if (total == 0 || visibleNeighbors == 0) {
      return 1.0;
    }
    float minFactor = constrain(1.0 - strength, 0.20, 0.95);
    return constrain(1.0 - visibleNeighbors / float(total) * strength, minFactor, 1.0);
  }
}

class FogVisionSource {
  PVector center;
  float radiusPx;
  int minTx;
  int minTy;
  int maxTx;
  int maxTy;

  FogVisionSource(PVector center, float radiusPx, TileMap map) {
    this.center = center;
    this.radiusPx = radiusPx;
    this.minTx = max(0, map.toTileX(center.x - radiusPx));
    this.maxTx = min(map.widthTiles - 1, map.toTileX(center.x + radiusPx));
    this.minTy = max(0, map.toTileY(center.y - radiusPx));
    this.maxTy = min(map.heightTiles - 1, map.toTileY(center.y + radiusPx));
  }

  FogVisionSource(PVector center, float radiusPx, int minTx, int minTy, int maxTx, int maxTy) {
    this.center = center;
    this.radiusPx = radiusPx;
    this.minTx = minTx;
    this.minTy = minTy;
    this.maxTx = maxTx;
    this.maxTy = maxTy;
  }

  FogVisionSource copy() {
    return new FogVisionSource(center.copy(), radiusPx, minTx, minTy, maxTx, maxTy);
  }
}
