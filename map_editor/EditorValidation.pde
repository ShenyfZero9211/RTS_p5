class EditorValidationResult {
  ArrayList<String> errors = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();
  boolean ok() {
    return errors.size() == 0;
  }
}

class EditorValidation {
  EditorState s;
  EditorValidation(EditorState state) {
    s = state;
  }

  EditorValidationResult validate() {
    EditorValidationResult r = new EditorValidationResult();
    int playerSpawns = 0;
    int enemySpawns = 0;
    for (EditorSpawn sp : s.spawns) {
      if (!s.inBounds(sp.tx, sp.ty)) {
        r.errors.add("Spawn out of bounds: " + sp.faction + " (" + sp.tx + "," + sp.ty + ")");
      }
      if ("player".equals(sp.faction)) playerSpawns++;
      if ("enemy".equals(sp.faction)) enemySpawns++;
    }
    if (!s.testMap) {
      if (playerSpawns <= 0) r.errors.add("Missing player spawn point.");
      if (enemySpawns <= 0) r.errors.add("Missing enemy spawn point.");
    } else {
      if (playerSpawns <= 0) r.warnings.add("Missing player spawn point (allowed while testMap=ON).");
      if (enemySpawns <= 0) r.warnings.add("Missing enemy spawn point (allowed while testMap=ON).");
    }

    for (EditorMine m : s.mines) {
      if (!s.inBounds(m.tx, m.ty)) {
        r.errors.add("Mine out of bounds at (" + m.tx + "," + m.ty + ")");
        continue;
      }
      if (s.terrainAt(m.tx, m.ty) == 2) {
        r.errors.add("Mine on blocked tile at (" + m.tx + "," + m.ty + ")");
      }
    }

    boolean[][] occupied = new boolean[s.mapHeight][s.mapWidth];
    for (EditorPlacedBuilding b : s.initialBuildings) {
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      for (int y = b.ty; y < b.ty + bh; y++) {
        for (int x = b.tx; x < b.tx + bw; x++) {
          if (!s.inBounds(x, y)) {
            r.errors.add("Building out of bounds: " + b.type + " at (" + b.tx + "," + b.ty + ")");
            continue;
          }
          if (occupied[y][x]) {
            r.errors.add("Building overlap near (" + x + "," + y + ")");
          }
          occupied[y][x] = true;
        }
      }
    }

    for (EditorPlacedUnit u : s.initialUnits) {
      float ur = s.unitRadiusPx(u.type);
      if (u.worldCX < ur || u.worldCY < ur ||
        u.worldCX > s.mapWidth * s.tileSize - ur || u.worldCY > s.mapHeight * s.tileSize - ur) {
        r.errors.add("Unit out of bounds: " + u.type);
        continue;
      }
      int utx = u.centerTileX(s);
      int uty = u.centerTileY(s);
      if (s.terrainAt(utx, uty) == 2) {
        r.errors.add("Unit on blocked tile: " + u.type + " (" + utx + "," + uty + ")");
      }
    }
    ArrayList<String> bundleKeys = new ArrayList<String>();
    for (int bi = 0; bi < s.scriptBundles.size(); bi++) {
      EditorScriptBundleBinding b = s.scriptBundles.get(bi);
      String key = trim(b.path == null || b.path.length() <= 0 ? b.id : b.path);
      if (key.length() <= 0) {
        r.errors.add("Script bundle #" + (bi + 1) + " missing path/id.");
        continue;
      }
      if (bundleKeys.contains(key)) {
        r.errors.add("Script bundle duplicated: " + key);
      } else {
        bundleKeys.add(key);
      }
      if (b.enabled) {
        String p = sketchPath("../RTS_p5/data/scripts/triggers/" + key + ".json");
        JSONObject root = loadJSONObject(p);
        if (root == null) {
          r.errors.add("Script bundle file missing: " + key + ".json");
        }
      } else {
        r.warnings.add("Script bundle disabled: " + key);
      }
    }
    ArrayList<String> triggerIds = new ArrayList<String>();
    String[] condAllowed = new String[] { "timeElapsed", "resourceAtLeast", "unitCountCmp", "buildingExists", "switchIs" };
    String[] actAllowed = new String[] { "spawnUnit", "grantResource", "setSwitch", "showMessage", "issueAttackWave", "winOrLose" };
    for (int ti = 0; ti < s.scriptTriggers.size(); ti++) {
      EditorScriptTrigger t = s.scriptTriggers.get(ti);
      String tid = t.id == null ? "" : trim(t.id);
      if (tid.length() <= 0) {
        r.errors.add("Script trigger #" + (ti + 1) + " missing id.");
      } else if (triggerIds.contains(tid)) {
        r.errors.add("Script trigger id duplicated: " + tid);
      } else {
        triggerIds.add(tid);
      }
      if (t.conditions.size() <= 0) r.errors.add("Script trigger " + tid + " has no conditions.");
      if (t.actions.size() <= 0) r.errors.add("Script trigger " + tid + " has no actions.");
      for (int ci = 0; ci < t.conditions.size(); ci++) {
        EditorScriptCondition c = t.conditions.get(ci);
        String type = c == null || c.data == null ? "" : c.data.getString("type", "");
        if (!inSet(type, condAllowed)) {
          r.errors.add("Script condition unsupported: " + type + " in " + tid);
        }
      }
      for (int ai = 0; ai < t.actions.size(); ai++) {
        EditorScriptAction a = t.actions.get(ai);
        String type = a == null || a.data == null ? "" : a.data.getString("type", "");
        if (!inSet(type, actAllowed)) {
          r.errors.add("Script action unsupported: " + type + " in " + tid);
          continue;
        }
        if ("spawnUnit".equals(type)) {
          String mode = a.data.getString("positionMode", "nearFactionSpawn");
          if (!inSet(mode, new String[] {"nearFactionSpawn", "tilePoint", "worldPoint"})) {
            r.errors.add("Trigger " + safeId(tid, ti) + ": spawnUnit invalid positionMode " + mode);
          }
          if ("tilePoint".equals(mode)) {
            int tx = a.data.getInt("tileX", -1);
            int ty = a.data.getInt("tileY", -1);
            if (!s.inBounds(tx, ty)) {
              r.errors.add("Trigger " + safeId(tid, ti) + ": spawnUnit tilePoint out of bounds.");
            }
          }
        }
      }

      // Condition <-> Action logic checks (first-pass guardrails)
      boolean hasTimeElapsed = triggerHasConditionType(t, "timeElapsed");
      boolean hasUnitCountCmp = triggerHasConditionType(t, "unitCountCmp");
      boolean hasBuildingExists = triggerHasConditionType(t, "buildingExists");
      boolean hasSwitchIs = triggerHasConditionType(t, "switchIs");
      boolean hasResourceAtLeast = triggerHasConditionType(t, "resourceAtLeast");

      boolean hasGrantResource = triggerHasActionType(t, "grantResource");
      boolean hasSpawnUnit = triggerHasActionType(t, "spawnUnit");
      boolean hasIssueAttackWave = triggerHasActionType(t, "issueAttackWave");
      boolean hasSetSwitch = triggerHasActionType(t, "setSwitch");
      boolean hasWinOrLose = triggerHasActionType(t, "winOrLose");

      // 1) Decisive actions should not be preserved forever.
      if (hasWinOrLose && t.preserve) {
        r.warnings.add("Trigger " + safeId(tid, ti) + ": winOrLose should set preserve=false.");
      }

      // 2) Spawning/attack/resource actions must have at least one gating condition.
      boolean hasStrongGate = hasTimeElapsed || hasUnitCountCmp || hasBuildingExists || hasSwitchIs || hasResourceAtLeast;
      if ((hasGrantResource || hasSpawnUnit || hasIssueAttackWave) && !hasStrongGate) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": action requires a gating condition (time/unit/building/switch/resource).");
      }

      // 3) Preserve + no cooldown + mutating actions is usually a runaway loop.
      if (t.preserve && t.cooldownMs <= 0 && (hasGrantResource || hasSpawnUnit || hasIssueAttackWave)) {
        r.warnings.add("Trigger " + safeId(tid, ti) + ": preserve=true and cooldownMs=0 may spam mutating actions.");
      }

      // 4) switchIs conditions should usually have a way to change switch state.
      if (hasSwitchIs && !hasSetSwitch && t.preserve && t.cooldownMs <= 0) {
        r.warnings.add("Trigger " + safeId(tid, ti) + ": switchIs without setSwitch can lock trigger state.");
      }

      // 5) Hard constraints by action type.
      if (hasIssueAttackWave && !(hasTimeElapsed || hasUnitCountCmp || hasBuildingExists || hasSwitchIs)) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": issueAttackWave requires timeElapsed/unitCountCmp/buildingExists/switchIs.");
      }
      if (hasSpawnUnit && !(hasTimeElapsed || hasResourceAtLeast || hasSwitchIs || hasBuildingExists)) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": spawnUnit requires timeElapsed/resourceAtLeast/switchIs/buildingExists.");
      }
      if (hasGrantResource && !(hasResourceAtLeast || hasSwitchIs || hasTimeElapsed)) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": grantResource requires resourceAtLeast/switchIs/timeElapsed.");
      }
      if (hasSetSwitch && !(hasSwitchIs || hasTimeElapsed || hasResourceAtLeast || hasUnitCountCmp || hasBuildingExists)) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": setSwitch requires at least one gating condition.");
      }
      if (hasWinOrLose && !(hasBuildingExists || hasUnitCountCmp || hasTimeElapsed || hasSwitchIs)) {
        r.errors.add("Trigger " + safeId(tid, ti) + ": winOrLose requires buildingExists/unitCountCmp/timeElapsed/switchIs.");
      }
    }
    return r;
  }

  boolean inSet(String v, String[] arr) {
    for (int i = 0; i < arr.length; i++) {
      if (arr[i].equals(v)) return true;
    }
    return false;
  }

  boolean triggerHasConditionType(EditorScriptTrigger t, String type) {
    if (t == null) return false;
    for (int i = 0; i < t.conditions.size(); i++) {
      EditorScriptCondition c = t.conditions.get(i);
      if (c == null || c.data == null) continue;
      if (type.equals(c.data.getString("type", ""))) return true;
    }
    return false;
  }

  boolean triggerHasActionType(EditorScriptTrigger t, String type) {
    if (t == null) return false;
    for (int i = 0; i < t.actions.size(); i++) {
      EditorScriptAction a = t.actions.get(i);
      if (a == null || a.data == null) continue;
      if (type.equals(a.data.getString("type", ""))) return true;
    }
    return false;
  }

  String safeId(String tid, int idx) {
    if (tid != null && tid.length() > 0) return tid;
    return "#" + (idx + 1);
  }
}
