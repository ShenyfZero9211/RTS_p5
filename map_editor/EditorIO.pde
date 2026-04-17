import java.io.File;

class EditorIO {
  EditorState s;
  String dataDirPath;
  boolean fileDialogPending = false;

  EditorIO(EditorState state) {
    s = state;
    dataDirPath = sketchPath("../RTS_p5/data");
  }

  /** Absolute path used for Save / subsequent saves; empty means dataDir + currentMapFile. */
  String effectiveSavePath() {
    if (s.loadedMapAbsolutePath != null && s.loadedMapAbsolutePath.length() > 0) {
      return s.loadedMapAbsolutePath;
    }
    return dataDirPath + File.separator + s.currentMapFile;
  }

  String currentMapPath() {
    return effectiveSavePath();
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
    s.loadedMapAbsolutePath = "";
    s.setStatus("Current map file: " + s.currentMapFile);
  }

  void promptLoadMap() {
    if (fileDialogPending) return;
    fileDialogPending = true;
    selectInput("Load map JSON", "loadMapFileSelected");
  }

  /** Opens Save As only if validation passes (same gate as Save). */
  void promptSaveAs(EditorValidation validator) {
    EditorValidationResult r = validator.validate();
    if (!r.ok()) {
      s.setStatus("Save As blocked: " + r.errors.size() + " validation errors.");
      return;
    }
    if (fileDialogPending) return;
    fileDialogPending = true;
    selectOutput("Save map as JSON", "saveMapAsSelected", new File(dataDirPath, s.currentMapFile));
  }

  void completeLoadDialog(File f) {
    fileDialogPending = false;
    if (f == null) {
      s.setStatus("Load cancelled.");
      return;
    }
    loadFromFile(f);
  }

  void completeSaveAsDialog(File f, EditorValidation validator) {
    fileDialogPending = false;
    if (f == null) {
      s.setStatus("Save As cancelled.");
      return;
    }
    String path = f.getAbsolutePath();
    if (!path.toLowerCase().endsWith(".json")) {
      path = path + ".json";
    }
    if (saveMapToAbsolutePath(path, validator)) {
      s.loadedMapAbsolutePath = path;
      s.currentMapFile = new File(path).getName();
      s.allowDirectSave = true;
      s.setStatus("Saved to: " + path);
    }
  }

  /** Save to current path, or open Save As if this map has no save target yet (e.g. after New). */
  void requestSave(EditorValidation validator) {
    if (!s.allowDirectSave) {
      promptSaveAs(validator);
      return;
    }
    saveCurrentMap(validator);
  }

  JSONObject buildMapRoot() {
    JSONObject root = new JSONObject();
    root.setInt("tileSize", s.tileSize);
    root.setInt("width", s.mapWidth);
    root.setInt("height", s.mapHeight);
    root.setBoolean("disableStaticObstacles", s.disableStaticObstacles);
    root.setBoolean("testMap", s.testMap);

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
      float ts = s.tileSize;
      o.setFloat("worldCX", u.worldCX);
      o.setFloat("worldCY", u.worldCY);
      o.setInt("x", (int)floor(u.worldCX / ts));
      o.setInt("y", (int)floor(u.worldCY / ts));
      units.append(o);
    }
    root.setJSONArray("initialUnits", units);
    if (s.scriptBundles.size() > 0 || s.scriptTriggers.size() > 0) {
      JSONArray bundleArr = new JSONArray();
      for (EditorScriptBundleBinding b : s.scriptBundles) {
        JSONObject bo = new JSONObject();
        bo.setString("id", b.id == null ? "" : b.id);
        bo.setString("name", b.name == null ? "" : b.name);
        bo.setString("path", b.path == null ? "" : b.path);
        bo.setBoolean("enabled", b.enabled);
        bo.setInt("priority", b.priority);
        bundleArr.append(bo);
      }
      if (bundleArr.size() > 0) {
        root.setJSONArray("scriptBundles", bundleArr);
      }
      JSONArray triggers = new JSONArray();
      for (EditorScriptTrigger t : s.scriptTriggers) {
        JSONObject trigObj = new JSONObject();
        trigObj.setString("id", t.id == null ? "" : t.id);
        trigObj.setBoolean("preserve", t.preserve);
        trigObj.setInt("cooldownMs", max(0, t.cooldownMs));
        trigObj.setInt("priority", t.priority);
        JSONArray conds = new JSONArray();
        for (EditorScriptCondition c : t.conditions) {
          JSONObject cp = parseJSONObject(c.data == null ? "{}" : c.data.toString());
          if (cp == null) cp = new JSONObject();
          conds.append(cp);
        }
        JSONArray acts = new JSONArray();
        for (EditorScriptAction a : t.actions) {
          JSONObject ap = parseJSONObject(a.data == null ? "{}" : a.data.toString());
          if (ap == null) ap = new JSONObject();
          acts.append(ap);
        }
        trigObj.setJSONArray("conditions", conds);
        trigObj.setJSONArray("actions", acts);
        triggers.append(trigObj);
      }
      root.setJSONArray("scriptTriggers", triggers);
    }
    if (s.scriptRegions.size() > 0) {
      JSONArray regions = new JSONArray();
      for (EditorScriptRegion r : s.scriptRegions) {
        JSONObject ro = new JSONObject();
        ro.setString("id", r.id == null ? "" : r.id);
        ro.setString("label", r.label == null ? "" : r.label);
        ro.setInt("x", r.x);
        ro.setInt("y", r.y);
        ro.setInt("w", max(1, r.w));
        ro.setInt("h", max(1, r.h));
        regions.append(ro);
      }
      root.setJSONArray("scriptRegions", regions);
    }
    return root;
  }

  boolean saveMapToAbsolutePath(String absolutePath, EditorValidation validator) {
    EditorValidationResult r = validator.validate();
    if (!r.ok()) {
      s.setStatus("Save blocked: " + r.errors.size() + " validation errors.");
      return false;
    }
    saveJSONObject(buildMapRoot(), absolutePath);
    return true;
  }

  /** Save over current path (data file or last loaded absolute path). Validates first. */
  boolean saveCurrentMap(EditorValidation validator) {
    EditorValidationResult r = validator.validate();
    if (!r.ok()) {
      s.setStatus("Save blocked: " + r.errors.size() + " validation errors.");
      return false;
    }
    String target = effectiveSavePath();
    saveJSONObject(buildMapRoot(), target);
    s.loadedMapAbsolutePath = target;
    s.currentMapFile = new File(target).getName();
    s.allowDirectSave = true;
    s.setStatus("Saved map: " + target);
    return true;
  }

  void applyMapFromJson(JSONObject root) {
    int w = root.getInt("width", 48);
    int h = root.getInt("height", 48);
    int ts = root.getInt("tileSize", 40);
    s.initDefaults(w, h, ts);
    s.disableStaticObstacles = root.getBoolean("disableStaticObstacles", false);
    s.testMap = root.getBoolean("testMap", true);

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
        float wcx;
        float wcy;
        if (u.hasKey("worldCX") && u.hasKey("worldCY")) {
          wcx = u.getFloat("worldCX");
          wcy = u.getFloat("worldCY");
        } else {
          int tx = u.getInt("x", 0);
          int ty = u.getInt("y", 0);
          wcx = (tx + 0.5f) * s.tileSize;
          wcy = (ty + 0.5f) * s.tileSize;
        }
        s.initialUnits.add(new EditorPlacedUnit(
          u.getString("faction", "player"),
          u.getString("type", "rifleman"),
          wcx, wcy
          ));
      }
    }
    s.scriptBundle = "";
    s.scriptBundles.clear();
    s.scriptRegions.clear();
    JSONArray bundleArr = root.getJSONArray("scriptBundles");
    if (bundleArr != null) {
      for (int bi = 0; bi < bundleArr.size(); bi++) {
        JSONObject bo = bundleArr.getJSONObject(bi);
        if (bo == null) continue;
        EditorScriptBundleBinding b = new EditorScriptBundleBinding();
        b.id = bo.getString("id", "");
        b.name = bo.getString("name", "");
        b.path = bo.getString("path", "");
        b.enabled = bo.getBoolean("enabled", true);
        b.priority = bo.getInt("priority", 0);
        if (trim(b.path).length() <= 0) {
          b.path = bo.getString("bundle", "");
        }
        s.scriptBundles.add(b);
      }
    }
    s.scriptTriggers.clear();
    JSONArray triggerArr = root.getJSONArray("scriptTriggers");
    if (triggerArr != null) {
      for (int i = 0; i < triggerArr.size(); i++) {
        JSONObject trigObj = triggerArr.getJSONObject(i);
        if (trigObj == null) continue;
        EditorScriptTrigger t = new EditorScriptTrigger();
        t.id = trigObj.getString("id", "trigger_" + (i + 1));
        t.preserve = trigObj.getBoolean("preserve", true);
        t.cooldownMs = max(0, trigObj.getInt("cooldownMs", 0));
        t.priority = trigObj.getInt("priority", 0);
        t.conditions.clear();
        t.actions.clear();
        JSONArray conds = trigObj.getJSONArray("conditions");
        if (conds != null) {
          for (int ci = 0; ci < conds.size(); ci++) {
            JSONObject c = conds.getJSONObject(ci);
            if (c == null) continue;
            JSONObject cp = parseJSONObject(c.toString());
            if (cp == null) cp = new JSONObject();
            t.conditions.add(new EditorScriptCondition(cp));
          }
        }
        JSONArray acts = trigObj.getJSONArray("actions");
        if (acts != null) {
          for (int ai = 0; ai < acts.size(); ai++) {
            JSONObject a = acts.getJSONObject(ai);
            if (a == null) continue;
            JSONObject ap = parseJSONObject(a.toString());
            if (ap == null) ap = new JSONObject();
            t.actions.add(new EditorScriptAction(ap));
          }
        }
        s.scriptTriggers.add(t);
      }
    }
    JSONArray regionArr = root.getJSONArray("scriptRegions");
    if (regionArr != null) {
      for (int ri = 0; ri < regionArr.size(); ri++) {
        JSONObject ro = regionArr.getJSONObject(ri);
        if (ro == null) continue;
        EditorScriptRegion rg = new EditorScriptRegion();
        rg.id = ro.getString("id", "region_" + (ri + 1));
        rg.label = ro.getString("label", "");
        rg.x = ro.getInt("x", 0);
        rg.y = ro.getInt("y", 0);
        rg.w = max(1, ro.getInt("w", 1));
        rg.h = max(1, ro.getInt("h", 1));
        s.scriptRegions.add(rg);
      }
    }
  }

  boolean loadFromFile(File f) {
    if (f == null || !f.exists()) {
      s.setStatus("File not found.");
      return false;
    }
    JSONObject root = loadJSONObject(f.getAbsolutePath());
    if (root == null) {
      s.setStatus("Failed to parse JSON: " + f.getAbsolutePath());
      return false;
    }
    applyMapFromJson(root);
    s.loadedMapAbsolutePath = f.getAbsolutePath();
    s.currentMapFile = f.getName();
    try {
      File dataDir = new File(dataDirPath).getCanonicalFile();
      File loaded = f.getCanonicalFile();
      if (loaded.getParent() != null && loaded.getParentFile().equals(dataDir)) {
        refreshMapFiles();
      }
    }
    catch (Exception e) {
      refreshMapFiles();
    }
    s.setStatus("Opened: " + f.getAbsolutePath());
    s.allowDirectSave = true;
    return true;
  }

  boolean openCurrentMap() {
    File f = new File(effectiveSavePath());
    if (!f.exists()) {
      s.setStatus("No file at: " + f.getAbsolutePath());
      return false;
    }
    return loadFromFile(f);
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

    s.unitRadiusById.clear();
    JSONObject uRoot = loadJSONObject(sketchPath("../RTS_p5/data/units.json"));
    if (uRoot != null) {
      JSONArray arr = uRoot.getJSONArray("units");
      if (arr != null) {
        for (int i = 0; i < arr.size(); i++) {
          JSONObject u = arr.getJSONObject(i);
          String id = u.getString("id", "");
          if (id.length() <= 0) continue;
          s.unitIds.add(id);
          s.unitRadiusById.put(id, u.getFloat("radius", 11f));
        }
      }
    }
  }

  void writeMapToMapTestForGameRun() {
    String src = effectiveSavePath();
    String dst = sketchPath("../RTS_p5/data/map_test.json");
    String[] lines = loadStrings(src);
    if (lines == null) {
      JSONObject root = buildMapRoot();
      saveJSONObject(root, dst);
      s.setStatus("Map written to map_test.json");
      return;
    }
    saveStrings(dst, lines);
    s.setStatus("Map written to map_test.json");
  }
}
