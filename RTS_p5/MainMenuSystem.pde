import java.io.File;
import java.util.Collections;

/** Full-screen menu and lightweight settings (session overrides written to GameState before start). */
class MainMenuSystem {
  UiWidgets widgets = new UiWidgets();
  ArrayList<UiHitButton> menuHits = new ArrayList<UiHitButton>();
  UiDropdown langDropdown = new UiDropdown();
  /** "", "header", or "opt:0".."opt:2" — language UI activates on mouse release. */
  String pendingLangPick = "";
  String pendingMenuActionId = "";
  boolean inSettings = false;
  boolean pauseMenu = false;
  boolean inMapSelect = false;
  ArrayList<String> mapFileNames = new ArrayList<String>();
  int mapListScroll = 0;
  int mapListSelected = 0;
  final int mapListVisibleRows = 10;
  final int mapListRowH = 44;
  boolean mapListWheelRectValid = false;
  float mapListWheelX, mapListWheelY, mapListWheelW, mapListWheelH;
  float mapBoxX, mapBoxY, mapBoxW, mapBoxH;
  float mapRowAreaX, mapRowAreaY, mapRowAreaW, mapRowAreaH;
  float mapSbX;
  final int mapListScrollGutterW = 42;
  boolean mapListHoverForScroll = false;
  int menuLastPtrX = -999999;
  int menuLastPtrY = -999999;
  int mapScrollFocusPrimeMs = -999999;
  final int mapScrollFocusCooldownMs = 100;
  boolean mapListLayoutReady = false;
  int mapRowLastReleaseIdx = -1;
  int mapRowLastReleaseMs = 0;
  float mapScrTrackX, mapScrTrackY, mapScrTrackW, mapScrTrackH;
  float mapScrThumbY, mapScrThumbH;
  boolean mapScrollMetricsValid = false;
  boolean mapScrollThumbDrag = false;
  float mapScrollDragAnchorY = 0;
  boolean wantPlay = false;
  boolean wantResume = false;
  boolean wantExit = false;

  void update(float dt) {
  }

  boolean consumePlayRequest() {
    if (!wantPlay) {
      return false;
    }
    wantPlay = false;
    return true;
  }

  boolean consumeExitRequest() {
    if (!wantExit) {
      return false;
    }
    wantExit = false;
    return true;
  }

  void openPauseMenu() {
    pauseMenu = true;
    inSettings = false;
    inMapSelect = false;
    pendingLangPick = "";
    mapRowLastReleaseIdx = -1;
    mapRowLastReleaseMs = 0;
    mapListHoverForScroll = false;
    menuLastPtrX = -999999;
    menuLastPtrY = -999999;
    mapScrollThumbDrag = false;
    mapScrollMetricsValid = false;
  }

  boolean isMapJsonDataFile(String fileNameInData) {
    String path = sketchPath("data" + File.separator + fileNameInData);
    File f = new File(path);
    if (!f.isFile()) {
      return false;
    }
    JSONObject root = loadJSONObject(path);
    if (root == null) {
      return false;
    }
    if (!root.hasKey("rows") || !root.hasKey("width") || !root.hasKey("height") || !root.hasKey("tileSize")) {
      return false;
    }
    int w = root.getInt("width", -1);
    int h = root.getInt("height", -1);
    if (w < 1 || h < 1) {
      return false;
    }
    JSONArray rows = root.getJSONArray("rows");
    if (rows == null || rows.size() != h) {
      return false;
    }
    for (int yi = 0; yi < h; yi++) {
      String row = rows.getString(yi);
      if (row == null || row.length() != w) {
        return false;
      }
    }
    return true;
  }

  void refreshMapListFromData() {
    mapFileNames.clear();
    File dir = new File(sketchPath("data"));
    if (!dir.isDirectory()) {
      return;
    }
    File[] files = dir.listFiles();
    if (files == null) {
      return;
    }
    ArrayList<String> found = new ArrayList<String>();
    for (int i = 0; i < files.length; i++) {
      File f = files[i];
      if (f == null || !f.isFile()) {
        continue;
      }
      String name = f.getName();
      if (name.length() < 6 || !name.toLowerCase().endsWith(".json")) {
        continue;
      }
      if (!isMapJsonDataFile(name)) {
        continue;
      }
      found.add(name);
    }
    Collections.sort(found);
    for (int j = 0; j < found.size(); j++) {
      mapFileNames.add(found.get(j));
    }
    mapListScroll = 0;
    mapListSelected = 0;
    if (mapFileNames.size() > 0) {
      mapListSelected = 0;
    }
    ensureSelectedRowVisible();
  }

  int mapListMaxScroll() {
    return max(0, mapFileNames.size() - mapListVisibleRows);
  }

  void ensureSelectedRowVisible() {
    if (mapFileNames.size() <= 0) {
      return;
    }
    mapListSelected = constrain(mapListSelected, 0, mapFileNames.size() - 1);
    if (mapListSelected < mapListScroll) {
      mapListScroll = mapListSelected;
    }
    if (mapListSelected >= mapListScroll + mapListVisibleRows) {
      mapListScroll = mapListSelected - mapListVisibleRows + 1;
    }
    mapListScroll = constrain(mapListScroll, 0, mapListMaxScroll());
  }

  /** Single layout for map list box, row viewport, gutter; updates wheel hit rect. Call before draw or scroll. */
  void layoutMapSelectListPanelFromScreen() {
    mapListWheelRectValid = false;
    mapListLayoutReady = false;
    if (!inMapSelect || mapFileNames.size() <= 0) {
      return;
    }
    float pad = 22;
    float panelY = pad;
    float panelW = width - pad * 2;
    float cx = width * 0.5;
    float innerPad = 10;
    float listTotalW = min(panelW - pad * 4, 640);
    boolean showScroll = mapListMaxScroll() > 0;
    float gutter = showScroll ? mapListScrollGutterW + innerPad : innerPad * 0.5;
    mapBoxX = cx - listTotalW * 0.5;
    mapBoxY = panelY + 96;
    mapBoxW = listTotalW;
    mapBoxH = mapListRowH * mapListVisibleRows + 4 + innerPad * 2;
    mapRowAreaX = mapBoxX + innerPad;
    mapRowAreaY = mapBoxY + innerPad;
    mapRowAreaW = mapBoxW - innerPad * 2 - gutter;
    mapRowAreaH = mapListRowH * mapListVisibleRows + 4;
    mapSbX = mapRowAreaX + mapRowAreaW + innerPad;
    mapListWheelX = mapBoxX;
    mapListWheelY = mapBoxY;
    mapListWheelW = mapBoxW;
    mapListWheelH = mapBoxH;
    mapListWheelRectValid = true;
    mapListLayoutReady = true;
  }

  boolean pointInMapListScrollHit(float mx, float my) {
    if (!mapListWheelRectValid) {
      return false;
    }
    return mx >= mapListWheelX && mx <= mapListWheelX + mapListWheelW
      && my >= mapListWheelY && my <= mapListWheelY + mapListWheelH;
  }

  void onPointerMoveInMenu(int mx, int my) {
    menuLastPtrX = mx;
    menuLastPtrY = my;
    maybePrimeWheelFocusFromPointer(mx, my);
  }

  /** Fullscreen + AWT: wheel often only reaches the sketch after the drawing surface has focus (click does that). Prime on hover. */
  void maybePrimeWheelFocusFromPointer(int mx, int my) {
    if (!inMapSelect || mapFileNames.size() <= 0 || mapListMaxScroll() <= 0) {
      return;
    }
    layoutMapSelectListPanelFromScreen();
    if (!pointInMapListScrollHit(float(mx), float(my))) {
      return;
    }
    int now = millis();
    if (now - mapScrollFocusPrimeMs < mapScrollFocusCooldownMs) {
      return;
    }
    mapScrollFocusPrimeMs = now;
    tryRequestSketchFocus();
  }

  void maybePrimeWheelFocusWhileHoveringList() {
    if (!inMapSelect || mapFileNames.size() <= 0 || mapListMaxScroll() <= 0 || !mapListHoverForScroll) {
      return;
    }
    int now = millis();
    if (now - mapScrollFocusPrimeMs < mapScrollFocusCooldownMs) {
      return;
    }
    mapScrollFocusPrimeMs = now;
    tryRequestSketchFocus();
  }

  void onMouseWheel(GameEngine engine, float amount, int mx, int my) {
    if (!inMapSelect) {
      return;
    }
    if (mapListMaxScroll() <= 0) {
      return;
    }
    layoutMapSelectListPanelFromScreen();
    boolean over = pointInMapListScrollHit(float(mx), float(my))
      || pointInMapListScrollHit(float(mouseX), float(mouseY))
      || mapListHoverForScroll
      || pointInMapListScrollHit(float(menuLastPtrX), float(menuLastPtrY));
    if (!over) {
      return;
    }
    int step = amount > 0 ? 1 : (amount < 0 ? -1 : 0);
    if (step == 0) {
      return;
    }
    mapListScroll = constrain(mapListScroll + step, 0, mapListMaxScroll());
  }

  void tryRequestSketchFocus() {
    try {
      Object nat = surface.getNative();
      if (nat instanceof java.awt.Window) {
        java.awt.Window w = (java.awt.Window) nat;
        w.setFocusableWindowState(true);
        w.requestFocus();
        primeFocusInContainer(w);
      } else if (nat instanceof java.awt.Component) {
        java.awt.Component c = (java.awt.Component) nat;
        c.setFocusable(true);
        c.requestFocusInWindow();
      }
    }
    catch (RuntimeException ex) {
    }
  }

  void primeFocusInContainer(java.awt.Container root) {
    if (root == null) {
      return;
    }
    java.awt.Component[] kids = root.getComponents();
    for (int i = 0; i < kids.length; i++) {
      java.awt.Component k = kids[i];
      if (k == null || !k.isShowing()) {
        continue;
      }
      if (k.isFocusable()) {
        k.requestFocusInWindow();
      }
      if (k instanceof java.awt.Container) {
        primeFocusInContainer((java.awt.Container) k);
      }
    }
  }

  void drawMapListPanelChrome() {
    if (!mapListLayoutReady) {
      return;
    }
    noStroke();
    fill(16, 18, 24);
    rect(mapBoxX, mapBoxY, mapBoxW, mapBoxH, 8);
  }

  void computeMapScrollMetrics(float sbX, float listTop, float listH, float scrollBtnW, int totalMaps, int maxScroll) {
    mapScrollMetricsValid = false;
    if (maxScroll <= 0 || totalMaps <= 0) {
      return;
    }
    float trackX = sbX + 4;
    float trackY = listTop + 44;
    float trackW = scrollBtnW - 8;
    float trackH = listH - 88;
    mapScrTrackX = trackX;
    mapScrTrackY = trackY;
    mapScrTrackW = trackW;
    mapScrTrackH = trackH;
    float thumbH = max(26.f, trackH * min(1.f, (float) mapListVisibleRows / (float) totalMaps));
    float room = max(1.f, trackH - thumbH);
    float t = (float) mapListScroll / (float) maxScroll;
    mapScrThumbH = thumbH;
    mapScrThumbY = trackY + room * t;
    mapScrollMetricsValid = true;
  }

  boolean pointInMapScrollTrack(float mx, float my) {
    if (!mapScrollMetricsValid) {
      return false;
    }
    return mx >= mapScrTrackX && mx <= mapScrTrackX + mapScrTrackW
      && my >= mapScrTrackY && my <= mapScrTrackY + mapScrTrackH;
  }

  boolean pointInMapScrollThumb(float mx, float my) {
    if (!mapScrollMetricsValid) {
      return false;
    }
    return mx >= mapScrTrackX && mx <= mapScrTrackX + mapScrTrackW
      && my >= mapScrThumbY && my <= mapScrThumbY + mapScrThumbH;
  }

  void applyMapScrollFromTrackY(float my) {
    int maxS = mapListMaxScroll();
    if (maxS <= 0 || !mapScrollMetricsValid) {
      return;
    }
    float trackY = mapScrTrackY;
    float trackH = mapScrTrackH;
    float thumbH = mapScrThumbH;
    float room = max(1.f, trackH - thumbH);
    float thumbTop = constrain(my - thumbH * 0.5f, trackY, trackY + room);
    mapListScroll = (int) floor((thumbTop - trackY) / room * (float) maxS + 0.5f);
    mapListScroll = constrain(mapListScroll, 0, maxS);
  }

  void updateMapScrollThumbDrag(float my) {
    int maxS = mapListMaxScroll();
    if (!mapScrollThumbDrag || maxS <= 0 || !mapScrollMetricsValid) {
      return;
    }
    float trackY = mapScrTrackY;
    float trackH = mapScrTrackH;
    float thumbH = mapScrThumbH;
    float room = max(1.f, trackH - thumbH);
    float thumbTop = constrain(my - mapScrollDragAnchorY, trackY, trackY + room);
    mapListScroll = (int) floor((thumbTop - trackY) / room * (float) maxS + 0.5f);
    mapListScroll = constrain(mapListScroll, 0, maxS);
  }

  void syncMapSelectScrollMetrics() {
    if (!inMapSelect || mapFileNames.size() <= 0) {
      mapScrollMetricsValid = false;
      return;
    }
    layoutMapSelectListPanelFromScreen();
    computeMapScrollMetrics(mapSbX, mapRowAreaY, mapRowAreaH, mapListScrollGutterW, mapFileNames.size(), mapListMaxScroll());
  }

  void onMouseDraggedInMenu(GameEngine engine, int mx, int my, int button) {
    onPointerMoveInMenu(mx, my);
    if (!inMapSelect || !mapScrollThumbDrag || !isMenuPrimaryButton(button)) {
      return;
    }
    syncMapSelectScrollMetrics();
    updateMapScrollThumbDrag(float(my));
  }

  void drawMapListScrollbar(float sbX, float listTop, float listH, float scrollBtnW, int totalMaps, int maxScroll) {
    float trackX = sbX + 4;
    float trackY = listTop + 44;
    float trackW = scrollBtnW - 8;
    float trackH = listH - 88;
    computeMapScrollMetrics(sbX, listTop, listH, scrollBtnW, totalMaps, maxScroll);
    noStroke();
    fill(20, 22, 28);
    rect(trackX, trackY, trackW, trackH, 4);
    stroke(60, 68, 80);
    strokeWeight(1);
    noFill();
    rect(trackX, trackY, trackW, trackH, 4);
    noStroke();
    if (maxScroll <= 0 || totalMaps <= 0) {
      return;
    }
    float thumbY = mapScrThumbY;
    float thumbH = mapScrThumbH;
    fill(70, 95, 125);
    rect(trackX + 2, thumbY + 1, trackW - 4, thumbH - 2, 3);
    fill(110, 155, 200);
    rect(trackX + 3, thumbY + 2, trackW - 6, thumbH - 4, 2);
  }

  boolean consumeResumeRequest() {
    if (!wantResume) {
      return false;
    }
    wantResume = false;
    return true;
  }

  void render(GameEngine engine) {
    GameState gs = engine == null ? null : engine.state();
    menuHits.clear();
    float pad = 22;
    float outerC = 12;
    float panelX = pad;
    float panelY = pad;
    float panelW = width - pad * 2;
    float panelH = height - pad * 2;

    background(10, 11, 13);
    widgets.drawChamferFill(panelX, panelY, panelW, panelH, outerC, color(20, 22, 26));
    widgets.drawChamferStroke(panelX, panelY, panelW, panelH, outerC, color(120, 125, 135), 2);
    widgets.drawChamferFill(panelX + 2, panelY + 2, panelW - 4, panelH - 4, outerC - 1, color(14, 15, 18));
    widgets.drawChamferStroke(panelX + 2, panelY + 2, panelW - 4, panelH - 4, outerC - 1, color(55, 58, 64), 1);
    widgets.drawCornerRivets(panelX, panelY, panelW, panelH, outerC);

    float cx = width * 0.5;
    float cy = height * 0.5;
    float btnW = 240;
    float btnH = 48;
    float gap = 14;

    if (inMapSelect) {
      fill(230);
      textAlign(CENTER, TOP);
      textSize(28);
      text(tr("menu.mapSelect.title"), cx, panelY + 38);
      textSize(13);
      fill(160, 175, 195);
      text(tr("menu.mapSelect.subtitle"), cx, panelY + 74);

      float listTopEmpty = panelY + 108;
      float listHEmpty = mapListRowH * mapListVisibleRows + 4;

      if (mapFileNames.size() <= 0) {
        fill(200, 150, 130);
        textSize(14);
        text(tr("menu.mapSelect.empty"), cx, listTopEmpty + 48);
      } else {
        layoutMapSelectListPanelFromScreen();
        mapListHoverForScroll = pointInMapListScrollHit(float(mouseX), float(mouseY));
        maybePrimeWheelFocusWhileHoveringList();
        drawMapListPanelChrome();
        widgets.pushClipRect(mapRowAreaX, mapRowAreaY, mapRowAreaW, mapRowAreaH);
        int showEnd = min(mapFileNames.size(), mapListScroll + mapListVisibleRows);
        for (int idx = mapListScroll; idx < showEnd; idx++) {
          float rowY = mapRowAreaY + 2 + (idx - mapListScroll) * mapListRowH;
          String fn = mapFileNames.get(idx);
          addMenuButton(mapRowAreaX + 2, rowY, mapRowAreaW - 4, mapListRowH - 4, fn, "", "mappick:" + idx, 3, true, idx == mapListSelected);
        }
        widgets.popClipRect();
        if (mapListMaxScroll() > 0) {
          drawMapListScrollbar(mapSbX, mapRowAreaY, mapRowAreaH, mapListScrollGutterW, mapFileNames.size(), mapListMaxScroll());
          addMenuButton(mapSbX, mapRowAreaY + 2, mapListScrollGutterW - 4, 40, tr("menu.mapSelect.up"), "", "mappick:scrollup", 3);
          addMenuButton(mapSbX, mapRowAreaY + mapRowAreaH - 42, mapListScrollGutterW - 4, 40, tr("menu.mapSelect.down"), "", "mappick:scrolldown", 3);
        }
      }

      float footY = mapFileNames.size() <= 0 ? (listTopEmpty + listHEmpty + 24) : (mapBoxY + mapBoxH + 20);
      boolean canStart = mapFileNames.size() > 0;
      addMenuButton(cx - btnW - gap * 0.5, footY, btnW, btnH, tr("menu.mapSelect.start"), tr("menu.mapSelect.start.sub"), "mappick:start", 3, canStart);
      addMenuButton(cx + gap * 0.5, footY, btnW, btnH, tr("menu.mapSelect.back"), tr("menu.mapSelect.back.sub"), "mappick:back", 3);
    } else {
      fill(230);
      textAlign(CENTER, TOP);
      textSize(34);
      text(tr("menu.title"), cx, panelY + 42);
      textSize(14);
      fill(160, 175, 195);
      text(tr("menu.subtitle"), cx, panelY + 86);

      float groupH = pauseMenu ? (btnH * 4 + gap * 3) : (btnH * 3 + gap * 2);
      float startY = cy - groupH * 0.5;

      if (!inSettings) {
        if (pauseMenu) {
          addMenuButton(cx - btnW * 0.5, startY, btnW, btnH, tr("menu.resume"), tr("menu.resume.sub"), "menu:resume", 3);
          addMenuButton(cx - btnW * 0.5, startY + (btnH + gap), btnW, btnH, tr("menu.returnMain"), tr("menu.returnMain.sub"), "menu:returnMain", 2);
          addMenuButton(cx - btnW * 0.5, startY + (btnH + gap) * 2, btnW, btnH, tr("menu.settings"), tr("menu.settings.sub"), "menu:settings", 3);
          addMenuButton(cx - btnW * 0.5, startY + (btnH + gap) * 3, btnW, btnH, tr("menu.exit"), tr("menu.exit.sub"), "menu:exit", 2);
        } else {
          addMenuButton(cx - btnW * 0.5, startY, btnW, btnH, tr("menu.play"), tr("menu.play.sub"), "menu:play", 3);
          addMenuButton(cx - btnW * 0.5, startY + (btnH + gap), btnW, btnH, tr("menu.settings"), tr("menu.settings.sub"), "menu:settings", 3);
          addMenuButton(cx - btnW * 0.5, startY + (btnH + gap) * 2, btnW, btnH, tr("menu.exit"), tr("menu.exit.sub"), "menu:exit", 2);
        }
      } else {
        textAlign(CENTER, TOP);
        fill(200);
        textSize(16);
        text(tr("menu.settings.title"), cx, startY - 70);
        textSize(13);
        fill(170);
        String fogL = tr("menu.fog.toggle") + ": " + ((gs != null && gs.fogEnabled) ? "ON" : "OFF");
        text(fogL, cx, startY - 40);
        String speedL = tr("menu.speed") + ": " + (engine != null ? engine.currentGameSpeedLabel() : "1.00x");
        text(speedL, cx, startY - 20);
        String profileL = tr("menu.profiling") + ": " + (engine != null ? engine.profilingOverlayLabel() : "OFF");
        text(profileL, cx, startY);
        String cred = tr("ui.faction") + " PLAYER $" + (gs != null ? gs.playerStartCredits : 0);
        text(cred, cx, startY + 20);

        addMenuButton(cx - btnW * 0.5, startY + 16, btnW, btnH, tr("menu.fog.toggle"), tr("menu.fog.toggle.sub"), "menu:fog", 3);
        addMenuButton(cx - btnW * 0.5, startY + 16 + (btnH + gap), btnW, btnH, tr("menu.speed"), tr("menu.speed.sub"), "menu:speed", 3);
        addMenuButton(cx - btnW * 0.5, startY + 16 + (btnH + gap) * 2, btnW, btnH, tr("menu.profiling"), tr("menu.profiling.sub"), "menu:profiling", 3);

        int langIdx = currentLangIndex();
        String[] langOptions = {tr("menu.lang.auto"), tr("menu.lang.zh"), tr("menu.lang.en")};
        float dropdownY = startY + 16 + (btnH + gap) * 3;
        langDropdown.x = cx - btnW * 0.5;
        langDropdown.y = dropdownY;
        langDropdown.w = btnW;
        langDropdown.h = btnH;
        langDropdown.label = tr("menu.lang.label");
        langDropdown.options = langOptions;
        langDropdown.selectedIndex = langIdx;
        langDropdown.value = langOptions[langIdx];
        widgets.drawDropdown(langDropdown, mouseX, mouseY);

        float dropdownExpandH = 4 + langDropdown.optionH * langOptions.length;
        float backY = dropdownY + btnH + dropdownExpandH + gap;
        addMenuButton(cx - btnW * 0.5, backY, btnW, btnH, tr("menu.back"), tr("menu.back.sub"), "menu:back", 3);
        fill(165);
        textSize(12);
        text(tr("menu.persist.hint"), cx, backY + btnH + 4);
      }
    }

    if (gs != null && gs.lastStartError != null && gs.lastStartError.length() > 0) {
      textAlign(CENTER, TOP);
      fill(255, 140, 130);
      textSize(12);
      text(gs.lastStartError, width * 0.5, height - 72);
    }

    textAlign(LEFT, TOP);
  }

  void addMenuButton(float x, float y, float w, float h, String a, String b, String actionId, int style) {
    addMenuButton(x, y, w, h, a, b, actionId, style, true, false);
  }

  void addMenuButton(float x, float y, float w, float h, String a, String b, String actionId, int style, boolean enabled) {
    addMenuButton(x, y, w, h, a, b, actionId, style, enabled, false);
  }

  void addMenuButton(float x, float y, float w, float h, String a, String b, String actionId, int style, boolean enabled, boolean selected) {
    UiHitButton hb = new UiHitButton();
    hb.x = x;
    hb.y = y;
    hb.w = w;
    hb.h = h;
    hb.chamfer = 6;
    hb.label = a;
    hb.sublabel = b;
    hb.actionId = actionId;
    hb.style = style;
    hb.enabled = enabled;
    hb.selected = selected;
    hb.hovered = enabled && widgets.hitContains(hb, float(mouseX), float(mouseY));
    hb.pressed = pendingMenuActionId != null && pendingMenuActionId.equals(actionId);
    menuHits.add(hb);
    widgets.drawHitButton(hb);
  }

  boolean isMenuPrimaryButton(int button) {
    return button == LEFT || button == 1;
  }

  void onMousePressed(GameEngine engine, int mx, int my, int button) {
    if (!isMenuPrimaryButton(button)) {
      return;
    }
    onPointerMoveInMenu(mx, my);
    pendingMenuActionId = "";
    pendingLangPick = "";
    if (inSettings && !inMapSelect) {
      if (widgets.dropdownContainsHeader(langDropdown, mx, my)) {
        pendingLangPick = "header";
        return;
      }
      int langPick = widgets.dropdownOptionAt(langDropdown, mx, my);
      if (langPick >= 0) {
        pendingLangPick = "opt:" + langPick;
        return;
      }
      langDropdown.expanded = false;
    }
    if (inMapSelect && mapListMaxScroll() > 0) {
      syncMapSelectScrollMetrics();
      if (mapScrollMetricsValid && pointInMapScrollThumb(float(mx), float(my))) {
        mapScrollThumbDrag = true;
        mapScrollDragAnchorY = float(my) - mapScrThumbY;
        return;
      }
      if (mapScrollMetricsValid && pointInMapScrollTrack(float(mx), float(my))
        && !pointInMapScrollThumb(float(mx), float(my))) {
        applyMapScrollFromTrackY(float(my));
        return;
      }
    }
    for (int i = menuHits.size() - 1; i >= 0; i--) {
      UiHitButton b = menuHits.get(i);
      if (!b.enabled || !widgets.hitContains(b, float(mx), float(my))) {
        continue;
      }
      pendingMenuActionId = b.actionId;
      return;
    }
  }

  void onMouseReleased(GameEngine engine, int mx, int my, int button) {
    GameState gs = engine == null ? null : engine.state();
    if (!isMenuPrimaryButton(button)) {
      return;
    }
    if (mapScrollThumbDrag) {
      mapScrollThumbDrag = false;
      return;
    }
    if (inSettings && !inMapSelect && pendingLangPick != null && pendingLangPick.length() > 0) {
      String pl = pendingLangPick;
      pendingLangPick = "";
      boolean consumed = false;
      if ("header".equals(pl) && widgets.dropdownContainsHeader(langDropdown, float(mx), float(my))) {
        langDropdown.expanded = !langDropdown.expanded;
        consumed = true;
      } else if (pl.startsWith("opt:") && langDropdown.expanded) {
        try {
          int pick = Integer.parseInt(pl.substring(4));
          if (widgets.dropdownOptionAt(langDropdown, float(mx), float(my)) == pick) {
            if (pick == 0) {
              applyLanguage(LanguageMode.AUTO);
            } else if (pick == 1) {
              applyLanguage(LanguageMode.ZH);
            } else {
              applyLanguage(LanguageMode.EN);
            }
            langDropdown.expanded = false;
            consumed = true;
          }
        }
        catch (NumberFormatException ex) {
        }
      }
      if (consumed) {
        return;
      }
    }
    String action = pendingMenuActionId;
    pendingMenuActionId = "";
    if (action == null || action.length() == 0) {
      return;
    }
    boolean releasedOnSameButton = false;
    for (int i = 0; i < menuHits.size(); i++) {
      UiHitButton b = menuHits.get(i);
      if (b == null || !b.enabled || !action.equals(b.actionId)) {
        continue;
      }
      if (widgets.hitContains(b, float(mx), float(my))) {
        releasedOnSameButton = true;
        break;
      }
    }
    if (!releasedOnSameButton) {
      return;
    }
    if ("mappick:scrollup".equals(action)) {
      mapListScroll = max(0, mapListScroll - 1);
      return;
    }
    if ("mappick:scrolldown".equals(action)) {
      mapListScroll = min(mapListMaxScroll(), mapListScroll + 1);
      return;
    }
    if ("mappick:back".equals(action)) {
      inMapSelect = false;
      mapScrollThumbDrag = false;
      mapRowLastReleaseIdx = -1;
      mapRowLastReleaseMs = 0;
      return;
    }
    if ("mappick:start".equals(action)) {
      if (gs != null && mapFileNames.size() > 0) {
        gs.defaultMapJson = mapFileNames.get(constrain(mapListSelected, 0, mapFileNames.size() - 1));
        inMapSelect = false;
        pauseMenu = false;
        wantPlay = true;
        mapRowLastReleaseIdx = -1;
        mapRowLastReleaseMs = 0;
      }
      return;
    }
    if (action.startsWith("mappick:") && !action.equals("mappick:start") && !action.equals("mappick:back")
      && !action.equals("mappick:scrollup") && !action.equals("mappick:scrolldown")) {
      String tail = action.substring("mappick:".length());
      try {
        int idx = Integer.parseInt(tail);
        if (idx >= 0 && idx < mapFileNames.size()) {
          int now = millis();
          boolean dbl = idx == mapRowLastReleaseIdx && (now - mapRowLastReleaseMs) <= 450;
          mapRowLastReleaseIdx = idx;
          mapRowLastReleaseMs = now;
          if (dbl && gs != null) {
            mapListSelected = idx;
            gs.defaultMapJson = mapFileNames.get(idx);
            inMapSelect = false;
            pauseMenu = false;
            wantPlay = true;
            mapRowLastReleaseIdx = -1;
            mapRowLastReleaseMs = 0;
            return;
          }
          mapListSelected = idx;
          ensureSelectedRowVisible();
        }
      }
      catch (NumberFormatException ex) {
      }
      return;
    }
    if ("menu:play".equals(action)) {
      pauseMenu = false;
      inSettings = false;
      refreshMapListFromData();
      inMapSelect = true;
      tryRequestSketchFocus();
      return;
    }
    if ("menu:resume".equals(action)) {
      wantResume = true;
      return;
    }
    if ("menu:returnMain".equals(action)) {
      pauseMenu = false;
      inSettings = false;
      inMapSelect = false;
      if (gs != null) {
        gs.pendingReturnToMenu = false;
        gs.shutdownSessionForMenu();
      }
      return;
    }
    if ("menu:exit".equals(action)) {
      wantExit = true;
      return;
    }
    if ("menu:settings".equals(action)) {
      inSettings = true;
      return;
    }
    if ("menu:back".equals(action)) {
      inSettings = false;
      return;
    }
    if ("menu:fog".equals(action) && gs != null) {
      gs.fogEnabled = !gs.fogEnabled;
      return;
    }
    if ("menu:speed".equals(action) && engine != null) {
      engine.cycleGameSpeed();
      return;
    }
    if ("menu:profiling".equals(action) && engine != null) {
      engine.toggleProfilingOverlay();
      return;
    }
  }

  int currentLangIndex() {
    if (i18n == null) {
      return 0;
    }
    if (i18n.mode == LanguageMode.ZH) {
      return 1;
    }
    if (i18n.mode == LanguageMode.EN) {
      return 2;
    }
    return 0;
  }

  void applyLanguage(LanguageMode mode) {
    if (i18n == null) {
      return;
    }
    i18n.mode = mode;
    i18n.saveUserSettings();
    surface.setTitle(tr("app.title"));
  }
}
