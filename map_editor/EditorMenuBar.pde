/**
 * Top menu strip: File / Edit / Help with dropdowns (VS Code style).
 */
class EditorMenuBar {
  static final int TITLE_TEXT = 14;
  static final int DROP_TEXT = 13;
  static final int TITLE_PAD_X = 12;
  static final int TITLE_GAP = 4;
  static final int DROP_ITEM_H = 24;
  static final int DROP_PAD_X = 12;

  final String[] topLabels = new String[] { "File", "Edit", "Help" };
  int[] titleLeft = new int[3];
  int[] titleW = new int[3];
  int openMenu = -1;

  void layoutTitles() {
    textSize(TITLE_TEXT);
    int x = TITLE_PAD_X;
    for (int i = 0; i < topLabels.length; i++) {
      titleLeft[i] = x;
      titleW[i] = (int)textWidth(topLabels[i]) + TITLE_PAD_X * 2;
      x += titleW[i] + TITLE_GAP;
    }
  }

  int titleBaselineY() {
    return EditorState.MENU_BAR_H / 2;
  }

  boolean contains(int mx, int my) {
    return my >= 0 && my < EditorState.MENU_BAR_H && mx >= 0 && mx < width;
  }

  int hoverTopMenu(int mx, int my) {
    if (!contains(mx, my)) return -1;
    if (my < 4 || my >= EditorState.MENU_BAR_H - 4) return -1;
    for (int i = 0; i < topLabels.length; i++) {
      if (mx >= titleLeft[i] && mx < titleLeft[i] + titleW[i]) return i;
    }
    return -1;
  }

  int dropdownWidth(int menuIdx) {
    textSize(DROP_TEXT);
    float mw = 0;
    if (menuIdx == 0) {
      String[] items = new String[] { "Save", "Save As...", "Load...", "New" };
      for (String it : items) mw = max(mw, textWidth(it));
    } else if (menuIdx == 1) {
      String[] items = new String[] {
        "Undo    Ctrl+Z",
        "Redo    Ctrl+Y / Ctrl+Shift+Z",
        "Cut    Ctrl+X",
        "Copy    Ctrl+C",
        "Paste    Ctrl+V"
      };
      for (String it : items) mw = max(mw, textWidth(it));
    } else {
      String[] lines = new String[] {
        "Terrain 1/2/3  E erase  F fill  I select",
        "M mine  P/O spawns  B building  U unit",
        "[ ] cycle type / brush  Wheel: zoom map",
        "Space+drag pan  Shift+drag rect terrain",
        "Ctrl+S save (Save As if new)  Ctrl+Shift+S Save As",
        "Ctrl+L load  Ctrl+N new (dialog)  Ctrl+R map_test",
        "Ctrl+Z undo  Ctrl+Y / Ctrl+Shift+Z redo  Ctrl+X/C/V",
        "Ctrl+[ ] cycle data map filename"
      };
      for (String ln : lines) mw = max(mw, textWidth(ln));
    }
    return (int)mw + DROP_PAD_X * 2 + 8;
  }

  int dropdownItemCount(int menuIdx) {
    if (menuIdx == 0) return 4;
    if (menuIdx == 1) return 5;
    return 0;
  }

  int dropdownHeight(int menuIdx) {
    if (menuIdx == 2) return 148;
    return 4 + dropdownItemCount(menuIdx) * DROP_ITEM_H;
  }

  int dropdownTop() {
    return EditorState.MENU_BAR_H;
  }

  int dropdownLeft(int menuIdx) {
    return titleLeft[menuIdx];
  }

  int hoverDropdownItem(int mx, int my) {
    if (openMenu < 0) return -1;
    if (openMenu == 2) return -1;
    int dx = dropdownLeft(openMenu);
    int dy = dropdownTop();
    int dw = dropdownWidth(openMenu);
    int dh = dropdownHeight(openMenu);
    if (mx < dx || mx >= dx + dw || my < dy || my >= dy + dh) return -1;
    int rel = my - (dy + 2);
    int idx = rel / DROP_ITEM_H;
    if (idx < 0 || idx >= dropdownItemCount(openMenu)) return -1;
    return idx;
  }

  boolean hoverDropdownPanel(int mx, int my) {
    if (openMenu < 0) return false;
    int dx = dropdownLeft(openMenu);
    int dy = dropdownTop();
    int dw = dropdownWidth(openMenu);
    int dh = dropdownHeight(openMenu);
    return mx >= dx && mx < dx + dw && my >= dy && my < dy + dh;
  }

  boolean anyMenuHover(int mx, int my) {
    return hoverTopMenu(mx, my) >= 0 || hoverDropdownPanel(mx, my);
  }

  void drawTitleUnderline(String label, float textLeft, float baselineY) {
    textSize(TITLE_TEXT);
    if (label.length() == 0) return;
    float u0 = textLeft;
    float u1 = textLeft + textWidth(label.substring(0, 1));
    stroke(180, 200, 220);
    strokeWeight(1);
    line(u0, baselineY + 8, u1, baselineY + 8);
    noStroke();
  }

  void render(EditorState s, int mx, int my) {
    layoutTitles();
    noStroke();
    fill(34, 38, 48);
    rect(0, 0, width, EditorState.MENU_BAR_H);
    stroke(60, 72, 90);
    line(0, EditorState.MENU_BAR_H - 1, width, EditorState.MENU_BAR_H - 1);

    int hoverTop = hoverTopMenu(mx, my);
    textAlign(CENTER, CENTER);
    textSize(TITLE_TEXT);
    int by = titleBaselineY();
    for (int i = 0; i < topLabels.length; i++) {
      boolean hov = (hoverTop == i) || (openMenu == i);
      float cx = titleLeft[i] + titleW[i] * 0.5f;
      if (hov) {
        fill(52, 64, 82);
        rect(titleLeft[i], 4, titleW[i], EditorState.MENU_BAR_H - 8, 2);
      }
      fill(hov ? 255 : 220);
      text(topLabels[i], cx, by);
      fill(220, 230, 245);
      float tw = textWidth(topLabels[i]);
      drawTitleUnderline(topLabels[i], cx - tw * 0.5f, by);
    }

    fill(150, 168, 190);
    textSize(12);
    textAlign(LEFT, CENTER);
    text(s.currentMapFile, titleLeft[2] + titleW[2] + 16, by);

    if (openMenu >= 0) {
      int dx = dropdownLeft(openMenu);
      int dy = dropdownTop();
      int dw = dropdownWidth(openMenu);
      int dh = dropdownHeight(openMenu);
      noStroke();
      fill(42, 48, 58);
      rect(dx, dy, dw, dh, 2);
      stroke(70, 82, 100);
      noFill();
      rect(dx + 0.5f, dy + 0.5f, dw - 1, dh - 1, 2);

      if (openMenu == 0) {
        int hi = hoverDropdownItem(mx, my);
        textSize(DROP_TEXT);
        textAlign(LEFT, CENTER);
        String[] items = new String[] { "Save", "Save As...", "Load...", "New" };
        for (int j = 0; j < items.length; j++) {
          int iy = dy + 2 + j * DROP_ITEM_H;
          boolean rowH = (hi == j);
          if (rowH) {
            noStroke();
            fill(55, 75, 98);
            rect(dx + 2, iy, dw - 4, DROP_ITEM_H - 1, 2);
          }
          fill(rowH ? 255 : 215);
          text(items[j], dx + DROP_PAD_X, iy + DROP_ITEM_H * 0.5f);
        }
      } else if (openMenu == 1) {
        int hi = hoverDropdownItem(mx, my);
        textSize(DROP_TEXT);
        textAlign(LEFT, CENTER);
        String[] items = new String[] {
          "Undo    Ctrl+Z",
          "Redo    Ctrl+Y / Ctrl+Shift+Z",
          "Cut    Ctrl+X",
          "Copy    Ctrl+C",
          "Paste    Ctrl+V"
        };
        for (int j = 0; j < items.length; j++) {
          int iy = dy + 2 + j * DROP_ITEM_H;
          boolean rowH = (hi == j);
          if (rowH) {
            noStroke();
            fill(55, 75, 98);
            rect(dx + 2, iy, dw - 4, DROP_ITEM_H - 1, 2);
          }
          fill(rowH ? 255 : 215);
          text(items[j], dx + DROP_PAD_X, iy + DROP_ITEM_H * 0.5f);
        }
      } else if (openMenu == 2) {
        textSize(11);
        textAlign(LEFT, TOP);
        fill(190, 200, 215);
        int tx = dx + 8;
        int ty = dy + 8;
        text("Terrain 1/2/3  E erase  F fill  I select", tx, ty);
        ty += 16;
        text("M mine  P/O spawns  B building  U unit", tx, ty);
        ty += 16;
        text("[ ] cycle type / brush  Wheel: zoom map", tx, ty);
        ty += 16;
        text("Space+drag pan  Shift+drag rect terrain", tx, ty);
        ty += 16;
        text("Ctrl+S save (Save As if new)  Ctrl+Shift+S Save As", tx, ty);
        ty += 16;
        text("Ctrl+L load  Ctrl+N new (dialog)  Ctrl+R map_test", tx, ty);
        ty += 16;
        text("Ctrl+Z undo  Ctrl+Y / Ctrl+Shift+Z redo  Ctrl+X/C/V", tx, ty);
        ty += 16;
        text("Ctrl+[ ] cycle data map filename", tx, ty);
      }
    }
    textAlign(LEFT, TOP);
  }

  void closeMenu() {
    openMenu = -1;
  }

  boolean runDropdownAction(EditorState s, EditorIO io, EditorValidation validator, EditorUI ui, int mx, int my) {
    if (!hoverDropdownPanel(mx, my)) return false;
    if (openMenu == 2) {
      closeMenu();
      return true;
    }
    int item = hoverDropdownItem(mx, my);
    if (item < 0) return true;
    if (openMenu == 0) {
      if (item == 0) {
        io.requestSave(validator);
      } else if (item == 1) {
        io.promptSaveAs(validator);
      } else if (item == 2) {
        io.promptLoadMap();
      } else if (item == 3) {
        ui.promptNewMap();
      }
    } else if (openMenu == 1) {
      if (item == 0) ui.menuUndo();
      else if (item == 1) ui.menuRedo();
      else if (item == 2) ui.menuCut();
      else if (item == 3) ui.menuCopy();
      else if (item == 4) ui.menuPaste();
    }
    closeMenu();
    return true;
  }

  boolean mousePressed(EditorState s, EditorIO io, EditorValidation validator, EditorUI ui, int mx, int my, int button) {
    if (button != LEFT) return false;

    if (openMenu >= 0 && hoverDropdownPanel(mx, my)) {
      return runDropdownAction(s, io, validator, ui, mx, my);
    }

    if (contains(mx, my)) {
      int top = hoverTopMenu(mx, my);
      if (top >= 0) {
        openMenu = (openMenu == top) ? -1 : top;
        return true;
      }
      if (openMenu >= 0) {
        closeMenu();
        return true;
      }
      return false;
    }

    if (openMenu >= 0) {
      closeMenu();
    }
    return false;
  }
}
