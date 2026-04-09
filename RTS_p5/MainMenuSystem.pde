/** Full-screen menu and lightweight settings (session overrides written to GameState before start). */
class MainMenuSystem {
  UiWidgets widgets = new UiWidgets();
  ArrayList<UiHitButton> menuHits = new ArrayList<UiHitButton>();
  UiDropdown langDropdown = new UiDropdown();
  String pendingMenuActionId = "";
  boolean inSettings = false;
  boolean pauseMenu = false;
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

    fill(230);
    textAlign(CENTER, TOP);
    textSize(34);
    text(tr("menu.title"), cx, panelY + 42);
    textSize(14);
    fill(160, 175, 195);
    text(tr("menu.subtitle"), cx, panelY + 86);

    float btnW = 240;
    float btnH = 48;
    float gap = 14;
    float groupH = btnH * 3 + gap * 2;
    float startY = cy - groupH * 0.5;

    if (!inSettings) {
      if (pauseMenu) {
        addMenuButton(cx - btnW * 0.5, startY, btnW, btnH, tr("menu.resume"), tr("menu.resume.sub"), "menu:resume", 3);
      } else {
        addMenuButton(cx - btnW * 0.5, startY, btnW, btnH, tr("menu.play"), tr("menu.play.sub"), "menu:play", 3);
      }
      addMenuButton(cx - btnW * 0.5, startY + (btnH + gap), btnW, btnH, tr("menu.settings"), tr("menu.settings.sub"), "menu:settings", 3);
      addMenuButton(cx - btnW * 0.5, startY + (btnH + gap) * 2, btnW, btnH, tr("menu.exit"), tr("menu.exit.sub"), "menu:exit", 2);
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

    if (gs != null && gs.lastStartError != null && gs.lastStartError.length() > 0) {
      textAlign(CENTER, TOP);
      fill(255, 140, 130);
      textSize(12);
      text(gs.lastStartError, width * 0.5, height - 72);
    }

    textAlign(LEFT, TOP);
  }

  void addMenuButton(float x, float y, float w, float h, String a, String b, String actionId, int style) {
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
    hb.enabled = true;
    hb.hovered = widgets.hitContains(hb, float(mouseX), float(mouseY));
    hb.pressed = pendingMenuActionId != null && pendingMenuActionId.equals(actionId);
    menuHits.add(hb);
    widgets.drawHitButton(hb);
  }

  void onMousePressed(GameEngine engine, int mx, int my, int button) {
    if (button != LEFT) {
      return;
    }
    pendingMenuActionId = "";
    if (inSettings) {
      if (widgets.dropdownContainsHeader(langDropdown, mx, my)) {
        langDropdown.expanded = !langDropdown.expanded;
        return;
      }
      int langPick = widgets.dropdownOptionAt(langDropdown, mx, my);
      if (langPick >= 0) {
        if (langPick == 0) {
          applyLanguage(LanguageMode.AUTO);
        } else if (langPick == 1) {
          applyLanguage(LanguageMode.ZH);
        } else {
          applyLanguage(LanguageMode.EN);
        }
        langDropdown.expanded = false;
        return;
      }
      langDropdown.expanded = false;
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
    if (button != LEFT) {
      return;
    }
    String action = pendingMenuActionId;
    pendingMenuActionId = "";
    if (action == null || action.length() == 0) {
      return;
    }
    boolean releasedOnSameButton = false;
    for (int i = menuHits.size() - 1; i >= 0; i--) {
      UiHitButton b = menuHits.get(i);
      if (!b.enabled || !widgets.hitContains(b, float(mx), float(my))) {
        continue;
      }
      if (action.equals(b.actionId)) {
        releasedOnSameButton = true;
      }
      break;
    }
    if (!releasedOnSameButton) {
      return;
    }
    if ("menu:play".equals(action)) {
      pauseMenu = false;
      wantPlay = true;
      return;
    }
    if ("menu:resume".equals(action)) {
      wantResume = true;
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
