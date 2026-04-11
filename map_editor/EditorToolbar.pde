/**
 * Left vertical tool rail: tools (capped above brush block), brush preview + labels + +/-, placement faction.
 */
class EditorToolbar {
  static final int W = EditorState.TOOLBAR_W;
  static final int BTN_H = 30;
  static final int BTN_GAP = 3;
  static final int PAD = 6;
  static final int PREVIEW_MAX = 76;

  final EditorToolType[] toolOrder = new EditorToolType[] {
    EditorToolType.TOOL_SELECT,
    EditorToolType.TOOL_TERRAIN_SAND,
    EditorToolType.TOOL_TERRAIN_ROCK,
    EditorToolType.TOOL_TERRAIN_BLOCK,
    EditorToolType.TOOL_ERASE,
    EditorToolType.TOOL_FILL,
    EditorToolType.TOOL_MINE,
    EditorToolType.TOOL_SPAWN_PLAYER,
    EditorToolType.TOOL_SPAWN_ENEMY,
    EditorToolType.TOOL_BUILDING,
    EditorToolType.TOOL_UNIT
  };

  final String[] toolLabels = new String[] {
    "Sel", "Sand", "Rock", "Blk", "Ers", "Fill", "Mine", "P sp", "E sp", "Bld", "Unit"
  };

  int contentTop() {
    return EditorState.MENU_BAR_H;
  }

  int toolsTopY() {
    return contentTop() + 40;
  }

  int factionRowY() {
    return height - 66;
  }

  int brushMinusY(EditorState s) {
    boolean fac = s.activeTool == EditorToolType.TOOL_BUILDING || s.activeTool == EditorToolType.TOOL_UNIT;
    return fac ? factionRowY() - 38 : height - 96;
  }

  int brushLabelY(EditorState s) {
    return brushMinusY(s) - 22;
  }

  int tilesCaptionY(EditorState s) {
    return brushLabelY(s) - 16;
  }

  float previewBoxBottom(EditorState s) {
    return tilesCaptionY(s) - 5;
  }

  float brushPreviewTop(EditorState s) {
    int dim = s.brushFootprintSide();
    float cell = min(14f, PREVIEW_MAX / float(max(1, dim)));
    float box = cell * dim;
    return previewBoxBottom(s) - box;
  }

  int maxToolBottomY(EditorState s) {
    return max(toolsTopY() + BTN_H, (int)brushPreviewTop(s) - 10);
  }

  int visibleToolCount(EditorState s) {
    int y = toolsTopY();
    int cap = maxToolBottomY(s);
    int n = 0;
    for (int i = 0; i < toolOrder.length; i++) {
      if (y + BTN_H > cap) break;
      y += BTN_H + BTN_GAP;
      n++;
    }
    return max(1, n);
  }

  boolean contains(int mx, int my) {
    return mx >= 0 && mx < W && my >= contentTop() && my < height;
  }

  boolean hoverAny(EditorState s, int mx, int my) {
    if (!contains(mx, my)) return false;
    if (hoverToolIndex(s, mx, my) >= 0) return true;
    if (hoverBrushPlusMinus(s, mx, my)) return true;
    if (hoverFaction(mx, my, s)) return true;
    return false;
  }

  int hoverToolIndex(EditorState s, int mx, int my) {
    int y = toolsTopY();
    int cap = visibleToolCount(s);
    for (int i = 0; i < cap; i++) {
      if (mx >= PAD && mx < W - PAD && my >= y && my < y + BTN_H) return i;
      y += BTN_H + BTN_GAP;
    }
    return -1;
  }

  boolean hoverBrushPlusMinus(EditorState s, int mx, int my) {
    int by = brushMinusY(s);
    return my >= by && my < by + 28 && ((mx >= PAD && mx < PAD + 30) || (mx >= PAD + 36 && mx < PAD + 36 + 30));
  }

  boolean hoverFaction(int mx, int my, EditorState s) {
    if (s.activeTool != EditorToolType.TOOL_BUILDING && s.activeTool != EditorToolType.TOOL_UNIT) return false;
    int fy = factionRowY();
    if (my < fy || my >= fy + 30) return false;
    int fw = (W - PAD * 2 - 4) / 2;
    return (mx >= PAD && mx < PAD + fw) || (mx >= PAD + fw + 4 && mx < PAD + fw + 4 + fw);
  }

  void renderBrushPreview(EditorState s, int mx, int my) {
    float py = brushPreviewTop(s);
    int dim = s.brushFootprintSide();
    float cell = min(14f, PREVIEW_MAX / float(max(1, dim)));
    float box = cell * dim;
    float ox = (W - box) * 0.5f;
    float pbottom = previewBoxBottom(s);
    boolean hoverPv = mx >= 0 && mx < W && my >= py && my < pbottom + 4 && contains(mx, my);

    fill(14, 18, 24);
    stroke(hoverPv ? color(90, 120, 160) : color(48, 58, 72));
    strokeWeight(1);
    rect(ox - 2, py - 2, box + 4, box + 4, 3);
    noStroke();
    for (int ty = 0; ty < dim; ty++) {
      for (int tx = 0; tx < dim; tx++) {
        fill(95, 185, 245);
        rect(ox + tx * cell, py + ty * cell, cell - 0.5f, cell - 0.5f, 1);
      }
    }

    fill(150, 165, 185);
    textSize(11);
    textAlign(LEFT, TOP);
    text(dim + " x " + dim + " tiles", PAD, tilesCaptionY(s));
    fill(160, 175, 195);
    textSize(12);
    text("Brush " + s.brushSize, PAD, brushLabelY(s));
    textAlign(LEFT, TOP);
  }

  void render(EditorState s, int mx, int my) {
    noStroke();
    fill(22, 26, 32);
    rect(0, contentTop(), W, height - contentTop());
    fill(220, 230, 245);
    textSize(13);
    textAlign(LEFT, TOP);
    text("Tools", PAD, contentTop() + 6);
    textSize(11);
    fill(130, 145, 165);
    text("Space+drag pan", PAD, contentTop() + 20);

    int y = toolsTopY();
    int hi = hoverToolIndex(s, mx, my);
    int vis = visibleToolCount(s);
    for (int i = 0; i < vis; i++) {
      boolean on = (s.activeTool == toolOrder[i]);
      boolean hov = (hi == i);
      if (on) fill(55, 95, 140);
      else if (hov) fill(50, 68, 88);
      else fill(38, 48, 62);
      rect(PAD, y, W - PAD * 2, BTN_H, 4);
      fill(on ? 255 : (hov ? 235 : 210));
      textSize(12);
      textAlign(LEFT, CENTER);
      text(toolLabels[i], PAD + 6, y + BTN_H * 0.5);
      textAlign(LEFT, TOP);
      y += BTN_H + BTN_GAP;
    }

    renderBrushPreview(s, mx, my);

    int by = brushMinusY(s);
    boolean hMinus = hoverBrushPlusMinus(s, mx, my) && mx < PAD + 30;
    boolean hPlus = hoverBrushPlusMinus(s, mx, my) && mx >= PAD + 36;
    fill(hMinus ? color(58, 72, 92) : color(45, 55, 70));
    rect(PAD, by, 30, 28, 4);
    fill(hPlus ? color(58, 72, 92) : color(45, 55, 70));
    rect(PAD + 36, by, 30, 28, 4);
    fill(230);
    textSize(15);
    textAlign(CENTER, CENTER);
    text("-", PAD + 15, by + 14);
    text("+", PAD + 36 + 15, by + 14);
    textAlign(LEFT, TOP);

    boolean showFaction = s.activeTool == EditorToolType.TOOL_BUILDING || s.activeTool == EditorToolType.TOOL_UNIT;
    if (showFaction) {
      fill(140, 155, 175);
      textSize(11);
      text("Place as", PAD, factionRowY() - 14);
      int fw = (W - PAD * 2 - 4) / 2;
      boolean pl = "player".equals(s.placementFaction);
      boolean en = "enemy".equals(s.placementFaction);
      boolean hPl = hoverFaction(mx, my, s) && mx < PAD + fw;
      boolean hEn = hoverFaction(mx, my, s) && mx >= PAD + fw + 4;
      fill(pl ? color(60, 110, 160) : (hPl ? color(52, 70, 90) : color(40, 50, 65)));
      rect(PAD, factionRowY(), fw, 30, 4);
      fill(en ? color(160, 70, 70) : (hEn ? color(95, 55, 55) : color(40, 50, 65)));
      rect(PAD + fw + 4, factionRowY(), fw, 30, 4);
      fill(255);
      textSize(12);
      textAlign(CENTER, CENTER);
      text("Player", PAD + fw * 0.5, factionRowY() + 15);
      text("Enemy", PAD + fw + 4 + fw * 0.5, factionRowY() + 15);
      textAlign(LEFT, TOP);
    }
  }

  boolean mousePressed(EditorState s, int mx, int my, int button) {
    if (button != LEFT || !contains(mx, my)) return false;

    int ti = hoverToolIndex(s, mx, my);
    if (ti >= 0) {
      s.activeTool = toolOrder[ti];
      s.setStatus("Tool: " + toolLabels[ti]);
      return true;
    }

    int by = brushMinusY(s);
    if (my >= by && my < by + 28) {
      if (mx >= PAD && mx < PAD + 30) {
        s.brushSize = max(1, s.brushSize - 1);
        return true;
      }
      if (mx >= PAD + 36 && mx < PAD + 36 + 30) {
        s.brushSize = min(9, s.brushSize + 1);
        return true;
      }
    }

    if (s.activeTool == EditorToolType.TOOL_BUILDING || s.activeTool == EditorToolType.TOOL_UNIT) {
      int fy = factionRowY();
      if (my >= fy && my < fy + 30) {
        int fw = (W - PAD * 2 - 4) / 2;
        if (mx >= PAD && mx < PAD + fw) {
          s.placementFaction = "player";
          s.setStatus("Placement: player");
          return true;
        }
        if (mx >= PAD + fw + 4 && mx < PAD + fw + 4 + fw) {
          s.placementFaction = "enemy";
          s.setStatus("Placement: enemy");
          return true;
        }
      }
    }
    return false;
  }
}
