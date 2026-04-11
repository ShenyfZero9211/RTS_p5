/**
 * Undo/redo via full map snapshots (terrain + entity lists).
 */
class EditorMapSnapshot {
  int mapW;
  int mapH;
  int tileSize;
  boolean disableStaticObstacles;
  boolean testMap;
  int[][] terrain;
  ArrayList<EditorMine> mines = new ArrayList<EditorMine>();
  ArrayList<EditorSpawn> spawns = new ArrayList<EditorSpawn>();
  ArrayList<EditorPlacedBuilding> buildings = new ArrayList<EditorPlacedBuilding>();
  ArrayList<EditorPlacedUnit> units = new ArrayList<EditorPlacedUnit>();

  /** Processing sketch inner classes cannot use static factory methods; use constructor. */
  EditorMapSnapshot(EditorState s) {
    mapW = s.mapWidth;
    mapH = s.mapHeight;
    tileSize = s.tileSize;
    disableStaticObstacles = s.disableStaticObstacles;
    testMap = s.testMap;
    terrain = new int[mapH][mapW];
    for (int y = 0; y < mapH; y++) {
      for (int x = 0; x < mapW; x++) {
        terrain[y][x] = s.terrainAt(x, y);
      }
    }
    for (EditorMine m : s.mines) {
      mines.add(new EditorMine(m.tx, m.ty, m.amount));
    }
    for (EditorSpawn sp : s.spawns) {
      spawns.add(new EditorSpawn(sp.faction, sp.tx, sp.ty));
    }
    for (EditorPlacedBuilding b : s.initialBuildings) {
      buildings.add(new EditorPlacedBuilding(b.faction, b.type, b.tx, b.ty));
    }
    for (EditorPlacedUnit u : s.initialUnits) {
      units.add(new EditorPlacedUnit(u.faction, u.type, u.worldCX, u.worldCY));
    }
  }

  void applyTo(EditorState s) {
    s.mapWidth = mapW;
    s.mapHeight = mapH;
    s.tileSize = tileSize;
    s.disableStaticObstacles = disableStaticObstacles;
    s.testMap = testMap;
    s.terrain = new int[mapH][mapW];
    for (int y = 0; y < mapH; y++) {
      for (int x = 0; x < mapW; x++) {
        s.terrain[y][x] = terrain[y][x];
      }
    }
    s.mines.clear();
    for (EditorMine m : mines) {
      s.mines.add(new EditorMine(m.tx, m.ty, m.amount));
    }
    s.spawns.clear();
    for (EditorSpawn sp : spawns) {
      s.spawns.add(new EditorSpawn(sp.faction, sp.tx, sp.ty));
    }
    s.initialBuildings.clear();
    for (EditorPlacedBuilding b : buildings) {
      s.initialBuildings.add(new EditorPlacedBuilding(b.faction, b.type, b.tx, b.ty));
    }
    s.initialUnits.clear();
    for (EditorPlacedUnit u : units) {
      s.initialUnits.add(new EditorPlacedUnit(u.faction, u.type, u.worldCX, u.worldCY));
    }
    s.paletteListScroll = 0;
    s.paletteValidationScroll = 0;
    s.clampWorldCamera(s.mapViewWidthPx(), s.mapViewHeightPx());
  }
}

class EditorEditHistory {
  static final int MAX_DEPTH = 50;
  final ArrayList<EditorMapSnapshot> undoStack = new ArrayList<EditorMapSnapshot>();
  final ArrayList<EditorMapSnapshot> redoStack = new ArrayList<EditorMapSnapshot>();

  void clear() {
    undoStack.clear();
    redoStack.clear();
  }

  void pushBeforeChange(EditorState s) {
    undoStack.add(new EditorMapSnapshot(s));
    while (undoStack.size() > MAX_DEPTH) {
      undoStack.remove(0);
    }
    redoStack.clear();
  }

  boolean undo(EditorState s) {
    if (undoStack.size() < 1) return false;
    EditorMapSnapshot past = undoStack.remove(undoStack.size() - 1);
    redoStack.add(new EditorMapSnapshot(s));
    past.applyTo(s);
    return true;
  }

  boolean redo(EditorState s) {
    if (redoStack.size() < 1) return false;
    EditorMapSnapshot next = redoStack.remove(redoStack.size() - 1);
    undoStack.add(new EditorMapSnapshot(s));
    next.applyTo(s);
    return true;
  }
}
