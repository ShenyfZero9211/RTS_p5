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

  void render(TileMap map, Camera camera, ArrayList<Unit> units, ArrayList<Building> buildings) {
    noStroke();
    fill(18);
    rect(x, y, w, h);

    float scaleX = w / float(map.worldWidthPx());
    float scaleY = h / float(map.worldHeightPx());

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
        float px = x + tx * map.tileSize * scaleX;
        float py = y + ty * map.tileSize * scaleY;
        rect(px, py, map.tileSize * scaleX * step, map.tileSize * scaleY * step);
      }
    }

    for (Building b : buildings) {
      fill(factionColor(b.faction));
      float bx = x + b.pos.x * scaleX;
      float by = y + b.pos.y * scaleY;
      rect(bx, by, b.tileW * map.tileSize * scaleX, b.tileH * map.tileSize * scaleY);
    }

    for (Unit u : units) {
      fill(factionColor(u.faction));
      float ux = x + u.pos.x * scaleX;
      float uy = y + u.pos.y * scaleY;
      rect(ux - 1, uy - 1, 3, 3);
    }

    noFill();
    stroke(120, 255, 120);
    float vwWorld = camera.visibleWorldW();
    float vhWorld = camera.visibleWorldH();
    float vx = x + camera.x * scaleX;
    float vy = y + camera.y * scaleY;
    float vw = vwWorld * scaleX;
    float vh = vhWorld * scaleY;
    vw = min(vw, w);
    vh = min(vh, h);
    vx = constrain(vx, x, x + w - vw);
    vy = constrain(vy, y, y + h - vh);
    rect(vx, vy, vw, vh);
  }

  boolean contains(int mx, int my) {
    return mx >= x && mx <= x + w && my >= y && my <= y + h;
  }

  PVector minimapToWorld(int mx, int my, TileMap map) {
    float nx = (mx - x) / float(w);
    float ny = (my - y) / float(h);
    return new PVector(nx * map.worldWidthPx(), ny * map.worldHeightPx());
  }
}
