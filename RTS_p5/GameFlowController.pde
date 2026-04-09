class GameFlowController {
  void checkWinCondition(GameState gs) {
    if (gs.gameEnded || gs.map == null) return;
    boolean playerAlive = gs.countFactionUnits(Faction.PLAYER) + gs.countFactionBuildings(Faction.PLAYER) > 0;
    boolean enemyAlive = gs.countFactionUnits(Faction.ENEMY) + gs.countFactionBuildings(Faction.ENEMY) > 0;
    if (!playerAlive || !enemyAlive) {
      gs.gameEnded = true;
      if (!playerAlive && !enemyAlive) {
        gs.gameResult = "DRAW";
      } else if (!playerAlive) {
        gs.gameResult = "DEFEAT";
      } else {
        gs.gameResult = "VICTORY";
      }
      gs.orderLabel = tr("order.gameOver");
      gs.buildSystem.active = false;
    }
  }

  void renderGameEndOverlay(GameState gs) {
    gs.gameEndHitButtons.clear();
    fill(0, 0, 0, 140);
    rect(0, 0, gs.worldViewW, gs.screenH);

    float cx = gs.worldViewW * 0.5;
    float boxW = min(440, gs.worldViewW - 36);
    float boxH = 210;
    float bx = cx - boxW * 0.5;
    float by = gs.screenH * 0.5 - boxH * 0.5;

    gs.ui.uiWidgets.drawChamferFill(bx, by, boxW, boxH, 10, color(28, 30, 34));
    gs.ui.uiWidgets.drawChamferStroke(bx, by, boxW, boxH, 10, color(130, 140, 155), 2);
    gs.ui.uiWidgets.drawCornerRivets(bx, by, boxW, boxH, 10);

    fill(255);
    textAlign(CENTER, CENTER);
    textSize(26);
    String title = gs.gameResult;
    if ("DEFEAT".equals(gs.gameResult)) title = tr("overlay.defeat");
    else if ("VICTORY".equals(gs.gameResult)) title = tr("overlay.victory");
    else if ("DRAW".equals(gs.gameResult)) title = tr("overlay.draw");
    text(title, cx, by + 38);
    textSize(13);
    fill(200);
    text(tr("overlay.desc"), cx, by + 74);

    float btnW = 148;
    float btnH = 42;
    float gap = 16;
    float btnY = by + boxH - 58;

    UiHitButton replay = new UiHitButton();
    replay.x = cx - btnW - gap * 0.5;
    replay.y = btnY;
    replay.w = btnW;
    replay.h = btnH;
    replay.chamfer = 5;
    replay.label = tr("overlay.replay");
    replay.sublabel = tr("overlay.replay");
    replay.actionId = "end:replay";
    replay.style = 3;
    replay.enabled = true;
    replay.hovered = mouseX >= replay.x && mouseX <= replay.x + replay.w && mouseY >= replay.y && mouseY <= replay.y + replay.h;
    gs.gameEndHitButtons.add(replay);
    gs.ui.uiWidgets.drawHitButton(replay);

    UiHitButton menu = new UiHitButton();
    menu.x = gap * 0.5 + cx;
    menu.y = btnY;
    menu.w = btnW;
    menu.h = btnH;
    menu.chamfer = 5;
    menu.label = tr("overlay.menu");
    menu.sublabel = tr("overlay.menu");
    menu.actionId = "end:menu";
    menu.style = 3;
    menu.enabled = true;
    menu.hovered = mouseX >= menu.x && mouseX <= menu.x + menu.w && mouseY >= menu.y && mouseY <= menu.y + menu.h;
    gs.gameEndHitButtons.add(menu);
    gs.ui.uiWidgets.drawHitButton(menu);

    textAlign(LEFT, TOP);
  }

  void handleGameEndOverlayClick(GameState gs, int mx, int my, int button) {
    if (button != LEFT) return;
    for (int i = gs.gameEndHitButtons.size() - 1; i >= 0; i--) {
      UiHitButton b = gs.gameEndHitButtons.get(i);
      if (!b.enabled || !gs.ui.uiWidgets.hitContains(b, mx, my)) continue;
      if ("end:replay".equals(b.actionId)) {
        gs.startNewGame();
        return;
      }
      if ("end:menu".equals(b.actionId)) {
        gs.pendingReturnToMenu = true;
        gs.gameEnded = false;
        gs.shutdownSessionForMenu();
        return;
      }
    }
  }
}
