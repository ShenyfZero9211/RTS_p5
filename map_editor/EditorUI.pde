class EditorUI {
  EditorState s;
  EditorTools tools;
  EditorIO io;
  EditorValidation validator;
  EditorToolbar chromeToolbar;
  EditorPalette chromePalette;
  EditorMenuBar chromeMenuBar;
  EditorMinimap chromeMinimap;
  EditorEditHistory editHistory = new EditorEditHistory();
  EditorMapSelection mapSelection = new EditorMapSelection();
  EditorNewMapDialog newMapDialog = new EditorNewMapDialog();
  EditorScriptDialog scriptDialog;

  boolean draggingPan = false;
  boolean draggingMinimapView = false;
  boolean selectingWorldDrag = false;
  float selStartWx;
  float selStartWy;
  float selCurrWx;
  float selCurrWy;
  int lastMouseX = 0;
  int lastMouseY = 0;

  EditorUI(EditorState state, EditorTools tools, EditorIO io, EditorValidation validator) {
    this.s = state;
    this.tools = tools;
    this.io = io;
    this.validator = validator;
    this.chromeToolbar = new EditorToolbar();
    this.chromePalette = new EditorPalette();
    this.chromeMenuBar = new EditorMenuBar();
    this.chromeMinimap = new EditorMinimap();
    this.scriptDialog = new EditorScriptDialog(state, this);
  }

  void onMapLoadedOrNew() {
    editHistory.clear();
    mapSelection.clear();
    syncInteractionMode();
  }

  void syncInteractionMode() {
    if (s.activeTool == EditorToolType.TOOL_BUILDING && s.buildingIds.size() <= 0) {
      s.activeTool = EditorToolType.TOOL_SELECT;
      s.interactionMode = EditorInteractionMode.MODE_SELECT;
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_UNIT && s.unitIds.size() <= 0) {
      s.activeTool = EditorToolType.TOOL_SELECT;
      s.interactionMode = EditorInteractionMode.MODE_SELECT;
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_SELECT) {
      s.interactionMode = EditorInteractionMode.MODE_SELECT;
    } else {
      s.interactionMode = EditorInteractionMode.MODE_PLACE;
    }
  }

  void mutationWillHappen() {
    editHistory.pushBeforeChange(s);
  }

  void menuUndo() {
    if (editHistory.undo(s)) {
      mapSelection.clear();
      s.setStatus("Undo");
    }
  }

  void menuRedo() {
    if (editHistory.redo(s)) {
      mapSelection.clear();
      s.setStatus("Redo");
    }
  }

  void menuCopy() {
    if (mapSelection.isEmpty()) {
      s.setStatus("Copy: nothing selected.");
      return;
    }
    mapSelection.copy(s);
    s.setStatus("Copy (" + mapSelection.handles.size() + " items)");
  }

  void menuCut() {
    if (mapSelection.isEmpty()) return;
    mutationWillHappen();
    mapSelection.cut(s);
    s.setStatus("Cut");
  }

  void menuPaste() {
    if (!inWorldViewport(mouseX, mouseY)) {
      s.setStatus("Paste: move mouse over map.");
      return;
    }
    PVector t = screenToTile(mouseX, mouseY);
    JSONObject root = parseJSONObject(mapSelection.readClipboard());
    if (root == null) {
      s.setStatus("Paste: clipboard is not map editor JSON.");
      return;
    }
    mutationWillHappen();
    int n = mapSelection.applyPastePayload(s, tools, root, int(t.x), int(t.y));
    mapSelection.clear();
    s.setStatus("Pasted " + n + " objects.");
  }

  void promptNewMap() {
    if (newMapDialog.showAndApply(s)) {
      s.setStatus("New map " + s.mapWidth + " x " + s.mapHeight + " @ " + s.tileSize + "px.");
      onMapLoadedOrNew();
    }
  }

  void toggleScriptDialog() {
    if (scriptDialog == null) return;
    scriptDialog.toggle();
    s.setStatus(scriptDialog.visible ? "Script dialog opened." : "Script dialog closed.");
  }

  String hotkeyHelpBlock() {
    return "Hotkeys: 1/2/3 terrain  E/F/I  M P O  B U V\n"
      + "[ / ] cycle type  +/- brush  Wheel zoom map\n"
      + "Shift+drag rect terrain  Space+drag pan\n"
      + "Ctrl+S save  Ctrl+Shift+S Save As  Ctrl+L load  Ctrl+N new\n"
      + "Ctrl+Z undo  Ctrl+Y / Ctrl+Shift+Z redo  Ctrl+X/C/V cut/copy/paste\n"
      + "Ctrl+R export map_test  Ctrl+[ ] cycle data map file  Ctrl+T script";
  }

  PVector screenToWorld(int mx, int my) {
    int viewL = s.mapViewLeftPx();
    int viewTop = s.mapViewTopPx();
    float lx = mx - viewL;
    float ly = my - viewTop;
    return new PVector(lx / s.zoom + s.camX, ly / s.zoom + s.camY);
  }

  void render() {
    int mx = mouseX;
    int my = mouseY;
    EditorValidationResult vr = validator.validate();
    syncInteractionMode();
    chromeToolbar.render(s, mx, my);
    renderWorld(mx, my);
    chromePalette.render(s, chromeMinimap, mx, my);
    chromePalette.renderFooter(s, vr, hotkeyHelpBlock());
    String st = s.activeStatus();
    if (st.length() > 0) {
      int x0 = s.paletteLeftPx();
      int pw = EditorState.PALETTE_W;
      fill(50, 60, 70);
      rect(x0 + 8, height - 42, pw - 16, 34, 6);
      fill(255, 230, 140);
      textSize(11);
      textAlign(LEFT, CENTER);
      text(st, x0 + 14, height - 25);
      textAlign(LEFT, TOP);
    }
    chromePalette.clampScroll(s);
    chromePalette.clampValidationScroll(s, vr);
    chromeMenuBar.render(s, mx, my);
    if (scriptDialog != null && scriptDialog.visible) {
      scriptDialog.render();
    }

    boolean onMinimapView = chromePalette.minimapContains(s, mx, my) && chromeMinimap.viewportContainsScreen(mx, my);
    boolean hand = chromeMenuBar.anyMenuHover(mx, my)
      || chromeToolbar.hoverAny(s, mx, my)
      || chromePalette.hoverAny(s, mx, my, vr)
      || onMinimapView;
    if (draggingMinimapView) {
      cursor(MOVE);
    } else {
      cursor(hand ? HAND : ARROW);
    }
  }

  void renderWorld(int mx, int my) {
    int viewL = s.mapViewLeftPx();
    int viewTop = s.mapViewTopPx();
    int viewW = s.mapViewWidthPx();
    int viewH = s.mapViewHeightPx();
    s.clampWorldCamera(viewW, viewH);

    pushMatrix();
    clip(viewL, viewTop, viewW, viewH);
    translate(viewL, viewTop);
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

    for (int bi = 0; bi < s.initialBuildings.size(); bi++) {
      EditorPlacedBuilding b = s.initialBuildings.get(bi);
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

    for (int ui = 0; ui < s.initialUnits.size(); ui++) {
      EditorPlacedUnit u = s.initialUnits.get(ui);
      if ("player".equals(u.faction)) fill(80, 180, 255);
      else fill(255, 120, 120);
      noStroke();
      ellipse(u.worldCX, u.worldCY, s.tileSize * 0.35, s.tileSize * 0.35);
    }

    renderSelectionHighlights();

    if (tools.draggingRectTerrain) {
      int minX = min(tools.rectStartTx, tools.rectEndTx);
      int maxX = max(tools.rectStartTx, tools.rectEndTx);
      int minY = min(tools.rectStartTy, tools.rectEndTy);
      int maxY = max(tools.rectStartTy, tools.rectEndTy);
      noFill();
      stroke(255, 230, 120);
      strokeWeight(2 / s.zoom);
      rect(minX * s.tileSize, minY * s.tileSize, (maxX - minX + 1) * s.tileSize, (maxY - minY + 1) * s.tileSize);
    } else if (selectingWorldDrag) {
      float loX = min(selStartWx, selCurrWx);
      float hiX = max(selStartWx, selCurrWx);
      float loY = min(selStartWy, selCurrWy);
      float hiY = max(selStartWy, selCurrWy);
      fill(120, 200, 255, 35);
      noStroke();
      rect(loX, loY, hiX - loX, hiY - loY);
      noFill();
      stroke(120, 230, 255, 220);
      strokeWeight(2 / s.zoom);
      rect(loX, loY, hiX - loX, hiY - loY);
      noStroke();
    } else {
      renderPlacementHoverPreview(mx, my);
    }

    noClip();
    popMatrix();
  }

  void renderSelectionHighlights() {
    float ts = s.tileSize;
    float sw = max(2f, 3f / s.zoom);
    noFill();
    stroke(255, 255, 80, 240);
    strokeWeight(sw);
    for (EditorSelectHandle h : mapSelection.handles) {
      if (h.kind == EditorSelectHandle.KIND_BUILDING && h.index >= 0 && h.index < s.initialBuildings.size()) {
        EditorPlacedBuilding b = s.initialBuildings.get(h.index);
        int[] sz = s.buildingSizeById.get(b.type);
        int bw = sz == null ? 1 : max(1, sz[0]);
        int bh = sz == null ? 1 : max(1, sz[1]);
        rect(b.tx * ts - 1, b.ty * ts - 1, bw * ts + 2, bh * ts + 2);
      } else if (h.kind == EditorSelectHandle.KIND_UNIT && h.index >= 0 && h.index < s.initialUnits.size()) {
        EditorPlacedUnit u = s.initialUnits.get(h.index);
        ellipse(u.worldCX, u.worldCY, ts * 0.55, ts * 0.55);
      }
    }
    noStroke();
  }

  void renderPlacementHoverPreview(int mx, int my) {
    if (!inWorldViewport(mx, my)) return;
    if (s.interactionMode == EditorInteractionMode.MODE_SELECT && s.activeTool == EditorToolType.TOOL_SELECT) {
      return;
    }
    PVector tv = screenToTile(mx, my);
    int tx = int(tv.x);
    int ty = int(tv.y);
    float ts = s.tileSize;
    float sw = max(1.2f, 2f / s.zoom);
    EditorToolType at = s.activeTool;

    if (at == EditorToolType.TOOL_SELECT) {
      if (!s.inBounds(tx, ty)) return;
      noFill();
      stroke(255, 220, 100, 220);
      strokeWeight(sw);
      rect(tx * ts + 0.5f, ty * ts + 0.5f, ts - 1, ts - 1, 2);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_TERRAIN_SAND || at == EditorToolType.TOOL_TERRAIN_ROCK ||
      at == EditorToolType.TOOL_TERRAIN_BLOCK || at == EditorToolType.TOOL_ERASE) {
      int n = s.brushFootprintSide();
      int x0 = tx - (n - 1) / 2;
      int y0 = ty - (n - 1) / 2;
      fill(255, 240, 120, 45);
      noStroke();
      rect(x0 * ts, y0 * ts, n * ts, n * ts, 2);
      noFill();
      stroke(255, 230, 80, 240);
      strokeWeight(sw);
      rect(x0 * ts + 0.5f, y0 * ts + 0.5f, n * ts - 1, n * ts - 1, 2);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_FILL) {
      if (!s.inBounds(tx, ty)) return;
      fill(120, 220, 255, 40);
      noStroke();
      rect(tx * ts + 1, ty * ts + 1, ts - 2, ts - 2, 2);
      noFill();
      stroke(120, 220, 255, 230);
      strokeWeight(sw);
      rect(tx * ts + 0.5f, ty * ts + 0.5f, ts - 1, ts - 1, 2);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_MINE) {
      if (!s.inBounds(tx, ty)) return;
      fill(80, 200, 255, 55);
      noStroke();
      rect(tx * ts + 4, ty * ts + 4, ts - 8, ts - 8, 2);
      noFill();
      stroke(80, 220, 255, 240);
      strokeWeight(sw);
      rect(tx * ts + 3, ty * ts + 3, ts - 6, ts - 6, 2);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_SPAWN_PLAYER || at == EditorToolType.TOOL_SPAWN_ENEMY) {
      if (!s.inBounds(tx, ty)) return;
      boolean pl = at == EditorToolType.TOOL_SPAWN_PLAYER;
      stroke(pl ? color(80, 200, 255, 240) : color(255, 130, 130, 240));
      strokeWeight(sw);
      noFill();
      ellipse(tx * ts + ts * 0.5, ty * ts + ts * 0.5, ts * 0.62, ts * 0.62);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_BUILDING) {
      if (!s.inBounds(tx, ty)) return;
      int[] sz = s.buildingSizeById.get(s.currentBuildingId());
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      boolean pl = "player".equals(s.placementFaction);
      fill(pl ? color(80, 180, 255, 55) : color(255, 120, 120, 55));
      noStroke();
      rect(tx * ts, ty * ts, bw * ts, bh * ts, 2);
      noFill();
      stroke(pl ? color(80, 200, 255, 240) : color(255, 140, 140, 240));
      strokeWeight(sw);
      rect(tx * ts + 0.5f, ty * ts + 0.5f, bw * ts - 1, bh * ts - 1, 2);
      noStroke();
      return;
    }

    if (at == EditorToolType.TOOL_UNIT) {
      PVector w = screenToWorld(mx, my);
      if (s.unitSnapToGrid) {
        if (!s.inBounds(tx, ty)) return;
      }
      PVector place = new PVector();
      int placeCode = tools.resolveUnitPlacement(s.currentUnitId(), w.x, w.y, true, place);
      float pxc = place.x;
      float pyc = place.y;
      boolean pl = "player".equals(s.placementFaction);
      stroke(pl ? color(80, 200, 255, 240) : color(255, 140, 140, 240));
      strokeWeight(sw);
      noFill();
      ellipse(pxc, pyc, ts * 0.42, ts * 0.42);
      if (placeCode != 0) {
        float inset = ts * 0.42 * 0.32f;
        stroke(220, 45, 45, 245);
        strokeWeight(max(1.4f, 2f / s.zoom));
        line(pxc - inset, pyc - inset, pxc + inset, pyc + inset);
        line(pxc - inset, pyc + inset, pxc + inset, pyc - inset);
      }
      noStroke();
    }
  }

  PVector screenToTile(int mx, int my) {
    int viewL = s.mapViewLeftPx();
    int viewTop = s.mapViewTopPx();
    float lx = mx - viewL;
    float ly = my - viewTop;
    float wx = lx / s.zoom + s.camX;
    float wy = ly / s.zoom + s.camY;
    int tx = floor(wx / s.tileSize);
    int ty = floor(wy / s.tileSize);
    return new PVector(tx, ty);
  }

  boolean inWorldViewport(int mx, int my) {
    int vt = s.mapViewTopPx();
    return mx >= s.mapViewLeftPx() && mx < s.mapViewRightPx() && my >= vt && my < height;
  }

  void applyToolAt(int tx, int ty, int button, boolean shiftDown) {
    if (s.interactionMode == EditorInteractionMode.MODE_SELECT && s.activeTool == EditorToolType.TOOL_SELECT) {
      return;
    }
    PVector wWorld = screenToWorld(mouseX, mouseY);
    if (button == RIGHT) {
      mutationWillHappen();
      tools.removeAtWorldPixel(wWorld.x, wWorld.y);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_UNIT) {
      if (!inWorldViewport(mouseX, mouseY)) return;
      mutationWillHappen();
      tools.tryPlaceUnit(s.placementFaction, s.currentUnitId(), wWorld.x, wWorld.y);
      return;
    }
    if (!s.inBounds(tx, ty)) return;

    if (s.activeTool == EditorToolType.TOOL_TERRAIN_SAND ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_ROCK ||
      s.activeTool == EditorToolType.TOOL_TERRAIN_BLOCK ||
      s.activeTool == EditorToolType.TOOL_ERASE) {
      if (shiftDown && !tools.draggingRectTerrain) {
        tools.beginRectTerrain(tx, ty);
      } else if (!shiftDown) {
        mutationWillHappen();
        tools.applyBrush(tx, ty, tools.toolTerrainValue());
      }
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_FILL) {
      mutationWillHappen();
      tools.fillTerrain(tx, ty, tools.toolTerrainValue());
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_MINE) {
      mutationWillHappen();
      tools.placeMine(tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_SPAWN_PLAYER) {
      mutationWillHappen();
      tools.placeSpawn("player", tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_SPAWN_ENEMY) {
      mutationWillHappen();
      tools.placeSpawn("enemy", tx, ty);
      return;
    }
    if (s.activeTool == EditorToolType.TOOL_BUILDING) {
      mutationWillHappen();
      tools.placeBuilding(s.placementFaction, s.currentBuildingId(), tx, ty);
      return;
    }
  }

  boolean panModifierKeys() {
    return keyPressed && (key == ' ' || keyCode == 32);
  }

  void onMousePressed(int mx, int my, int button) {
    if (chromeMenuBar.mousePressed(s, io, validator, this, mx, my, button)) return;
    if (scriptDialog != null && scriptDialog.visible && scriptDialog.onMousePressed(mx, my, button)) return;
    if (chromeToolbar.mousePressed(s, mx, my, button)) {
      syncInteractionMode();
      return;
    }
    if (button == LEFT && chromePalette.minimapContains(s, mx, my)) {
      int[] r = new int[4];
      chromePalette.minimapScreenRect(s, r);
      chromeMinimap.syncGeometry(s, r[0], r[1], r[2], r[3]);
      if (chromeMinimap.viewportContainsScreen(mx, my)) {
        draggingMinimapView = true;
        lastMouseX = mx;
        lastMouseY = my;
        return;
      }
    }
    if (chromePalette.tryMinimapClick(s, chromeMinimap, mx, my, button)) return;
    if (chromePalette.mousePressed(s, mx, my, button, editHistory)) return;

    if (!inWorldViewport(mx, my)) return;
    if (button == CENTER || (button == LEFT && panModifierKeys())) {
      draggingPan = true;
      lastMouseX = mx;
      lastMouseY = my;
      return;
    }

    if (button == LEFT && s.interactionMode == EditorInteractionMode.MODE_SELECT && s.activeTool == EditorToolType.TOOL_SELECT) {
      PVector w = screenToWorld(mx, my);
      selectingWorldDrag = true;
      selStartWx = w.x;
      selStartWy = w.y;
      selCurrWx = w.x;
      selCurrWy = w.y;
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
    if (draggingMinimapView) {
      chromeMinimap.dragCameraByMinimapDelta(s, mx - lastMouseX, my - lastMouseY);
      lastMouseX = mx;
      lastMouseY = my;
      return;
    }
    if (draggingPan) {
      s.camX -= (mx - lastMouseX) / s.zoom;
      s.camY -= (my - lastMouseY) / s.zoom;
      s.clampWorldCamera(s.mapViewWidthPx(), s.mapViewHeightPx());
      lastMouseX = mx;
      lastMouseY = my;
      return;
    }
    if (selectingWorldDrag && button == LEFT) {
      PVector w = screenToWorld(mx, my);
      selCurrWx = w.x;
      selCurrWy = w.y;
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
      mutationWillHappen();
      tools.applyBrush(int(t.x), int(t.y), tools.toolTerrainValue());
    }
  }

  void onMouseReleased(int mx, int my, int button) {
    if (draggingMinimapView) {
      draggingMinimapView = false;
      return;
    }
    if (draggingPan) {
      draggingPan = false;
      return;
    }
    if (selectingWorldDrag && button == LEFT) {
      selectingWorldDrag = false;
      PVector w = screenToWorld(mx, my);
      selCurrWx = w.x;
      selCurrWy = w.y;
      boolean isClick = abs(selCurrWx - selStartWx) < 4 && abs(selCurrWy - selStartWy) < 4;
      boolean shift = keyPressed && keyCode == SHIFT;
      if (isClick) {
        mapSelection.pickAtWorld(s, selCurrWx, selCurrWy, shift, 2.5f * s.tileSize);
      } else {
        mapSelection.selectBox(s, selStartWx, selStartWy, selCurrWx, selCurrWy, shift);
      }
      return;
    }
    if (tools.draggingRectTerrain) {
      if (inWorldViewport(mx, my)) {
        mutationWillHappen();
        tools.commitRectTerrain(tools.toolTerrainValue());
      } else {
        tools.cancelRectTerrain();
      }
    }
  }

  void onMouseWheel(float amount, int mx, int my) {
    if (my < EditorState.MENU_BAR_H) return;
    EditorValidationResult vr = validator.validate();
    if (chromePalette.mouseWheel(s, amount, mx, my, vr)) return;
    if (!inWorldViewport(mx, my)) return;
    int viewL = s.mapViewLeftPx();
    int viewTop = s.mapViewTopPx();
    int viewW = s.mapViewWidthPx();
    int viewH = s.mapViewHeightPx();
    s.applyWheelZoom(amount, mx - viewL, my - viewTop, viewW, viewH);
  }

  void onKeyPressed(char k, int keyCode) {
    boolean ctrl = keyEvent != null && keyEvent.isControlDown();
    boolean shift = keyEvent != null && keyEvent.isShiftDown();
    int vk = keyCode;
    if (scriptDialog != null && scriptDialog.visible && scriptDialog.onKeyPressed(k, keyCode)) {
      return;
    }
    // With Ctrl held, `key` is often a control char (e.g. Ctrl+Z -> 26), not 'z'. Use keyCode + VK_*.
    if (ctrl) {
      if (shift && vk == java.awt.event.KeyEvent.VK_S) {
        io.promptSaveAs(validator);
        return;
      }
      if (!shift && vk == java.awt.event.KeyEvent.VK_S) {
        io.requestSave(validator);
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_L) {
        io.promptLoadMap();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_N) {
        promptNewMap();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_R) {
        if (!s.allowDirectSave) {
          io.promptSaveAs(validator);
          return;
        }
        if (io.saveCurrentMap(validator)) {
          io.writeMapToMapTestForGameRun();
        }
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_OPEN_BRACKET) {
        io.cycleMapFile(-1);
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_CLOSE_BRACKET) {
        io.cycleMapFile(1);
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_Z && shift) {
        menuRedo();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_Z && !shift) {
        menuUndo();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_Y) {
        menuRedo();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_X) {
        menuCut();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_C) {
        menuCopy();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_V) {
        menuPaste();
        return;
      }
      if (vk == java.awt.event.KeyEvent.VK_T) {
        toggleScriptDialog();
        return;
      }
    }

    EditorToolType prevTool = s.activeTool;
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
      if (!mapSelection.isEmpty()) {
        mutationWillHappen();
        mapSelection.removeSelectedFromMap(s);
        s.setStatus("Deleted selection.");
      } else if (inWorldViewport(mouseX, mouseY)) {
        mutationWillHappen();
        PVector t = screenToTile(mouseX, mouseY);
        tools.removeAt(int(t.x), int(t.y));
      }
    }
    if (prevTool != s.activeTool) {
      s.paletteListScroll = 0;
      syncInteractionMode();
    }
  }
}
