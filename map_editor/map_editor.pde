EditorState editorState;
EditorTools editorTools;
EditorIO editorIO;
EditorValidation editorValidation;
EditorUI editorUI;

void settings() {
  size(1600, 900);
}

void setup() {
  surface.setTitle("RTS Map Editor");
  textAlign(LEFT, TOP);
  editorState = new EditorState();
  editorTools = new EditorTools(editorState);
  editorIO = new EditorIO(editorState);
  editorValidation = new EditorValidation(editorState);
  editorUI = new EditorUI(editorState, editorTools, editorIO, editorValidation);

  editorState.initDefaults(48, 48, 40);
  editorIO.loadDefinitions();
  editorIO.refreshMapFiles();
  if (!editorIO.openCurrentMap()) {
    editorState.setStatus("New map session started.");
  }
}

void draw() {
  background(18);
  editorUI.render();
}

void mousePressed() {
  editorUI.onMousePressed(mouseX, mouseY, mouseButton);
}

void mouseDragged() {
  editorUI.onMouseDragged(mouseX, mouseY, mouseButton);
}

void mouseReleased() {
  editorUI.onMouseReleased(mouseX, mouseY, mouseButton);
}

void mouseWheel(processing.event.MouseEvent event) {
  editorUI.onMouseWheel(event.getCount(), mouseX, mouseY);
}

void keyPressed() {
  editorUI.onKeyPressed(key, keyCode);
}
