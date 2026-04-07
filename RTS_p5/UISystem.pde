class UISystem {
  int sidePanelX;
  int sidePanelW;
  int viewportH;
  Minimap minimap;
  int buildButtonsY;
  int buildButtonH = 24;
  int buildButtonGap = 8;

  UISystem(int worldViewW, int viewportH) {
    this.sidePanelX = worldViewW;
    this.sidePanelW = max(180, width - worldViewW);
    this.viewportH = viewportH;
    minimap = new Minimap(sidePanelX + 16, 24, sidePanelW - 32, 180);
    buildButtonsY = 430;
  }

  void render(GameState state) {
    textAlign(LEFT, TOP);
    noStroke();
    fill(34, 30, 22);
    rect(sidePanelX, 0, sidePanelW, viewportH);

    fill(210, 185, 120);
    textSize(16);
    text("RTS MVP", sidePanelX + 16, 8);

    minimap.render(state.map, state.camera, state.units, state.buildings);

    int panelY = 220;
    int contentX = sidePanelX + 18;
    int contentW = sidePanelW - 56;
    int y = panelY + 12;
    int lineH = 20;
    fill(40, 36, 28);
    rect(sidePanelX + 10, panelY, sidePanelW - 20, viewportH - panelY - 10);
    fill(230);
    textSize(13);
    text("Faction: " + state.activeFaction, contentX, y);
    y += lineH;
    text("Credits: " + state.resources.credits, contentX, y);
    y += lineH;
    text("Selected: " + state.selectedUnits.size(), contentX, y);
    y += lineH;
    if (state.selectedUnits.size() == 1) {
      Unit su = state.selectedUnits.get(0);
      if (su.faction == Faction.NEUTRAL) {
        fill(255, 200, 140);
        text("AI [NEUTRAL]: " + su.aiDebugStateLabel(), contentX, y);
        y += lineH;
        fill(230);
      }
    }
    text("Build Mode [B]: " + (state.buildSystem.active ? "ON" : "OFF"), contentX, y);
    y += lineH;
    text("Build Queue: " + state.buildSystem.queuedCount(), contentX, y);
    y += lineH;
    text("Last Order: " + state.orderLabel, contentX, y);
    y += lineH;
    text("A-Mode: " + (state.attackMoveArmed ? "ARMED" : "OFF"), contentX, y);
    y += lineH;
    text("CursorLock [L]: " + (state.hardCursorLock ? "ON" : "OFF"), contentX, y);
    y += lineH;
    text("Paths [P]: " + (state.debugShowPaths ? "ON" : "OFF"), contentX, y);
    y += lineH + 6;

    fill(200);
    text("LMB: Select / Place", contentX, y);
    y += lineH;
    text("RMB: Move / Attack", contentX, y);
    y += lineH;
    text("A + Click: AttackMove", contentX, y);
    y += lineH + 8;

    float p = state.buildSystem.currentProgress01();
    if (p > 0) {
      fill(20, 20, 20);
      rect(contentX, y, contentW, 10);
      fill(80, 230, 110);
      rect(contentX, y, contentW * p, 10);
      fill(220);
      y += 14;
      text("Constructing: " + int(p * 100) + "%", contentX, y);
      y += lineH + 4;
    }

    buildButtonsY = y + 4;
    renderBuildButtons(state);
    if (state.buildSystem.lastFailReason.length() > 0) {
      fill(255, 130, 130);
      text("Build error: " + state.buildSystem.lastFailReason, contentX, buildButtonsY - 22);
    }
  }

  boolean isPointInUI(int mx, int my) {
    return mx >= sidePanelX || minimap.contains(mx, my);
  }

  void renderBuildButtons(GameState state) {
    fill(220);
    text("Blueprints", sidePanelX + 18, buildButtonsY - 24);
    for (int i = 0; i < state.buildSystem.defs.size(); i++) {
      BuildingDef def = state.buildSystem.defs.get(i);
      int y = buildButtonsY + i * (buildButtonH + buildButtonGap);
      boolean selected = i == state.buildSystem.selectedIndex;

      if (selected) {
        fill(95, 120, 85);
      } else {
        fill(65, 58, 45);
      }
      noStroke();
      rect(sidePanelX + 18, y, sidePanelW - 56, buildButtonH);
      fill(230);
      text(def.id + "  $" + def.cost + "  " + def.tileW + "x" + def.tileH, sidePanelX + 24, y + 4);
    }
  }

  boolean handleClick(GameState state, int mx, int my) {
    if (minimap.contains(mx, my)) {
      return false;
    }
    for (int i = 0; i < state.buildSystem.defs.size(); i++) {
      int y = buildButtonsY + i * (buildButtonH + buildButtonGap);
      if (mx >= sidePanelX + 18 && mx <= sidePanelX + sidePanelW - 38 && my >= y && my <= y + buildButtonH) {
        state.buildSystem.selectIndex(i);
        state.buildSystem.lastFailReason = "";
        return true;
      }
    }
    return mx >= sidePanelX;
  }
}
