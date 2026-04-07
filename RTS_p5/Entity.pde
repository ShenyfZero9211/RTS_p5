abstract class Entity {
  PVector pos;
  float radius;
  Faction faction;

  Entity(float x, float y, float r, Faction faction) {
    this.pos = new PVector(x, y);
    this.radius = r;
    this.faction = faction;
  }
}

class Unit extends Entity {
  ArrayList<PVector> pathQueue = new ArrayList<PVector>();
  boolean selected;
  float speed = 120;
  int hp = 100;
  String unitType = "scout";
  float attackRange = 95;
  float attackDamage = 8;
  float attackCooldown = 0.6;
  float attackTimer = 0;
  UnitOrderType orderType = UnitOrderType.NONE;
  UnitState state = UnitState.IDLE;
  Unit attackTarget;
  PVector moveTarget;
  float repathTimer = 0;
  float acquireTimer = 0;
  float sightRange = 220;
  float aiThinkTimer = 0;
  float aiInvestigateTimer = 0;
  PVector aiLastKnownEnemyPos;
  ArrayList<PVector> aiPatrolPoints;
  int aiPatrolIndex;
  PVector lastProgressPos = new PVector();
  float stuckTimer = 0;

  Unit(float x, float y, Faction faction, UnitDef def) {
    super(x, y, def.radius, faction);
    speed = def.speed;
    hp = def.hp;
    unitType = def.id;
    lastProgressPos.set(pos);
  }

  void issueMove(PVector target, GameState state, boolean queue) {
    if (!queue) {
      pathQueue.clear();
      attackTarget = null;
    }
    moveTarget = target.copy();
    stuckTimer = 0;
    lastProgressPos.set(pos);
    orderType = UnitOrderType.MOVE;
    state.pathfinderRepath(this, target, queue);
    state.orderLabel = "Move";
  }

  void issueAttackMove(PVector target, GameState state, boolean queue) {
    if (!queue) {
      pathQueue.clear();
      attackTarget = null;
    }
    moveTarget = target.copy();
    stuckTimer = 0;
    lastProgressPos.set(pos);
    orderType = UnitOrderType.ATTACK_MOVE;
    state.pathfinderRepath(this, target, queue);
    state.orderLabel = "AttackMove";
  }

  void issueAttack(Unit target) {
    attackTarget = target;
    orderType = UnitOrderType.ATTACK;
    state = UnitState.CHASING;
  }

  void update(float dt, GameState gs) {
    attackTimer = max(0, attackTimer - dt);
    repathTimer = max(0, repathTimer - dt);
    acquireTimer = max(0, acquireTimer - dt);
    aiThinkTimer = max(0, aiThinkTimer - dt);
    aiInvestigateTimer = max(0, aiInvestigateTimer - dt);

    if (faction == Faction.NEUTRAL) {
      updateNeutralAi(gs);
    }

    if (orderType == UnitOrderType.ATTACK && attackTarget != null && attackTarget.hp > 0) {
      float d = PVector.dist(pos, attackTarget.pos);
      if (d <= attackRange) {
        state = UnitState.ATTACKING;
        pathQueue.clear();
        if (attackTimer <= 0) {
          attackTarget.hp -= int(attackDamage);
          attackTimer = attackCooldown;
        }
      } else {
        state = UnitState.CHASING;
        if (repathTimer <= 0) {
          gs.pathfinderRepath(this, attackTarget.pos.copy(), false);
          repathTimer = 0.35;
        }
        followPath(dt, gs);
      }
      if (attackTarget.hp <= 0) {
        Unit next = null;
        if (faction == Faction.NEUTRAL) {
          next = gs.findHostileInRange(this, max(attackRange * 1.8, sightRange));
        } else {
          next = gs.findPriorityEnemy(this, attackRange * 1.8);
        }
        if (next != null) {
          issueAttack(next);
        } else {
          orderType = UnitOrderType.NONE;
          state = UnitState.IDLE;
          attackTarget = null;
        }
      }
      return;
    }

    if (orderType == UnitOrderType.MOVE) {
      if (pathQueue.size() == 0) {
        state = UnitState.IDLE;
        orderType = UnitOrderType.NONE;
      } else {
        state = UnitState.MOVING;
        followPath(dt, gs);
      }
      return;
    }

    if (orderType == UnitOrderType.ATTACK_MOVE) {
      if (attackTarget == null && acquireTimer <= 0) {
        attackTarget = gs.findPriorityEnemy(this, attackRange * 1.4);
        acquireTimer = 0.15;
      }
      if (attackTarget != null && attackTarget.hp > 0) {
        float d = PVector.dist(pos, attackTarget.pos);
        if (d <= attackRange) {
          state = UnitState.ATTACKING;
          pathQueue.clear();
          if (attackTimer <= 0) {
            attackTarget.hp -= int(attackDamage);
            attackTimer = attackCooldown;
          }
        } else {
          state = UnitState.CHASING;
          if (repathTimer <= 0) {
            gs.pathfinderRepath(this, attackTarget.pos.copy(), false);
            repathTimer = 0.25;
          }
          followPath(dt, gs);
        }
        if (attackTarget.hp <= 0) {
          attackTarget = null;
          if (moveTarget != null) {
            gs.pathfinderRepath(this, moveTarget.copy(), false);
          }
        }
        return;
      }
      if (pathQueue.size() == 0) {
        state = UnitState.IDLE;
        orderType = UnitOrderType.NONE;
      } else {
        state = UnitState.MOVING;
        followPath(dt, gs);
      }
      return;
    }
    state = UnitState.IDLE;
  }

  void updateNeutralAi(GameState gs) {
    if (aiThinkTimer > 0 || gs == null) {
      return;
    }
    aiThinkTimer = random(0.12, 0.22);

    Unit visible = gs.findHostileInRange(this, sightRange);
    if (visible != null) {
      aiLastKnownEnemyPos = visible.pos.copy();
      aiInvestigateTimer = 2.4;
      if (attackTarget != visible) {
        issueAttack(visible);
      }
      return;
    }

    if (aiLastKnownEnemyPos != null && aiInvestigateTimer > 0) {
      if (PVector.dist(pos, aiLastKnownEnemyPos) < radius + 10) {
        aiInvestigateTimer = 0;
        aiLastKnownEnemyPos = null;
      } else {
        boolean needMove = (moveTarget == null) || PVector.dist(moveTarget, aiLastKnownEnemyPos) > 10;
        if (needMove || pathQueue.size() == 0) {
          issueMove(aiLastKnownEnemyPos.copy(), gs, false);
        }
      }
      return;
    }

    if (aiLastKnownEnemyPos != null && aiInvestigateTimer <= 0) {
      aiLastKnownEnemyPos = null;
    }

    if (aiPatrolPoints != null && aiPatrolPoints.size() > 0) {
      if (orderType == UnitOrderType.ATTACK || orderType == UnitOrderType.ATTACK_MOVE) {
        return;
      }
      PVector wp = aiPatrolPoints.get(aiPatrolIndex);
      if (PVector.dist(pos, wp) < radius + 22) {
        aiPatrolIndex = (aiPatrolIndex + 1) % aiPatrolPoints.size();
        wp = aiPatrolPoints.get(aiPatrolIndex);
      }
      if (pathQueue.size() == 0 && orderType == UnitOrderType.NONE) {
        issueMove(wp.copy(), gs, false);
      }
    }
  }

  String aiDebugStateLabel() {
    if (faction != Faction.NEUTRAL) {
      return "";
    }
    if (orderType == UnitOrderType.ATTACK && attackTarget != null && attackTarget.hp > 0) {
      return "ENGAGE";
    }
    if (aiLastKnownEnemyPos != null && aiInvestigateTimer > 0) {
      return "INVEST";
    }
    if (aiPatrolPoints != null && aiPatrolPoints.size() > 0) {
      if (orderType == UnitOrderType.MOVE && pathQueue.size() > 0) {
        return "PATROL";
      }
      return "IDLE";
    }
    return "IDLE";
  }

  void followPath(float dt, GameState gs) {
    if (pathQueue.size() == 0) {
      return;
    }
    while (pathQueue.size() > 1 && PVector.dist(pos, pathQueue.get(0)) < radius * 0.75 + 4) {
      pathQueue.remove(0);
    }
    PVector target = pathQueue.get(0);
    PVector delta = PVector.sub(target, pos);
    float dist = delta.mag();
    if (dist < max(2, radius * 0.35)) {
      pos.set(target);
      pathQueue.remove(0);
      return;
    }
    float terrainFactor = 1.0;
    if (gs != null) {
      terrainFactor = gs.movementSpeedFactorAt(pos);
    }
    delta.normalize().mult(speed * terrainFactor * dt);
    if (delta.mag() > dist) {
      pos.set(target);
      pathQueue.remove(0);
    } else {
      pos.add(delta);
    }
    if (gs != null) {
      applyStaticAvoidance(gs, dt);
      gs.resolveUnitAgainstSolids(this);
    }

    float remain = PVector.dist(pos, target);
    float arriveEps = max(6, radius * 0.9);
    if (remain <= arriveEps) {
      pathQueue.remove(0);
      stuckTimer = 0;
      lastProgressPos.set(pos);
      return;
    }

    float movedSinceProgress = PVector.dist(pos, lastProgressPos);
    if (movedSinceProgress > 2.0) {
      stuckTimer = 0;
      lastProgressPos.set(pos);
    } else {
      stuckTimer += dt;
      // Prevent infinite "trying to reach impossible waypoint".
      if (stuckTimer > 0.38) {
        if (pathQueue.size() > 0) {
          pathQueue.remove(0);
        }
        stuckTimer = 0;
        lastProgressPos.set(pos);
      }
    }
  }

  void applyStaticAvoidance(GameState gs, float dt) {
    TileMap m = gs.map;
    float probe = radius + 5;
    float pushAmt = 95 * dt;
    PVector acc = new PVector();
    float[] ox = {probe, -probe, 0, 0};
    float[] oy = {0, 0, probe, -probe};
    for (int k = 0; k < 4; k++) {
      int tx = m.toTileX(pos.x + ox[k]);
      int ty = m.toTileY(pos.y + oy[k]);
      if (!gs.pathfinder.isWalkable(tx, ty, gs.buildings)) {
        acc.add(-ox[k] / probe * pushAmt, -oy[k] / probe * pushAmt);
      }
    }
    if (acc.magSq() > 1e-6) {
      pos.add(acc);
      gs.clampUnitToWorld(this);
    }
  }

  void render(Camera camera) {
    PVector s = camera.worldToScreen(pos.x, pos.y);
    float rr = radius * camera.zoom;
    noStroke();
    fill(factionColor(faction));
    ellipse(s.x, s.y, rr * 2, rr * 2);
    if (selected) {
      noFill();
      stroke(20, 240, 90);
      strokeWeight(2);
      ellipse(s.x, s.y, (rr + 5) * 2, (rr + 5) * 2);
    }

    if (hp > 0 && hp < 100) {
      noStroke();
      fill(20, 20, 20);
      rect(s.x - 14, s.y - radius - 10, 28, 4);
      fill(80, 220, 100);
      rect(s.x - 14, s.y - radius - 10, 28 * constrain(hp / 100.0, 0, 1), 4);
    }
  }
}

class Building extends Entity {
  int tileW;
  int tileH;
  boolean completed = false;
  float buildProgress = 0;
  float buildTime = 3;
  String buildingType = "outpost";

  Building(float x, float y, int tileW, int tileH, Faction faction, BuildingDef def) {
    super(x, y, 8, faction);
    this.tileW = tileW;
    this.tileH = tileH;
    this.buildTime = max(0.1, def.buildTime);
    this.buildingType = def.id;
  }

  void render(Camera camera, int tileSize) {
    PVector s = camera.worldToScreen(pos.x, pos.y);
    float sw = tileW * tileSize * camera.zoom;
    float sh = tileH * tileSize * camera.zoom;
    noStroke();
    int base = factionColor(faction);
    if (!completed) {
      fill(red(base), green(base), blue(base), 120);
    } else {
      fill(base, 220);
    }
    rect(s.x, s.y, sw, sh);
    stroke(40);
    noFill();
    rect(s.x, s.y, sw, sh);

    if (!completed) {
      float pct = constrain(buildProgress / buildTime, 0, 1);
      noStroke();
      fill(20, 20, 20, 220);
      rect(s.x, s.y - 8, sw, 5);
      fill(80, 230, 110);
      rect(s.x, s.y - 8, sw * pct, 5);
    }
  }
}

int factionColor(Faction faction) {
  switch (faction) {
  case PLAYER:
    return color(90, 170, 255);
  case ENEMY:
    return color(255, 100, 100);
  default:
    return color(245, 165, 70);
  }
}
