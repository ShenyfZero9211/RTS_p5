class EffectsRuntime {
  void updateOrderMarkers(GameState gs, float dt) {
    for (int i = gs.orderMarkers.size() - 1; i >= 0; i--) {
      OrderMarker m = gs.orderMarkers.get(i);
      m.ttl -= dt;
      if (m.ttl <= 0) {
        gs.orderMarkers.remove(i);
      }
    }
  }

  void renderOrderMarkers(GameState gs) {
    for (OrderMarker m : gs.orderMarkers) {
      m.render(gs.camera);
    }
  }

  void spawnMuzzleFx(GameState gs, Unit shooter, PVector targetPos) {
    gs.muzzleFx.add(new MuzzleFx(shooter.pos.copy(), targetPos));
  }

  void updateMuzzleFx(GameState gs, float dt) {
    for (int i = gs.muzzleFx.size() - 1; i >= 0; i--) {
      MuzzleFx fx = gs.muzzleFx.get(i);
      fx.ttl -= dt;
      if (fx.ttl <= 0) {
        gs.muzzleFx.remove(i);
      }
    }
  }

  void renderMuzzleFx(GameState gs) {
    for (MuzzleFx fx : gs.muzzleFx) {
      fx.render(gs.camera);
    }
  }

  void spawnDeliveryFx(GameState gs, PVector worldPos, int amount) {
    if (amount <= 0) return;
    gs.deliveries.add(new DeliveryFx(worldPos.copy(), amount));
  }

  void updateDeliveryFx(GameState gs, float dt) {
    for (int i = gs.deliveries.size() - 1; i >= 0; i--) {
      DeliveryFx fx = gs.deliveries.get(i);
      fx.ttl -= dt;
      if (fx.ttl <= 0) {
        gs.deliveries.remove(i);
      }
    }
  }

  void renderDeliveryFx(GameState gs) {
    for (DeliveryFx fx : gs.deliveries) {
      fx.render(gs.camera);
    }
  }
}

class MuzzleFx {
  PVector startPos;
  PVector endPos;
  float ttl = 0.07;

  MuzzleFx(PVector startPos, PVector endPos) {
    this.startPos = startPos;
    this.endPos = endPos;
  }

  void render(Camera camera) {
    float k = constrain(ttl / 0.07, 0, 1);
    PVector a = camera.worldToScreen(startPos.x, startPos.y);
    PVector b = camera.worldToScreen(endPos.x, endPos.y);
    PVector d = PVector.sub(b, a);
    if (d.magSq() < 1e-6) return;
    d.normalize();
    PVector m = PVector.add(a, PVector.mult(d, 12 * camera.zoom));
    stroke(255, 225, 130, 230 * k);
    strokeWeight(max(1, 2 * camera.zoom));
    line(a.x, a.y, m.x, m.y);
    noStroke();
    fill(255, 250, 160, 220 * k);
    ellipse(a.x, a.y, 5 * camera.zoom, 5 * camera.zoom);
  }
}

class DeliveryFx {
  PVector pos;
  int amount;
  float ttl = 0.9;

  DeliveryFx(PVector pos, int amount) {
    this.pos = pos;
    this.amount = amount;
  }

  void render(Camera camera) {
    float k = constrain(ttl / 0.9, 0, 1);
    float up = (1 - k) * 22;
    PVector s = camera.worldToScreen(pos.x, pos.y - up);
    noFill();
    stroke(255, 225, 120, 200 * k);
    strokeWeight(max(1, 1.6 * camera.zoom));
    ellipse(s.x, s.y, (10 + (1 - k) * 18) * camera.zoom, (10 + (1 - k) * 18) * camera.zoom);
    fill(255, 235, 140, 230 * k);
    noStroke();
    textAlign(CENTER, TOP);
    textSize(11);
    text("+ " + amount, s.x, s.y - 14 * camera.zoom);
    textAlign(LEFT, TOP);
  }
}

class OrderMarker {
  PVector pos;
  boolean attackStyle;
  float ttl = 0.6;

  OrderMarker(PVector pos, boolean attackStyle) {
    this.pos = pos;
    this.attackStyle = attackStyle;
  }

  void render(Camera camera) {
    PVector s = camera.worldToScreen(pos.x, pos.y);
    float k = constrain(ttl / 0.6, 0, 1);
    float r = 8 + (1 - k) * 14;
    noFill();
    strokeWeight(2);
    if (attackStyle) {
      stroke(255, 90, 90, 220 * k);
      ellipse(s.x, s.y, r * 2, r * 2);
      line(s.x - r, s.y - r, s.x + r, s.y + r);
      line(s.x - r, s.y + r, s.x + r, s.y - r);
    } else {
      stroke(120, 255, 120, 220 * k);
      ellipse(s.x, s.y, r * 2, r * 2);
    }
  }
}
