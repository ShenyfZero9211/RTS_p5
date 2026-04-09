BuildingRenderer BUILDING_RENDERER = new BuildingRenderer();

class BuildingRenderer {
  void render(Building b, Camera camera, int tileSize) {
    PVector s = camera.worldToScreen(b.pos.x, b.pos.y);
    float sw = b.tileW * tileSize * camera.zoom;
    float sh = b.tileH * tileSize * camera.zoom;
    float margin = 18;
    if (s.x + sw < -margin || s.y + sh < -margin || s.x > camera.viewportW + margin || s.y > camera.viewportH + margin) {
      return;
    }
    pushStyle();
    noStroke();
    int base = factionColor(b.faction);
    if (!b.completed) {
      fill(red(base), green(base), blue(base), 120);
    } else {
      fill(base, 220);
    }
    rect(s.x, s.y, sw, sh);
    stroke(40);
    strokeWeight(1);
    noFill();
    rect(s.x, s.y, sw, sh);
    if (b.selected) {
      stroke(20, 240, 90);
      strokeWeight(2);
      noFill();
      rect(s.x - 2, s.y - 2, sw + 4, sh + 4);
    }

    if (!b.completed) {
      float pct = constrain(b.buildProgress / b.buildTime, 0, 1);
      noStroke();
      fill(20, 20, 20, 220);
      rect(s.x, s.y - 8, sw, 5);
      fill(80, 230, 110);
      rect(s.x, s.y - 8, sw * pct, 5);
    }
    if (b.completed && b.hp < b.maxHp) {
      noStroke();
      fill(20, 20, 20, 220);
      rect(s.x, s.y - 8, sw, 5);
      fill(95, 220, 110);
      rect(s.x, s.y - 8, sw * constrain(b.hp / float(max(1, b.maxHp)), 0, 1), 5);
    }

    String label = b.buildingType == null ? "BUILDING" : b.buildingType.toUpperCase();
    fill(18, 18, 18, 180);
    rect(s.x, s.y - 24, min(sw, 90), 14);
    fill(245);
    textSize(10);
    textAlign(LEFT, TOP);
    text(label, s.x + 3, s.y - 22);

    if (b.buildingType != null && b.buildingType.equals("tower") && b.completed) {
      float cx = s.x + sw * 0.5;
      float cy = s.y + sh * 0.52;
      float bodyR = max(4, min(sw, sh) * 0.22);
      noStroke();
      fill(48, 52, 60, 220);
      ellipse(cx, cy, bodyR * 2.3, bodyR * 2.3);
      fill(90, 96, 110, 220);
      ellipse(cx, cy, bodyR * 1.3, bodyR * 1.3);
      float ang = b.turretAimAngle;
      float barrelLen = max(6, min(sw, sh) * 0.62);
      float bx = cx + cos(ang) * barrelLen;
      float by = cy + sin(ang) * barrelLen;
      stroke(120, 128, 145, 240);
      strokeWeight(max(2, min(sw, sh) * 0.12));
      line(cx, cy, bx, by);
      noStroke();
      fill(245, 180, 120, 220);
      ellipse(bx, by, max(3, min(sw, sh) * 0.12), max(3, min(sw, sh) * 0.12));
    }
    popStyle();
  }
}
