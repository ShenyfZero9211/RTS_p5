class EditorValidationResult {
  ArrayList<String> errors = new ArrayList<String>();
  boolean ok() {
    return errors.size() == 0;
  }
}

class EditorValidation {
  EditorState s;
  EditorValidation(EditorState state) {
    s = state;
  }

  EditorValidationResult validate() {
    EditorValidationResult r = new EditorValidationResult();
    int playerSpawns = 0;
    int enemySpawns = 0;
    for (EditorSpawn sp : s.spawns) {
      if (!s.inBounds(sp.tx, sp.ty)) {
        r.errors.add("Spawn out of bounds: " + sp.faction + " (" + sp.tx + "," + sp.ty + ")");
      }
      if ("player".equals(sp.faction)) playerSpawns++;
      if ("enemy".equals(sp.faction)) enemySpawns++;
    }
    if (playerSpawns <= 0) r.errors.add("Missing player spawn point.");
    if (enemySpawns <= 0) r.errors.add("Missing enemy spawn point.");

    for (EditorMine m : s.mines) {
      if (!s.inBounds(m.tx, m.ty)) {
        r.errors.add("Mine out of bounds at (" + m.tx + "," + m.ty + ")");
        continue;
      }
      if (s.terrainAt(m.tx, m.ty) == 2) {
        r.errors.add("Mine on blocked tile at (" + m.tx + "," + m.ty + ")");
      }
    }

    boolean[][] occupied = new boolean[s.mapHeight][s.mapWidth];
    for (EditorPlacedBuilding b : s.initialBuildings) {
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      for (int y = b.ty; y < b.ty + bh; y++) {
        for (int x = b.tx; x < b.tx + bw; x++) {
          if (!s.inBounds(x, y)) {
            r.errors.add("Building out of bounds: " + b.type + " at (" + b.tx + "," + b.ty + ")");
            continue;
          }
          if (occupied[y][x]) {
            r.errors.add("Building overlap near (" + x + "," + y + ")");
          }
          occupied[y][x] = true;
        }
      }
    }

    for (EditorPlacedUnit u : s.initialUnits) {
      if (!s.inBounds(u.tx, u.ty)) {
        r.errors.add("Unit out of bounds: " + u.type + " (" + u.tx + "," + u.ty + ")");
        continue;
      }
      if (s.terrainAt(u.tx, u.ty) == 2) {
        r.errors.add("Unit on blocked tile: " + u.type + " (" + u.tx + "," + u.ty + ")");
      }
    }
    return r;
  }
}
