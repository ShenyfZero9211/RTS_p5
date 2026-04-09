enum AppMode {
  MENU,
  PLAYING
}

GameState game;
MainMenuSystem mainMenu;
Localization i18n;
PFont appFont;
AppMode appMode = AppMode.MENU;
int lastMillis;

void settings() {
  pixelDensity(1);
  fullScreen();
}

void setup() {
  i18n = new Localization();
  i18n.loadUserSettings();
  appFont = loadBestUIFont();
  if (appFont != null) {
    textFont(appFont, 14);
  }
  surface.setTitle(tr("app.title"));
  surface.setResizable(false);
  rectMode(CORNER);
  textAlign(LEFT, TOP);
  game = new GameState(width, height);
  mainMenu = new MainMenuSystem();
  lastMillis = millis();
}

void draw() {
  int now = millis();
  float dt = min(0.05, max(0.001, (now - lastMillis) / 1000.0));
  lastMillis = now;

  if (appMode == AppMode.MENU) {
    mainMenu.update(dt);
    mainMenu.render(game);
    if (mainMenu.consumeResumeRequest()) {
      appMode = AppMode.PLAYING;
      return;
    }
    if (mainMenu.consumePlayRequest()) {
      if (game.startNewGame()) {
        appMode = AppMode.PLAYING;
      }
    }
    if (mainMenu.consumeExitRequest()) {
      exit();
    }
    return;
  }

  if (game.sessionReady()) {
    game.update(dt);
    game.render();
  } else {
    background(0);
  }

  if (game.pendingReturnToMenu) {
    game.pendingReturnToMenu = false;
    appMode = AppMode.MENU;
  }
}

void mousePressed() {
  if (appMode == AppMode.MENU) {
    mainMenu.onMousePressed(game, mouseX, mouseY, mouseButton);
    return;
  }
  game.onMousePressed(mouseX, mouseY, mouseButton);
}

void mouseReleased() {
  if (appMode == AppMode.MENU) {
    mainMenu.onMouseReleased(game, mouseX, mouseY, mouseButton);
    return;
  }
  if (appMode != AppMode.PLAYING || !game.sessionReady()) {
    return;
  }
  game.onMouseReleased(mouseX, mouseY, mouseButton);
}

void mouseDragged() {
  if (appMode != AppMode.PLAYING || !game.sessionReady()) {
    return;
  }
  game.onMouseDragged(mouseX, mouseY, mouseButton);
}

void keyPressed() {
  if (appMode == AppMode.MENU && mainMenu.pauseMenu && (key == '`' || key == '·')) {
    appMode = AppMode.PLAYING;
    return;
  }
  if (appMode != AppMode.PLAYING || !game.sessionReady()) {
    return;
  }
  if (key == '`' || key == '·') {
    mainMenu.openPauseMenu();
    appMode = AppMode.MENU;
    return;
  }
  game.onKeyPressed(key, keyCode);
}

void mouseWheel(processing.event.MouseEvent event) {
  if (appMode != AppMode.PLAYING || !game.sessionReady()) {
    return;
  }
  game.onMouseWheel(event.getCount(), mouseX, mouseY);
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
