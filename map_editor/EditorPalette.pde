/**
 * Right column: minimap, file/map meta, scrollable building/unit list.
 */
class EditorPalette {
  static final int ROW_H = 27;
  static final int PALETTE_MINIMAP_H = 148;
  static final int MM_PAD_TOP = 8;
  static final int MM_SIDE = 10;
  static final int META_AFTER_MM = 12;
  static final int META_LINE_H = 22;
  /** Minimap block + meta lines + padding below meta (before scroll list). */
  int headerTotal(EditorState s) {
    int metaLines = 5 + (s.activeTool == EditorToolType.TOOL_UNIT ? 1 : 0);
    return MM_PAD_TOP + PALETTE_MINIMAP_H + META_AFTER_MM + metaLines * META_LINE_H + 12;
  }
  static final int FOOTER_VALIDATION_SCROLL_H = 100;
  static final int FOOTER_VALIDATION_TITLE_H = 18;
  static final int FOOTER_HOTKEY_BLOCK_H = 72;
  static final int FOOTER_ABOVE_STATUS = 46;

  int contentTop() {
    return EditorState.MENU_BAR_H;
  }

  int metaStartY() {
    return contentTop() + MM_PAD_TOP + PALETTE_MINIMAP_H + META_AFTER_MM;
  }

  int listBottomMargin() {
    return FOOTER_VALIDATION_TITLE_H + FOOTER_VALIDATION_SCROLL_H + FOOTER_HOTKEY_BLOCK_H + FOOTER_ABOVE_STATUS + 10;
  }

  int listTopY(EditorState s) {
    return contentTop() + headerTotal(s);
  }

  int listHeight(EditorState s) {
    return max(40, height - listTopY(s) - listBottomMargin());
  }

  void minimapScreenRect(EditorState s, int[] r) {
    int x0 = s.paletteLeftPx();
    int top = contentTop();
    r[0] = x0 + MM_SIDE;
    r[1] = top + MM_PAD_TOP;
    r[2] = EditorState.PALETTE_W - MM_SIDE * 2;
    r[3] = PALETTE_MINIMAP_H;
  }

  boolean minimapContains(EditorState s, int mx, int my) {
    int[] r = new int[4];
    minimapScreenRect(s, r);
    return mx >= r[0] && mx < r[0] + r[2] && my >= r[1] && my < r[1] + r[3];
  }

  boolean contains(int mx, int my, EditorState s) {
    int x0 = s.paletteLeftPx();
    return mx >= x0 && mx < width && my >= contentTop() && my < height;
  }

  boolean listContains(int mx, int my, EditorState s) {
    if (!contains(mx, my, s)) return false;
    int x0 = s.paletteLeftPx();
    int y0 = listTopY(s);
    int h = listHeight(s);
    return mx >= x0 + 6 && mx < width - 6 && my >= y0 && my < y0 + h;
  }

  int hoverListRow(EditorState s, int mx, int my) {
    if (!listContains(mx, my, s)) return -1;
    float relY = my - (listTopY(s) + 4) + s.paletteListScroll;
    if (s.activeTool == EditorToolType.TOOL_BUILDING) {
      int idx = floor((relY - 18) / ROW_H);
      if (idx >= 0 && idx < s.buildingIds.size()) return idx;
    } else if (s.activeTool == EditorToolType.TOOL_UNIT) {
      int idx = floor((relY - 18) / ROW_H);
      if (idx >= 0 && idx < s.unitIds.size()) return idx;
    }
    return -1;
  }

  int validationTitleY() {
    return height - FOOTER_ABOVE_STATUS - FOOTER_HOTKEY_BLOCK_H - FOOTER_VALIDATION_SCROLL_H - FOOTER_VALIDATION_TITLE_H;
  }

  int validationBodyTop() {
    return validationTitleY() + FOOTER_VALIDATION_TITLE_H;
  }

  int hotkeyBlockTop() {
    return height - FOOTER_ABOVE_STATUS - FOOTER_HOTKEY_BLOCK_H;
  }

  boolean hoverValidationErrors(EditorState s, int mx, int my, EditorValidationResult vr) {
    if (vr.ok() || vr.errors.size() <= 0) return false;
    int x0 = s.paletteLeftPx();
    int pw = EditorState.PALETTE_W;
    int top = validationBodyTop();
    return mx >= x0 + 8 && mx < x0 + pw - 8 && my >= top && my < top + FOOTER_VALIDATION_SCROLL_H;
  }

  boolean hoverTestMapToggle(EditorState s, int mx, int my) {
    int x0 = s.paletteLeftPx();
    int lineY = metaStartY() + 4 * META_LINE_H;
    return mx >= x0 + MM_SIDE && mx < x0 + EditorState.PALETTE_W - MM_SIDE && my >= lineY && my < lineY + META_LINE_H;
  }

  boolean hoverUnitSnapToggle(EditorState s, int mx, int my) {
    if (s.activeTool != EditorToolType.TOOL_UNIT) return false;
    int x0 = s.paletteLeftPx();
    int lineY = metaStartY() + 5 * META_LINE_H;
    return mx >= x0 + MM_SIDE && mx < x0 + EditorState.PALETTE_W - MM_SIDE && my >= lineY && my < lineY + META_LINE_H;
  }

  boolean hoverAny(EditorState s, int mx, int my, EditorValidationResult vr) {
    return minimapContains(s, mx, my) || hoverListRow(s, mx, my) >= 0
      || hoverTestMapToggle(s, mx, my)
      || hoverUnitSnapToggle(s, mx, my)
      || hoverValidationErrors(s, mx, my, vr);
  }

  void render(EditorState s, EditorMinimap mm, int mx, int my) {
    int x0 = s.paletteLeftPx();
    int pw = EditorState.PALETTE_W;
    int top = contentTop();
    noStroke();
    fill(26, 30, 38);
    rect(x0, top, pw, height - top);

    int[] r = new int[4];
    minimapScreenRect(s, r);
    mm.renderAt(s, r[0], r[1], r[2], r[3]);

    int myMeta = metaStartY();
    fill(230, 238, 250);
    textSize(14);
    textAlign(LEFT, TOP);
    text("RTS Map Editor", x0 + MM_SIDE, myMeta);
    myMeta += META_LINE_H;
    textSize(12);
    fill(165, 180, 200);
    text("File: " + s.currentMapFile, x0 + MM_SIDE, myMeta);
    myMeta += META_LINE_H;
    text("Map: " + s.mapWidth + " x " + s.mapHeight + "  tile " + s.tileSize, x0 + MM_SIDE, myMeta);
    myMeta += META_LINE_H;
    fill(205, 215, 230);
    text("Zoom: " + nf(s.zoom, 1, 2), x0 + MM_SIDE, myMeta);
    myMeta += META_LINE_H;
    boolean hTest = hoverTestMapToggle(s, mx, my);
    fill(hTest ? 220 : 175, hTest ? 235 : 195, 250);
    text("Test map (engine auto-init): " + (s.testMap ? "ON" : "OFF") + "  (click)", x0 + MM_SIDE, myMeta);
    myMeta += META_LINE_H;
    if (s.activeTool == EditorToolType.TOOL_UNIT) {
      boolean hSnap = hoverUnitSnapToggle(s, mx, my);
      fill(hSnap ? 220 : 175, hSnap ? 235 : 195, 250);
      text("Unit snap grid: " + (s.unitSnapToGrid ? "ON" : "OFF") + "  (click)", x0 + MM_SIDE, myMeta);
    }

    int yList = listTopY(s);
    int lh = listHeight(s);
    fill(18, 22, 28);
    rect(x0 + 6, yList, pw - 12, lh, 4);

    boolean showBuildings = s.activeTool == EditorToolType.TOOL_BUILDING;
    boolean showUnits = s.activeTool == EditorToolType.TOOL_UNIT;
    int hoverRow = hoverListRow(s, mx, my);

    pushMatrix();
    translate(x0 + 8, yList + 4);
    clip(0, 0, pw - 16, lh - 8);
    translate(0, -s.paletteListScroll);

    if (showBuildings) {
      fill(175, 195, 218);
      textSize(12);
      text("Buildings (click)", 0, 0);
      int y = 18;
      for (int i = 0; i < s.buildingIds.size(); i++) {
        String id = s.buildingIds.get(i);
        boolean sel = (i == s.selectedBuildingIndex);
        boolean hov = (hoverRow == i && !sel);
        if (sel) {
          fill(55, 95, 140);
          noStroke();
          rect(-2, y - 2, pw - 20, ROW_H, 2);
        } else if (hov) {
          fill(48, 62, 82);
          noStroke();
          rect(-2, y - 2, pw - 20, ROW_H, 2);
        }
        fill(sel ? 255 : (hov ? 235 : 205));
        textSize(12);
        text(id, 4, y + 5);
        y += ROW_H;
      }
    } else if (showUnits) {
      fill(175, 195, 218);
      textSize(12);
      text("Units (click)", 0, 0);
      int y = 18;
      for (int i = 0; i < s.unitIds.size(); i++) {
        String id = s.unitIds.get(i);
        boolean sel = (i == s.selectedUnitIndex);
        boolean hov = (hoverRow == i && !sel);
        if (sel) {
          fill(55, 95, 140);
          noStroke();
          rect(-2, y - 2, pw - 20, ROW_H, 2);
        } else if (hov) {
          fill(48, 62, 82);
          noStroke();
          rect(-2, y - 2, pw - 20, ROW_H, 2);
        }
        fill(sel ? 255 : (hov ? 235 : 205));
        textSize(12);
        text(id, 4, y + 5);
        y += ROW_H;
      }
    } else {
      fill(125, 135, 150);
      textSize(12);
      text("Select Building (Bld)", 0, 10);
      text("or Unit tool to pick", 0, 28);
      text("a type from this list.", 0, 46);
    }

    noClip();
    popMatrix();
  }

  void renderFooter(EditorState s, EditorValidationResult vr, String hotkeyBlock) {
    int x0 = s.paletteLeftPx();
    int pw = EditorState.PALETTE_W;
    int titleY = validationTitleY();
    int bodyTop = validationBodyTop();
    int hkTop = hotkeyBlockTop();

    fill(vr.ok() ? color(100, 190, 120) : color(230, 120, 120));
    textSize(11);
    textAlign(LEFT, TOP);
    text(vr.ok() ? "Validation: PASS" : "Validation: " + vr.errors.size() + " issues", x0 + 10, titleY);

    if (!vr.ok() && vr.errors.size() > 0) {
      noStroke();
      fill(20, 24, 30);
      rect(x0 + 8, bodyTop, pw - 16, FOOTER_VALIDATION_SCROLL_H, 4);
      stroke(52, 62, 78);
      noFill();
      rect(x0 + 8.5f, bodyTop + 0.5f, pw - 17, FOOTER_VALIDATION_SCROLL_H - 1, 4);
      noStroke();

      pushMatrix();
      translate(x0 + 10, bodyTop + 4);
      clip(0, 0, pw - 20, FOOTER_VALIDATION_SCROLL_H - 8);
      translate(0, -s.paletteValidationScroll);
      textSize(10);
      textLeading(14);
      textAlign(LEFT, TOP);
      fill(165, 180, 200);
      float ey = 0;
      for (int i = 0; i < vr.errors.size(); i++) {
        text("- " + vr.errors.get(i), 0, ey, pw - 28, 14);
        ey += 14;
      }
      noClip();
      popMatrix();
    }

    fill(125, 140, 160);
    textSize(10);
    textLeading(13);
    textAlign(LEFT, TOP);
    text(hotkeyBlock, x0 + 10, hkTop + 4, pw - 20, FOOTER_HOTKEY_BLOCK_H - 8);
    textLeading(14);
  }

  void clampValidationScroll(EditorState s, EditorValidationResult vr) {
    if (vr.ok() || vr.errors.size() <= 0) {
      s.paletteValidationScroll = 0;
      return;
    }
    int lineH = 14;
    int contentH = vr.errors.size() * lineH;
    int viewInner = FOOTER_VALIDATION_SCROLL_H - 8;
    int maxScroll = max(0, contentH - viewInner);
    s.paletteValidationScroll = constrain(s.paletteValidationScroll, 0, maxScroll);
  }

  boolean mouseWheelValidation(EditorState s, float amount, int mx, int my, EditorValidationResult vr) {
    if (!hoverValidationErrors(s, mx, my, vr)) return false;
    s.paletteValidationScroll += int(amount * 28);
    clampValidationScroll(s, vr);
    return true;
  }

  void clampScroll(EditorState s) {
    int total = 0;
    if (s.activeTool == EditorToolType.TOOL_BUILDING) total = s.buildingIds.size() * ROW_H + 22;
    else if (s.activeTool == EditorToolType.TOOL_UNIT) total = s.unitIds.size() * ROW_H + 22;
    else total = 0;
    int maxScroll = max(0, total - listHeight(s) + 8);
    s.paletteListScroll = constrain(s.paletteListScroll, 0, maxScroll);
  }

  boolean tryMinimapClick(EditorState s, EditorMinimap mm, int mx, int my, int button) {
    if (button != LEFT || !minimapContains(s, mx, my)) return false;
    int[] r = new int[4];
    minimapScreenRect(s, r);
    mm.syncGeometry(s, r[0], r[1], r[2], r[3]);
    PVector w = mm.minimapToWorld(s, mx, my);
    mm.centerCameraOnWorldPoint(s, w.x, w.y);
    return true;
  }

  boolean mousePressed(EditorState s, int mx, int my, int button, EditorEditHistory editHistory) {
    if (button == LEFT && hoverTestMapToggle(s, mx, my)) {
      if (editHistory != null) {
        editHistory.pushBeforeChange(s);
      }
      s.testMap = !s.testMap;
      s.setStatus(s.testMap ? "Test map: engine will auto-place demo bases/units." : "Custom map: engine uses only JSON initial buildings/units.");
      return true;
    }
    if (button == LEFT && hoverUnitSnapToggle(s, mx, my)) {
      s.unitSnapToGrid = !s.unitSnapToGrid;
      s.setStatus(s.unitSnapToGrid ? "Unit placement: snap to tile centers." : "Unit placement: free (no overlap).");
      return true;
    }
    if (button != LEFT || !listContains(mx, my, s)) return false;
    float relY = my - (listTopY(s) + 4) + s.paletteListScroll;

    if (s.activeTool == EditorToolType.TOOL_BUILDING) {
      int header = 18;
      int idx = floor((relY - header) / ROW_H);
      if (idx >= 0 && idx < s.buildingIds.size()) {
        s.selectedBuildingIndex = idx;
        s.setStatus("Building: " + s.currentBuildingId());
        return true;
      }
    } else if (s.activeTool == EditorToolType.TOOL_UNIT) {
      int header = 18;
      int idx = floor((relY - header) / ROW_H);
      if (idx >= 0 && idx < s.unitIds.size()) {
        s.selectedUnitIndex = idx;
        s.setStatus("Unit: " + s.currentUnitId());
        return true;
      }
    }
    return false;
  }

  boolean mouseWheel(EditorState s, float amount, int mx, int my, EditorValidationResult vr) {
    if (mouseWheelValidation(s, amount, mx, my, vr)) return true;
    if (minimapContains(s, mx, my)) return true;
    if (!listContains(mx, my, s)) return false;
    if (s.activeTool != EditorToolType.TOOL_BUILDING && s.activeTool != EditorToolType.TOOL_UNIT) {
      return false;
    }
    s.paletteListScroll += int(amount * 32);
    clampScroll(s);
    return true;
  }
}
