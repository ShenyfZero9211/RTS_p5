class Pathfinder {
  TileMap map;

  Pathfinder(TileMap map) {
    this.map = map;
  }

  ArrayList<PVector> findPath(PVector startWorld, PVector goalWorld, ArrayList<Building> buildings) {
    int sx = map.toTileX(startWorld.x);
    int sy = map.toTileY(startWorld.y);
    int gx = map.toTileX(goalWorld.x);
    int gy = map.toTileY(goalWorld.y);

    if (!isWalkable(gx, gy, buildings)) {
      PVector fallback = findClosestWalkable(gx, gy, buildings);
      gx = int(fallback.x);
      gy = int(fallback.y);
    }
    if (!isWalkable(sx, sy, buildings) || !isWalkable(gx, gy, buildings)) {
      return new ArrayList<PVector>();
    }

    ArrayList<PathNode> open = new ArrayList<PathNode>();
    boolean[][] closed = new boolean[map.heightTiles][map.widthTiles];
    PathNode[][] nodes = new PathNode[map.heightTiles][map.widthTiles];

    PathNode start = new PathNode(sx, sy);
    start.g = 0;
    start.h = heuristic(sx, sy, gx, gy);
    start.f = start.h;
    open.add(start);
    nodes[sy][sx] = start;

    while (open.size() > 0) {
      int bestIdx = 0;
      for (int i = 1; i < open.size(); i++) {
        if (open.get(i).f < open.get(bestIdx).f) {
          bestIdx = i;
        }
      }
      PathNode cur = open.remove(bestIdx);
      if (cur.x == gx && cur.y == gy) {
        ArrayList<PVector> raw = reconstruct(cur);
        return smoothPath(raw, buildings);
      }
      closed[cur.y][cur.x] = true;

      int[] dx = {1, -1, 0, 0, 1, 1, -1, -1};
      int[] dy = {0, 0, 1, -1, 1, -1, 1, -1};
      for (int i = 0; i < 8; i++) {
        int nx = cur.x + dx[i];
        int ny = cur.y + dy[i];
        if (nx < 0 || ny < 0 || nx >= map.widthTiles || ny >= map.heightTiles) {
          continue;
        }
        boolean diagonal = (dx[i] != 0 && dy[i] != 0);
        if (diagonal && !canMoveDiagonal(cur.x, cur.y, nx, ny, buildings)) {
          continue;
        }
        if (closed[ny][nx] || !isWalkable(nx, ny, buildings)) {
          continue;
        }
        float step = diagonal ? 1.4142135 : 1.0;
        float ng = cur.g + step * edgeMovementCost(cur.x, cur.y, nx, ny, buildings);
        PathNode nxt = nodes[ny][nx];
        if (nxt == null) {
          nxt = new PathNode(nx, ny);
          nodes[ny][nx] = nxt;
        }
        if (!open.contains(nxt) || ng < nxt.g) {
          nxt.parent = cur;
          nxt.g = ng;
          nxt.h = heuristic(nx, ny, gx, gy);
          nxt.f = nxt.g + nxt.h;
          if (!open.contains(nxt)) {
            open.add(nxt);
          }
        }
      }
    }
    return new ArrayList<PVector>();
  }

  PVector findClosestWalkable(int tx, int ty, ArrayList<Building> buildings) {
    if (isWalkable(tx, ty, buildings)) {
      return new PVector(tx, ty);
    }
    int maxR = max(map.widthTiles, map.heightTiles) + 2;
    for (int r = 1; r <= maxR; r++) {
      PVector best = null;
      float bestD = 1e18;
      for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
          if (abs(dx) != r && abs(dy) != r) {
            continue;
          }
          int nx = tx + dx;
          int ny = ty + dy;
          if (!isWalkable(nx, ny, buildings)) {
            continue;
          }
          float d = dx * dx + dy * dy;
          if (d < bestD) {
            bestD = d;
            best = new PVector(nx, ny);
          }
        }
      }
      if (best != null) {
        return best;
      }
    }
    for (int y = 0; y < map.heightTiles; y++) {
      for (int x = 0; x < map.widthTiles; x++) {
        if (isWalkable(x, y, buildings)) {
          return new PVector(x, y);
        }
      }
    }
    return new PVector(tx, ty);
  }

  PVector resolveGoalWorld(PVector goalWorld, ArrayList<Building> buildings) {
    int gx = map.toTileX(goalWorld.x);
    int gy = map.toTileY(goalWorld.y);
    if (isWalkable(gx, gy, buildings)) {
      return goalWorld.copy();
    }
    PVector t = findClosestWalkable(gx, gy, buildings);
    int wx = int(t.x);
    int wy = int(t.y);
    if (!isWalkable(wx, wy, buildings)) {
      return goalWorld.copy();
    }
    return new PVector((wx + 0.5) * map.tileSize, (wy + 0.5) * map.tileSize);
  }

  boolean isWalkable(int tx, int ty, ArrayList<Building> buildings) {
    if (map.isBlockedTile(tx, ty)) {
      return false;
    }
    for (Building b : buildings) {
      int bx = map.toTileX(b.pos.x);
      int by = map.toTileY(b.pos.y);
      if (tx >= bx && tx < bx + b.tileW && ty >= by && ty < by + b.tileH) {
        return false;
      }
    }
    return true;
  }

  float heuristic(int ax, int ay, int bx, int by) {
    float dx = abs(ax - bx);
    float dy = abs(ay - by);
    float minv = min(dx, dy);
    float maxv = max(dx, dy);
    return 1.4142135 * minv + (maxv - minv);
  }

  ArrayList<PVector> reconstruct(PathNode end) {
    ArrayList<PVector> reversed = new ArrayList<PVector>();
    PathNode cur = end;
    while (cur != null) {
      float cx = (cur.x + 0.5) * map.tileSize;
      float cy = (cur.y + 0.5) * map.tileSize;
      reversed.add(new PVector(cx, cy));
      cur = cur.parent;
    }
    ArrayList<PVector> path = new ArrayList<PVector>();
    for (int i = reversed.size() - 1; i >= 0; i--) {
      path.add(reversed.get(i));
    }
    return path;
  }

  boolean canMoveDiagonal(int x0, int y0, int x1, int y1, ArrayList<Building> buildings) {
    return isWalkable(x0, y1, buildings) && isWalkable(x1, y0, buildings);
  }

  ArrayList<PVector> smoothPath(ArrayList<PVector> raw, ArrayList<Building> buildings) {
    if (raw.size() <= 2) {
      return raw;
    }
    ArrayList<PVector> out = new ArrayList<PVector>();
    int anchor = 0;
    out.add(raw.get(0));
    while (anchor < raw.size() - 1) {
      int furthest = anchor + 1;
      for (int i = raw.size() - 1; i > anchor + 1; i--) {
        if (hasLineOfSight(raw.get(anchor), raw.get(i), buildings)) {
          furthest = i;
          break;
        }
      }
      out.add(raw.get(furthest));
      anchor = furthest;
    }
    return out;
  }

  boolean hasLineOfSight(PVector a, PVector b, ArrayList<Building> buildings) {
    float d = PVector.dist(a, b);
    int stepCount = max(2, int(d / (map.tileSize * 0.28)));
    for (int i = 0; i <= stepCount; i++) {
      float t = i / float(stepCount);
      float x = lerp(a.x, b.x, t);
      float y = lerp(a.y, b.y, t);
      int tx = map.toTileX(x);
      int ty = map.toTileY(y);
      if (!isWalkable(tx, ty, buildings)) {
        return false;
      }
    }
    return true;
  }

  float edgeMovementCost(int x0, int y0, int x1, int y1, ArrayList<Building> buildings) {
    return 0.5 * (tileMovementCost(x0, y0, buildings) + tileMovementCost(x1, y1, buildings));
  }

  float tileMovementCost(int tx, int ty, ArrayList<Building> buildings) {
    if (!isWalkable(tx, ty, buildings)) {
      return 1e6;
    }
    int t = map.terrainAt(tx, ty);
    float base = 1.0;
    if (t == 1) {
      base = 1.38;
    }
    int blockedNeighbors = countNonWalkableNeighbors8(tx, ty, buildings);
    float wallBias = min(6, blockedNeighbors) * 0.16;
    return base + wallBias;
  }

  int countNonWalkableNeighbors8(int tx, int ty, ArrayList<Building> buildings) {
    int c = 0;
    int[] dx = {1, -1, 0, 0, 1, 1, -1, -1};
    int[] dy = {0, 0, 1, -1, 1, -1, 1, -1};
    for (int i = 0; i < 8; i++) {
      int nx = tx + dx[i];
      int ny = ty + dy[i];
      if (!isWalkable(nx, ny, buildings)) {
        c++;
      }
    }
    return c;
  }
}

class PathNode {
  int x;
  int y;
  float g = 1e9;
  float h;
  float f;
  PathNode parent;

  PathNode(int x, int y) {
    this.x = x;
    this.y = y;
  }
}
