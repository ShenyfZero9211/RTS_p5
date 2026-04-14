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
  float simAccumulator = 0;
  boolean runtimeProfilingOverlay = false;
  String enemyAiProfile = "balanced";
  BenchmarkRuntime benchmarkRuntime;

  GameEngine(int screenW, int screenH, String[] sketchArgs) {
    if (i18n == null) {
      i18n = new Localization();
      i18n.loadUserSettings();
    }
    state = new GameState(screenW, screenH);
    state.applySketchArguments(sketchArgs);
    mainMenu = new MainMenuSystem();
    timeSystem = new TimeSystem();
    timeSystem.loadFromUiJson();
    loadRuntimeOptions();
    benchmarkRuntime = new BenchmarkRuntime();
    benchmarkRuntime.loadConfig();
    appFont = loadBestUIFont();
    if (appFont != null) {
      textFont(appFont, 14);
    }
    surface.setTitle(tr("app.title"));
    lastMillis = millis();
    // Benchmark must run before RTS_MAP_FILE / args auto-start: otherwise startNewGame() uses
    // defaultMapJson from env and skips beginIfNeeded, so map_test.json (written by benchmark.ps1) is never loaded.
    if (benchmarkRuntime != null && benchmarkRuntime.enabled) {
      runtimeProfilingOverlay = true;
      benchmarkRuntime.beginIfNeeded(this);
    } else if (state != null && state.autoStartPlayFromLaunch) {
      if (startNewGame()) {
        mode = AppMode.PLAYING;
      } else {
        println("[RTS] Map launch failed: " + (state.lastStartError != null ? state.lastStartError : ""));
      }
    }
  }

  GameState state() {
    return state;
  }

  boolean startNewGame() {
    if (state == null) {
      return false;
    }
    boolean ok = state.startNewGame();
    if (ok) {
      simAccumulator = 0;
      applyEnemyAiProfile();
      state.showRuntimeProfiling = runtimeProfilingOverlay;
      state.profileStepLabel = timeSystem.fixedStepHz + "Hz";
    }
    return ok;
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
  }

  void tick() {
    int now = millis();
    float rawFrameMs = max(0.1, now - lastMillis);
    float rawDt = timeSystem.computeRawDt(now, lastMillis);
    lastMillis = now;
    if (mode == AppMode.MENU) {
      update(rawDt);
      if (benchmarkRuntime != null && benchmarkRuntime.enabled) {
        benchmarkRuntime.beginIfNeeded(this);
      }
      return;
    }
    if (state == null || !state.sessionReady()) {
      background(0);
      return;
    }
    float fixedStep = timeSystem.fixedStepSeconds();
    simAccumulator += timeSystem.gameplayDt(rawDt);
    int steps = 0;
    while (simAccumulator >= fixedStep && steps < timeSystem.maxStepsPerFrame) {
      state.update(fixedStep);
      simAccumulator -= fixedStep;
      steps++;
    }
    if (simAccumulator > fixedStep * timeSystem.maxStepsPerFrame) {
      simAccumulator = fixedStep * 0.5;
    }
    state.render();
    if (benchmarkRuntime != null && benchmarkRuntime.enabled) {
      benchmarkRuntime.update(this, rawFrameMs);
    }
    if (consumePendingReturnToMenu()) {
      mode = AppMode.MENU;
    }
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
    if (mode == AppMode.MENU) {
      mainMenu.onMouseDraggedInMenu(this, mx, my, button);
      return;
    }
    if (mode != AppMode.PLAYING || !sessionReady()) {
      return;
    }
    if (state != null) {
      state.onMouseDragged(mx, my, button);
    }
  }

  void onMouseMoved(int mx, int my) {
    if (mode == AppMode.MENU) {
      mainMenu.onPointerMoveInMenu(mx, my);
    }
  }

  void onMouseEntered() {
    if (mode == AppMode.MENU && mainMenu.inMapSelect) {
      mainMenu.tryRequestSketchFocus();
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
    if (mode == AppMode.MENU) {
      mainMenu.onMouseWheel(this, amount, mx, my);
      return;
    }
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

  String profilingOverlayLabel() {
    return runtimeProfilingOverlay ? "ON" : "OFF";
  }

  void toggleProfilingOverlay() {
    runtimeProfilingOverlay = !runtimeProfilingOverlay;
    if (state != null) {
      state.showRuntimeProfiling = runtimeProfilingOverlay;
    }
    saveRuntimeUserSettings();
  }

  void loadRuntimeOptions() {
    JSONObject root = loadJSONObject("ui.json");
    if (root == null) return;
    runtimeProfilingOverlay = root.getBoolean("runtimeProfilingOverlay", runtimeProfilingOverlay);
    enemyAiProfile = root.getString("enemyAiProfile", enemyAiProfile);
    JSONObject user = loadJSONObject("data/settings_user.json");
    if (user != null) {
      runtimeProfilingOverlay = user.getBoolean("runtimeProfilingOverlay", runtimeProfilingOverlay);
    }
  }

  void applyEnemyAiProfile() {
    if (state == null || state.enemyAi == null) return;
    state.enemyAi.applyProfile(enemyAiProfile, state);
  }

  void saveRuntimeUserSettings() {
    JSONObject root = loadJSONObject("data/settings_user.json");
    if (root == null) {
      root = new JSONObject();
    }
    root.setBoolean("runtimeProfilingOverlay", runtimeProfilingOverlay);
    saveJSONObject(root, "data/settings_user.json");
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
