UnitCombatLogic UNIT_COMBAT_LOGIC = new UnitCombatLogic();
UnitRenderer UNIT_RENDERER = new UnitRenderer();

class UnitCombatLogic {
  void updateCombatAi(Unit u, GameState gs) {
    if (u.aiThinkTimer > 0 || gs == null) {
      return;
    }
    u.aiThinkTimer = random(0.12, 0.22);

    Unit visible = gs.findHostileInRange(u, u.sightRange, gs);
    if (visible != null) {
      u.aiLastKnownEnemyPos = visible.pos.copy();
      u.aiInvestigateTimer = 2.4;
      if (u.attackTarget != visible) {
        u.issueAttack(visible);
      }
      return;
    }

    if (u.faction == Faction.ENEMY && u.canAttack) {
      float bRange = max(u.attackRange * 1.15, u.sightRange);
      Building hostileB = gs.findNearestHostileBuilding(u, bRange);
      if (hostileB != null) {
        if (u.attackBuildingTarget != hostileB) {
          u.issueAttackBuilding(hostileB);
        }
        return;
      }
    }

    if (u.aiLastKnownEnemyPos != null && u.aiInvestigateTimer > 0) {
      if (PVector.dist(u.pos, u.aiLastKnownEnemyPos) < u.radius + 10) {
        u.aiInvestigateTimer = 0;
        u.aiLastKnownEnemyPos = null;
      } else {
        boolean needMove = (u.moveTarget == null) || PVector.dist(u.moveTarget, u.aiLastKnownEnemyPos) > 10;
        if (needMove || u.pathQueue.size() == 0) {
          u.issueMove(u.aiLastKnownEnemyPos.copy(), gs, false);
        }
      }
      return;
    }

    if (u.aiLastKnownEnemyPos != null && u.aiInvestigateTimer <= 0) {
      u.aiLastKnownEnemyPos = null;
    }

    if (u.aiPatrolPoints != null && u.aiPatrolPoints.size() > 0) {
      if (u.orderType == UnitOrderType.ATTACK || u.orderType == UnitOrderType.ATTACK_MOVE) {
        return;
      }
      PVector wp = u.aiPatrolPoints.get(u.aiPatrolIndex);
      if (PVector.dist(u.pos, wp) < u.radius + 22) {
        u.aiPatrolIndex = (u.aiPatrolIndex + 1) % u.aiPatrolPoints.size();
        wp = u.aiPatrolPoints.get(u.aiPatrolIndex);
      }
      if (u.pathQueue.size() == 0 && u.orderType == UnitOrderType.NONE) {
        u.issueMove(wp.copy(), gs, false);
      }
    }
  }

  void updatePlayerDefensiveCombatAi(Unit u, GameState gs) {
    if (gs == null || !u.canAttack || u.canHarvest || !u.autoDefend) {
      return;
    }
    if (gs.attackMoveArmed) {
      return;
    }
    if (u.orderType != UnitOrderType.NONE || u.state != UnitState.IDLE) {
      return;
    }
    if (u.aiThinkTimer > 0) {
      return;
    }
    u.aiThinkTimer = random(0.12, 0.22);
    Unit visible = gs.findHostileInRange(u, u.sightRange, gs);
    if (visible != null) {
      u.issueAttack(visible);
    }
  }
}

class UnitRenderer {
  void render(Unit u, Camera camera) {
    PVector s = camera.worldToScreen(u.pos.x, u.pos.y);
    float rr = u.radius * camera.zoom;
    float margin = max(24, rr + 24);
    if (s.x < -margin || s.y < -margin || s.x > camera.viewportW + margin || s.y > camera.viewportH + margin) {
      return;
    }
    pushStyle();
    noStroke();
    fill(factionColor(u.faction));
    ellipse(s.x, s.y, rr * 2, rr * 2);
    if (u.selected) {
      noFill();
      stroke(20, 240, 90);
      strokeWeight(2);
      ellipse(s.x, s.y, (rr + 5) * 2, (rr + 5) * 2);
    }

    if (u.hp > 0 && u.hp < 100) {
      noStroke();
      fill(20, 20, 20);
      rect(s.x - 14, s.y - u.radius - 10, 28, 4);
      fill(80, 220, 100);
      rect(s.x - 14, s.y - u.radius - 10, 28 * constrain(u.hp / 100.0, 0, 1), 4);
    }

    if (u.canHarvest && u.harvestTimer > 0) {
      float k = constrain(u.harvestTimer / max(0.01, u.harvestTime), 0, 1);
      noFill();
      stroke(255, 220, 90, 180);
      strokeWeight(1.5);
      float pr = (u.radius + 6 + (1 - k) * 8) * camera.zoom;
      ellipse(s.x, s.y, pr * 2, pr * 2);
      noStroke();
      fill(255, 230, 130, 180);
      ellipse(s.x + pr * 0.2, s.y - pr * 0.2, 3 * camera.zoom, 3 * camera.zoom);
    }

    String unitLabel = unitTypeLabel(u.unitType);
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

  String unitTypeLabel(String unitType) {
    if ("miner".equals(unitType)) return "MINER";
    if ("rifleman".equals(unitType)) return "RIFLE";
    if ("rocketeer".equals(unitType)) return "ROCKET";
    return "UNIT";
  }
}
