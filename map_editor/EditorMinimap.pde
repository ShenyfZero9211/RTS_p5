/**
 * Minimap: terrain, entities, green viewport. Bounds + layout via syncGeometry / renderAt.
 */
class EditorMinimap {
  int x;
  int y;
  int w;
  int h;

  float mmOx;
  float mmOy;
  float mmScale;
  float mmDrawW;
  float mmDrawH;

  float viewScreenX;
  float viewScreenY;
  float viewScreenW;
  float viewScreenH;

  void setBounds(int sx, int sy, int sw, int sh) {
    x = sx;
    y = sy;
    w = sw;
    h = sh;
  }

  /** Recompute inner map rect, scale, and green viewport (screen px). Call before hit tests or render. */
  void syncGeometry(EditorState s, int rx, int ry, int rw, int rh) {
    setBounds(rx, ry, rw, rh);
    int worldWpx = s.mapWidth * s.tileSize;
    int worldHpx = s.mapHeight * s.tileSize;
    float scaleX = w / float(max(1, worldWpx));
    float scaleY = h / float(max(1, worldHpx));
    mmScale = min(scaleX, scaleY);
    mmDrawW = worldWpx * mmScale;
    mmDrawH = worldHpx * mmScale;
    mmOx = x + (w - mmDrawW) * 0.5f;
    mmOy = y + (h - mmDrawH) * 0.5f;

    int viewW = s.mapViewWidthPx();
    int viewH = s.mapViewHeightPx();
    float vwWorld = s.editorVisibleWorldW(viewW);
    float vhWorld = s.editorVisibleWorldH(viewH);
    float vx = mmOx + s.camX * mmScale;
    float vy = mmOy + s.camY * mmScale;
    float vw = min(vwWorld * mmScale, mmDrawW);
    float vh = min(vhWorld * mmScale, mmDrawH);
    vx = constrain(vx, mmOx, mmOx + mmDrawW - vw);
    vy = constrain(vy, mmOy, mmOy + mmDrawH - vh);
    viewScreenX = vx;
    viewScreenY = vy;
    viewScreenW = vw;
    viewScreenH = vh;
  }

  boolean contains(int mx, int my) {
    return mx >= x && mx < x + w && my >= y && my < y + h;
  }

  boolean viewportContainsScreen(int mx, int my) {
    return mx >= viewScreenX && mx < viewScreenX + viewScreenW
      && my >= viewScreenY && my < viewScreenY + viewScreenH;
  }

  void dragCameraByMinimapDelta(EditorState s, int dmx, int dmy) {
    if (mmScale <= 0.0001) return;
    s.camX += dmx / mmScale;
    s.camY += dmy / mmScale;
    s.clampWorldCamera(s.mapViewWidthPx(), s.mapViewHeightPx());
  }

  void renderAt(EditorState s, int rx, int ry, int rw, int rh) {
    syncGeometry(s, rx, ry, rw, rh);
    int worldWpx = s.mapWidth * s.tileSize;
    int worldHpx = s.mapHeight * s.tileSize;

    noStroke();
    fill(18);
    rect(x, y, w, h);

    float ox = mmOx;
    float oy = mmOy;
    float drawW = mmDrawW;
    float drawH = mmDrawH;
    float scale = mmScale;

    fill(10, 10, 10, 170);
    rect(x, y, w, h);
    stroke(55, 55, 55);
    noFill();
    rect(ox, oy, drawW, drawH);

    int step = 2;
    for (int ty = 0; ty < s.mapHeight; ty += step) {
      for (int tx = 0; tx < s.mapWidth; tx += step) {
        int t = s.terrainAt(tx, ty);
        if (t == 0) fill(95, 80, 60);
        else if (t == 1) fill(80, 80, 80);
        else fill(42, 42, 42);
        noStroke();
        float px = ox + tx * s.tileSize * scale;
        float py = oy + ty * s.tileSize * scale;
        rect(px, py, s.tileSize * scale * step, s.tileSize * scale * step);
      }
    }

    for (EditorMine m : s.mines) {
      fill(80, 160, 235);
      float px = ox + m.tx * s.tileSize * scale;
      float py = oy + m.ty * s.tileSize * scale;
      rect(px + 1, py + 1, max(2, s.tileSize * scale * 0.6), max(2, s.tileSize * scale * 0.6));
    }

    for (EditorSpawn sp : s.spawns) {
      if ("player".equals(sp.faction)) fill(80, 180, 255);
      else fill(255, 110, 110);
      float cx = ox + (sp.tx + 0.5) * s.tileSize * scale;
      float cy = oy + (sp.ty + 0.5) * s.tileSize * scale;
      float d = max(3, 5 * scale);
      ellipse(cx, cy, d, d);
    }

    for (EditorPlacedBuilding b : s.initialBuildings) {
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      if ("player".equals(b.faction)) fill(80, 180, 255);
      else fill(255, 120, 120);
      float bx = ox + b.tx * s.tileSize * scale;
      float by = oy + b.ty * s.tileSize * scale;
      rect(bx, by, bw * s.tileSize * scale, bh * s.tileSize * scale);
    }

    for (EditorPlacedUnit u : s.initialUnits) {
      if ("player".equals(u.faction)) fill(80, 180, 255);
      else fill(255, 120, 120);
      float ux = ox + u.worldCX * scale;
      float uy = oy + u.worldCY * scale;
      float d = max(2, 3 * scale / min(w / float(max(1, worldWpx)), h / float(max(1, worldHpx))));
      rect(ux - d * 0.5, uy - d * 0.5, d, d);
    }

    noFill();
    stroke(120, 255, 120);
    strokeWeight(1);
    rect(viewScreenX, viewScreenY, viewScreenW, viewScreenH);
    noStroke();
  }

  PVector minimapToWorld(EditorState s, int mx, int my) {
    int worldWpx = s.mapWidth * s.tileSize;
    int worldHpx = s.mapHeight * s.tileSize;
    float scaleX = w / float(max(1, worldWpx));
    float scaleY = h / float(max(1, worldHpx));
    float scale = min(scaleX, scaleY);
    float drawW = worldWpx * scale;
    float drawH = worldHpx * scale;
    float ox = x + (w - drawW) * 0.5;
    float oy = y + (h - drawH) * 0.5;
    float nx = (mx - ox) / max(1, drawW);
    float ny = (my - oy) / max(1, drawH);
    nx = constrain(nx, 0, 1);
    ny = constrain(ny, 0, 1);
    return new PVector(nx * worldWpx, ny * worldHpx);
  }

  void centerCameraOnWorldPoint(EditorState s, float worldX, float worldY) {
    int viewW = s.mapViewWidthPx();
    int viewH = s.mapViewHeightPx();
    float vw = s.editorVisibleWorldW(viewW);
    float vh = s.editorVisibleWorldH(viewH);
    s.camX = worldX - vw * 0.5;
    s.camY = worldY - vh * 0.5;
    s.clampWorldCamera(viewW, viewH);
  }
}
