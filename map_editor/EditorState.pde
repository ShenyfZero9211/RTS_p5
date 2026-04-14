enum EditorInteractionMode {
  MODE_SELECT,
  MODE_PLACE
}

enum EditorToolType {
  TOOL_SELECT,
  TOOL_TERRAIN_SAND,
  TOOL_TERRAIN_ROCK,
  TOOL_TERRAIN_BLOCK,
  TOOL_ERASE,
  TOOL_FILL,
  TOOL_MINE,
  TOOL_SPAWN_PLAYER,
  TOOL_SPAWN_ENEMY,
  TOOL_BUILDING,
  TOOL_UNIT
}

class EditorMine {
  int tx, ty, amount;
  EditorMine(int tx, int ty, int amount) {
    this.tx = tx;
    this.ty = ty;
    this.amount = amount;
  }
}

class EditorSpawn {
  String faction;
  int tx, ty;
  EditorSpawn(String faction, int tx, int ty) {
    this.faction = faction;
    this.tx = tx;
    this.ty = ty;
  }
}

class EditorPlacedBuilding {
  String faction;
  String type;
  int tx, ty;
  EditorPlacedBuilding(String faction, String type, int tx, int ty) {
    this.faction = faction;
    this.type = type;
    this.tx = tx;
    this.ty = ty;
  }
}

class EditorPlacedUnit {
  String faction;
  String type;
  /** World pixel center (matches runtime Unit position). */
  float worldCX;
  float worldCY;
  EditorPlacedUnit(String faction, String type, float worldCX, float worldCY) {
    this.faction = faction;
    this.type = type;
    this.worldCX = worldCX;
    this.worldCY = worldCY;
  }

  int centerTileX(EditorState s) {
    return constrain((int)floor(worldCX / s.tileSize), 0, s.mapWidth - 1);
  }

  int centerTileY(EditorState s) {
    return constrain((int)floor(worldCY / s.tileSize), 0, s.mapHeight - 1);
  }
}

class EditorScriptCondition {
  JSONObject data = new JSONObject();

  EditorScriptCondition() {
  }

  EditorScriptCondition(JSONObject src) {
    if (src != null) {
      data = src;
    }
  }

  EditorScriptCondition copy() {
    JSONObject cp = parseJSONObject(data == null ? "{}" : data.toString());
    if (cp == null) cp = new JSONObject();
    return new EditorScriptCondition(cp);
  }
}

class EditorScriptAction {
  JSONObject data = new JSONObject();

  EditorScriptAction() {
  }

  EditorScriptAction(JSONObject src) {
    if (src != null) {
      data = src;
    }
  }

  EditorScriptAction copy() {
    JSONObject cp = parseJSONObject(data == null ? "{}" : data.toString());
    if (cp == null) cp = new JSONObject();
    return new EditorScriptAction(cp);
  }
}

class EditorScriptTrigger {
  String id = "trigger_1";
  boolean preserve = true;
  int cooldownMs = 0;
  int priority = 0;
  ArrayList<EditorScriptCondition> conditions = new ArrayList<EditorScriptCondition>();
  ArrayList<EditorScriptAction> actions = new ArrayList<EditorScriptAction>();

  EditorScriptTrigger copy() {
    EditorScriptTrigger cp = new EditorScriptTrigger();
    cp.id = id;
    cp.preserve = preserve;
    cp.cooldownMs = cooldownMs;
    cp.priority = priority;
    cp.conditions.clear();
    for (EditorScriptCondition c : conditions) cp.conditions.add(c.copy());
    cp.actions.clear();
    for (EditorScriptAction a : actions) cp.actions.add(a.copy());
    return cp;
  }
}

class EditorScriptBundleBinding {
  String id = "";
  String name = "";
  String path = "";
  boolean enabled = true;
  int priority = 0;

  EditorScriptBundleBinding copy() {
    EditorScriptBundleBinding cp = new EditorScriptBundleBinding();
    cp.id = id;
    cp.name = name;
    cp.path = path;
    cp.enabled = enabled;
    cp.priority = priority;
    return cp;
  }
}

class EditorState {
  int mapWidth = 48;
  int mapHeight = 48;
  int tileSize = 40;
  boolean disableStaticObstacles = false;
  /** When true, RTS engine spawns demo bases/units; when false, only JSON initialBuildings/units. */
  boolean testMap = true;
  int[][] terrain;
  JSONObject unknownFields = new JSONObject();

  ArrayList<EditorMine> mines = new ArrayList<EditorMine>();
  ArrayList<EditorSpawn> spawns = new ArrayList<EditorSpawn>();
  ArrayList<EditorPlacedBuilding> initialBuildings = new ArrayList<EditorPlacedBuilding>();
  ArrayList<EditorPlacedUnit> initialUnits = new ArrayList<EditorPlacedUnit>();
  String scriptBundle = "";
  ArrayList<EditorScriptBundleBinding> scriptBundles = new ArrayList<EditorScriptBundleBinding>();
  ArrayList<EditorScriptTrigger> scriptTriggers = new ArrayList<EditorScriptTrigger>();

  HashMap<String, int[]> buildingSizeById = new HashMap<String, int[]>();
  HashMap<String, Float> unitRadiusById = new HashMap<String, Float>();
  ArrayList<String> buildingIds = new ArrayList<String>();
  ArrayList<String> unitIds = new ArrayList<String>();
  /** When true (default), unit tool snaps to tile centers; when false, free placement with overlap checks. */
  boolean unitSnapToGrid = true;

  EditorToolType activeTool = EditorToolType.TOOL_TERRAIN_SAND;
  EditorInteractionMode interactionMode = EditorInteractionMode.MODE_PLACE;
  /** When set, Save targets this path; otherwise dataDir + currentMapFile. */
  String loadedMapAbsolutePath = "";
  /**
   * After New (or fresh session with no loaded file), Save must use Save As first.
   * Set true after a successful Load or Save / Save As to disk.
   */
  boolean allowDirectSave = false;
  /** Brush level 1..9; tile span from brushFootprintSide() (1,2,3,4,5,6,8,10,10). */
  int brushSize = 1;
  /** Matches RTS_p5 Camera: 1 screen pixel : 1/zoom world pixels at default. */
  float zoom = 1.0;
  /** Top-left of visible world in world pixels (same convention as Camera.x / Camera.y). */
  float camX = 0;
  float camY = 0;
  /** Full-width top menu bar height (pixels). */
  static final int MENU_BAR_H = 40;
  /** Left tool rail width (pixels); room for brush footprint preview. */
  static final int TOOLBAR_W = 112;
  /** Right palette + info column width (pixels). */
  static final int PALETTE_W = 320;
  /** "player" or "enemy" for building/unit placement tools. */
  String placementFaction = "player";
  /** Vertical scroll for building/unit list in the palette (pixels). */
  int paletteListScroll = 0;
  /** Vertical scroll for validation error list in the palette footer (pixels). */
  int paletteValidationScroll = 0;

  static final float GAME_MIN_ZOOM = 0.6;
  static final float GAME_MAX_ZOOM = 2.2;
  static final float WHEEL_ZOOM_STEP = 1.08;

  int selectedBuildingIndex = 0;
  int selectedUnitIndex = 0;
  String selectedObjectType = "";
  int selectedObjectIndex = -1;
  String statusMessage = "";
  long statusUntilMillis = 0;

  String currentMapFile = "map_test.json";
  ArrayList<String> availableMapFiles = new ArrayList<String>();

  void initDefaults(int w, int h, int ts) {
    mapWidth = max(8, w);
    mapHeight = max(8, h);
    tileSize = max(8, ts);
    terrain = new int[mapHeight][mapWidth];
    mines.clear();
    spawns.clear();
    initialBuildings.clear();
    initialUnits.clear();
    scriptBundle = "";
    scriptBundles.clear();
    scriptTriggers.clear();
    selectedObjectType = "";
    selectedObjectIndex = -1;
    placementFaction = "player";
    paletteListScroll = 0;
    paletteValidationScroll = 0;
    loadedMapAbsolutePath = "";
    allowDirectSave = false;
    resetWorldView();
  }

  /** Discrete terrain brush width/height in tiles for the current {@link #brushSize} level. */
  int brushFootprintSide() {
    int[] sides = new int[] { 1, 2, 3, 4, 5, 6, 8, 10, 10 };
    int idx = constrain(brushSize, 1, sides.length) - 1;
    return sides[idx];
  }

  void resetWorldView() {
    camX = 0;
    camY = 0;
    zoom = 1.0;
  }

  int mapViewTopPx() {
    return MENU_BAR_H;
  }

  int mapViewLeftPx() {
    return TOOLBAR_W;
  }

  int mapViewRightPx() {
    return width - PALETTE_W;
  }

  int mapViewWidthPx() {
    return max(1, mapViewRightPx() - mapViewLeftPx());
  }

  int mapViewHeightPx() {
    return max(1, height - MENU_BAR_H);
  }

  int paletteLeftPx() {
    return width - PALETTE_W;
  }

  /** Visible world width in pixels (matches game camera convention). */
  float editorVisibleWorldW(int viewW) {
    return viewW / max(0.001, zoom);
  }

  /** Visible world height in pixels. */
  float editorVisibleWorldH(int viewH) {
    return viewH / max(0.001, zoom);
  }

  float effectiveMinZoom(int viewW, int viewH) {
    int ww = max(1, mapWidth * tileSize);
    int wh = max(1, mapHeight * tileSize);
    float fitX = viewW / float(ww);
    float fitY = viewH / float(wh);
    return max(GAME_MIN_ZOOM, max(fitX, fitY));
  }

  void clampWorldCamera(int viewW, int viewH) {
    zoom = constrain(zoom, effectiveMinZoom(viewW, viewH), GAME_MAX_ZOOM);
    float visW = viewW / zoom;
    float visH = viewH / zoom;
    int worldWpx = mapWidth * tileSize;
    int worldHpx = mapHeight * tileSize;
    float minCamX = 0;
    float maxCamX = worldWpx - visW;
    if (maxCamX < 0) {
      minCamX = maxCamX;
      maxCamX = 0;
    }
    float minCamY = 0;
    float maxCamY = worldHpx - visH;
    if (maxCamY < 0) {
      minCamY = maxCamY;
      maxCamY = 0;
    }
    camX = constrain(camX, minCamX, maxCamX);
    camY = constrain(camY, minCamY, maxCamY);
  }

  void applyWheelZoom(float wheelAmount, float focusLocalX, float focusLocalY, int viewW, int viewH) {
    float fwx = focusLocalX / zoom + camX;
    float fwy = focusLocalY / zoom + camY;
    zoom *= pow(WHEEL_ZOOM_STEP, -wheelAmount);
    zoom = constrain(zoom, effectiveMinZoom(viewW, viewH), GAME_MAX_ZOOM);
    camX = fwx - focusLocalX / zoom;
    camY = fwy - focusLocalY / zoom;
    clampWorldCamera(viewW, viewH);
  }

  boolean inBounds(int tx, int ty) {
    return tx >= 0 && ty >= 0 && tx < mapWidth && ty < mapHeight;
  }

  int terrainAt(int tx, int ty) {
    if (!inBounds(tx, ty)) return 2;
    return terrain[ty][tx];
  }

  void setTerrainAt(int tx, int ty, int t) {
    if (!inBounds(tx, ty)) return;
    terrain[ty][tx] = constrain(t, 0, 2);
  }

  String currentBuildingId() {
    if (buildingIds.size() <= 0) return "base";
    selectedBuildingIndex = (selectedBuildingIndex % buildingIds.size() + buildingIds.size()) % buildingIds.size();
    return buildingIds.get(selectedBuildingIndex);
  }

  String currentUnitId() {
    if (unitIds.size() <= 0) return "rifleman";
    selectedUnitIndex = (selectedUnitIndex % unitIds.size() + unitIds.size()) % unitIds.size();
    return unitIds.get(selectedUnitIndex);
  }

  float unitRadiusPx(String typeId) {
    Float r = unitRadiusById.get(typeId);
    return r != null ? r : tileSize * 0.28f;
  }

  void cycleBuilding(int dir) {
    if (buildingIds.size() <= 0) return;
    selectedBuildingIndex += dir;
    if (selectedBuildingIndex < 0) selectedBuildingIndex = buildingIds.size() - 1;
    if (selectedBuildingIndex >= buildingIds.size()) selectedBuildingIndex = 0;
    setStatus("Building type: " + currentBuildingId());
  }

  void cycleUnit(int dir) {
    if (unitIds.size() <= 0) return;
    selectedUnitIndex += dir;
    if (selectedUnitIndex < 0) selectedUnitIndex = unitIds.size() - 1;
    if (selectedUnitIndex >= unitIds.size()) selectedUnitIndex = 0;
    setStatus("Unit type: " + currentUnitId());
  }

  void setStatus(String msg) {
    statusMessage = msg;
    statusUntilMillis = millis() + 4000;
    println("[MAP-EDITOR] " + msg);
  }

  String activeStatus() {
    if (millis() > statusUntilMillis) return "";
    return statusMessage;
  }
}
