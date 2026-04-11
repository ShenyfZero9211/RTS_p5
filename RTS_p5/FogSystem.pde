class FogSystem {
  boolean[][] explored;
  boolean[][] visible;
  boolean[][] visibleWork;
  float[][] fogDisplayAlpha;
  float updateTimer = 0;
  boolean rebuilding = false;
  int rebuildCursor = 0;
  ArrayList<FogVisionSource> activeSources = new ArrayList<FogVisionSource>();
  int dirtyMinX = 0;
  int dirtyMinY = 0;
  int dirtyMaxX = -1;
  int dirtyMaxY = -1;
  float adaptiveIntervalCached = 0.10;

  FogSystem(TileMap map) {
    explored = new boolean[map.heightTiles][map.widthTiles];
    visible = new boolean[map.heightTiles][map.widthTiles];
    visibleWork = new boolean[map.heightTiles][map.widthTiles];
    fogDisplayAlpha = new float[map.heightTiles][map.widthTiles];
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

    // Full-map visible rebuild every tick: incremental dirty rects left stale true cells
    // (esp. when vision sources disappear) and caused shroud flicker.
    dirtyMinX = 0;
    dirtyMinY = 0;
    dirtyMaxX = map.widthTiles - 1;
    dirtyMaxY = map.heightTiles - 1;
    if (map.widthTiles <= 0 || map.heightTiles <= 0 || dirtyMaxX < dirtyMinX || dirtyMaxY < dirtyMinY) {
      updateTimer = adaptiveIntervalCached;
      rebuilding = false;
      return;
    }

    for (int ty = 0; ty < map.heightTiles; ty++) {
      for (int tx = 0; tx < map.widthTiles; tx++) {
        visibleWork[ty][tx] = false;
      }
    }

    rebuildCursor = 0;
    rebuilding = true;
  }

  void processRebuildBatch(GameState gs) {
    // Respect per-frame fog budget to avoid long stalls in heavy scenes.
    int batch = max(1, gs.fogBatchSourcesPerFrame);
    int processed = 0;
    TileMap map = gs.map;
    float budgetMs = max(0.1, gs.fogUpdateBudgetMs);
    long budgetStart = System.nanoTime();
    while (processed < batch && rebuildCursor < activeSources.size()) {
      FogVisionSource s = activeSources.get(rebuildCursor++);
      markCircleSource(s, map);
      processed++;
      if ((System.nanoTime() - budgetStart) / 1000000.0 >= budgetMs) {
        break;
      }
    }

    if (rebuildCursor < activeSources.size()) {
      return;
    }

    for (int ty = 0; ty < map.heightTiles; ty++) {
      for (int tx = 0; tx < map.widthTiles; tx++) {
        if (visibleWork[ty][tx]) {
          explored[ty][tx] = true;
        }
      }
    }

    boolean[][] tmp = visible;
    visible = visibleWork;
    visibleWork = tmp;

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
      if (b.faction == Faction.PLAYER && b.hp > 0 && b.completed) {
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
      float fts = map.tileSize;
      int utx = constrain(round(u.pos.x / fts - 0.5), 0, map.widthTiles - 1);
      int uty = constrain(round(u.pos.y / fts - 0.5), 0, map.heightTiles - 1);
      PVector snapped = new PVector((utx + 0.5) * fts, (uty + 0.5) * fts);
      out.add(new FogVisionSource(snapped, max(70, u.sightRange), map));
    }
    for (Building b : gs.buildings) {
      if (b.faction != Faction.PLAYER || b.hp <= 0 || !b.completed) {
        continue;
      }
      float r = max(b.tileW, b.tileH) * map.tileSize * 0.95 + 80;
      int btx = constrain(map.toTileX(b.pos.x), 0, max(0, map.widthTiles - b.tileW));
      int bty = constrain(map.toTileY(b.pos.y), 0, max(0, map.heightTiles - b.tileH));
      float fts = map.tileSize;
      PVector c = new PVector((btx + b.tileW * 0.5) * fts, (bty + b.tileH * 0.5) * fts);
      out.add(new FogVisionSource(c, r, map));
    }
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

  float computeTargetFogAlpha(int tx, int ty, GameState gs) {
    if (!explored[ty][tx]) {
      return gs.fogUnexploredAlpha;
    }
    if (!visible[ty][tx]) {
      float a = gs.fogExploredAlpha;
      if (gs.fogSoftEdges) {
        a *= edgeFadeFactor(tx, ty, gs.map, gs.fogEdgeRadius, gs.fogEdgeStrength);
      }
      return a;
    }
    return 0;
  }

  /** Snap visual fog to logical targets (call after creating FogSystem so the first frame is not a fade-in from zero). */
  void syncDisplayToTargets(GameState gs) {
    TileMap map = gs.map;
    for (int ty = 0; ty < map.heightTiles; ty++) {
      for (int tx = 0; tx < map.widthTiles; tx++) {
        fogDisplayAlpha[ty][tx] = computeTargetFogAlpha(tx, ty, gs);
      }
    }
  }

  void updateDisplayBlend(float dt, GameState gs) {
    if (!gs.fogEnabled) {
      return;
    }
    TileMap map = gs.map;
    float k = max(0.01, gs.fogTransitionSpeed);
    float blend = 1 - exp(-dt * k);
    for (int ty = 0; ty < map.heightTiles; ty++) {
      for (int tx = 0; tx < map.widthTiles; tx++) {
        float target = computeTargetFogAlpha(tx, ty, gs);
        // Black or gray -> visible: hard cut (no fade to clear).
        if (target <= 0.001f) {
          fogDisplayAlpha[ty][tx] = 0;
        } else {
          float cur = fogDisplayAlpha[ty][tx];
          fogDisplayAlpha[ty][tx] = cur + (target - cur) * blend;
        }
      }
    }
  }

  int displayAlphaInt(int tx, int ty) {
    return constrain(round(fogDisplayAlpha[ty][tx]), 0, 255);
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
        int alpha = displayAlphaInt(tx, ty);
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

}
