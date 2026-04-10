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
  int tx, ty;
  EditorPlacedUnit(String faction, String type, int tx, int ty) {
    this.faction = faction;
    this.type = type;
    this.tx = tx;
    this.ty = ty;
  }
}

class EditorState {
  int mapWidth = 48;
  int mapHeight = 48;
  int tileSize = 40;
  boolean disableStaticObstacles = false;
  int[][] terrain;
  JSONObject unknownFields = new JSONObject();

  ArrayList<EditorMine> mines = new ArrayList<EditorMine>();
  ArrayList<EditorSpawn> spawns = new ArrayList<EditorSpawn>();
  ArrayList<EditorPlacedBuilding> initialBuildings = new ArrayList<EditorPlacedBuilding>();
  ArrayList<EditorPlacedUnit> initialUnits = new ArrayList<EditorPlacedUnit>();

  HashMap<String, int[]> buildingSizeById = new HashMap<String, int[]>();
  ArrayList<String> buildingIds = new ArrayList<String>();
  ArrayList<String> unitIds = new ArrayList<String>();

  EditorToolType activeTool = EditorToolType.TOOL_TERRAIN_SAND;
  int brushSize = 1;
  /** Matches RTS_p5 Camera: 1 screen pixel : 1/zoom world pixels at default. */
  float zoom = 1.0;
  /** Top-left of visible world in world pixels (same convention as Camera.x / Camera.y). */
  float camX = 0;
  float camY = 0;
  int sidePanelW = 360;

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
    selectedObjectType = "";
    selectedObjectIndex = -1;
    resetWorldView();
  }

  void resetWorldView() {
    camX = 0;
    camY = 0;
    zoom = 1.0;
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
