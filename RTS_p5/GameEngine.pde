enum AppMode {
  MENU,
  PLAYING
}

Localization i18n;

class GameEngine {
  GameState state;
  MainMenuSystem mainMenu;
  TimeSystem timeSystem;
  PFont appFont;
  AppMode mode = AppMode.MENU;
  boolean wantExit = false;
  int lastMillis = 0;

  GameEngine(int screenW, int screenH) {
    if (i18n == null) {
      i18n = new Localization();
      i18n.loadUserSettings();
    }
    state = new GameState(screenW, screenH);
    mainMenu = new MainMenuSystem();
    timeSystem = new TimeSystem();
    timeSystem.loadFromUiJson();
    appFont = loadBestUIFont();
    if (appFont != null) {
      textFont(appFont, 14);
    }
    surface.setTitle(tr("app.title"));
    lastMillis = millis();
  }

  GameState state() {
    return state;
  }

  boolean startNewGame() {
    return state != null && state.startNewGame();
  }

  boolean sessionReady() {
    return state != null && state.sessionReady();
  }

  void update(float dt) {
    if (mode == AppMode.MENU) {
      mainMenu.update(dt);
      mainMenu.render(this);
      if (mainMenu.consumeResumeRequest()) {
        mode = AppMode.PLAYING;
        return;
      }
      if (mainMenu.consumePlayRequest()) {
        if (startNewGame()) {
          mode = AppMode.PLAYING;
        }
      }
      if (mainMenu.consumeExitRequest()) {
        wantExit = true;
      }
      return;
    }
    if (state != null && state.sessionReady()) {
      state.update(timeSystem.gameplayDt(dt));
      state.render();
    } else {
      background(0);
    }
    if (consumePendingReturnToMenu()) {
      mode = AppMode.MENU;
    }
  }

  void tick() {
    int now = millis();
    float dt = timeSystem.computeRawDt(now, lastMillis);
    lastMillis = now;
    update(dt);
  }

  void render() {
    // Rendering is driven inside update(dt) to keep mode-switch flow cohesive.
  }

  void onMousePressed(int mx, int my, int button) {
    if (mode == AppMode.MENU) {
      mainMenu.onMousePressed(this, mx, my, button);
      return;
    }
    if (state != null) {
      state.onMousePressed(mx, my, button);
    }
  }

  void onMouseReleased(int mx, int my, int button) {
    if (mode == AppMode.MENU) {
      mainMenu.onMouseReleased(this, mx, my, button);
      return;
    }
    if (mode != AppMode.PLAYING || !sessionReady()) {
      return;
    }
    if (state != null) {
      state.onMouseReleased(mx, my, button);
    }
  }

  void onMouseDragged(int mx, int my, int button) {
    if (mode != AppMode.PLAYING || !sessionReady()) {
      return;
    }
    if (state != null) {
      state.onMouseDragged(mx, my, button);
    }
  }

  void onKeyPressed(char key, int keyCode) {
    if (mode == AppMode.MENU && mainMenu.pauseMenu && (key == '`' || key == '·')) {
      mode = AppMode.PLAYING;
      return;
    }
    if (mode != AppMode.PLAYING || !sessionReady()) {
      return;
    }
    if (key == '`' || key == '·') {
      mainMenu.openPauseMenu();
      mode = AppMode.MENU;
      return;
    }
    if (state != null) {
      state.onKeyPressed(key, keyCode);
    }
  }

  void onMouseWheel(float amount, int mx, int my) {
    if (mode != AppMode.PLAYING || !sessionReady()) {
      return;
    }
    if (state != null) {
      state.onMouseWheel(amount, mx, my);
    }
  }

  boolean consumePendingReturnToMenu() {
    if (state == null || !state.pendingReturnToMenu) {
      return false;
    }
    state.pendingReturnToMenu = false;
    return true;
  }

  boolean consumeExitRequest() {
    if (!wantExit) {
      return false;
    }
    wantExit = false;
    return true;
  }

  String currentGameSpeedLabel() {
    return timeSystem == null ? "1.00x" : timeSystem.speedLabel();
  }

  void cycleGameSpeed() {
    if (timeSystem != null) {
      timeSystem.cycleSpeed();
    }
  }

  PFont loadBestUIFont() {
    String[] candidates = {
      "Microsoft YaHei UI",
      "Microsoft YaHei",
      "SimHei",
      "Noto Sans CJK SC",
      "Source Han Sans CN",
      "Arial Unicode MS",
      "Dialog"
    };
    String[] installed = PFont.list();
    for (int i = 0; i < candidates.length; i++) {
      String c = candidates[i];
      for (int j = 0; j < installed.length; j++) {
        String f = installed[j];
        if (f.equals(c) || f.startsWith(c + ".") || f.toLowerCase().contains(c.toLowerCase())) {
          return createFont(c, 18, true);
        }
      }
    }
    return createFont("Dialog", 18, true);
  }
}
