class Minimap {
  int x;
  int y;
  int w;
  int h;

  Minimap(int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  void render(TileMap map, Camera camera, ArrayList<Unit> units, ArrayList<Building> buildings, GameState gs) {
    noStroke();
    fill(18);
    rect(x, y, w, h);

    float scaleX = w / float(map.worldWidthPx());
    float scaleY = h / float(map.worldHeightPx());
    float scale = min(scaleX, scaleY);
    float drawW = map.worldWidthPx() * scale;
    float drawH = map.worldHeightPx() * scale;
    float ox = x + (w - drawW) * 0.5;
    float oy = y + (h - drawH) * 0.5;

    // Letterbox/pillarbox background for non-square aspect fit.
    fill(10, 10, 10, 170);
    rect(x, y, w, h);
    stroke(55, 55, 55);
    noFill();
    rect(ox, oy, drawW, drawH);

    int step = 2;
    for (int ty = 0; ty < map.heightTiles; ty += step) {
      for (int tx = 0; tx < map.widthTiles; tx += step) {
        int t = map.terrain[ty][tx];
        if (t == 0) {
          fill(95, 80, 60);
        } else if (t == 1) {
          fill(80, 80, 80);
        } else {
          fill(42, 42, 42);
        }
        float px = ox + tx * map.tileSize * scale;
        float py = oy + ty * map.tileSize * scale;
        rect(px, py, map.tileSize * scale * step, map.tileSize * scale * step);
      }
    }

    for (Building b : buildings) {
      if (gs != null && !gs.isBuildingVisibleToPlayer(b)) {
        continue;
      }
      fill(factionColor(b.faction));
      float bx = ox + b.pos.x * scale;
      float by = oy + b.pos.y * scale;
      rect(bx, by, b.tileW * map.tileSize * scale, b.tileH * map.tileSize * scale);
    }

    for (Unit u : units) {
      if (gs != null && !gs.isUnitVisibleToPlayer(u)) {
        continue;
      }
      fill(factionColor(u.faction));
      float ux = ox + u.pos.x * scale;
      float uy = oy + u.pos.y * scale;
      float d = max(2, 3 * scale / min(scaleX, scaleY));
      rect(ux - d * 0.5, uy - d * 0.5, d, d);
    }

    if (gs != null && gs.fogEnabled && gs.fog != null) {
      noStroke();
      for (int ty = 0; ty < map.heightTiles; ty += step) {
        for (int tx = 0; tx < map.widthTiles; tx += step) {
          int alpha = gs.fog.displayAlphaInt(tx, ty);
          if (alpha <= 0) {
            continue;
          }
          fill(0, 0, 0, alpha);
          float px = ox + tx * map.tileSize * scale;
          float py = oy + ty * map.tileSize * scale;
          rect(px, py, map.tileSize * scale * step, map.tileSize * scale * step);
        }
      }
    }

    noFill();
    stroke(120, 255, 120);
    float vwWorld = camera.visibleWorldW();
    float vhWorld = camera.visibleWorldH();
    float vx = ox + camera.x * scale;
    float vy = oy + camera.y * scale;
    float vw = min(vwWorld * scale, drawW);
    float vh = min(vhWorld * scale, drawH);
    vx = constrain(vx, ox, ox + drawW - vw);
    vy = constrain(vy, oy, oy + drawH - vh);
    rect(vx, vy, vw, vh);
  }

  boolean contains(int mx, int my) {
    return mx >= x && mx <= x + w && my >= y && my <= y + h;
  }

  PVector minimapToWorld(int mx, int my, TileMap map) {
    float scale = min(w / float(map.worldWidthPx()), h / float(map.worldHeightPx()));
    float drawW = map.worldWidthPx() * scale;
    float drawH = map.worldHeightPx() * scale;
    float ox = x + (w - drawW) * 0.5;
    float oy = y + (h - drawH) * 0.5;
    float nx = (mx - ox) / max(1, drawW);
    float ny = (my - oy) / max(1, drawH);
    nx = constrain(nx, 0, 1);
    ny = constrain(ny, 0, 1);
    return new PVector(nx * map.worldWidthPx(), ny * map.worldHeightPx());
  }
}
