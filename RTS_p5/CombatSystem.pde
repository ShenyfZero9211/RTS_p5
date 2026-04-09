class CombatSystem {
  void updateTowerDefense(GameState gs, float dt) {
    if (gs.gameEnded) return;
    for (Building b : gs.buildings) {
      if (!b.completed || b.hp <= 0) continue;
      BuildingDef ddef = gs.getBuildingDef(b.buildingType);
      if (ddef == null || !ddef.isTower) continue;
      b.towerCooldown = max(0, b.towerCooldown - dt);
      if (b.towerCooldown > 0) continue;
      float range = ddef.towerAttackRange;
      Unit tgt = findTowerHostileUnitInRange(gs, b, range);
      Building bt = null;
      if (tgt == null) {
        bt = findTowerHostileBuildingInRange(gs, b, range);
        if (bt == null) continue;
      }
      PVector muzzle = towerMuzzleWorld(gs, b);
      float cx = b.pos.x + b.tileW * gs.map.tileSize * 0.5;
      float cy = b.pos.y + b.tileH * gs.map.tileSize * 0.5;
      if (tgt != null) {
        b.turretAimAngle = atan2(tgt.pos.y - cy, tgt.pos.x - cx);
        spawnRocketProjectileFromWorld(gs, muzzle, tgt, ddef.towerDamage, ddef.towerProjectileSpeed);
      } else {
        PVector bc = new PVector(bt.pos.x + bt.tileW * gs.map.tileSize * 0.5, bt.pos.y + bt.tileH * gs.map.tileSize * 0.5);
        b.turretAimAngle = atan2(bc.y - cy, bc.x - cx);
        spawnRocketProjectileFromWorld(gs, muzzle, bt, ddef.towerDamage, ddef.towerProjectileSpeed);
      }
      b.towerCooldown = ddef.towerCooldown;
    }
  }

  PVector towerMuzzleWorld(GameState gs, Building b) {
    float ts = gs.map.tileSize;
    float cx = b.pos.x + b.tileW * ts * 0.5;
    float cy = b.pos.y + b.tileH * ts * 0.5;
    return new PVector(cx, cy - ts * 0.20);
  }

  Unit findTowerHostileUnitInRange(GameState gs, Building tower, float rangePx) {
    float cx = tower.pos.x + tower.tileW * gs.map.tileSize * 0.5;
    float cy = tower.pos.y + tower.tileH * gs.map.tileSize * 0.5;
    Unit best = null;
    float bestScore = 1e9;
    for (Unit u : gs.units) {
      if (u.hp <= 0 || !gs.isHostile(tower.faction, u.faction)) continue;
      float d = dist(cx, cy, u.pos.x, u.pos.y);
      if (d > rangePx) continue;
      if (tower.faction == Faction.PLAYER && !gs.isUnitVisibleToPlayer(u)) continue;
      float score = d + u.hp * 0.2;
      if (score < bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  Building findTowerHostileBuildingInRange(GameState gs, Building tower, float rangePx) {
    float cx = tower.pos.x + tower.tileW * gs.map.tileSize * 0.5;
    float cy = tower.pos.y + tower.tileH * gs.map.tileSize * 0.5;
    Building best = null;
    float bestScore = 1e9;
    for (Building b : gs.buildings) {
      if (b == null || b.hp <= 0 || !gs.isHostile(tower.faction, b.faction)) continue;
      float bx = b.pos.x + b.tileW * gs.map.tileSize * 0.5;
      float by = b.pos.y + b.tileH * gs.map.tileSize * 0.5;
      float d = dist(cx, cy, bx, by);
      if (d > rangePx) continue;
      if (tower.faction == Faction.PLAYER && !gs.isBuildingVisibleToPlayer(b)) continue;
      float score = d + b.hp * 0.1;
      if (score < bestScore) {
        bestScore = score;
        best = b;
      }
    }
    return best;
  }

  void spawnRocketProjectile(GameState gs, Unit from, Unit target, float dmg, float speed) {
    if (target == null || target.hp <= 0) return;
    gs.rockets.add(new RocketProjectile(from.pos.copy(), target, dmg, speed));
  }

  void spawnRocketProjectile(GameState gs, Unit from, Building target, float dmg, float speed) {
    if (from == null || target == null || target.hp <= 0 || gs.map == null) return;
    PVector center = new PVector(target.pos.x + target.tileW * gs.map.tileSize * 0.5, target.pos.y + target.tileH * gs.map.tileSize * 0.5);
    gs.rockets.add(new RocketProjectile(from.pos.copy(), target, center, dmg, speed));
  }

  void spawnRocketProjectileFromWorld(GameState gs, PVector worldStart, Unit target, float dmg, float speed) {
    if (worldStart == null || target == null || target.hp <= 0) return;
    gs.rockets.add(new RocketProjectile(worldStart.copy(), target, dmg, speed));
  }

  void spawnRocketProjectileFromWorld(GameState gs, PVector worldStart, Building target, float dmg, float speed) {
    if (worldStart == null || target == null || target.hp <= 0 || gs.map == null) return;
    PVector center = new PVector(target.pos.x + target.tileW * gs.map.tileSize * 0.5, target.pos.y + target.tileH * gs.map.tileSize * 0.5);
    gs.rockets.add(new RocketProjectile(worldStart.copy(), target, center, dmg, speed));
  }

  void updateRockets(GameState gs, float dt) {
    for (int i = gs.rockets.size() - 1; i >= 0; i--) {
      RocketProjectile p = gs.rockets.get(i);
      if (p.update(dt)) {
        gs.rockets.remove(i);
      }
    }
  }

  void renderRockets(GameState gs) {
    for (RocketProjectile p : gs.rockets) {
      p.render(gs.camera);
    }
  }
}

class RocketProjectile {
  PVector pos;
  Unit target;
  Building buildingTarget;
  PVector fixedTargetPos;
  float damage;
  float speed;
  PVector vel = new PVector();
  ArrayList<RocketSmoke> smokeTrail = new ArrayList<RocketSmoke>();
  int maxTrail = 44;
  float ttl = 3.0;
  boolean impactDone = false;

  RocketProjectile(PVector pos, Unit target, float damage, float speed) {
    this.pos = pos.copy();
    this.target = target;
    this.damage = damage;
    this.speed = speed;
    fixedTargetPos = target != null ? target.pos.copy() : pos.copy();
    PVector aim = fixedTargetPos.copy();
    PVector initial = PVector.sub(aim, this.pos);
    if (initial.magSq() < 1e-6) {
      initial.set(1, 0);
    } else {
      initial.normalize();
    }
    vel = initial.mult(max(60, speed * 0.62));
  }

  RocketProjectile(PVector pos, Building target, PVector targetPos, float damage, float speed) {
    this.pos = pos.copy();
    this.buildingTarget = target;
    this.fixedTargetPos = targetPos == null ? pos.copy() : targetPos.copy();
    this.damage = damage;
    this.speed = speed;
    PVector initial = PVector.sub(this.fixedTargetPos, this.pos);
    if (initial.magSq() < 1e-6) {
      initial.set(1, 0);
    } else {
      initial.normalize();
    }
    vel = initial.mult(max(60, speed * 0.60));
  }

  PVector liveTargetPos() {
    if (target != null && target.hp > 0) {
      fixedTargetPos = target.pos.copy();
      return fixedTargetPos.copy();
    }
    if (fixedTargetPos != null) {
      return fixedTargetPos.copy();
    }
    return null;
  }

  void applyImpact() {
    if (impactDone) return;
    impactDone = true;
    if (target != null && target.hp > 0) {
      target.hp -= int(damage);
      return;
    }
    if (buildingTarget != null && buildingTarget.hp > 0) {
      buildingTarget.hp -= int(damage);
    }
  }

  boolean update(float dt) {
    for (int i = smokeTrail.size() - 1; i >= 0; i--) {
      RocketSmoke rs = smokeTrail.get(i);
      rs.age += dt;
      if (rs.age >= rs.ttl) {
        smokeTrail.remove(i);
      }
    }
    if (impactDone) return smokeTrail.size() == 0;
    ttl -= dt;
    if (ttl <= 0) {
      impactDone = true;
      return smokeTrail.size() == 0;
    }
    PVector aim = liveTargetPos();
    if (aim == null) {
      impactDone = true;
      return smokeTrail.size() == 0;
    }
    PVector delta = PVector.sub(aim, pos);
    float dist = delta.mag();
    if (dist < 10) {
      applyImpact();
      return smokeTrail.size() == 0;
    }
    if (delta.magSq() < 1e-6) {
      delta.set(1, 0);
    } else {
      delta.normalize();
    }
    PVector desiredVel = PVector.mult(delta, speed);
    float steer = constrain(0.95 * dt + 0.10, 0.10, 0.42);
    vel.lerp(desiredVel, steer);
    PVector step = PVector.mult(vel, dt);
    if (step.mag() >= dist) {
      pos.set(aim);
      applyImpact();
      return smokeTrail.size() == 0;
    }
    pos.add(step);
    smokeTrail.add(new RocketSmoke(pos.copy(), random(0.22, 0.44), random(2.0, 5.2)));
    while (smokeTrail.size() > maxTrail) smokeTrail.remove(0);
    return false;
  }

  void render(Camera camera) {
    if (camera == null) return;
    PVector s = camera.worldToScreen(pos.x, pos.y);
    noStroke();
    for (int i = 0; i < smokeTrail.size(); i++) {
      RocketSmoke rs = smokeTrail.get(i);
      float life = constrain(1.0 - rs.age / max(0.001, rs.ttl), 0, 1);
      PVector sp = camera.worldToScreen(rs.pos.x, rs.pos.y);
      float r = rs.size * life * camera.zoom;
      fill(80, 85, 95, 165 * life);
      ellipse(sp.x, sp.y, r * 2, r * 2);
    }
    if (impactDone) return;
    fill(255, 225, 170, 245);
    ellipse(s.x, s.y, 6 * camera.zoom, 6 * camera.zoom);
  }
}

class RocketSmoke {
  PVector pos;
  float ttl;
  float age = 0;
  float size;

  RocketSmoke(PVector pos, float ttl, float size) {
    this.pos = pos;
    this.ttl = ttl;
    this.size = size;
  }
}
