class EditorTools {
  EditorState s;
  boolean draggingRectTerrain = false;
  int rectStartTx = -1;
  int rectStartTy = -1;
  int rectEndTx = -1;
  int rectEndTy = -1;

  EditorTools(EditorState state) {
    s = state;
  }

  int toolTerrainValue() {
    if (s.activeTool == EditorToolType.TOOL_TERRAIN_SAND || s.activeTool == EditorToolType.TOOL_ERASE) return 0;
    if (s.activeTool == EditorToolType.TOOL_TERRAIN_ROCK) return 1;
    if (s.activeTool == EditorToolType.TOOL_TERRAIN_BLOCK) return 2;
    return 0;
  }

  void applyBrush(int centerTx, int centerTy, int terrainType) {
    int n = s.brushFootprintSide();
    int x0 = centerTx - (n - 1) / 2;
    int y0 = centerTy - (n - 1) / 2;
    for (int dy = 0; dy < n; dy++) {
      for (int dx = 0; dx < n; dx++) {
        int tx = x0 + dx;
        int ty = y0 + dy;
        if (!s.inBounds(tx, ty)) continue;
        s.setTerrainAt(tx, ty, terrainType);
      }
    }
  }

  void fillTerrain(int startTx, int startTy, int targetType) {
    if (!s.inBounds(startTx, startTy)) return;
    int source = s.terrainAt(startTx, startTy);
    if (source == targetType) return;
    ArrayList<PVector> q = new ArrayList<PVector>();
    q.add(new PVector(startTx, startTy));
    while (q.size() > 0) {
      PVector p = q.remove(q.size() - 1);
      int tx = int(p.x);
      int ty = int(p.y);
      if (!s.inBounds(tx, ty)) continue;
      if (s.terrainAt(tx, ty) != source) continue;
      s.setTerrainAt(tx, ty, targetType);
      q.add(new PVector(tx + 1, ty));
      q.add(new PVector(tx - 1, ty));
      q.add(new PVector(tx, ty + 1));
      q.add(new PVector(tx, ty - 1));
    }
  }

  void beginRectTerrain(int tx, int ty) {
    draggingRectTerrain = true;
    rectStartTx = tx;
    rectStartTy = ty;
    rectEndTx = tx;
    rectEndTy = ty;
  }

  void updateRectTerrain(int tx, int ty) {
    if (!draggingRectTerrain) return;
    rectEndTx = tx;
    rectEndTy = ty;
  }

  void commitRectTerrain(int terrainType) {
    if (!draggingRectTerrain) return;
    int minX = min(rectStartTx, rectEndTx);
    int maxX = max(rectStartTx, rectEndTx);
    int minY = min(rectStartTy, rectEndTy);
    int maxY = max(rectStartTy, rectEndTy);
    for (int ty = minY; ty <= maxY; ty++) {
      for (int tx = minX; tx <= maxX; tx++) {
        s.setTerrainAt(tx, ty, terrainType);
      }
    }
    draggingRectTerrain = false;
  }

  void cancelRectTerrain() {
    draggingRectTerrain = false;
  }

  void removeAt(int tx, int ty) {
    for (int i = s.mines.size() - 1; i >= 0; i--) {
      EditorMine m = s.mines.get(i);
      if (m.tx == tx && m.ty == ty) {
        s.mines.remove(i);
        return;
      }
    }
    for (int i = s.spawns.size() - 1; i >= 0; i--) {
      EditorSpawn sp = s.spawns.get(i);
      if (sp.tx == tx && sp.ty == ty) {
        s.spawns.remove(i);
        return;
      }
    }
    for (int i = s.initialBuildings.size() - 1; i >= 0; i--) {
      EditorPlacedBuilding b = s.initialBuildings.get(i);
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      if (tx >= b.tx && ty >= b.ty && tx < b.tx + bw && ty < b.ty + bh) {
        s.initialBuildings.remove(i);
        return;
      }
    }
    removeUnitNearWorld((tx + 0.5f) * s.tileSize, (ty + 0.5f) * s.tileSize);
  }

  /** Remove unit if click is near its center (works for grid and free placement). */
  void removeUnitNearWorld(float wx, float wy) {
    float pick = s.tileSize * 0.55f;
    for (int i = s.initialUnits.size() - 1; i >= 0; i--) {
      EditorPlacedUnit u = s.initialUnits.get(i);
      float ur = s.unitRadiusPx(u.type);
      if (dist(wx, wy, u.worldCX, u.worldCY) <= pick + ur * 0.35f) {
        s.initialUnits.remove(i);
        return;
      }
    }
  }

  void removeAtWorldPixel(float wx, float wy) {
    int tx = constrain((int)floor(wx / s.tileSize), 0, s.mapWidth - 1);
    int ty = constrain((int)floor(wy / s.tileSize), 0, s.mapHeight - 1);
    for (int i = s.mines.size() - 1; i >= 0; i--) {
      EditorMine m = s.mines.get(i);
      if (m.tx == tx && m.ty == ty) {
        s.mines.remove(i);
        return;
      }
    }
    for (int i = s.spawns.size() - 1; i >= 0; i--) {
      EditorSpawn sp = s.spawns.get(i);
      if (sp.tx == tx && sp.ty == ty) {
        s.spawns.remove(i);
        return;
      }
    }
    float ts = s.tileSize;
    for (int i = s.initialBuildings.size() - 1; i >= 0; i--) {
      EditorPlacedBuilding b = s.initialBuildings.get(i);
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      float bx0 = b.tx * ts;
      float by0 = b.ty * ts;
      if (wx >= bx0 && wy >= by0 && wx < bx0 + bw * ts && wy < by0 + bh * ts) {
        s.initialBuildings.remove(i);
        return;
      }
    }
    removeUnitNearWorld(wx, wy);
  }

  void placeMine(int tx, int ty) {
    removeMine(tx, ty);
    s.mines.add(new EditorMine(tx, ty, 5000));
  }

  void removeMine(int tx, int ty) {
    for (int i = s.mines.size() - 1; i >= 0; i--) {
      EditorMine m = s.mines.get(i);
      if (m.tx == tx && m.ty == ty) {
        s.mines.remove(i);
      }
    }
  }

  void placeSpawn(String faction, int tx, int ty) {
    s.spawns.add(new EditorSpawn(faction, tx, ty));
  }

  void placeBuilding(String faction, String type, int tx, int ty) {
    s.initialBuildings.add(new EditorPlacedBuilding(faction, type, tx, ty));
  }

  boolean circleOverlapsBuildingFootprint(float cx, float cy, float radius, EditorPlacedBuilding b) {
    float ts = s.tileSize;
    int[] sz = s.buildingSizeById.get(b.type);
    int bw = sz == null ? 1 : max(1, sz[0]);
    int bh = sz == null ? 1 : max(1, sz[1]);
    float bx0 = b.tx * ts;
    float by0 = b.ty * ts;
    float bx1 = bx0 + bw * ts;
    float by1 = by0 + bh * ts;
    float px = constrain(cx, bx0, bx1);
    float py = constrain(cy, by0, by1);
    float dx = cx - px;
    float dy = cy - py;
    return dx * dx + dy * dy < radius * radius;
  }

  /**
   * Resolves world position for unit placement (snap + constrain) and checks terrain / overlap.
   * @param respectSnapToggle when true, applies grid snap if {@link EditorState#unitSnapToGrid}
   * @param outWorld receives resolved center if return is 0
   * @return 0 valid, 1 blocked terrain, 2 overlap with unit or building
   */
  int resolveUnitPlacement(String type, float inWcx, float inWcy, boolean respectSnapToggle, PVector outWorld) {
    float ts = s.tileSize;
    float r = s.unitRadiusPx(type);
    float wcx = inWcx;
    float wcy = inWcy;
    if (respectSnapToggle && s.unitSnapToGrid) {
      int gtx = (int)floor(wcx / ts);
      int gty = (int)floor(wcy / ts);
      wcx = (gtx + 0.5f) * ts;
      wcy = (gty + 0.5f) * ts;
    }
    wcx = constrain(wcx, r, s.mapWidth * ts - r);
    wcy = constrain(wcy, r, s.mapHeight * ts - r);
    int ttx = (int)floor(wcx / ts);
    int tty = (int)floor(wcy / ts);
    ttx = constrain(ttx, 0, s.mapWidth - 1);
    tty = constrain(tty, 0, s.mapHeight - 1);
    if (s.terrainAt(ttx, tty) == 2) {
      outWorld.set(wcx, wcy);
      return 1;
    }
    if (!canPlaceUnitVolume(type, wcx, wcy, r, -1)) {
      outWorld.set(wcx, wcy);
      return 2;
    }
    outWorld.set(wcx, wcy);
    return 0;
  }

  /** @param ignoreUnitIndex pass -1 when placing new */
  boolean canPlaceUnitVolume(String type, float wcx, float wcy, float r, int ignoreUnitIndex) {
    for (int i = 0; i < s.initialUnits.size(); i++) {
      if (i == ignoreUnitIndex) continue;
      EditorPlacedUnit o = s.initialUnits.get(i);
      float or = s.unitRadiusPx(o.type);
      float minD = r + or + 2;
      if (dist(wcx, wcy, o.worldCX, o.worldCY) < minD) {
        return false;
      }
    }
    for (EditorPlacedBuilding b : s.initialBuildings) {
      if (circleOverlapsBuildingFootprint(wcx, wcy, r, b)) {
        return false;
      }
    }
    return true;
  }

  boolean tryPlaceUnit(String faction, String type, float wcx, float wcy, boolean respectSnapToggle) {
    PVector p = new PVector();
    int code = resolveUnitPlacement(type, wcx, wcy, respectSnapToggle, p);
    if (code == 1) {
      s.setStatus("Cannot place unit on blocked tile.");
      return false;
    }
    if (code == 2) {
      s.setStatus("Too close to building or another unit.");
      return false;
    }
    s.initialUnits.add(new EditorPlacedUnit(faction, type, p.x, p.y));
    return true;
  }

  boolean tryPlaceUnit(String faction, String type, float wcx, float wcy) {
    return tryPlaceUnit(faction, type, wcx, wcy, true);
  }

  void pickTerrain(int tx, int ty) {
    int t = s.terrainAt(tx, ty);
    if (t == 0) s.activeTool = EditorToolType.TOOL_TERRAIN_SAND;
    else if (t == 1) s.activeTool = EditorToolType.TOOL_TERRAIN_ROCK;
    else s.activeTool = EditorToolType.TOOL_TERRAIN_BLOCK;
  }
}
