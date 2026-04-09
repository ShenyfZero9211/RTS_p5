class ProductionSystem {
  void updateTrainQueue(GameState gs, float dt) {
    if (gs.gameEnded) return;
    for (int i = gs.trainQueue.size() - 1; i >= 0; i--) {
      TrainJob j = gs.trainQueue.get(i);
      if (j.trainer == null || j.trainer.hp <= 0 || !j.trainer.completed || !buildingHostsTrainQueue(gs, j.trainer)) {
        gs.trainQueue.remove(i);
      }
    }
    for (int i = 0; i < gs.trainQueue.size(); i++) {
      TrainJob j = gs.trainQueue.get(i);
      if (!isFirstTrainJobForTrainer(gs, j.trainer, i)) continue;
      j.timeRemaining -= dt;
      if (j.timeRemaining <= 0) {
        UnitDef def = gs.getUnitDef(j.unitId);
        if (def != null && j.trainer != null && buildingHostsTrainQueue(gs, j.trainer)) {
          PVector spawn = findSpawnForTrainer(gs, j.trainer, def.radius);
          Unit nu = new Unit(spawn.x, spawn.y, j.faction, def);
          gs.units.add(nu);
          if (j.trainer.rallyPoint != null && j.trainer.completed) {
            nu.issueMove(j.trainer.rallyPoint.copy(), gs, false);
          }
        }
        gs.trainQueue.remove(i);
        i--;
      }
    }
  }

  TrainJob activeTrainJobFor(GameState gs, Building trainer) {
    for (TrainJob j : gs.trainQueue) {
      if (j.trainer == trainer) return j;
    }
    return null;
  }

  void removeTrainingJobsForTrainer(GameState gs, Building trainer) {
    for (int i = gs.trainQueue.size() - 1; i >= 0; i--) {
      if (gs.trainQueue.get(i).trainer == trainer) gs.trainQueue.remove(i);
    }
  }

  boolean isFirstTrainJobForTrainer(GameState gs, Building trainer, int queueIndex) {
    for (int k = 0; k < queueIndex; k++) {
      if (gs.trainQueue.get(k).trainer == trainer) return false;
    }
    return true;
  }

  boolean buildingHostsTrainQueue(GameState gs, Building b) {
    if (b == null) return false;
    for (int i = 0; i < gs.buildings.size(); i++) {
      if (gs.buildings.get(i) == b) return true;
    }
    return false;
  }

  boolean tryTrainUnitForFaction(GameState gs, Faction faction, String unitId) {
    UnitDef def = gs.getUnitDef(unitId);
    if (def == null) return false;
    ResourcePool pool = gs.resourcePoolForFaction(faction);
    if (pool == null || !pool.canAfford(def.cost)) return false;
    int needSupply = max(0, def.supplyCost);
    if (gs.usedSupplyForFaction(faction) + needSupply > gs.supplyCapForFaction(faction)) return false;
    Building trainer = gs.pickTrainerForUnit(faction, unitId);
    if (trainer == null) return false;
    if (!pool.spend(def.cost)) return false;
    gs.trainQueue.add(new TrainJob(trainer, unitId, def.trainTime, faction));
    return true;
  }

  boolean trainUnitAtSelectedBuilding(GameState gs, String unitId) {
    if (gs.gameEnded) return false;
    if (gs.selectedUnits.size() > 0) return false;
    if (gs.selectedBuilding == null || gs.selectedBuilding.faction != gs.activeFaction || !gs.selectedBuilding.completed) {
      gs.orderLabel = tr("order.selectProducer");
      return false;
    }
    BuildingDef bdef = gs.getBuildingDef(gs.selectedBuilding.buildingType);
    if (bdef == null || !bdef.canTrainUnits || bdef.trainableUnits == null) {
      gs.orderLabel = tr("order.noTrainHere");
      return false;
    }
    boolean allowed = false;
    for (int i = 0; i < bdef.trainableUnits.length; i++) {
      if (bdef.trainableUnits[i].equals(unitId)) {
        allowed = true;
        break;
      }
    }
    if (!allowed) {
      gs.orderLabel = tr("order.unitNotInRoster");
      return false;
    }
    UnitDef def = gs.getUnitDef(unitId);
    if (def == null) return false;
    if (!gs.resources.canAfford(def.cost)) {
      gs.orderLabel = tr("order.needCredits");
      return false;
    }
    int needSupply = max(0, def.supplyCost);
    if (gs.usedSupplyForFaction(gs.activeFaction) + needSupply > gs.supplyCapForFaction(gs.activeFaction)) {
      gs.orderLabel = tr("order.needSupply");
      return false;
    }
    if (!gs.resources.spend(def.cost)) return false;
    gs.trainQueue.add(new TrainJob(gs.selectedBuilding, unitId, def.trainTime, gs.activeFaction));
    gs.orderLabel = tr("order.train") + ":" + unitId;
    return true;
  }

  PVector findSpawnForTrainer(GameState gs, Building trainer, float unitRadius) {
    if (trainer == null) return new PVector(0, 0);
    BuildingDef bdef = gs.getBuildingDef(trainer.buildingType);
    if (bdef != null && bdef.spawnPoints != null && bdef.spawnPoints.length > 0) {
      PVector configured = findConfiguredSpawnNearBuilding(gs, trainer, bdef, unitRadius);
      if (configured != null) return configured;
    }
    return gs.findSpawnNearBuildingAvoidingUnits(trainer, unitRadius, new ArrayList<String>());
  }

  PVector findConfiguredSpawnNearBuilding(GameState gs, Building b, BuildingDef bdef, float unitRadius) {
    float ts = gs.map.tileSize;
    float pad = max(0, bdef.spawnClearancePad);
    for (int i = 0; i < bdef.spawnPoints.length; i++) {
      SpawnPointDef sp = bdef.spawnPoints[i];
      PVector seed;
      if ("localWorld".equals(sp.mode)) {
        seed = new PVector(b.pos.x + sp.x * ts, b.pos.y + sp.y * ts);
      } else {
        seed = new PVector(b.pos.x + (sp.x + 0.5) * ts, b.pos.y + (sp.y + 0.5) * ts);
      }
      int tx = gs.map.toTileX(seed.x);
      int ty = gs.map.toTileY(seed.y);
      PVector walkable = gs.pathfinder.findClosestWalkable(tx, ty, gs.buildings);
      int wx = int(walkable.x);
      int wy = int(walkable.y);
      if (!gs.pathfinder.isWalkable(wx, wy, gs.buildings)) continue;
      float worldX = (wx + 0.5) * ts;
      float worldY = (wy + 0.5) * ts;
      if (gs.isWorldSpawnFreeOfUnits(worldX, worldY, unitRadius, pad)) {
        return new PVector(worldX, worldY);
      }
    }
    if (bdef.useLegacySpawnFallback) {
      return gs.findSpawnNearBuildingAvoidingUnits(b, unitRadius, new ArrayList<String>());
    }
    return null;
  }

  int queuedTrainCountForUnit(GameState gs, Building trainer, String unitId) {
    if (trainer == null || unitId == null) return 0;
    int c = 0;
    for (TrainJob j : gs.trainQueue) {
      if (j.trainer == trainer && unitId.equals(j.unitId)) c++;
    }
    return c;
  }

  float activeTrainProgressForUnit(GameState gs, Building trainer, String unitId) {
    if (trainer == null || unitId == null) return -1;
    for (int i = 0; i < gs.trainQueue.size(); i++) {
      TrainJob j = gs.trainQueue.get(i);
      if (j.trainer == trainer && unitId.equals(j.unitId) && isFirstTrainJobForTrainer(gs, trainer, i)) {
        return j.progress01();
      }
    }
    return -1;
  }

  boolean cancelOneTrainJobForSelectedBuilding(GameState gs, String unitId) {
    if (gs.selectedBuilding == null || unitId == null || unitId.length() == 0) return false;
    UnitDef def = gs.getUnitDef(unitId);
    if (def == null) return false;
    for (int i = gs.trainQueue.size() - 1; i >= 0; i--) {
      TrainJob j = gs.trainQueue.get(i);
      if (j.trainer == gs.selectedBuilding && unitId.equals(j.unitId)) {
        gs.trainQueue.remove(i);
        ResourcePool pool = gs.resourcePoolForFaction(gs.activeFaction);
        if (pool != null) pool.addCredits(def.cost);
        gs.orderLabel = tr("order.trainCancel") + ":" + unitId;
        return true;
      }
    }
    return false;
  }
}

class TrainJob {
  Building trainer;
  String unitId;
  float timeRemaining;
  float totalTime;
  Faction faction;

  TrainJob(Building trainer, String unitId, float trainTime, Faction faction) {
    this.trainer = trainer;
    this.unitId = unitId;
    this.totalTime = max(0.05, trainTime);
    this.timeRemaining = this.totalTime;
    this.faction = faction;
  }

  float progress01() {
    if (totalTime <= 1e-6) return 1;
    return constrain(1.0 - timeRemaining / totalTime, 0, 1);
  }
}
