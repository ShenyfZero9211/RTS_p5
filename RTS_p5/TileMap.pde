class TileMap {
  int tileSize = 32;
  int widthTiles;
  int heightTiles;
  int[][] terrain;
  boolean[][] blocked;
  boolean disableStaticObstacles = false;

  boolean loadFromJson(String fileName) {
    JSONObject root = loadJSONObject(fileName);
    if (root == null) {
      return false;
    }

    tileSize = root.getInt("tileSize");
    widthTiles = root.getInt("width");
    heightTiles = root.getInt("height");

    disableStaticObstacles = root.getBoolean("disableStaticObstacles", false);
    terrain = new int[heightTiles][widthTiles];
    blocked = new boolean[heightTiles][widthTiles];
    JSONArray rows = root.getJSONArray("rows");

    for (int y = 0; y < heightTiles; y++) {
      String row = rows.getString(y);
      for (int x = 0; x < widthTiles; x++) {
        char c = row.charAt(x);
        int t = 0;
        if (c == 'R') {
          t = 1;
        } else if (c == 'B') {
          t = 2;
        }
        if (disableStaticObstacles) {
          t = 0;
        }
        terrain[y][x] = t;
        blocked[y][x] = (t == 2);
      }
    }
    return true;
  }

  int worldWidthPx() {
    return widthTiles * tileSize;
  }

  int worldHeightPx() {
    return heightTiles * tileSize;
  }

  void render(Camera camera, int viewportW, int viewportH) {
    int startX = max(0, int(camera.x / tileSize));
    int startY = max(0, int(camera.y / tileSize));
    int endX = min(widthTiles - 1, int((camera.x + camera.visibleWorldW()) / tileSize) + 1);
    int endY = min(heightTiles - 1, int((camera.y + camera.visibleWorldH()) / tileSize) + 1);

    noStroke();
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        int t = terrain[y][x];
        if (t == 0) {
          fill(126, 103, 74);
        } else if (t == 1) {
          fill(92, 88, 84);
        } else {
          fill(65, 65, 65);
        }
        float sx = (x * tileSize - camera.x) * camera.zoom;
        float sy = (y * tileSize - camera.y) * camera.zoom;
        float s = tileSize * camera.zoom;
        rect(sx, sy, s, s);
      }
    }
  }

  boolean isBlockedTile(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= widthTiles || ty >= heightTiles) {
      return true;
    }
    return blocked[ty][tx];
  }

  int terrainAt(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= widthTiles || ty >= heightTiles) {
      return -1;
    }
    return terrain[ty][tx];
  }

  int toTileX(float worldX) {
    return floor(worldX / tileSize);
  }

  int toTileY(float worldY) {
    return floor(worldY / tileSize);
  }
}
