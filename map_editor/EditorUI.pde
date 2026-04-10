class EditorUI {
  EditorState s;
  EditorTools tools;
  EditorIO io;
  EditorValidation validator;

  boolean draggingPan = false;
  int lastMouseX = 0;
  int lastMouseY = 0;
  int panelW = 360;

  EditorUI(EditorState state, EditorTools tools, EditorIO io, EditorValidation validator) {
    this.s = state;
    this.tools = tools;
    this.io = io;
    this.validator = validator;
  }

  void render() {
    panelW = s.sidePanelW;
    renderWorld();
    renderSidePanel();
  }

  void renderWorld() {
    int viewW = width - panelW;
    int viewH = height;
    s.clampWorldCamera(viewW, viewH);

    pushMatrix();
    clip(panelW, 0, viewW, viewH);
    translate(panelW, 0);
    // Same convention as RTS_p5 Camera: world (camX,camY) maps to top-left of world viewport.
    scale(s.zoom);
    translate(-s.camX, -s.camY);

    int totalW = s.mapWidth * s.tileSize;
    int totalH = s.mapHeight * s.tileSize;
    noStroke();
    fill(20);
    rect(-20, -20, totalW + 40, totalH + 40);

    for (int y = 0; y < s.mapHeight; y++) {
      for (int x = 0; x < s.mapWidth; x++) {
        int t = s.terrainAt(x, y);
        if (t == 0) fill(126, 103, 74);
        else if (t == 1) fill(92, 88, 84);
        else fill(65, 65, 65);
        rect(x * s.tileSize, y * s.tileSize, s.tileSize, s.tileSize);
      }
    }

    stroke(0, 30);
    strokeWeight(1 / s.zoom);
    for (int x = 0; x <= s.mapWidth; x++) {
      float sx = x * s.tileSize;
      line(sx, 0, sx, totalH);
    }
    for (int y = 0; y <= s.mapHeight; y++) {
      float sy = y * s.tileSize;
      line(0, sy, totalW, sy);
    }

    for (EditorMine m : s.mines) {
      fill(80, 160, 235);
      noStroke();
      rect(m.tx * s.tileSize + 4, m.ty * s.tileSize + 4, s.tileSize - 8, s.tileSize - 8);
      fill(20);
      textSize(10 / s.zoom);
      text("M", m.tx * s.tileSize + s.tileSize * 0.5 - 3 / s.zoom, m.ty * s.tileSize + s.tileSize * 0.5 - 6 / s.zoom);
    }

    for (EditorSpawn sp : s.spawns) {
      if ("player".equals(sp.faction)) fill(80, 180, 255);
      else fill(255, 110, 110);
      noStroke();
      ellipse(sp.tx * s.tileSize + s.tileSize * 0.5, sp.ty * s.tileSize + s.tileSize * 0.5, s.tileSize * 0.55, s.tileSize * 0.55);
    }

    for (EditorPlacedBuilding b : s.initialBuildings) {
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      noFill();
      if ("player".equals(b.faction)) stroke(80, 180, 255);
      else stroke(255, 120, 120);
      strokeWeight(2 / s.zoom);
      rect(b.tx * s.tileSize + 2, b.ty * s.tileSize + 2, bw * s.tileSize - 4, bh * s.tileSize - 4);
      fill(240);
      textSize(9 / s.zoom);
      text(b.type, b.tx * s.tileSize + 4, b.ty * s.tileSize + 4);
    }

    for (EditorPlacedUnit u : s.initialUnits) {
      if ("player".equals(u.faction)) fill(80, 180, 255);
      else fill(255, 120, 120);
      noStroke();
      ellipse(u.tx * s.tileSize + s.tileSize * 0.5, u.ty * s.tileSize + s.tileSize * 0.5, s.tileSize * 0.35, s.tileSize * 0.35);
    }

    if (tools.draggingRectTerrain) {
      int minX = min(tools.rectStartTx, tools.rectEndTx);
      int maxX = max(tools.rectStartTx, tools.rectEndTx);
      int minY = min(tools.rectStartTy, tools.rectEndTy);
      int maxY = max(tools.rectStartTy, tools.rectEndTy);
      noFill();
      stroke(255, 230, 120);
      strokeWeight(2 / s.zoom);
      rect(minX * s.tileSize, minY * s.tileSize, (maxX - minX + 1) * s.tileSize, (maxY - minY + 1) * s.tileSize);
    }

    noClip();
    popMatrix();
  }

  void renderSidePanel() {
    noStroke();
    fill(24);
    rect(0, 0, panelW, height);
    fill(240);
    textSize(20);
    text("RTS Map Editor", 16, 12);
    textSize(12);
    text("File: " + s.currentMapFile, 16, 46);
    text("Map: " + s.mapWidth + "x" + s.mapHeight + "  tile=" + s.tileSize, 16, 64);
    text("Tool: " + toolName(s.activeTool), 16, 82);
    text("Brush: " + s.brushSize + "  Zoom: " + nf(s.zoom, 1, 2), 16, 100);
    text("Building: " + s.currentBuildingId(), 16, 118);
    text("Unit: " + s.currentUnitId(), 16, 136);

    int y = 168;
    fill(190);
    text("Hotkeys", 16, y);
    y += 18;
    text("1/2/3 terrain  E erase  F fill  I pick", 16, y);
    y += 16;
    text("M mine  P player spawn  O enemy spawn", 16, y);
    y += 16;
    text("B building  U unit  V select", 16, y);
    y += 16;
    text("[ / ] cycle type  +/- brush  Wheel zoom", 16, y);
    y += 16;
    text("Shift+drag rect terrain  Space+drag pan", 16, y);
    y += 16;
    text("Ctrl+S save  Ctrl+L load  Ctrl+N new", 16, y);
    y += 16;
    text("Ctrl+[ / Ctrl+] cycle map file", 16, y);
    y += 16;
    text("Ctrl+R write to map_test.json", 16, y);

    y += 28;
    EditorValidationResult vr = validator.validate();
    fill(vr.ok() ? color(120, 220, 140) : color(255, 145, 145));
    text(vr.ok() ? "Validation: PASS" : "Validation: " + vr.errors.size() + " issues", 16, y);
    y += 18;
    fill(210);
    int limit = min(10, vr.errors.size());
    for (int i = 0; i < limit; i++) {
      text("- " + vr.errors.get(i), 16, y);
      y += 14;
    }

    String st = s.activeStatus();
    if (st.length() > 0) {
      fill(50, 60, 70);
      rect(12, height - 44, panelW - 24, 30, 6);
      fill(255, 230, 140);
      text(st, 20, height - 35);
    }
  }

  String toolName(EditorToolType t) {
    switch(t) {
    case TOOL_SELECT:
      return "SELECT";
    case TOOL_TERRAIN_SAND:
      return "TERRAIN_SAND";
    case TOOL_TERRAIN_ROCK:
      return "TERRAIN_ROCK";
    case TOOL_TERRAIN_BLOCK:
      return "TERRAIN_BLOCK";
    case TOOL_ERASE:
      return "ERASE";
    case TOOL_FILL:
      return "FILL";
    case TOOL_MINE:
      return "MINE";
    case TOOL_SPAWN_PLAYER:
      return "SPAWN_PLAYER";
    case TOOL_SPAWN_ENEMY:
      return "SPAWN_ENEMY";
    case TOOL_BUILDING:
      return "BUILDING";
    case TOOL_UNIT:
      return "UNIT";
    }
    return "UNKNOWN";
  }

  PVector screenToTile(int mx, int my) {
    float lx = mx - panelW;
    float ly = my;
    float wx = lx / s.zoom + s.camX;
    float wy = ly / s.zoom + s.camY;
    int tx = floor(wx / s.tileSize);
    int ty = floor(wy / s.tileSize);
    return new PVector(tx, ty);
  }

  boolean inWorldViewport(int mx, int my) {
    return mx >= panelW && mx < width && my >= 0 && my < height;
  }

  void applyToolAt(int tx, int ty, int button, boolean shiftDown) {
    if (!s.inBounds(tx, ty)) return;
    if (button == RIGHT) {
      tools.removeAt(tx, ty);
      return;
    }

    if (s.activeTool == EditorToolType.TOOL_TERRAIN_SAND ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_ROCK ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_BLOCK ||
      s.activeTool == EditorToolType.TOOL_ERASE) {
      if (shiftDown && !tools.draggingRectTerrain) {
        tools.beginRectTerrain(tx, ty);
      } else if (!shiftDown) {
        tools.applyBrush(tx, ty, tools.toolTerrainValue());
      }
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_FILL) {
      tools.fillTerrain(tx, ty, tools.toolTerrainValue());
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_MINE) {
      tools.placeMine(tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_SPAWN_PLAYER) {
      tools.placeSpawn("player", tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_SPAWN_ENEMY) {
      tools.placeSpawn("enemy", tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_BUILDING) {
      tools.placeBuilding("player", s.currentBuildingId(), tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_UNIT) {
      tools.placeUnit("player", s.currentUnitId(), tx, ty);
      return;
    }
  }

  boolean panModifierKeys() {
    // Space+drag to pan: use key (reliable); keyCode is not always 32 for space in Processing.
    return keyPressed && (key == ' ' || keyCode == 32);
  }

  void onMousePressed(int mx, int my, int button) {
    if (!inWorldViewport(mx, my)) return;
    if (button == CENTER || (button == LEFT && panModifierKeys())) {
      draggingPan = true;
      lastMouseX = mx;
      lastMouseY = my;
      return;
    }
    PVector t = screenToTile(mx, my);
    if (button == CENTER) {
      tools.pickTerrain(int(t.x), int(t.y));
      return;
    }
    applyToolAt(int(t.x), int(t.y), button, keyPressed && keyCode == SHIFT);
  }

  void onMouseDragged(int mx, int my, int button) {
    if (draggingPan) {
      s.camX -= (mx - lastMouseX) / s.zoom;
      s.camY -= (my - lastMouseY) / s.zoom;
      s.clampWorldCamera(width - panelW, height);
      lastMouseX = mx;
      lastMouseY = my;
      return;
    }
    if (!inWorldViewport(mx, my)) return;
    PVector t = screenToTile(mx, my);
    if (tools.draggingRectTerrain) {
      tools.updateRectTerrain(int(t.x), int(t.y));
      return;
    }
    if (button == LEFT &&
      (s.activeTool == EditorToolType.TOOL_TERRAIN_SAND ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_ROCK ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_BLOCK ||
      s.activeTool == EditorToolType.TOOL_ERASE)) {
      tools.applyBrush(int(t.x), int(t.y), tools.toolTerrainValue());
    }
  }

  void onMouseReleased(int mx, int my, int button) {
    if (draggingPan) {
      draggingPan = false;
      return;
    }
    if (tools.draggingRectTerrain) {
      tools.commitRectTerrain(tools.toolTerrainValue());
    }
  }

  void onMouseWheel(float amount, int mx, int my) {
    if (!inWorldViewport(mx, my)) return;
    int viewW = width - panelW;
    s.applyWheelZoom(amount, mx - panelW, my, viewW, height);
  }

  void onKeyPressed(char k, int keyCode) {
    boolean ctrl = keyEvent != null && keyEvent.isControlDown();
    if (ctrl && (k == 's' || k == 'S')) {
      EditorValidationResult r = validator.validate();
      if (!r.ok()) {
        s.setStatus("Save blocked: " + r.errors.size() + " validation errors.");
      } else {
        io.saveCurrentMap();
      }
      return;
    }
    if (ctrl && (k == 'l' || k == 'L')) {
      io.openCurrentMap();
      return;
    }
    if (ctrl && (k == 'n' || k == 'N')) {
      s.initDefaults(48, 48, 40);
      s.setStatus("New blank map.");
      return;
    }
    if (ctrl && (k == 'r' || k == 'R')) {
      io.saveCurrentMap();
      io.writeMapToMapTestForGameRun();
      return;
    }
    if (ctrl && k == '[') {
      io.cycleMapFile(-1);
      return;
    }
    if (ctrl && k == ']') {
      io.cycleMapFile(1);
      return;
    }

    if (k == '1') s.activeTool = EditorToolType.TOOL_TERRAIN_SAND;
    else if (k == '2') s.activeTool = EditorToolType.TOOL_TERRAIN_ROCK;
    else if (k == '3') s.activeTool = EditorToolType.TOOL_TERRAIN_BLOCK;
    else if (k == 'e' || k == 'E') s.activeTool = EditorToolType.TOOL_ERASE;
    else if (k == 'f' || k == 'F') s.activeTool = EditorToolType.TOOL_FILL;
    else if (k == 'i' || k == 'I') s.activeTool = EditorToolType.TOOL_SELECT;
    else if (k == 'm' || k == 'M') s.activeTool = EditorToolType.TOOL_MINE;
    else if (k == 'p' || k == 'P') s.activeTool = EditorToolType.TOOL_SPAWN_PLAYER;
    else if (k == 'o' || k == 'O') s.activeTool = EditorToolType.TOOL_SPAWN_ENEMY;
    else if (k == 'b' || k == 'B') s.activeTool = EditorToolType.TOOL_BUILDING;
    else if (k == 'u' || k == 'U') s.activeTool = EditorToolType.TOOL_UNIT;
    else if (k == 'v' || k == 'V') s.activeTool = EditorToolType.TOOL_SELECT;
    else if (k == '[') {
      if (s.activeTool == EditorToolType.TOOL_BUILDING) s.cycleBuilding(-1);
      else if (s.activeTool == EditorToolType.TOOL_UNIT) s.cycleUnit(-1);
      else s.brushSize = max(1, s.brushSize - 1);
    } else if (k == ']') {
      if (s.activeTool == EditorToolType.TOOL_BUILDING) s.cycleBuilding(1);
      else if (s.activeTool == EditorToolType.TOOL_UNIT) s.cycleUnit(1);
      else s.brushSize = min(9, s.brushSize + 1);
    } else if (k == '+' || k == '=') {
      s.brushSize = min(9, s.brushSize + 1);
    } else if (k == '-') {
      s.brushSize = max(1, s.brushSize - 1);
    } else if (keyCode == DELETE || keyCode == BACKSPACE) {
      // Delete currently selected object by tile under cursor.
      PVector t = screenToTile(mouseX, mouseY);
      tools.removeAt(int(t.x), int(t.y));
    }
  }
}
