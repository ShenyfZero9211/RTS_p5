EditorState editorState;
EditorTools editorTools;
EditorIO editorIO;
EditorValidation editorValidation;
EditorUI editorUI;

void settings() {
  pixelDensity(1);
  fullScreen();
}

void setup() {
  surface.setTitle("RTS Map Editor");
  surface.setResizable(false);
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
  editorUI.onMapLoadedOrNew();
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

void loadMapFileSelected(File f) {
  if (editorIO != null) {
    editorIO.completeLoadDialog(f);
    if (editorUI != null) {
      editorUI.onMapLoadedOrNew();
    }
  }
}

void saveMapAsSelected(File f) {
  if (editorIO != null && editorValidation != null) {
    editorIO.completeSaveAsDialog(f, editorValidation);
  }
}
