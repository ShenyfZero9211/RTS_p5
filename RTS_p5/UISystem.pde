class UISystem {
  int sidePanelX;
  int sidePanelW;
  int viewportH;
  Minimap minimap;
  int buildButtonsY;
  int buildButtonH = 56;
  int buildButtonGap = 8;
  int buildButtonCols = 2;
  int buildGridX;
  int buildCellW;

  UISystem(int worldViewW, int viewportH) {
    this.sidePanelX = worldViewW;
    this.sidePanelW = max(180, width - worldViewW);
    this.viewportH = viewportH;
    minimap = new Minimap(sidePanelX + 24, 124, sidePanelW - 48, 170);
    buildButtonsY = 430;
  }

  void render(GameState state) {
    textAlign(LEFT, TOP);
    int panelMargin = 10;
    int panelX = sidePanelX + panelMargin;
    int panelW = sidePanelW - panelMargin * 2;
    int y = 12;
    float outerChamfer = 10;
    float innerChamfer = 5;

    noStroke();
    fill(14, 14, 14);
    rect(sidePanelX, 0, sidePanelW, viewportH);

    // Outer metal shell (chamfered)
    drawChamferFill(panelX, y, panelW, viewportH - y - 10, outerChamfer, color(32, 32, 32));
    drawChamferStroke(panelX, y, panelW, viewportH - y - 10, outerChamfer, color(140, 140, 140), 2);
    drawChamferStroke(panelX + 2, y + 2, panelW - 4, viewportH - y - 14, outerChamfer - 1, color(55, 55, 55), 1);

    drawCornerRivets(panelX, y, panelW, viewportH - y - 10, outerChamfer);

    // Top icon bar
    int topBarH = 34;
    int bx = panelX + 10;
    int by = y + 10;
    int bw = panelW - 20;
    drawChamferFill(bx, by, bw, topBarH, innerChamfer, color(24, 24, 24));
    drawChamferStroke(bx, by, bw, topBarH, innerChamfer, color(88, 88, 88), 1);

    fill(230);
    textSize(15);
    text("$", bx + 14, by + 9);
    text("W", bx + 44, by + 9);
    text("P", bx + 74, by + 9);
    text("RTS", bx + bw * 0.5 - 16, by + 9);
    text("G", bx + bw - 24, by + 9);

    y += topBarH + 22;

    // Main tactical display zone
    int tacticalH = 260;
    int tx = panelX + 10;
    int ty = y;
    int tw = panelW - 20;
    drawChamferFill(tx, ty, tw, tacticalH, innerChamfer + 1, color(10, 10, 10));
    drawChamferStroke(tx, ty, tw, tacticalH, innerChamfer + 1, color(72, 72, 72), 1);

    minimap.x = tx + 14;
    minimap.y = ty + 16;
    minimap.w = tw - 28;
    minimap.h = 118;

    minimap.render(state.map, state.camera, state.units, state.buildings);

    int contentX = tx + 14;
    int contentW = tw - 28;
    int infoY = minimap.y + minimap.h + 12;
    int lineH = 16;
    fill(230);
    textSize(12);
    text("Faction: " + state.activeFaction, contentX, infoY);
    infoY += lineH;
    text("Credits: " + state.resources.credits + "   Units: " + state.selectedUnits.size(), contentX, infoY);
    infoY += lineH;
    text("Order: " + state.orderLabel + "   BuildQ: " + state.buildSystem.queuedCount(), contentX, infoY);
    infoY += lineH;
    if (state.selectedUnits.size() == 1) {
      Unit su = state.selectedUnits.get(0);
      if (su.faction == Faction.NEUTRAL) {
        fill(255, 200, 140);
        text("AI [NEUTRAL]: " + su.aiDebugStateLabel(), contentX, infoY);
        infoY += lineH;
        fill(230);
      }
    }
    fill(190);
    text("A:" + (state.attackMoveArmed ? "ON" : "OFF") + "  L:" + (state.hardCursorLock ? "ON" : "OFF") + "  P:" + (state.debugShowPaths ? "ON" : "OFF"), contentX, infoY);
    infoY += lineH;
    text("LMB Select/Place  RMB Move/Attack", contentX, infoY);
    infoY += lineH + 4;

    float p = state.buildSystem.currentProgress01();
    if (p > 0) {
      fill(20, 20, 20);
      rect(contentX, infoY, contentW, 10);
      fill(80, 230, 110);
      rect(contentX, infoY, contentW * p, 10);
      fill(220);
      infoY += 12;
      text("Constructing: " + int(p * 100) + "%", contentX, infoY);
      infoY += lineH;
    }

    y += tacticalH + 12;

    // Bottom command tabs
    int tabsH = 30;
    int tabx = panelX + 10;
    int tabw = panelW - 20;
    drawChamferFill(tabx, y, tabw, tabsH, innerChamfer, color(22, 22, 22));
    drawChamferStroke(tabx, y, tabw, tabsH, innerChamfer, color(80, 80, 80), 1);

    fill(230, 210, 90);
    textSize(16);
    text("B", tabx + 14, y + 7);
    fill(90, 170, 255);
    text("U", tabx + 44, y + 7);
    fill(255, 120, 120);
    text("P", tabx + 74, y + 7);
    fill(190);
    textSize(11);
    text("Blueprints", tabx + 108, y + 9);
    y += tabsH + 10;

    buildButtonsY = y;
    buildGridX = panelX + 12;
    buildCellW = int((panelW - 28 - buildButtonGap * (buildButtonCols - 1)) / float(buildButtonCols));
    renderBuildButtons(state);
    if (state.buildSystem.lastFailReason.length() > 0) {
      fill(255, 130, 130);
      textSize(11);
      text("Build error: " + state.buildSystem.lastFailReason, panelX + 14, buildButtonsY - 18);
    }
  }

  void drawChamferFill(float x, float y, float w, float h, float c, int col) {
    c = constrain(c, 2, min(w, h) * 0.35);
    noStroke();
    fill(col);
    beginShape();
    vertex(x + c, y);
    vertex(x + w - c, y);
    vertex(x + w, y + c);
    vertex(x + w, y + h - c);
    vertex(x + w - c, y + h);
    vertex(x + c, y + h);
    vertex(x, y + h - c);
    vertex(x, y + c);
    endShape(CLOSE);
  }

  void drawChamferStroke(float x, float y, float w, float h, float c, int col, float sw) {
    c = constrain(c, 2, min(w, h) * 0.35);
    noFill();
    stroke(col);
    strokeWeight(sw);
    beginShape();
    vertex(x + c, y);
    vertex(x + w - c, y);
    vertex(x + w, y + c);
    vertex(x + w, y + h - c);
    vertex(x + w - c, y + h);
    vertex(x + c, y + h);
    vertex(x, y + h - c);
    vertex(x, y + c);
    endShape(CLOSE);
  }

  void drawCornerRivets(float x, float y, float w, float h, float c) {
    noStroke();
    fill(90, 90, 90);
    float inset = max(6, c * 0.45);
    ellipse(x + inset, y + inset, 5, 5);
    ellipse(x + w - inset, y + inset, 5, 5);
    ellipse(x + inset, y + h - inset, 5, 5);
    ellipse(x + w - inset, y + h - inset, 5, 5);
    fill(55, 55, 55);
    ellipse(x + inset, y + inset, 2, 2);
    ellipse(x + w - inset, y + inset, 2, 2);
    ellipse(x + inset, y + h - inset, 2, 2);
    ellipse(x + w - inset, y + h - inset, 2, 2);
  }

  void renderBlueprintThumb(BuildingDef def, int bx, int by, int bw, int bh) {
    drawChamferFill(bx, by, bw, bh, 3, color(18, 18, 18));
    drawChamferStroke(bx, by, bw, bh, 3, color(55, 55, 55), 1);

    int h = def.id.hashCode();
    int r = 70 + (abs(h) % 40);
    int g = 75 + (abs(h >> 8) % 35);
    int b = 65 + (abs(h >> 16) % 30);

    noStroke();
    if (def.tileW >= 3) {
      fill(r, g, b);
      quad(bx + 8, by + bh - 14, bx + bw - 10, by + bh - 18, bx + bw - 6, by + bh - 6, bx + 10, by + bh - 4);
      fill(min(255, r + 25), min(255, g + 25), min(255, b + 20));
      rect(bx + bw - 14, by + 8, 7, bh - 26);
      fill(40, 42, 38);
      rect(bx + bw - 13, by + 10, 4, 5);
    } else {
      fill(r, g, b);
      rect(bx + 8, by + bh - 16, bw - 16, 11);
      fill(min(255, r + 30), min(255, g + 28), min(255, b + 22));
      rect(bx + 14, by + bh - 22, bw - 28, 9);
      fill(55, 60, 52);
      rect(bx + bw * 0.5 - 3, by + bh - 26, 6, 5);
    }
  }

  boolean isPointInUI(int mx, int my) {
    return mx >= sidePanelX || minimap.contains(mx, my);
  }

  void renderBuildButtons(GameState state) {
    float cellChamfer = 4;
    for (int i = 0; i < state.buildSystem.defs.size(); i++) {
      BuildingDef def = state.buildSystem.defs.get(i);
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      boolean selected = i == state.buildSystem.selectedIndex;

      int thumbW = min(50, max(36, int(buildCellW * 0.42)));
      int thumbH = buildButtonH - 10;
      int thumbX = x + 6;
      int thumbY = y + 5;
      int textX = thumbX + thumbW + 8;

      int baseFill = selected ? color(78, 108, 72) : color(48, 48, 48);
      drawChamferFill(x, y, buildCellW, buildButtonH, cellChamfer, baseFill);
      drawChamferStroke(x, y, buildCellW, buildButtonH, cellChamfer, selected ? color(130, 240, 130) : color(70, 70, 70), selected ? 2 : 1);

      renderBlueprintThumb(def, thumbX, thumbY, thumbW, thumbH);

      fill(240);
      textSize(11);
      text(def.id.toUpperCase(), textX, y + 8);
      fill(200);
      text("$" + def.cost, textX, y + 24);
      fill(175);
      text(def.tileW + " x " + def.tileH, textX, y + 38);
    }
  }

  boolean handleClick(GameState state, int mx, int my) {
    if (minimap.contains(mx, my)) {
      return false;
    }
    for (int i = 0; i < state.buildSystem.defs.size(); i++) {
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      if (mx >= x && mx <= x + buildCellW && my >= y && my <= y + buildButtonH) {
        state.buildSystem.selectIndex(i);
        state.buildSystem.lastFailReason = "";
        return true;
      }
    }
    return mx >= sidePanelX;
  }
}
