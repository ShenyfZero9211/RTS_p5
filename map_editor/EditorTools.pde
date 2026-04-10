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
    int r = max(0, s.brushSize - 1);
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        int tx = centerTx + dx;
        int ty = centerTy + dy;
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
    for (int i = s.initialUnits.size() - 1; i >= 0; i--) {
      EditorPlacedUnit u = s.initialUnits.get(i);
      if (u.tx == tx && u.ty == ty) {
        s.initialUnits.remove(i);
        return;
      }
    }
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

  void placeUnit(String faction, String type, int tx, int ty) {
    s.initialUnits.add(new EditorPlacedUnit(faction, type, tx, ty));
  }

  void pickTerrain(int tx, int ty) {
    int t = s.terrainAt(tx, ty);
    if (t == 0) s.activeTool = EditorToolType.TOOL_TERRAIN_SAND;
    else if (t == 1) s.activeTool = EditorToolType.TOOL_TERRAIN_ROCK;
    else s.activeTool = EditorToolType.TOOL_TERRAIN_BLOCK;
  }
}
