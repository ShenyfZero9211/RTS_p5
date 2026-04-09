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
  boolean canAttack = true;
  float sightRange = 220;
  boolean usesProjectile = false;
  float projectileSpeed = 260;
  boolean canHarvest = false;
  int harvestAmount = 20;
  float harvestTime = 1.2;
  int cargoGold = 0;
  float harvestTimer = 0;
  float autoHarvestDelay = 0;
  int harvestMode = 0; // 0 idle, 1 to-mine, 2 mining, 3 to-dropoff
  GoldMine assignedMine;
  Building assignedDropoff;
  boolean manualHarvestOrder = false;
  float attackTimer = 0;
  UnitOrderType orderType = UnitOrderType.NONE;
  UnitState state = UnitState.IDLE;
  Unit attackTarget;
  Building attackBuildingTarget;
  PVector moveTarget;
  float repathTimer = 0;
  float acquireTimer = 0;
  float aiThinkTimer = 0;
  float aiInvestigateTimer = 0;
  PVector aiLastKnownEnemyPos;
  ArrayList<PVector> aiPatrolPoints;
  int aiPatrolIndex;
  PVector lastProgressPos = new PVector();
  float stuckTimer = 0;
  float dropoffRechooseTimer = 0;
  boolean autoDefend = true;

  Unit(float x, float y, Faction faction, UnitDef def) {
    super(x, y, def.radius, faction);
    speed = def.speed;
    hp = def.hp;
    unitType = def.id;
    attackRange = def.attackRange;
    attackDamage = def.attackDamage;
    attackCooldown = def.attackCooldown;
    canAttack = def.canAttack;
    sightRange = def.sightRange;
    usesProjectile = def.usesProjectile;
    projectileSpeed = def.projectileSpeed;
    canHarvest = def.canHarvest;
    harvestAmount = def.harvestAmount;
    harvestTime = def.harvestTime;
    if (canHarvest) {
      // Prevent miners from all rushing at frame 0.
      autoHarvestDelay = random(1.0, 2.6);
    }
    autoDefend = def.autoDefend;
    lastProgressPos.set(pos);
  }

  void issueMove(PVector target, GameState state, boolean queue) {
    if (!queue) {
      pathQueue.clear();
      attackTarget = null;
      attackBuildingTarget = null;
    }
    moveTarget = target.copy();
    stuckTimer = 0;
    lastProgressPos.set(pos);
    orderType = UnitOrderType.MOVE;
    state.pathfinderRepath(this, target, queue);
    if (faction == Faction.PLAYER) {
      state.orderLabel = tr("order.move");
    }
  }

  void issueAttackMove(PVector target, GameState state, boolean queue) {
    if (!queue) {
      pathQueue.clear();
      attackTarget = null;
      attackBuildingTarget = null;
    }
    moveTarget = target.copy();
    cancelHarvestOrder();
    stuckTimer = 0;
    lastProgressPos.set(pos);
    orderType = UnitOrderType.ATTACK_MOVE;
    state.pathfinderRepath(this, target, queue);
    if (faction == Faction.PLAYER) {
      state.orderLabel = tr("order.attackMove");
    }
  }

  void issueAttack(Unit target) {
    if (!canAttack) {
      return;
    }
    attackTarget = target;
    attackBuildingTarget = null;
    cancelHarvestOrder();
    orderType = UnitOrderType.ATTACK;
    state = UnitState.CHASING;
  }

  void issueAttackBuilding(Building target) {
    if (!canAttack) {
      return;
    }
    attackTarget = null;
    attackBuildingTarget = target;
    cancelHarvestOrder();
    orderType = UnitOrderType.ATTACK;
    state = UnitState.CHASING;
  }

  void issueHarvest(GoldMine mine, GameState gs) {
    if (!canHarvest || mine == null || gs == null) {
      return;
    }
    manualHarvestOrder = true;
    assignedMine = mine;
    assignedDropoff = null;
    harvestMode = 1;
    harvestTimer = 0;
    attackTarget = null;
    pathQueue.clear();
    moveTarget = null;
    orderType = UnitOrderType.NONE;
    if (faction == Faction.PLAYER) {
      gs.orderLabel = tr("order.harvest");
    }
  }

  void cancelHarvestOrder() {
    manualHarvestOrder = false;
    assignedMine = null;
    assignedDropoff = null;
    harvestMode = 0;
    harvestTimer = 0;
  }

  void update(float dt, GameState gs) {
    attackTimer = max(0, attackTimer - dt);
    repathTimer = max(0, repathTimer - dt);
    acquireTimer = max(0, acquireTimer - dt);
    aiThinkTimer = max(0, aiThinkTimer - dt);
    aiInvestigateTimer = max(0, aiInvestigateTimer - dt);
    harvestTimer = max(0, harvestTimer - dt);

    if (canHarvest && gs != null && (shouldAutoHarvest(gs) || manualHarvestOrder)) {
      // Manual harvest orders should react immediately; delay only applies to autonomous behavior.
      if (!manualHarvestOrder && autoHarvestDelay > 0) {
        autoHarvestDelay = max(0, autoHarvestDelay - dt);
      } else {
        updateHarvestBehavior(dt, gs);
        if (orderType == UnitOrderType.NONE) {
          state = UnitState.IDLE;
          return;
        }
      }
    }

    if (faction == Faction.NEUTRAL || faction == Faction.ENEMY) {
      updateCombatAi(gs);
    } else if (faction == Faction.PLAYER) {
      updatePlayerDefensiveCombatAi(gs);
    }

    if (!canAttack) {
      if (orderType == UnitOrderType.ATTACK || orderType == UnitOrderType.ATTACK_MOVE) {
        orderType = UnitOrderType.NONE;
        attackTarget = null;
        attackBuildingTarget = null;
      }
      if (orderType == UnitOrderType.NONE) {
        state = UnitState.IDLE;
        return;
      }
    }

    if (orderType == UnitOrderType.ATTACK &&
      ((attackTarget != null && attackTarget.hp > 0) || (attackBuildingTarget != null && attackBuildingTarget.hp > 0))) {
      if (attackBuildingTarget != null && attackBuildingTarget.hp <= 0) {
        attackBuildingTarget = null;
      }
      if (faction == Faction.PLAYER && gs != null && attackTarget != null && !gs.isUnitVisibleToPlayer(attackTarget)) {
        attackTarget = null;
        orderType = UnitOrderType.NONE;
        state = UnitState.IDLE;
        pathQueue.clear();
        return;
      }
      PVector targetPos = attackTarget != null ? attackTarget.pos :
        new PVector(attackBuildingTarget.pos.x + attackBuildingTarget.tileW * gs.map.tileSize * 0.5,
        attackBuildingTarget.pos.y + attackBuildingTarget.tileH * gs.map.tileSize * 0.5);
      float d = PVector.dist(pos, targetPos);
      if (d <= attackRange) {
        state = UnitState.ATTACKING;
        pathQueue.clear();
        if (attackTimer <= 0) {
          if (attackBuildingTarget != null) {
            if (usesProjectile && gs != null) {
              gs.spawnRocketProjectile(this, attackBuildingTarget, attackDamage, max(120, projectileSpeed));
            } else {
              attackBuildingTarget.hp -= int(attackDamage);
            }
            if (gs != null && unitType.equals("rifleman")) {
              gs.spawnMuzzleFx(this, targetPos.copy());
            }
          } else if (usesProjectile && gs != null) {
            gs.spawnRocketProjectile(this, attackTarget, attackDamage, max(120, projectileSpeed));
          } else {
            attackTarget.hp -= int(attackDamage);
            if (gs != null && unitType.equals("rifleman")) {
              gs.spawnMuzzleFx(this, attackTarget.pos.copy());
            }
          }
          attackTimer = attackCooldown;
        }
      } else {
        state = UnitState.CHASING;
        if (repathTimer <= 0) {
          gs.pathfinderRepath(this, targetPos.copy(), false);
          repathTimer = 0.35;
        }
        followPath(dt, gs);
      }
      if ((attackTarget == null || attackTarget.hp <= 0) && (attackBuildingTarget == null || attackBuildingTarget.hp <= 0)) {
        Unit next = null;
        if (faction == Faction.NEUTRAL) {
          next = gs.findHostileInRange(this, max(attackRange * 1.8, sightRange), gs);
        } else {
          next = gs.findPriorityEnemy(this, attackRange * 1.8);
        }
        if (next != null) {
          issueAttack(next);
        } else if (faction == Faction.ENEMY && canAttack) {
          Building hb = gs.findNearestHostileBuilding(this, max(attackRange * 1.8, sightRange));
          if (hb != null) {
            issueAttackBuilding(hb);
          } else {
            orderType = UnitOrderType.NONE;
            state = UnitState.IDLE;
            attackTarget = null;
            attackBuildingTarget = null;
          }
        } else {
          orderType = UnitOrderType.NONE;
          state = UnitState.IDLE;
          attackTarget = null;
          attackBuildingTarget = null;
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
      if (attackTarget != null && attackTarget.hp <= 0) {
        attackTarget = null;
        if (moveTarget != null) {
          gs.pathfinderRepath(this, moveTarget.copy(), false);
        }
      }
      if (attackBuildingTarget != null && attackBuildingTarget.hp <= 0) {
        attackBuildingTarget = null;
        if (moveTarget != null) {
          gs.pathfinderRepath(this, moveTarget.copy(), false);
        }
      }
      if (attackTarget == null && acquireTimer <= 0) {
        attackTarget = gs.findPriorityEnemy(this, attackRange * 1.4);
        if (attackTarget == null && canAttack) {
          attackBuildingTarget = gs.findNearestHostileBuilding(this, max(attackRange * 1.4, sightRange));
        }
        acquireTimer = 0.15;
      }
      if (attackTarget != null && faction == Faction.PLAYER && gs != null && !gs.isUnitVisibleToPlayer(attackTarget)) {
        attackTarget = null;
      }
      if (attackTarget != null && attackTarget.hp > 0) {
        float d = PVector.dist(pos, attackTarget.pos);
        if (d <= attackRange) {
          state = UnitState.ATTACKING;
          pathQueue.clear();
          if (attackTimer <= 0) {
            if (usesProjectile && gs != null) {
              gs.spawnRocketProjectile(this, attackTarget, attackDamage, max(120, projectileSpeed));
            } else {
              attackTarget.hp -= int(attackDamage);
              if (gs != null && unitType.equals("rifleman")) {
                gs.spawnMuzzleFx(this, attackTarget.pos.copy());
              }
            }
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
      if (attackBuildingTarget != null && attackBuildingTarget.hp > 0) {
        PVector bt = new PVector(
          attackBuildingTarget.pos.x + attackBuildingTarget.tileW * gs.map.tileSize * 0.5,
          attackBuildingTarget.pos.y + attackBuildingTarget.tileH * gs.map.tileSize * 0.5
          );
        float d = PVector.dist(pos, bt);
        if (d <= attackRange) {
          state = UnitState.ATTACKING;
          pathQueue.clear();
          if (attackTimer <= 0) {
            if (usesProjectile && gs != null) {
              gs.spawnRocketProjectile(this, attackBuildingTarget, attackDamage, max(120, projectileSpeed));
            } else {
              attackBuildingTarget.hp -= int(attackDamage);
            }
            if (gs != null && unitType.equals("rifleman")) {
              gs.spawnMuzzleFx(this, bt.copy());
            }
            attackTimer = attackCooldown;
          }
        } else {
          state = UnitState.CHASING;
          if (repathTimer <= 0) {
            gs.pathfinderRepath(this, bt.copy(), false);
            repathTimer = 0.25;
          }
          followPath(dt, gs);
        }
        if (attackBuildingTarget.hp <= 0) {
          attackBuildingTarget = null;
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

  void updateHarvestBehavior(float dt, GameState gs) {
    if (cargoGold > 0) {
      harvestMode = 3;
    } else if (harvestMode == 3) {
      harvestMode = 1;
    }

    if (assignedMine != null && assignedMine.amount <= 0) {
      assignedMine = null;
      if (manualHarvestOrder) {
        manualHarvestOrder = false;
      }
    }

    BuildingDef dropDef = assignedDropoff == null ? null : gs.getBuildingDef(assignedDropoff.buildingType);
    if (assignedDropoff == null || assignedDropoff.faction != faction || !assignedDropoff.completed
      || dropDef == null || !dropDef.isDropoff) {
      assignedDropoff = gs.findNearestDropoffBuilding(pos, faction);
    }
    if (assignedDropoff == null) {
      return;
    }

    if (harvestMode == 0) {
      if (manualHarvestOrder || shouldAutoHarvest(gs)) {
        if (assignedMine == null) {
          assignedMine = gs.findNearestAvailableMine(pos, faction);
        }
        if (assignedMine != null) {
          harvestMode = 1;
        }
      }
      return;
    }

    if (harvestMode == 1) {
      if (assignedMine == null) {
        assignedMine = gs.findNearestAvailableMine(pos, faction);
        if (assignedMine == null) {
          harvestMode = 0;
          return;
        }
      }
      PVector minePos = assignedMine.worldCenter(gs.map);
      float mineRange = max(radius + 6, gs.map.tileSize * 0.55);
      float dMine = PVector.dist(pos, minePos);
      if (dMine <= mineRange) {
        harvestMode = 2;
        harvestTimer = max(0.2, harvestTime);
        orderType = UnitOrderType.NONE;
        pathQueue.clear();
        moveTarget = null;
        state = UnitState.IDLE;
      } else if (orderType == UnitOrderType.NONE || moveTarget == null || PVector.dist(moveTarget, minePos) > 12) {
        issueMove(minePos, gs, false);
      }
      return;
    }

    if (harvestMode == 2) {
      if (assignedMine == null || assignedMine.amount <= 0) {
        harvestMode = 0;
        manualHarvestOrder = false;
        return;
      }
      PVector minePos = assignedMine.worldCenter(gs.map);
      float mineRange = max(radius + 6, gs.map.tileSize * 0.58);
      float dMine = PVector.dist(pos, minePos);
      if (dMine > mineRange) {
        harvestMode = 1;
        return;
      }
      orderType = UnitOrderType.NONE;
      pathQueue.clear();
      moveTarget = null;
      state = UnitState.IDLE;
      if (harvestTimer <= 0) {
        int mined = min(harvestAmount, assignedMine.amount);
        if (mined > 0) {
          assignedMine.amount -= mined;
          cargoGold += mined;
          assignedDropoff = gs.findNearestDropoffBuilding(pos, faction);
          dropoffRechooseTimer = 1.0;
          harvestMode = 3;
        } else {
          harvestMode = 0;
        }
      }
      return;
    }

    if (harvestMode == 3) {
      dropoffRechooseTimer -= dt;
      if (dropoffRechooseTimer <= 0) {
        dropoffRechooseTimer = 1.4;
        Building nearer = gs.findNearestDropoffBuilding(pos, faction);
        if (nearer != null && assignedDropoff != null && nearer != assignedDropoff) {
          float cxo = assignedDropoff.pos.x + assignedDropoff.tileW * gs.map.tileSize * 0.5;
          float cyo = assignedDropoff.pos.y + assignedDropoff.tileH * gs.map.tileSize * 0.5;
          float cxn = nearer.pos.x + nearer.tileW * gs.map.tileSize * 0.5;
          float cyn = nearer.pos.y + nearer.tileH * gs.map.tileSize * 0.5;
          if (dist(pos.x, pos.y, cxn, cyn) + 12 < dist(pos.x, pos.y, cxo, cyo)) {
            assignedDropoff = nearer;
            orderType = UnitOrderType.NONE;
            pathQueue.clear();
            moveTarget = null;
          }
        }
      }
      Building drop = assignedDropoff;
      float left = drop.pos.x;
      float top = drop.pos.y;
      float right = drop.pos.x + drop.tileW * gs.map.tileSize;
      float bottom = drop.pos.y + drop.tileH * gs.map.tileSize;
      float deliverPad = radius + 8;
      boolean inDropoffBox =
        pos.x >= left - deliverPad && pos.x <= right + deliverPad &&
        pos.y >= top - deliverPad && pos.y <= bottom + deliverPad;
      float nearX = constrain(pos.x, left, right);
      float nearY = constrain(pos.y, top, bottom);
      float dDrop = dist(pos.x, pos.y, nearX, nearY);
      float fallbackDeliverRange = max(radius + 14, gs.map.tileSize * 0.78);

      if (inDropoffBox || dDrop <= fallbackDeliverRange) {
        ResourcePool pool = gs.resourcePoolForFaction(faction);
        if (pool != null) {
          pool.addCredits(cargoGold);
        }
        gs.spawnDeliveryFx(pos.copy(), cargoGold);
        cargoGold = 0;
        orderType = UnitOrderType.NONE;
        pathQueue.clear();
        moveTarget = null;
        state = UnitState.IDLE;
        harvestMode = (manualHarvestOrder || shouldAutoHarvest(gs)) ? 1 : 0;
        return;
      }

      PVector edge = new PVector(nearX, nearY);
      PVector away = PVector.sub(pos, edge);
      if (away.magSq() < 1e-6) {
        away.set(1, 0);
      } else {
        away.normalize();
      }
      PVector dropPos = PVector.add(edge, PVector.mult(away, radius + 2));
      if (orderType == UnitOrderType.NONE || moveTarget == null || PVector.dist(moveTarget, dropPos) > 12) {
        issueMove(dropPos, gs, false);
      }
      return;
    }
  }

  boolean shouldAutoHarvest(GameState gs) {
    // Player-controlled miners should not auto-rush unexplored mines.
    return faction != Faction.PLAYER;
  }

  void updateCombatAi(GameState gs) {
    if (aiThinkTimer > 0 || gs == null) {
      return;
    }
    aiThinkTimer = random(0.12, 0.22);

    Unit visible = gs.findHostileInRange(this, sightRange, gs);
    if (visible != null) {
      aiLastKnownEnemyPos = visible.pos.copy();
      aiInvestigateTimer = 2.4;
      if (attackTarget != visible) {
        issueAttack(visible);
      }
      return;
    }

    if (faction == Faction.ENEMY && canAttack) {
      float bRange = max(attackRange * 1.15, sightRange);
      Building hostileB = gs.findNearestHostileBuilding(this, bRange);
      if (hostileB != null) {
        if (attackBuildingTarget != hostileB) {
          issueAttackBuilding(hostileB);
        }
        return;
      }
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

  void updatePlayerDefensiveCombatAi(GameState gs) {
    if (gs == null || !canAttack || canHarvest || !autoDefend) {
      return;
    }
    if (gs.attackMoveArmed) {
      return;
    }
    if (orderType != UnitOrderType.NONE || state != UnitState.IDLE) {
      return;
    }
    if (aiThinkTimer > 0) {
      return;
    }
    aiThinkTimer = random(0.12, 0.22);
    Unit visible = gs.findHostileInRange(this, sightRange, gs);
    if (visible != null) {
      issueAttack(visible);
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
      return;
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
      if (pathQueue.size() > 0) {
        pathQueue.remove(0);
      }
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
    pushStyle();
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

    if (canHarvest && harvestTimer > 0) {
      float k = constrain(harvestTimer / max(0.01, harvestTime), 0, 1);
      noFill();
      stroke(255, 220, 90, 180);
      strokeWeight(1.5);
      float pr = (radius + 6 + (1 - k) * 8) * camera.zoom;
      ellipse(s.x, s.y, pr * 2, pr * 2);
      noStroke();
      fill(255, 230, 130, 180);
      ellipse(s.x + pr * 0.2, s.y - pr * 0.2, 3 * camera.zoom, 3 * camera.zoom);
    }

    String unitLabel = "UNIT";
    if (unitType.equals("miner")) {
      unitLabel = "MINER";
    } else if (unitType.equals("rifleman")) {
      unitLabel = "RIFLE";
    } else if (unitType.equals("rocketeer")) {
      unitLabel = "ROCKET";
    }
    float tagW = 52;
    float tagH = 12;
    noStroke();
    fill(18, 18, 18, 175);
    rect(s.x - tagW * 0.5, s.y - rr - 20, tagW, tagH);
    fill(240);
    textSize(9);
    textAlign(CENTER, TOP);
    text(unitLabel, s.x, s.y - rr - 19);
    textAlign(LEFT, TOP);
    popStyle();
  }
}

class Building extends Entity {
  int tileW;
  int tileH;
  boolean completed = false;
  float buildProgress = 0;
  float buildTime = 3;
  String buildingType = "outpost";
  int hp;
  int maxHp;
  boolean selected = false;
  float towerCooldown = 0;
  float turretAimAngle = -HALF_PI;
  PVector rallyPoint;

  Building(float x, float y, int tileW, int tileH, Faction faction, BuildingDef def) {
    super(x, y, 8, faction);
    this.tileW = tileW;
    this.tileH = tileH;
    this.buildTime = max(0.1, def.buildTime);
    this.buildingType = def.id;
    this.maxHp = max(180, def.cost * 4);
    this.hp = maxHp;
  }

  void render(Camera camera, int tileSize) {
    pushStyle();
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
    strokeWeight(1);
    noFill();
    rect(s.x, s.y, sw, sh);
    if (selected) {
      stroke(20, 240, 90);
      strokeWeight(2);
      noFill();
      rect(s.x - 2, s.y - 2, sw + 4, sh + 4);
    }

    if (!completed) {
      float pct = constrain(buildProgress / buildTime, 0, 1);
      noStroke();
      fill(20, 20, 20, 220);
      rect(s.x, s.y - 8, sw, 5);
      fill(80, 230, 110);
      rect(s.x, s.y - 8, sw * pct, 5);
    }
    if (completed && hp < maxHp) {
      noStroke();
      fill(20, 20, 20, 220);
      rect(s.x, s.y - 8, sw, 5);
      fill(95, 220, 110);
      rect(s.x, s.y - 8, sw * constrain(hp / float(max(1, maxHp)), 0, 1), 5);
    }

    // Building type marker for quick battlefield identification.
    String label = buildingType == null ? "BUILDING" : buildingType.toUpperCase();
    fill(18, 18, 18, 180);
    rect(s.x, s.y - 24, min(sw, 90), 14);
    fill(245);
    textSize(10);
    textAlign(LEFT, TOP);
    text(label, s.x + 3, s.y - 22);

    if (buildingType != null && buildingType.equals("tower") && completed) {
      float cx = s.x + sw * 0.5;
      float cy = s.y + sh * 0.52;
      float bodyR = max(4, min(sw, sh) * 0.22);
      noStroke();
      fill(48, 52, 60, 220);
      ellipse(cx, cy, bodyR * 2.3, bodyR * 2.3);
      fill(90, 96, 110, 220);
      ellipse(cx, cy, bodyR * 1.3, bodyR * 1.3);
      float ang = turretAimAngle;
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
