class UiSettingsLoader {
  void apply(GameState gs) {
    JSONObject root = loadJSONObject("ui.json");
    if (root == null) return;
    gs.sidePanelWidthRatio = root.getFloat("sidePanelWidthRatio", gs.sidePanelWidthRatio);
    gs.sidePanelMinW = root.getInt("sidePanelMinW", gs.sidePanelMinW);
    gs.sidePanelMaxW = root.getInt("sidePanelMaxW", gs.sidePanelMaxW);
    gs.wheelZoomStep = root.getFloat("wheelZoomStep", gs.wheelZoomStep);
    gs.edgeScrollSpeed = root.getFloat("edgeScrollSpeed", gs.edgeScrollSpeed);
    gs.fogEnabled = root.getBoolean("fogEnabled", gs.fogEnabled);
    gs.fogSoftEdges = root.getBoolean("fogSoftEdges", gs.fogSoftEdges);
    gs.fogEdgeRadius = root.getInt("fogEdgeRadius", gs.fogEdgeRadius);
    gs.fogEdgeStrength = root.getFloat("fogEdgeStrength", gs.fogEdgeStrength);
    gs.fogUpdateInterval = root.getFloat("fogUpdateInterval", gs.fogUpdateInterval);
    gs.fogBatchSourcesPerFrame = root.getInt("fogBatchSourcesPerFrame", gs.fogBatchSourcesPerFrame);
    gs.fogAutoAdaptiveInterval = root.getBoolean("fogAutoAdaptiveInterval", gs.fogAutoAdaptiveInterval);
    gs.fogAutoAdaptiveThreshold = root.getInt("fogAutoAdaptiveThreshold", gs.fogAutoAdaptiveThreshold);
    gs.fogAutoAdaptiveStep = root.getFloat("fogAutoAdaptiveStep", gs.fogAutoAdaptiveStep);
    gs.fogAutoAdaptiveMaxInterval = root.getFloat("fogAutoAdaptiveMaxInterval", gs.fogAutoAdaptiveMaxInterval);
    gs.fogUnexploredAlpha = root.getInt("fogUnexploredAlpha", gs.fogUnexploredAlpha);
    gs.fogExploredAlpha = root.getInt("fogExploredAlpha", gs.fogExploredAlpha);
    gs.enemyAiDecisionInterval = root.getFloat("enemyAiDecisionInterval", gs.enemyAiDecisionInterval);
    gs.enemyAiMinersMin = root.getInt("enemyAiMinersMin", gs.enemyAiMinersMin);
    gs.enemyAiMinersMax = root.getInt("enemyAiMinersMax", gs.enemyAiMinersMax);
    gs.enemyAiAttackInterval = root.getFloat("enemyAiAttackInterval", gs.enemyAiAttackInterval);
    gs.enemyAiAttackAdvantage = root.getFloat("enemyAiAttackAdvantage", gs.enemyAiAttackAdvantage);
    gs.enemyAiAttackMinArmy = root.getInt("enemyAiAttackMinArmy", gs.enemyAiAttackMinArmy);
    gs.enemyAiRifleRatio = root.getFloat("enemyAiRifleRatio", gs.enemyAiRifleRatio);
    gs.enemyAiRocketRatio = root.getFloat("enemyAiRocketRatio", gs.enemyAiRocketRatio);
    gs.enemyAiDebug = root.getBoolean("enemyAiDebug", gs.enemyAiDebug);
    gs.playerStartCredits = root.getInt("playerStartCredits", gs.playerStartCredits);
    gs.enemyStartCredits = root.getInt("enemyStartCredits", gs.enemyStartCredits);
    gs.defaultCreditCap = root.getInt("defaultCreditCap", gs.defaultCreditCap);
    gs.playerBaseSupplyCap = root.getInt("playerBaseSupplyCap", gs.playerBaseSupplyCap);
    gs.enemyBaseSupplyCap = root.getInt("enemyBaseSupplyCap", gs.enemyBaseSupplyCap);
    gs.warehouseSupplyCapBonus = root.getInt("warehouseSupplyCapBonus", gs.warehouseSupplyCapBonus);
    gs.warehouseCreditCapBonus = root.getInt("warehouseCreditCapBonus", gs.warehouseCreditCapBonus);
    gs.sidePanelWidthRatio = constrain(gs.sidePanelWidthRatio, 0.12, 0.45);
    gs.sidePanelMinW = max(180, gs.sidePanelMinW);
    gs.sidePanelMaxW = max(gs.sidePanelMinW, gs.sidePanelMaxW);
    gs.wheelZoomStep = constrain(gs.wheelZoomStep, 1.02, 1.35);
    gs.edgeScrollSpeed = constrain(gs.edgeScrollSpeed, 160, 1800);
    gs.fogEdgeRadius = int(constrain(gs.fogEdgeRadius, 1, 4));
    gs.fogEdgeStrength = constrain(gs.fogEdgeStrength, 0.10, 0.80);
    gs.fogUpdateInterval = constrain(gs.fogUpdateInterval, 0.02, 0.30);
    gs.fogBatchSourcesPerFrame = int(constrain(gs.fogBatchSourcesPerFrame, 2, 128));
    gs.fogAutoAdaptiveThreshold = int(constrain(gs.fogAutoAdaptiveThreshold, 0, 2000));
    gs.fogAutoAdaptiveStep = constrain(gs.fogAutoAdaptiveStep, 0.0, 0.03);
    gs.fogAutoAdaptiveMaxInterval = constrain(gs.fogAutoAdaptiveMaxInterval, gs.fogUpdateInterval, 0.8);
    gs.fogUnexploredAlpha = int(constrain(gs.fogUnexploredAlpha, 80, 255));
    gs.fogExploredAlpha = int(constrain(gs.fogExploredAlpha, 30, 220));
    gs.enemyAiDecisionInterval = constrain(gs.enemyAiDecisionInterval, 0.08, 0.8);
    gs.enemyAiMinersMin = int(constrain(gs.enemyAiMinersMin, 1, 24));
    gs.enemyAiMinersMax = int(constrain(gs.enemyAiMinersMax, gs.enemyAiMinersMin, 32));
    gs.enemyAiAttackInterval = constrain(gs.enemyAiAttackInterval, 12, 180);
    gs.enemyAiAttackAdvantage = constrain(gs.enemyAiAttackAdvantage, 0.7, 2.4);
    gs.enemyAiAttackMinArmy = int(constrain(gs.enemyAiAttackMinArmy, 2, 40));
    gs.enemyAiRifleRatio = constrain(gs.enemyAiRifleRatio, 0.10, 0.80);
    gs.enemyAiRocketRatio = constrain(gs.enemyAiRocketRatio, 0.05, 0.70);
    gs.playerStartCredits = int(constrain(gs.playerStartCredits, 0, 99999));
    gs.enemyStartCredits = int(constrain(gs.enemyStartCredits, 0, 99999));
    gs.defaultCreditCap = int(constrain(gs.defaultCreditCap, 200, 999999));
    gs.playerBaseSupplyCap = int(constrain(gs.playerBaseSupplyCap, 1, 300));
    gs.enemyBaseSupplyCap = int(constrain(gs.enemyBaseSupplyCap, 1, 300));
    gs.warehouseSupplyCapBonus = int(constrain(gs.warehouseSupplyCapBonus, 1, 200));
    gs.warehouseCreditCapBonus = int(constrain(gs.warehouseCreditCapBonus, 50, 100000));
  }
}

class DefinitionsLoader {
  void apply(GameState gs) {
    gs.unitDefsById.clear();
    gs.buildingDefsById.clear();
    gs.scoutDef = new UnitDef();
    gs.scoutDef.id = "scout";
    gs.scoutDef.role = "machinegun";
    gs.scoutDef.speed = 120;
    gs.scoutDef.radius = 11;
    gs.scoutDef.hp = 100;
    gs.unitDefsById.put(gs.scoutDef.id, gs.scoutDef);

    BuildingDef defaultOutpost = new BuildingDef();
    defaultOutpost.id = "base";
    defaultOutpost.category = "core";
    defaultOutpost.tileW = 2;
    defaultOutpost.tileH = 2;
    defaultOutpost.buildTime = 3.0;
    defaultOutpost.cost = 120;
    defaultOutpost.prerequisites = new String[0];
    defaultOutpost.trainableUnits = new String[0];
    gs.buildingDefs.add(defaultOutpost);
    gs.buildingDefsById.put(defaultOutpost.id, defaultOutpost);

    JSONObject unitRoot = loadJSONObject("units.json");
    if (unitRoot != null) {
      JSONArray arr = unitRoot.getJSONArray("units");
      if (arr != null && arr.size() > 0) {
        gs.unitDefsById.clear();
        for (int i = 0; i < arr.size(); i++) {
          JSONObject o = arr.getJSONObject(i);
          UnitDef def = new UnitDef();
          def.id = o.getString("id", "unit_" + i);
          def.role = o.getString("role", "machinegun");
          def.speed = o.getFloat("speed", 120);
          def.radius = o.getFloat("radius", 11);
          def.hp = o.getInt("hp", 100);
          def.attackRange = o.getFloat("attackRange", 95);
          def.attackDamage = o.getFloat("attackDamage", 8);
          def.attackCooldown = o.getFloat("attackCooldown", 0.6);
          def.canAttack = o.getBoolean("canAttack", true);
          def.cost = o.getInt("cost", 60);
          def.trainTime = o.getFloat("trainTime", 2.0);
          def.sightRange = o.getFloat("sightRange", 220);
          def.usesProjectile = o.getBoolean("usesProjectile", false);
          def.projectileSpeed = o.getFloat("projectileSpeed", 260);
          def.canHarvest = o.getBoolean("canHarvest", false);
          def.harvestAmount = o.getInt("harvestAmount", 20);
          def.harvestTime = o.getFloat("harvestTime", 1.2);
          def.autoDefend = o.getBoolean("autoDefend", true);
          def.supplyCost = max(0, o.getInt("supplyCost", 1));
          gs.unitDefsById.put(def.id, def);
        }
        if (gs.unitDefsById.containsKey("rifleman")) {
          gs.scoutDef = gs.unitDefsById.get("rifleman");
        } else {
          for (String key : gs.unitDefsById.keySet()) {
            gs.scoutDef = gs.unitDefsById.get(key);
            break;
          }
        }
      }
    }

    JSONObject buildingRoot = loadJSONObject("buildings.json");
    if (buildingRoot != null) {
      JSONArray arr = buildingRoot.getJSONArray("buildings");
      if (arr != null && arr.size() > 0) {
        gs.buildingDefs.clear();
        gs.buildingDefsById.clear();
        for (int i = 0; i < arr.size(); i++) {
          JSONObject o = arr.getJSONObject(i);
          BuildingDef def = new BuildingDef();
          def.id = o.getString("id", "building_" + i);
          def.category = o.getString("category", "general");
          def.tileW = o.getInt("tileW", 2);
          def.tileH = o.getInt("tileH", 2);
          def.buildTime = o.getFloat("buildTime", 3.0);
          def.cost = o.getInt("cost", 120);
          def.prerequisites = new String[0];
          def.trainableUnits = new String[0];
          JSONArray req = o.getJSONArray("requires");
          if (req != null) {
            def.prerequisites = new String[req.size()];
            for (int r = 0; r < req.size(); r++) def.prerequisites[r] = req.getString(r);
          }
          def.canTrainUnits = o.getBoolean("canTrainUnits", false);
          JSONArray train = o.getJSONArray("trainableUnits");
          if (train != null) {
            def.trainableUnits = new String[train.size()];
            for (int t = 0; t < train.size(); t++) def.trainableUnits[t] = train.getString(t);
          }
          def.isDropoff = o.getBoolean("isDropoff", false);
          def.isMainBase = o.getBoolean("isMainBase", false);
          def.sellRefundRatio = constrain(o.getFloat("sellRefundRatio", 0.5), 0, 1);
          def.isTower = o.getBoolean("isTower", false);
          def.towerAttackRange = o.getFloat("towerAttackRange", def.towerAttackRange);
          def.towerDamage = o.getFloat("towerDamage", def.towerDamage);
          def.towerCooldown = o.getFloat("towerCooldown", def.towerCooldown);
          def.towerProjectileSpeed = o.getFloat("towerProjectileSpeed", def.towerProjectileSpeed);
          def.useLegacySpawnFallback = o.getBoolean("useLegacySpawnFallback", true);
          def.spawnClearancePad = o.getFloat("spawnClearancePad", 3.0);
          int defaultSupplyBonus = "warehouse".equals(def.id) ? gs.warehouseSupplyCapBonus : 0;
          int defaultCreditBonus = "warehouse".equals(def.id) ? gs.warehouseCreditCapBonus : 0;
          def.supplyCapBonus = max(0, o.getInt("supplyCapBonus", defaultSupplyBonus));
          def.creditCapBonus = max(0, o.getInt("creditCapBonus", defaultCreditBonus));
          JSONArray spawnPointsArr = o.getJSONArray("spawnPoints");
          if (spawnPointsArr != null) {
            def.spawnPoints = new SpawnPointDef[spawnPointsArr.size()];
            for (int s = 0; s < spawnPointsArr.size(); s++) {
              JSONObject so = spawnPointsArr.getJSONObject(s);
              SpawnPointDef sp = new SpawnPointDef();
              sp.mode = so.getString("mode", "localTile");
              sp.x = so.getFloat("x", 0);
              sp.y = so.getFloat("y", 0);
              def.spawnPoints[s] = sp;
            }
          } else {
            def.spawnPoints = new SpawnPointDef[0];
          }
          gs.buildingDefs.add(def);
          gs.buildingDefsById.put(def.id, def);
        }
      }
    }
  }
}
