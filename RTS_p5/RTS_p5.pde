GameState game;
int lastMillis;

void settings() {
  fullScreen();
}

void setup() {
  surface.setTitle("RTS_p5 MVP");
  rectMode(CORNER);
  textAlign(LEFT, TOP);
  game = new GameState(width, height);
  lastMillis = millis();
}

void draw() {
  int now = millis();
  float dt = min(0.05, max(0.001, (now - lastMillis) / 1000.0));
  lastMillis = now;

  game.update(dt);
  game.render();
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
