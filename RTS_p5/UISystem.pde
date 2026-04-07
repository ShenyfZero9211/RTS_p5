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
    noStroke();
    fill(34, 30, 22);
    rect(sidePanelX, 0, sidePanelW, viewportH);

    fill(210, 185, 120);
    textSize(16);
    text("RTS MVP", sidePanelX + 16, 8);

    minimap.render(state.map, state.camera, state.units, state.buildings);

    int panelY = 220;
    fill(40, 36, 28);
    rect(sidePanelX + 10, panelY, sidePanelW - 20, viewportH - panelY - 10);
    fill(230);
    textSize(13);
    text("Faction: " + state.activeFaction, sidePanelX + 18, panelY + 10);
    text("Credits: " + state.resources.credits, sidePanelX + 18, panelY + 30);
    text("Selected: " + state.selectedUnits.size(), sidePanelX + 18, panelY + 48);
    text("Build Mode [B]: " + (state.buildSystem.active ? "ON" : "OFF"), sidePanelX + 18, panelY + 66);
    text("Build Queue: " + state.buildSystem.queuedCount(), sidePanelX + 18, panelY + 84);
    text("Last Order: " + state.orderLabel, sidePanelX + 18, panelY + 96);
    text("A-Mode: " + (state.attackMoveArmed ? "ARMED" : "OFF"), sidePanelX + 18, panelY + 108);
    text("CursorLock[L]: " + (state.hardCursorLock ? "ON" : "OFF"), sidePanelX + 18, panelY + 120);
    text("Paths[P]: " + (state.debugShowPaths ? "ON" : "OFF"), sidePanelX + 18, panelY + 132);
    text("LMB: Select / Place", sidePanelX + 18, panelY + 148);
    text("RMB: Move / Attack", sidePanelX + 18, panelY + 166);
    text("A + Click: AttackMove", sidePanelX + 18, panelY + 184);

    float p = state.buildSystem.currentProgress01();
    if (p > 0) {
      fill(20, 20, 20);
      rect(sidePanelX + 18, panelY + 200, sidePanelW - 56, 10);
      fill(80, 230, 110);
      rect(sidePanelX + 18, panelY + 200, (sidePanelW - 56) * p, 10);
      fill(220);
      text("Constructing: " + int(p * 100) + "%", sidePanelX + 18, panelY + 214);
    }

    renderBuildButtons(state);
    if (state.buildSystem.lastFailReason.length() > 0) {
      fill(255, 130, 130);
      text("Build error: " + state.buildSystem.lastFailReason, sidePanelX + 18, buildButtonsY - 18);
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
