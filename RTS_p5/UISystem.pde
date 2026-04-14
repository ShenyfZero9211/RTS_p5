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
  int hoveredBuildIndex = -1;
  int armedBuildIndex = -1;
  int pressedBuildIndex = -1;
  int hoveredTrainIndex = -1;
  int pressedTrainIndex = -1;
  String pendingActionId = "";
  float pressedFlashTimer = 0;
  int sellBtnX;
  int sellBtnY;
  int sellBtnW = 72;
  int sellBtnH = 36;
  boolean sellBtnVisible = false;
  UiWidgets uiWidgets = new UiWidgets();
  ArrayList<UiHitButton> frameHitButtons = new ArrayList<UiHitButton>();
  float infoScroll = 0;
  float infoMaxScroll = 0;
  float infoScrollStep = 18;
  int infoClipX = 0;
  int infoClipY = 0;
  int infoClipW = 0;
  int infoClipH = 0;
  String infoContextKey = "";

  UISystem(int worldViewW, int viewportH) {
    this.sidePanelX = worldViewW;
    this.sidePanelW = max(180, width - worldViewW);
    this.viewportH = viewportH;
    minimap = new Minimap(sidePanelX + 24, 120, sidePanelW - 48, 200);
    buildButtonsY = 430;
  }

  void render(GameState state) {
    frameHitButtons.clear();
    textAlign(LEFT, TOP);
    sidePanelW = width - sidePanelX;
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

    uiWidgets.drawCornerRivets(panelX, y, panelW, viewportH - y - 10, outerChamfer);

    // Top icon bar
    int topBarH = 34;
    int bx = panelX + 10;
    int by = y + 10;
    int bw = panelW - 20;
    drawChamferFill(bx, by, bw, topBarH, innerChamfer, color(24, 24, 24));
    drawChamferStroke(bx, by, bw, topBarH, innerChamfer, color(88, 88, 88), 1);

    fill(230);
    textSize(15);
    text("W", bx + 14, by + 9);
    text("P", bx + 44, by + 9);
    text("RTS", bx + bw * 0.5 - 16, by + 9);
    text("G", bx + bw - 24, by + 9);

    y += topBarH + 22;

    // Main tactical display zone
    int tacticalH = int(constrain(viewportH * 0.40, 270, 360));
    int tx = panelX + 10;
    int ty = y;
    int tw = panelW - 20;
    drawChamferFill(tx, ty, tw, tacticalH, innerChamfer + 1, color(10, 10, 10));
    drawChamferStroke(tx, ty, tw, tacticalH, innerChamfer + 1, color(72, 72, 72), 1);

    minimap.x = tx + 14;
    minimap.y = ty + 16;
    minimap.w = tw - 28;
    minimap.h = int(constrain(tacticalH * 0.52, 138, 192));

    minimap.render(state.map, state.camera, state.units, state.buildings, state);

    int contentX = tx + 14;
    int contentW = tw - 28;
    int infoY = minimap.y + minimap.h + 12;
    int infoClipTop = infoY;
    int infoClipH = (int) max(40f, (float) (ty + tacticalH - infoClipTop - 8));
    infoClipX = contentX;
    infoClipY = infoClipTop;
    infoClipW = contentW;
    this.infoClipH = infoClipH;
    sellBtnVisible = false;

    String ctx = "none";
    if (state.selectedBuilding != null) {
      ctx = "b:" + state.selectedBuilding.buildingType + ":" + state.selectedBuilding.hp;
    } else if (state.selectedUnits.size() == 1) {
      Unit su = state.selectedUnits.get(0);
      ctx = "u:" + su.unitType + ":" + su.hp;
    } else {
      ctx = "g:" + state.selectedUnits.size();
    }
    if (!ctx.equals(infoContextKey)) {
      infoContextKey = ctx;
      infoScroll = 0;
    }

    uiWidgets.pushClipRect(contentX, infoClipTop, contentW, infoClipH);
    float contentStartY = infoY - infoScroll;
    float cy = contentStartY;
    fill(230);
    cy = uiWidgets.drawLineClamped(tr("ui.faction") + ": " + state.activeFaction, contentX, cy, contentW, 12);
    ResourcePool pool = state.resourcePoolForFaction(state.activeFaction);
    if (pool != null) {
      cy = uiWidgets.drawLineClamped(tr("ui.creditsCap") + ": " + pool.credits + "/" + pool.creditCap, contentX, cy, contentW, 12);
    }
    cy = uiWidgets.drawLineClamped(tr("ui.supply") + ": " + state.usedSupplyForFaction(state.activeFaction) + "/" + state.supplyCapForFaction(state.activeFaction), contentX, cy, contentW, 12);
    cy = uiWidgets.drawLineClamped(tr("ui.unitsSelected") + ": " + state.selectedUnits.size(), contentX, cy, contentW, 12);
    cy = uiWidgets.drawLineClamped(tr("ui.order") + ": " + state.orderLabel + "   " + tr("ui.buildQueue") + ": " + state.buildSystem.queuedCount(), contentX, cy, contentW, 12);
    if (state.enemyAiDebug && state.enemyAi != null) {
      fill(180, 210, 255);
      cy = uiWidgets.drawLineClamped(tr("ui.enemyAi") + ": " + state.enemyAi.phaseLabel() + "  $" + state.enemyResources.credits, contentX, cy, contentW, 12);
      fill(160, 190, 220);
      cy = uiWidgets.drawLineClamped(tr("ui.waveTimer") + ": " + nf(state.enemyAi.attackTimer, 1, 1) + "  " + tr("ui.last") + ": " + state.enemyAi.lastAction, contentX, cy, contentW, 12);
      fill(230);
    }
    if (state.benchmarkScenarioActive) {
      if (state.benchmarkReinforceFlashTimer > 0) {
        fill(255, 205, 110);
      } else {
        fill(185, 205, 225);
      }
      cy = uiWidgets.drawLineClamped(
        "BENCH " + state.benchmarkIntensity.toUpperCase() +
        "  wave#" + state.benchmarkWaveSerial +
        "  next " + nf(max(0, state.benchmarkReinforceTimer), 1, 1) + "s",
        contentX, cy, contentW, 12
      );
      cy = uiWidgets.drawLineClamped(
        "Reinforce  P+" + state.benchmarkLastPlayerReinforce +
        "  E+" + state.benchmarkLastEnemyReinforce,
        contentX, cy, contentW, 12
      );
      if (game != null && game.benchmarkRuntime != null && game.benchmarkRuntime.isManualControlActive()) {
        fill(255, 220, 120);
        cy = uiWidgets.drawLineClamped(
          "BENCH MANUAL  " + game.benchmarkRuntime.manualEndKey + " finish  remain " + nf(game.benchmarkRuntime.remainingSeconds(), 1, 1) + "s",
          contentX, cy, contentW, 12
        );
        cy = uiWidgets.drawLineClamped(
          "Q = reinforce wave   W = auto frontline " + (game.benchmarkRuntime.manualAutoFrontlineRuntime ? "ON" : "OFF"),
          contentX, cy, contentW, 12
        );
      }
      fill(230);
    }
    if (state.selectedBuilding != null) {
      Building sb = state.selectedBuilding;
      BuildingDef bdef = state.getBuildingDef(sb.buildingType);
      fill(210, 235, 255);
      cy = uiWidgets.drawLineClamped(tr("ui.building") + ": " + sb.buildingType.toUpperCase(), contentX, cy, contentW, 12);
      fill(200);
      cy = uiWidgets.drawLineClamped("HP: " + sb.hp + " / " + max(1, sb.maxHp) + "   " + sb.tileW + "x" + sb.tileH, contentX, cy, contentW, 12);
      if (bdef != null) {
        cy = uiWidgets.drawLineClamped(tr("ui.category") + ": " + bdef.category + "   Time: " + nf(bdef.buildTime, 1, 1), contentX, cy, contentW, 12);
        if (bdef.supplyCapBonus > 0 || bdef.creditCapBonus > 0) {
          cy = uiWidgets.drawLineClamped(tr("ui.supply") + " +" + bdef.supplyCapBonus + "   " + tr("ui.creditsCap") + " +" + bdef.creditCapBonus, contentX, cy, contentW, 12);
        }
      }
      fill(230);
      if (state.canSellSelectedBuilding() && bdef != null) {
        int refund = max(0, int(bdef.cost * bdef.sellRefundRatio));
        cy = uiWidgets.drawLineClamped(tr("ui.sellRefund") + " ~$" + refund + "  [Del]", contentX, cy, contentW, 12);
        sellBtnX = contentX;
        sellBtnY = (int) (cy + 4);
        sellBtnVisible = true;
        UiHitButton sellHit = new UiHitButton();
        sellHit.x = sellBtnX;
        sellHit.y = sellBtnY;
        sellHit.w = sellBtnW;
        sellHit.h = sellBtnH;
        sellHit.chamfer = 4;
        sellHit.label = tr("ui.sell");
        sellHit.sublabel = "$" + refund;
        sellHit.sublabel2 = "";
        sellHit.actionId = "sell";
        sellHit.style = 2;
        sellHit.enabled = true;
        sellHit.hovered = mouseX >= sellHit.x && mouseX <= sellHit.x + sellHit.w && mouseY >= sellHit.y && mouseY <= sellHit.y + sellHit.h;
        frameHitButtons.add(sellHit);
        uiWidgets.drawHitButton(sellHit);
        textAlign(LEFT, TOP);
        cy = sellBtnY + sellBtnH + 8;
      }
    } else if (state.selectedUnits.size() == 1) {
      Unit su = state.selectedUnits.get(0);
      fill(210, 235, 255);
      cy = uiWidgets.drawLineClamped(tr("ui.unit") + ": " + unitTypeLabel(su.unitType), contentX, cy, contentW, 12);
      fill(200);
      cy = uiWidgets.drawLineClamped("HP: " + su.hp + "   " + su.unitType, contentX, cy, contentW, 12);
      cy = uiWidgets.drawLineClamped("ATK " + int(su.attackDamage) + "  RNG " + int(su.attackRange) + "  SPD " + int(su.speed), contentX, cy, contentW, 12);
      if (su.canHarvest) {
        cy = uiWidgets.drawLineClamped("Harvest cargo " + su.cargoGold + "  m" + su.harvestMode, contentX, cy, contentW, 12);
      }
      if (su.faction == Faction.NEUTRAL || su.faction == Faction.ENEMY) {
        fill(255, 200, 140);
        cy = uiWidgets.drawLineClamped("AI: " + su.aiDebugStateLabel(), contentX, cy, contentW, 12);
      }
      fill(230);
    } else if (state.selectedUnits.size() > 1) {
      int miners = 0;
      int rifles = 0;
      int rockets = 0;
      for (Unit u : state.selectedUnits) {
        if (u.unitType.equals("miner")) {
          miners++;
        } else if (u.unitType.equals("rifleman")) {
          rifles++;
        } else if (u.unitType.equals("rocketeer")) {
          rockets++;
        }
      }
      fill(210, 235, 255);
      cy = uiWidgets.drawLineClamped(tr("ui.group") + ": " + state.selectedUnits.size(), contentX, cy, contentW, 12);
      fill(200);
      String[] lines = {
        "Miner " + miners + "   Rifle " + rifles + "   Rocket " + rockets
      };
      cy = uiWidgets.drawList(contentX, cy, contentW, 15, lines, 0, 4, 12);
      fill(230);
    }
    fill(190);
    cy = uiWidgets.drawLineClamped("A:" + (state.attackMoveArmed ? "ON" : "OFF") + "  L:" + (state.hardCursorLock ? "ON" : "OFF") + "  P:" + (state.debugShowPaths ? "ON" : "OFF"), contentX, cy, contentW, 11);
    cy = uiWidgets.drawTextBlock(tr("ui.hint.controls"), contentX, cy, contentW, infoClipTop + infoClipH - cy - 2, 11, 14);
    uiWidgets.popClipRect();
    float infoContentH = max(0, cy - contentStartY);
    infoMaxScroll = max(0, infoContentH - infoClipH + 6);
    infoScroll = constrain(infoScroll, 0, infoMaxScroll);
    infoY = (int) max((float) infoY, cy) + 4;
    if (infoMaxScroll > 0.5) {
      float trackX = contentX + contentW - 5;
      float trackY = infoClipTop;
      float trackH = infoClipH;
      noStroke();
      fill(24, 28, 32, 180);
      rect(trackX, trackY, 4, trackH, 2);
      float thumbH = max(18, trackH * (trackH / max(trackH, infoContentH)));
      float thumbY = trackY + (trackH - thumbH) * (infoScroll / max(1, infoMaxScroll));
      fill(120, 145, 175, 220);
      rect(trackX, thumbY, 4, thumbH, 2);
    }
    y += tacticalH + 12;

    // Context command panel (StarCraft / C&C Generals: content follows selected structure)
    int cmdHeaderH = 26;
    int cmdx = panelX + 10;
    int cmdw = panelW - 20;
    drawChamferFill(cmdx, y, cmdw, cmdHeaderH, innerChamfer, color(26, 28, 32));
    drawChamferStroke(cmdx, y, cmdw, cmdHeaderH, innerChamfer, color(90, 98, 110), 1);
    fill(210, 218, 228);
    textSize(11);
    textAlign(LEFT, CENTER);
    if (state.selectedStructureOffersBuildMenu()) {
      text(tr("ui.construct") + "  —  " + state.selectedBuilding.buildingType.toUpperCase(), cmdx + 10, y + cmdHeaderH * 0.5);
    } else if (state.selectedStructureOffersTrainMenu()) {
      BuildingDef pd = state.getBuildingDef(state.selectedBuilding.buildingType);
      text(tr("ui.train") + "  —  " + (pd != null ? pd.id.toUpperCase() : "?"), cmdx + 10, y + cmdHeaderH * 0.5);
    } else {
      text(tr("ui.commands") + "  —  " + tr("ui.selectStructure"), cmdx + 10, y + cmdHeaderH * 0.5);
    }
    textAlign(LEFT, TOP);
    y += cmdHeaderH + 8;

    buildButtonsY = y;
    buildGridX = panelX + 12;
    buildButtonCols = panelW >= 300 ? 2 : 1;
    buildCellW = int((panelW - 28 - buildButtonGap * (buildButtonCols - 1)) / float(buildButtonCols));
    hoveredBuildIndex = -1;
    hoveredTrainIndex = -1;
    if (state.selectedStructureOffersBuildMenu()) {
      hoveredBuildIndex = buildButtonIndexAt(mouseX, mouseY, state);
      renderContextBuildButtons(state);
    } else if (state.selectedStructureOffersTrainMenu()) {
      hoveredTrainIndex = trainButtonIndexAt(mouseX, mouseY, state);
      renderContextTrainButtons(state);
    } else {
      renderCommandPanelIdle(state, cmdx, buildButtonsY, cmdw);
    }
    if (state.buildSystem.lastFailReason.length() > 0 && state.selectedStructureOffersBuildMenu()) {
      fill(255, 130, 130);
      textSize(11);
      text(tr("ui.buildError") + ": " + state.buildSystem.lastFailReason, panelX + 14, buildButtonsY - 18);
    }
    if (state.showRuntimeProfiling) {
      int px = panelX + 12;
      int py = viewportH - 112;
      int pw = panelW - 24;
      int ph = 96;
      fill(8, 10, 14, 210);
      stroke(80, 110, 150, 200);
      rect(px, py, pw, ph, 6);
      noStroke();
      fill(200, 220, 240);
      textSize(10);
      textAlign(LEFT, TOP);
      text("FPS " + nf(frameRate, 1, 1) +
        " | Frame " + nf(state.profileFrameMs, 1, 2) + "ms", px + 8, py + 6);
      fill(165, 195, 220);
      text("Input " + nf(state.profileInputMs, 1, 2) +
        "  Build " + nf(state.profileBuildMs, 1, 2) +
        "  Units " + nf(state.profileUnitsMs, 1, 2), px + 8, py + 24);
      text("Fog " + nf(state.profileFogMs, 1, 2) +
        "  Combat " + nf(state.profileCombatMs, 1, 2) +
        "  AI " + nf(state.profileAiMs, 1, 2) +
        "  UI " + nf(state.profileUiMs, 1, 2), px + 8, py + 42);
      text("Steps fixed@" + state.profileStepHzLabel() + "  FogBudget " + nf(state.fogUpdateBudgetMs, 1, 1) + "ms", px + 8, py + 60);
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

  String unitTypeLabel(String id) {
    if (id.equals("miner")) {
      return "MINER";
    }
    if (id.equals("rifleman")) {
      return "RIFLEMAN";
    }
    if (id.equals("rocketeer")) {
      return "ROCKETEER";
    }
    return id.toUpperCase();
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

  int contextualBuildPaletteCount(GameState state) {
    if (!state.selectedStructureOffersBuildMenu()) {
      return 0;
    }
    int n = 0;
    for (int j = 0; j < state.buildSystem.defs.size(); j++) {
      if (!state.buildSystem.defs.get(j).isMainBase) {
        n++;
      }
    }
    return n;
  }

  BuildingDef contextualBuildDefAt(GameState state, int paletteIndex) {
    if (!state.selectedStructureOffersBuildMenu()) {
      return null;
    }
    int k = 0;
    for (int j = 0; j < state.buildSystem.defs.size(); j++) {
      BuildingDef d = state.buildSystem.defs.get(j);
      if (d.isMainBase) {
        continue;
      }
      if (k == paletteIndex) {
        return d;
      }
      k++;
    }
    return null;
  }

  int globalBuildIndexForPalette(GameState state, int paletteIndex) {
    int k = 0;
    for (int j = 0; j < state.buildSystem.defs.size(); j++) {
      BuildingDef d = state.buildSystem.defs.get(j);
      if (d.isMainBase) {
        continue;
      }
      if (k == paletteIndex) {
        return j;
      }
      k++;
    }
    return -1;
  }

  int contextualPaletteIndexForBuildingDef(GameState state, BuildingDef target) {
    if (target == null || target.isMainBase) {
      return -1;
    }
    int k = 0;
    for (int j = 0; j < state.buildSystem.defs.size(); j++) {
      BuildingDef d = state.buildSystem.defs.get(j);
      if (d.isMainBase) {
        continue;
      }
      if (d.id != null && d.id.equals(target.id)) {
        return k;
      }
      k++;
    }
    return -1;
  }

  void renderCommandPanelIdle(GameState state, int cmdx, int y, int cmdw) {
    int idleH = 100;
    drawChamferFill(cmdx, y, cmdw, idleH, 4, color(22, 22, 24));
    drawChamferStroke(cmdx, y, cmdw, idleH, 4, color(60, 60, 64), 1);
    fill(140, 150, 165);
    textSize(11);
    text(tr("ui.hint.idle1"), cmdx + 12, y + 14);
    text(tr("ui.hint.idle2"), cmdx + 12, y + 30);
    if (state.selectedUnits.size() > 0) {
      fill(175, 188, 205);
      text(tr("ui.hint.controls"), cmdx + 12, y + 82);
    }
  }

  void renderContextBuildButtons(GameState state) {
    float cellChamfer = 4;
    int n = contextualBuildPaletteCount(state);
    BuildingDef cur = state.buildSystem.selectedDef();
    int armedPalette = -1;
    if (state.buildSystem.active && cur != null && !cur.isMainBase) {
      armedPalette = contextualPaletteIndexForBuildingDef(state, cur);
    }
    for (int i = 0; i < n; i++) {
      BuildingDef def = contextualBuildDefAt(state, i);
      if (def == null) {
        continue;
      }
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      int thumbW = min(50, max(36, int(buildCellW * 0.42)));
      int thumbH = buildButtonH - 10;
      int thumbX = x + 6;
      int thumbY = y + 5;

      boolean armed = (state.buildSystem.active && armedPalette == i);
      boolean hovered = hoveredBuildIndex == i;
      boolean pressed = pressedBuildIndex == i;
      boolean unlocked = state.buildSystem.canBuildDefForFaction(def, state.buildings, state.activeFaction);

      UiHitButton hb = new UiHitButton();
      hb.x = x;
      hb.y = y;
      hb.w = buildCellW;
      hb.h = buildButtonH;
      hb.chamfer = cellChamfer;
      hb.actionId = "build:" + i;
      hb.style = 0;
      hb.enabled = unlocked;
      hb.hovered = hovered && unlocked;
      hb.pressed = pressed && unlocked;
      hb.emphasisArmed = armed && unlocked;
      hb.labelInsetX = (thumbX + thumbW + 8) - x;
      hb.label = def.id.toUpperCase();
      hb.sublabel = "$" + def.cost;
      hb.sublabel2 = def.tileW + " x " + def.tileH;
      frameHitButtons.add(hb);
      uiWidgets.drawHitButton(hb);

      renderBlueprintThumb(def, thumbX, thumbY, thumbW, thumbH);

      int queueCount = state.queuedBuildCountForDef(def.id, state.activeFaction);
      float progress = state.activeBuildProgressForDef(def.id, state.activeFaction);
      renderButtonProgress(x, y, buildCellW, buildButtonH, queueCount, progress);

      if (!unlocked) {
        fill(255, 120, 120);
        textSize(10);
        text(tr("ui.locked"), x + buildCellW - 44, y + 4);
      }
    }
  }

  boolean beginClick(GameState state, int mx, int my) {
    if (minimap.contains(mx, my)) {
      return false;
    }
    pendingActionId = "";
    for (int i = frameHitButtons.size() - 1; i >= 0; i--) {
      UiHitButton b = frameHitButtons.get(i);
      if (!b.enabled || !uiWidgets.hitContains(b, float(mx), float(my))) {
        continue;
      }
      pendingActionId = b.actionId;
      if (b.actionId.startsWith("train:")) {
        pressedTrainIndex = parseInt(b.actionId.substring(6));
      } else if (b.actionId.startsWith("build:")) {
        pressedBuildIndex = parseInt(b.actionId.substring(6));
      }
      return true;
    }
    return false;
  }

  boolean endClick(GameState state, int mx, int my) {
    String action = pendingActionId;
    pendingActionId = "";
    if (action == null || action.length() == 0) {
      return false;
    }
    boolean releasedOnSameButton = false;
    for (int i = frameHitButtons.size() - 1; i >= 0; i--) {
      UiHitButton b = frameHitButtons.get(i);
      if (!b.enabled || !uiWidgets.hitContains(b, float(mx), float(my))) {
        continue;
      }
      if (action.equals(b.actionId)) {
        releasedOnSameButton = true;
      }
      break;
    }
    if (!releasedOnSameButton) {
      return false;
    }
    if ("sell".equals(action)) {
      state.trySellSelectedBuilding();
      return true;
    }
    if (action.startsWith("train:")) {
      int tidx = parseInt(action.substring(6));
      BuildingDef bdef = state.getBuildingDef(state.selectedBuilding.buildingType);
      if (bdef != null && tidx >= 0 && tidx < bdef.trainableUnits.length) {
        pressedTrainIndex = tidx;
        state.trainUnitAtSelectedBuilding(bdef.trainableUnits[tidx]);
      }
      return true;
    }
    if (action.startsWith("build:")) {
      int idx = parseInt(action.substring(6));
      int g = globalBuildIndexForPalette(state, idx);
      if (g < 0) {
        return true;
      }
      BuildingDef def = state.buildSystem.defs.get(g);
      if (!state.buildSystem.canBuildDefForFaction(def, state.buildings, state.activeFaction)) {
        state.buildSystem.lastFailReason = "Need prerequisite";
        return true;
      }
      state.buildSystem.selectIndex(g);
      state.buildSystem.active = true;
      state.buildSystem.lastFailReason = "";
      state.orderLabel = tr("order.buildArmed");
      armedBuildIndex = idx;
      pressedBuildIndex = idx;
      pressedFlashTimer = 0;
      return true;
    }
    return false;
  }

  boolean onMouseWheel(float amount, int mx, int my) {
    if (mx < infoClipX || mx > infoClipX + infoClipW || my < infoClipY || my > infoClipY + infoClipH) {
      return false;
    }
    if (infoMaxScroll <= 0) {
      return true;
    }
    infoScroll = constrain(infoScroll + amount * infoScrollStep, 0, infoMaxScroll);
    return true;
  }

  boolean handleRightClickQueueCancel(GameState state, int mx, int my) {
    if (mx < sidePanelX) {
      return false;
    }
    for (int i = frameHitButtons.size() - 1; i >= 0; i--) {
      UiHitButton b = frameHitButtons.get(i);
      if (!uiWidgets.hitContains(b, float(mx), float(my))) {
        continue;
      }
      if (b.actionId.startsWith("train:")) {
        if (state.selectedBuilding == null) {
          return true;
        }
        int tidx = parseInt(b.actionId.substring(6));
        BuildingDef bdef = state.getBuildingDef(state.selectedBuilding.buildingType);
        if (bdef != null && bdef.trainableUnits != null && tidx >= 0 && tidx < bdef.trainableUnits.length) {
          state.cancelOneTrainJobForSelectedBuilding(bdef.trainableUnits[tidx]);
        }
        return true;
      }
      if (b.actionId.startsWith("build:")) {
        int idx = parseInt(b.actionId.substring(6));
        int g = globalBuildIndexForPalette(state, idx);
        if (g >= 0) {
          BuildingDef def = state.buildSystem.defs.get(g);
          state.cancelOneBuildJobByDef(def.id, state.activeFaction);
        }
        return true;
      }
      return true;
    }
    return mx >= sidePanelX;
  }

  int buildButtonIndexAt(int mx, int my, GameState state) {
    int n = contextualBuildPaletteCount(state);
    for (int i = 0; i < n; i++) {
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      if (mx >= x && mx <= x + buildCellW && my >= y && my <= y + buildButtonH) {
        return i;
      }
    }
    return -1;
  }

  void clearBuildButtonState() {
    hoveredBuildIndex = -1;
    armedBuildIndex = -1;
    pressedBuildIndex = -1;
    hoveredTrainIndex = -1;
    pressedTrainIndex = -1;
    pressedFlashTimer = 0;
  }

  void releaseBuildButtonPress() {
    pendingActionId = "";
    pressedBuildIndex = -1;
    pressedTrainIndex = -1;
    pressedFlashTimer = 0;
  }

  int trainButtonIndexAt(int mx, int my, GameState state) {
    BuildingDef bdef = state.selectedBuilding == null ? null : state.getBuildingDef(state.selectedBuilding.buildingType);
    if (bdef == null || bdef.trainableUnits == null) {
      return -1;
    }
    int rows = bdef.trainableUnits.length;
    for (int i = 0; i < rows; i++) {
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      if (mx >= x && mx <= x + buildCellW && my >= y && my <= y + buildButtonH) {
        return i;
      }
    }
    return -1;
  }

  String trainHotkeyLabel(int slot) {
    if (slot == 0) {
      return "Q";
    }
    if (slot == 1) {
      return "W";
    }
    if (slot == 2) {
      return "E";
    }
    return "";
  }

  void renderContextTrainButtons(GameState state) {
    BuildingDef bdef = state.getBuildingDef(state.selectedBuilding.buildingType);
    if (bdef == null || bdef.trainableUnits == null) {
      return;
    }
    float cellChamfer = 4;
    for (int i = 0; i < bdef.trainableUnits.length; i++) {
      String uid = bdef.trainableUnits[i];
      UnitDef def = state.getUnitDef(uid);
      if (def == null) {
        continue;
      }
      int col = i % buildButtonCols;
      int row = i / buildButtonCols;
      int x = buildGridX + col * (buildCellW + buildButtonGap);
      int y = buildButtonsY + row * (buildButtonH + buildButtonGap);
      boolean hovered = hoveredTrainIndex == i;
      boolean pressed = pressedTrainIndex == i;
      boolean canAfford = state.resources.canAfford(def.cost);
      boolean hasSupply = state.usedSupplyForFaction(state.activeFaction) + max(0, def.supplyCost) <= state.supplyCapForFaction(state.activeFaction);
      boolean unlocked = canAfford && hasSupply;
      String hk = trainHotkeyLabel(i);

      UiHitButton hb = new UiHitButton();
      hb.x = x;
      hb.y = y;
      hb.w = buildCellW;
      hb.h = buildButtonH;
      hb.chamfer = cellChamfer;
      hb.actionId = "train:" + i;
      hb.style = 1;
      hb.enabled = unlocked;
      hb.hovered = hovered && unlocked;
      hb.pressed = pressed && unlocked;
      hb.label = unitTypeLabel(uid);
      hb.sublabel = "$" + def.cost + (hk.length() > 0 ? "   [" + hk + "]" : "");
      hb.sublabel2 = "HP " + def.hp + "  RNG " + int(def.attackRange);
      frameHitButtons.add(hb);
      uiWidgets.drawHitButton(hb);

      int queueCount = state.queuedTrainCountForUnit(state.selectedBuilding, uid);
      float progress = state.activeTrainProgressForUnit(state.selectedBuilding, uid);
      renderButtonProgress(x, y, buildCellW, buildButtonH, queueCount, progress);

      if (!unlocked) {
        fill(255, 150, 130);
        textSize(10);
        text(canAfford ? tr("ui.lowSupply") : tr("ui.lowCredits"), x + buildCellW - 64, y + 4);
      }
    }
  }

  void renderButtonProgress(int x, int y, int w, int h, int queueCount, float progress01) {
    if (queueCount <= 0 && progress01 < 0) {
      return;
    }
    if (queueCount > 0) {
      fill(178, 205, 230);
      textSize(10);
      textAlign(RIGHT, TOP);
      text("Q" + queueCount, x + w - 6, y + 4);
      textAlign(LEFT, TOP);
    }
    if (progress01 >= 0) {
      int barX = x + 6;
      int barY = y + h - 7;
      int barW = w - 12;
      int barH = 4;
      noStroke();
      fill(40, 42, 46, 220);
      rect(barX, barY, barW, barH);
      fill(95, 220, 130);
      rect(barX, barY, int(barW * constrain(progress01, 0, 1)), barH);
      stroke(72, 82, 86);
      noFill();
      rect(barX, barY, barW, barH);
    }
  }
}
