GameEngine game;

void settings() {
  pixelDensity(1);
  fullScreen();
}

void setup() {
  game = new GameEngine(width, height);
  surface.setResizable(false);
  rectMode(CORNER);
  textAlign(LEFT, TOP);
}

void draw() {
  game.tick();
  if (game.consumeExitRequest()) {
    exit();
  }
}

void mousePressed() {
  game.onMousePressed(mouseX, mouseY, mouseButton);
}

void mouseReleased() {
  game.onMouseReleased(mouseX, mouseY, mouseButton);
}

void mouseDragged() {
  game.onMouseDragged(mouseX, mouseY, mouseButton);
}

void keyPressed() {
  game.onKeyPressed(key, keyCode);
}

void mouseWheel(processing.event.MouseEvent event) {
  game.onMouseWheel(event.getCount(), mouseX, mouseY);
}
