import java.io.File;

class EditorIO {
  EditorState s;
  String dataDirPath;

  EditorIO(EditorState state) {
    s = state;
    dataDirPath = sketchPath("../RTS_p5/data");
  }

  String currentMapPath() {
    return dataDirPath + File.separator + s.currentMapFile;
  }

  void refreshMapFiles() {
    s.availableMapFiles.clear();
    File dir = new File(dataDirPath);
    File[] files = dir.listFiles();
    if (files == null) return;
    for (File f : files) {
      String name = f.getName().toLowerCase();
      if (name.endsWith(".json") && name.startsWith("map")) {
        s.availableMapFiles.add(f.getName());
      }
    }
    if (s.availableMapFiles.size() <= 0) {
      s.availableMapFiles.add("map_test.json");
    }
    if (!s.availableMapFiles.contains(s.currentMapFile)) {
      s.currentMapFile = s.availableMapFiles.get(0);
    }
  }

  void cycleMapFile(int dir) {
    refreshMapFiles();
    int idx = s.availableMapFiles.indexOf(s.currentMapFile);
    if (idx < 0) idx = 0;
    idx += dir;
    if (idx < 0) idx = s.availableMapFiles.size() - 1;
    if (idx >= s.availableMapFiles.size()) idx = 0;
    s.currentMapFile = s.availableMapFiles.get(idx);
    s.setStatus("Current map file: " + s.currentMapFile);
  }

  boolean openCurrentMap() {
    String p = currentMapPath();
    JSONObject root = loadJSONObject(p);
    if (root == null) {
      s.setStatus("Failed to open: " + p);
      return false;
    }
    int w = root.getInt("width", 48);
    int h = root.getInt("height", 48);
    int ts = root.getInt("tileSize", 40);
    s.initDefaults(w, h, ts);
    s.disableStaticObstacles = root.getBoolean("disableStaticObstacles", false);

    JSONArray rows = root.getJSONArray("rows");
    if (rows != null) {
      for (int y = 0; y < min(s.mapHeight, rows.size()); y++) {
        String row = rows.getString(y);
        for (int x = 0; x < min(s.mapWidth, row.length()); x++) {
          char c = row.charAt(x);
          int t = 0;
          if (c == 'R') t = 1;
          if (c == 'B') t = 2;
          s.setTerrainAt(x, y, t);
        }
      }
    }

    s.mines.clear();
    JSONArray mines = root.getJSONArray("goldMines");
    if (mines != null) {
      for (int i = 0; i < mines.size(); i++) {
        JSONObject m = mines.getJSONObject(i);
        s.mines.add(new EditorMine(m.getInt("x", 0), m.getInt("y", 0), m.getInt("amount", 3000)));
      }
    }

    s.spawns.clear();
    JSONArray spawns = root.getJSONArray("spawnPoints");
    if (spawns != null) {
      for (int i = 0; i < spawns.size(); i++) {
        JSONObject sp = spawns.getJSONObject(i);
        s.spawns.add(new EditorSpawn(sp.getString("faction", "player"), sp.getInt("x", 0), sp.getInt("y", 0)));
      }
    }

    s.initialBuildings.clear();
    JSONArray buildings = root.getJSONArray("initialBuildings");
    if (buildings != null) {
      for (int i = 0; i < buildings.size(); i++) {
        JSONObject b = buildings.getJSONObject(i);
        s.initialBuildings.add(new EditorPlacedBuilding(
          b.getString("faction", "player"),
          b.getString("type", "base"),
          b.getInt("x", 0),
          b.getInt("y", 0)
          ));
      }
    }

    s.initialUnits.clear();
    JSONArray units = root.getJSONArray("initialUnits");
    if (units != null) {
      for (int i = 0; i < units.size(); i++) {
        JSONObject u = units.getJSONObject(i);
        s.initialUnits.add(new EditorPlacedUnit(
          u.getString("faction", "player"),
          u.getString("type", "rifleman"),
          u.getInt("x", 0),
          u.getInt("y", 0)
          ));
      }
    }

    s.setStatus("Opened map: " + s.currentMapFile);
    return true;
  }

  boolean saveCurrentMap() {
    JSONObject root = new JSONObject();
    root.setInt("tileSize", s.tileSize);
    root.setInt("width", s.mapWidth);
    root.setInt("height", s.mapHeight);
    root.setBoolean("disableStaticObstacles", s.disableStaticObstacles);

    JSONObject legend = new JSONObject();
    legend.setString(".", "sand - walkable open ground");
    legend.setString("R", "rock - walkable rough terrain");
    legend.setString("B", "block - impassable obstacle");
    root.setJSONObject("legend", legend);

    JSONArray mineArr = new JSONArray();
    for (EditorMine m : s.mines) {
      JSONObject o = new JSONObject();
      o.setInt("x", m.tx);
      o.setInt("y", m.ty);
      o.setInt("amount", m.amount);
      mineArr.append(o);
    }
    root.setJSONArray("goldMines", mineArr);

    JSONArray rows = new JSONArray();
    for (int y = 0; y < s.mapHeight; y++) {
      StringBuilder sb = new StringBuilder();
      for (int x = 0; x < s.mapWidth; x++) {
        int t = s.terrainAt(x, y);
        char c = '.';
        if (t == 1) c = 'R';
        if (t == 2) c = 'B';
        sb.append(c);
      }
      rows.append(sb.toString());
    }
    root.setJSONArray("rows", rows);

    JSONArray spawns = new JSONArray();
    for (EditorSpawn sp : s.spawns) {
      JSONObject o = new JSONObject();
      o.setString("faction", sp.faction);
      o.setInt("x", sp.tx);
      o.setInt("y", sp.ty);
      spawns.append(o);
    }
    root.setJSONArray("spawnPoints", spawns);

    JSONArray buildings = new JSONArray();
    for (EditorPlacedBuilding b : s.initialBuildings) {
      JSONObject o = new JSONObject();
      o.setString("faction", b.faction);
      o.setString("type", b.type);
      o.setInt("x", b.tx);
      o.setInt("y", b.ty);
      buildings.append(o);
    }
    root.setJSONArray("initialBuildings", buildings);

    JSONArray units = new JSONArray();
    for (EditorPlacedUnit u : s.initialUnits) {
      JSONObject o = new JSONObject();
      o.setString("faction", u.faction);
      o.setString("type", u.type);
      o.setInt("x", u.tx);
      o.setInt("y", u.ty);
      units.append(o);
    }
    root.setJSONArray("initialUnits", units);

    String target = currentMapPath();
    saveJSONObject(root, target);
    s.setStatus("Saved map: " + target);
    return true;
  }

  void loadDefinitions() {
    s.buildingIds.clear();
    s.unitIds.clear();
    s.buildingSizeById.clear();

    JSONObject bRoot = loadJSONObject(sketchPath("../RTS_p5/data/buildings.json"));
    if (bRoot != null) {
      JSONArray arr = bRoot.getJSONArray("buildings");
      if (arr != null) {
        for (int i = 0; i < arr.size(); i++) {
          JSONObject b = arr.getJSONObject(i);
          String id = b.getString("id", "");
          if (id.length() <= 0) continue;
          s.buildingIds.add(id);
          int w = b.getInt("tileW", 1);
          int h = b.getInt("tileH", 1);
          s.buildingSizeById.put(id, new int[] { max(1, w), max(1, h) });
        }
      }
    }

    JSONObject uRoot = loadJSONObject(sketchPath("../RTS_p5/data/units.json"));
    if (uRoot != null) {
      JSONArray arr = uRoot.getJSONArray("units");
      if (arr != null) {
        for (int i = 0; i < arr.size(); i++) {
          JSONObject u = arr.getJSONObject(i);
          String id = u.getString("id", "");
          if (id.length() <= 0) continue;
          s.unitIds.add(id);
        }
      }
    }
  }

  void writeMapToMapTestForGameRun() {
    String src = currentMapPath();
    String dst = sketchPath("../RTS_p5/data/map_test.json");
    String[] lines = loadStrings(src);
    if (lines == null) return;
    saveStrings(dst, lines);
    s.setStatus("Map written to map_test.json");
  }
}
