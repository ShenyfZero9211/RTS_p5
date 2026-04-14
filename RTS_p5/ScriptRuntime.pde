class ScriptClock {
  float elapsedSec = 0;
  int tickSerial = 0;

  void reset() {
    elapsedSec = 0;
    tickSerial = 0;
  }

  void advance(float dt) {
    elapsedSec += max(0, dt);
    tickSerial++;
  }
}

class ScriptActionLog {
  String text = "";
  float atSec = 0;

  ScriptActionLog(String t, float s) {
    text = t == null ? "" : t;
    atSec = max(0, s);
  }
}

class ScriptBlackboard {
  HashMap<String, Boolean> switches = new HashMap<String, Boolean>();
  int triggerFireCount = 0;
  int triggerFireCountLastTick = 0;
  int actionsExecutedTotal = 0;
  int actionsExecutedLastTick = 0;
  ArrayList<ScriptActionLog> actionLogs = new ArrayList<ScriptActionLog>();
  static final int MAX_LOGS = 24;

  void reset() {
    switches.clear();
    triggerFireCount = 0;
    triggerFireCountLastTick = 0;
    actionsExecutedTotal = 0;
    actionsExecutedLastTick = 0;
    actionLogs.clear();
  }

  void beginTick() {
    triggerFireCountLastTick = 0;
    actionsExecutedLastTick = 0;
  }

  void markTriggerFired() {
    triggerFireCount++;
    triggerFireCountLastTick++;
  }

  void markActionExecuted(String msg, float atSec) {
    actionsExecutedTotal++;
    actionsExecutedLastTick++;
    actionLogs.add(new ScriptActionLog(msg, atSec));
    while (actionLogs.size() > MAX_LOGS) {
      actionLogs.remove(0);
    }
  }

  boolean readSwitch(String key) {
    if (key == null) return false;
    if (!switches.containsKey(key)) return false;
    Boolean v = switches.get(key);
    return v != null && v.booleanValue();
  }

  void writeSwitch(String key, boolean value) {
    if (key == null || key.length() <= 0) return;
    switches.put(key, value);
  }
}

class GameActionBus {
  void executeAction(GameState gs, ScriptBlackboard bb, ScriptClock clock, JSONObject actionObj) {
    if (gs == null || bb == null || actionObj == null) return;
    String type = safeLower(actionObj.getString("type", ""));
    if ("spawnunit".equals(type)) {
      doSpawnUnit(gs, actionObj);
      bb.markActionExecuted("spawnUnit", clock.elapsedSec);
      return;
    }
    if ("grantresource".equals(type)) {
      doGrantResource(gs, actionObj);
      bb.markActionExecuted("grantResource", clock.elapsedSec);
      return;
    }
    if ("setswitch".equals(type)) {
      String key = actionObj.getString("key", "");
      boolean val = actionObj.getBoolean("value", true);
      bb.writeSwitch(key, val);
      bb.markActionExecuted("setSwitch:" + key + "=" + val, clock.elapsedSec);
      return;
    }
    if ("showmessage".equals(type)) {
      String msg = actionObj.getString("message", "");
      if (msg.length() > 0) {
        gs.orderLabel = msg;
      }
      bb.markActionExecuted("showMessage", clock.elapsedSec);
      return;
    }
    if ("issueattackwave".equals(type)) {
      doIssueAttackWave(gs, actionObj);
      bb.markActionExecuted("issueAttackWave", clock.elapsedSec);
      return;
    }
    if ("winorlose".equals(type)) {
      String result = safeUpper(actionObj.getString("result", "VICTORY"));
      if (!"DEFEAT".equals(result) && !"DRAW".equals(result)) {
        result = "VICTORY";
      }
      gs.gameEnded = true;
      gs.gameResult = result;
      gs.orderLabel = tr("order.gameOver");
      bb.markActionExecuted("winOrLose:" + result, clock.elapsedSec);
      return;
    }
    bb.markActionExecuted("unknownAction:" + type, clock.elapsedSec);
  }

  void doSpawnUnit(GameState gs, JSONObject actionObj) {
    if (gs.map == null) return;
    String factionRaw = safeLower(actionObj.getString("faction", "enemy"));
    Faction faction = "player".equals(factionRaw) ? Faction.PLAYER : Faction.ENEMY;
    String unitId = actionObj.getString("unit", "rifleman");
    int count = max(1, actionObj.getInt("count", 1));
    int tx = actionObj.getInt("tileX", -1);
    int ty = actionObj.getInt("tileY", -1);
    float wx = actionObj.getFloat("worldX", -1);
    float wy = actionObj.getFloat("worldY", -1);
    String positionMode = safeLower(actionObj.getString("positionMode", ""));
    PVector anchor = null;
    if ("worldpoint".equals(positionMode) && wx >= 0 && wy >= 0) {
      anchor = new PVector(wx, wy);
    } else if (("tilepoint".equals(positionMode) && tx >= 0 && ty >= 0) || (positionMode.length() <= 0 && tx >= 0 && ty >= 0)) {
      anchor = new PVector((tx + 0.5) * gs.map.tileSize, (ty + 0.5) * gs.map.tileSize);
    } else {
      Building base = gs.findMainBaseForFaction(faction);
      if (base != null) {
        anchor = new PVector(base.pos.x + base.tileW * gs.map.tileSize * 0.5, base.pos.y + base.tileH * gs.map.tileSize * 0.5);
      }
    }
    if (anchor == null) {
      anchor = new PVector(gs.map.worldWidthPx() * ("player".equals(factionRaw) ? 0.25 : 0.75), gs.map.worldHeightPx() * 0.5);
    }
    UnitDef def = gs.getUnitDef(unitId);
    if (def == null) return;
    ArrayList<String> used = new ArrayList<String>();
    for (int i = 0; i < count; i++) {
      float ox = (i % 4) * gs.map.tileSize * 0.8;
      float oy = (i / 4) * gs.map.tileSize * 0.7;
      PVector desired = new PVector(anchor.x + ox, anchor.y + oy);
      PVector safe = gs.findNearestOpenSlot(desired, used);
      used.add(gs.tileKeyForWorld(safe));
      gs.units.add(new Unit(safe.x, safe.y, faction, def));
    }
    gs.refreshFactionCaps();
  }

  void doGrantResource(GameState gs, JSONObject actionObj) {
    String factionRaw = safeLower(actionObj.getString("faction", "player"));
    Faction faction = "enemy".equals(factionRaw) ? Faction.ENEMY : Faction.PLAYER;
    int amount = actionObj.getInt("credits", 0);
    if (amount == 0) return;
    ResourcePool rp = faction == Faction.ENEMY ? gs.enemyResources : gs.resources;
    if (rp == null) return;
    rp.credits = constrain(rp.credits + amount, 0, rp.creditCap);
  }

  void doIssueAttackWave(GameState gs, JSONObject actionObj) {
    if (gs.map == null) return;
    String factionRaw = safeLower(actionObj.getString("faction", "enemy"));
    Faction attacker = "player".equals(factionRaw) ? Faction.PLAYER : Faction.ENEMY;
    Faction defender = attacker == Faction.PLAYER ? Faction.ENEMY : Faction.PLAYER;
    int count = max(1, actionObj.getInt("count", 6));
    Building enemyBase = gs.findMainBaseForFaction(defender);
    PVector target = enemyBase == null
      ? new PVector(gs.map.worldWidthPx() * (defender == Faction.PLAYER ? 0.25 : 0.75), gs.map.worldHeightPx() * 0.5)
      : new PVector(enemyBase.pos.x + enemyBase.tileW * gs.map.tileSize * 0.5, enemyBase.pos.y + enemyBase.tileH * gs.map.tileSize * 0.5);
    int committed = 0;
    for (Unit u : gs.units) {
      if (u.faction != attacker || u.hp <= 0 || u.canHarvest) continue;
      u.issueAttackMove(target.copy(), gs, false);
      committed++;
      if (committed >= count) break;
    }
  }

  String safeLower(String s) {
    if (s == null) return "";
    return trim(s).toLowerCase();
  }

  String safeUpper(String s) {
    if (s == null) return "";
    return trim(s).toUpperCase();
  }
}

class TriggerRule {
  String id = "";
  boolean preserve = true;
  int cooldownMs = 0;
  int priority = 0;
  int timesFired = 0;
  int lastFireMs = -99999999;
  JSONArray conditions;
  JSONArray actions;
}

class TriggerEngine {
  ArrayList<TriggerRule> rules = new ArrayList<TriggerRule>();
  int maxActionsPerTick = 16;

  void clear() {
    rules.clear();
  }

  void loadFromJson(JSONObject root) {
    rules.clear();
    if (root == null) return;
    JSONArray arr = root.getJSONArray("triggers");
    if (arr == null) return;
    for (int i = 0; i < arr.size(); i++) {
      JSONObject o = arr.getJSONObject(i);
      if (o == null) continue;
      TriggerRule r = new TriggerRule();
      r.id = o.getString("id", "trigger_" + i);
      r.preserve = o.getBoolean("preserve", true);
      r.cooldownMs = max(0, o.getInt("cooldownMs", 0));
      r.priority = o.getInt("priority", 0);
      r.conditions = o.getJSONArray("conditions");
      r.actions = o.getJSONArray("actions");
      rules.add(r);
    }
    for (int i = 0; i < rules.size() - 1; i++) {
      for (int j = i + 1; j < rules.size(); j++) {
        if (rules.get(j).priority > rules.get(i).priority) {
          TriggerRule tmp = rules.get(i);
          rules.set(i, rules.get(j));
          rules.set(j, tmp);
        }
      }
    }
  }

  void tick(GameState gs, ScriptClock clock, ScriptBlackboard bb, GameActionBus bus) {
    if (gs == null || bb == null || bus == null) return;
    int actionBudget = maxActionsPerTick;
    int now = millis();
    for (TriggerRule r : rules) {
      if (actionBudget <= 0) break;
      if (!r.preserve && r.timesFired > 0) continue;
      if (r.cooldownMs > 0 && now - r.lastFireMs < r.cooldownMs) continue;
      if (!conditionsMet(gs, bb, clock, r.conditions)) continue;
      r.lastFireMs = now;
      r.timesFired++;
      bb.markTriggerFired();
      if (r.actions != null) {
        for (int ai = 0; ai < r.actions.size(); ai++) {
          if (actionBudget <= 0) break;
          JSONObject a = r.actions.getJSONObject(ai);
          bus.executeAction(gs, bb, clock, a);
          actionBudget--;
        }
      }
    }
  }

  boolean conditionsMet(GameState gs, ScriptBlackboard bb, ScriptClock clock, JSONArray conditions) {
    if (conditions == null || conditions.size() <= 0) {
      return true;
    }
    for (int i = 0; i < conditions.size(); i++) {
      JSONObject c = conditions.getJSONObject(i);
      if (c == null) continue;
      if (!checkCondition(gs, bb, clock, c)) {
        return false;
      }
    }
    return true;
  }

  boolean checkCondition(GameState gs, ScriptBlackboard bb, ScriptClock clock, JSONObject c) {
    String type = safeLower(c.getString("type", ""));
    if ("timeelapsed".equals(type)) {
      float sec = max(0, c.getFloat("seconds", 0));
      return clock.elapsedSec >= sec;
    }
    if ("resourceatleast".equals(type)) {
      String factionRaw = safeLower(c.getString("faction", "player"));
      int amount = c.getInt("credits", 0);
      if ("enemy".equals(factionRaw)) {
        return gs.enemyResources != null && gs.enemyResources.credits >= amount;
      }
      return gs.resources != null && gs.resources.credits >= amount;
    }
    if ("resourceatmost".equals(type)) {
      String factionRaw = safeLower(c.getString("faction", "player"));
      int amount = c.getInt("credits", 0);
      if ("enemy".equals(factionRaw)) {
        return gs.enemyResources != null && gs.enemyResources.credits <= amount;
      }
      return gs.resources != null && gs.resources.credits <= amount;
    }
    if ("unitcountcmp".equals(type)) {
      String factionRaw = safeLower(c.getString("faction", "enemy"));
      Faction faction = "player".equals(factionRaw) ? Faction.PLAYER : Faction.ENEMY;
      String unitId = c.getString("unit", "");
      int value = c.getInt("value", 0);
      String op = c.getString("op", ">=");
      int cur = unitId.length() > 0 ? gs.countFactionUnitsByType(faction, unitId) : gs.countFactionUnits(faction);
      return compareInt(cur, op, value);
    }
    if ("buildingexists".equals(type)) {
      String factionRaw = safeLower(c.getString("faction", "enemy"));
      Faction faction = "player".equals(factionRaw) ? Faction.PLAYER : Faction.ENEMY;
      String buildingId = c.getString("building", "base");
      int cur = gs.countFactionBuildingsByType(faction, buildingId, false);
      return cur > 0;
    }
    if ("switchis".equals(type)) {
      String key = c.getString("key", "");
      boolean val = c.getBoolean("value", true);
      return bb.readSwitch(key) == val;
    }
    return false;
  }

  boolean compareInt(int cur, String op, int value) {
    if ("==".equals(op)) return cur == value;
    if ("<".equals(op)) return cur < value;
    if (">".equals(op)) return cur > value;
    if ("<=".equals(op)) return cur <= value;
    if ("!=".equals(op)) return cur != value;
    return cur >= value;
  }

  String safeLower(String s) {
    if (s == null) return "";
    return trim(s).toLowerCase();
  }
}

class AiStateRuntime {
  String id = "";
  JSONArray commands;
  JSONArray transitions;
}

class AiThreadRuntime {
  String id = "thread";
  String owner = "enemy";
  String currentStateId = "";
  int commandIndex = 0;
  float waitRemainSec = 0;
  HashMap<String, AiStateRuntime> states = new HashMap<String, AiStateRuntime>();
}

class AIScriptEngine {
  String profileName = "";
  boolean enabled = false;
  boolean ownsEnemyAi = false;
  ArrayList<AiThreadRuntime> threads = new ArrayList<AiThreadRuntime>();
  int maxCommandsPerTick = 6;

  void clear() {
    enabled = false;
    ownsEnemyAi = false;
    profileName = "";
    threads.clear();
  }

  void loadFromJson(JSONObject root) {
    clear();
    if (root == null) return;
    profileName = root.getString("profile", "");
    ownsEnemyAi = root.getBoolean("ownsEnemyAi", false);
    JSONArray threadArr = root.getJSONArray("threads");
    if (threadArr == null || threadArr.size() <= 0) return;
    for (int i = 0; i < threadArr.size(); i++) {
      JSONObject threadObj = threadArr.getJSONObject(i);
      if (threadObj == null) continue;
      AiThreadRuntime trt = new AiThreadRuntime();
      trt.id = threadObj.getString("id", "thread_" + i);
      trt.owner = safeLower(threadObj.getString("owner", "enemy"));
      trt.currentStateId = threadObj.getString("initialState", "");
      JSONArray states = threadObj.getJSONArray("states");
      if (states != null) {
        for (int si = 0; si < states.size(); si++) {
          JSONObject so = states.getJSONObject(si);
          if (so == null) continue;
          AiStateRuntime st = new AiStateRuntime();
          st.id = so.getString("id", "state_" + si);
          st.commands = so.getJSONArray("commands");
          st.transitions = so.getJSONArray("transitions");
          trt.states.put(st.id, st);
          if (trt.currentStateId.length() <= 0) {
            trt.currentStateId = st.id;
          }
        }
      }
      if (trt.currentStateId.length() > 0 && trt.states.containsKey(trt.currentStateId)) {
        threads.add(trt);
      }
    }
    enabled = threads.size() > 0;
  }

  void tick(float dt, GameState gs, ScriptClock clock, ScriptBlackboard bb, GameActionBus bus, TriggerEngine triggerEval) {
    if (!enabled || gs == null) return;
    int commandBudget = maxCommandsPerTick;
    for (AiThreadRuntime t : threads) {
      if (commandBudget <= 0) break;
      AiStateRuntime st = t.states.get(t.currentStateId);
      if (st == null) continue;

      String newState = evaluateTransitions(gs, bb, clock, st.transitions, triggerEval);
      if (newState != null && newState.length() > 0 && t.states.containsKey(newState)) {
        t.currentStateId = newState;
        t.commandIndex = 0;
        t.waitRemainSec = 0;
        st = t.states.get(t.currentStateId);
      }
      if (st == null) continue;
      if (t.waitRemainSec > 0) {
        t.waitRemainSec -= max(0, dt);
        continue;
      }
      if (st.commands == null || st.commands.size() <= 0) continue;
      if (t.commandIndex >= st.commands.size()) {
        t.commandIndex = 0;
      }
      JSONObject cmd = st.commands.getJSONObject(t.commandIndex);
      if (cmd == null) {
        t.commandIndex++;
        continue;
      }
      boolean consumed = executeCommand(gs, bb, clock, bus, cmd, t);
      if (consumed) {
        commandBudget--;
      }
      t.commandIndex++;
      if (t.commandIndex >= st.commands.size()) {
        t.commandIndex = 0;
      }
    }
  }

  String evaluateTransitions(GameState gs, ScriptBlackboard bb, ScriptClock clock, JSONArray transitions, TriggerEngine triggerEval) {
    if (transitions == null) return null;
    for (int i = 0; i < transitions.size(); i++) {
      JSONObject t = transitions.getJSONObject(i);
      if (t == null) continue;
      String toState = t.getString("to", "");
      String when = safeLower(t.getString("when", ""));
      JSONObject cond = t;
      if (t.hasKey("condition")) {
        cond = t.getJSONObject("condition");
        if (cond != null && !cond.hasKey("type") && when.length() > 0) {
          cond.setString("type", when);
        }
      } else if (when.length() > 0) {
        cond.setString("type", when);
      }
      if (cond != null && triggerEval != null && triggerEval.checkCondition(gs, bb, clock, cond)) {
        return toState;
      }
    }
    return null;
  }

  boolean executeCommand(GameState gs, ScriptBlackboard bb, ScriptClock clock, GameActionBus bus, JSONObject cmd, AiThreadRuntime thread) {
    String type = safeLower(cmd.getString("type", ""));
    if ("wait".equals(type)) {
      thread.waitRemainSec = max(0.01, cmd.getFloat("seconds", 0.5));
      bb.markActionExecuted("ai.wait:" + thread.id, clock.elapsedSec);
      return false;
    }
    if ("train".equals(type)) {
      Faction faction = parseFaction(cmd.getString("faction", thread.owner));
      String unit = cmd.getString("unit", "rifleman");
      int untilCount = cmd.getInt("untilCount", -1);
      int cur = gs.countFactionUnitsByType(faction, unit);
      if (untilCount < 0 || cur < untilCount) {
        gs.tryTrainUnitForFaction(faction, unit);
      }
      bb.markActionExecuted("ai.train:" + unit, clock.elapsedSec);
      return true;
    }
    if ("build".equals(type)) {
      Faction faction = parseFaction(cmd.getString("faction", thread.owner));
      String building = cmd.getString("building", "barracks");
      Building base = gs.findMainBaseForFaction(faction);
      PVector anchor = base == null ? new PVector(gs.map.worldWidthPx() * 0.5, gs.map.worldHeightPx() * 0.5) : base.pos.copy();
      gs.tryQueueBuildingForFaction(faction, building, anchor);
      bb.markActionExecuted("ai.build:" + building, clock.elapsedSec);
      return true;
    }
    if ("attackprepare".equals(type) || "attackdo".equals(type) || "retreat".equals(type) || "setrally".equals(type)) {
      JSONObject proxy = new JSONObject();
      proxy.setString("type", "issueAttackWave");
      proxy.setString("faction", cmd.getString("faction", thread.owner));
      proxy.setInt("count", cmd.getInt("count", 6));
      bus.executeAction(gs, bb, clock, proxy);
      bb.markActionExecuted("ai." + type, clock.elapsedSec);
      return true;
    }
    bb.markActionExecuted("ai.unknown:" + type, clock.elapsedSec);
    return false;
  }

  Faction parseFaction(String raw) {
    return "player".equals(safeLower(raw)) ? Faction.PLAYER : Faction.ENEMY;
  }

  String safeLower(String s) {
    if (s == null) return "";
    return trim(s).toLowerCase();
  }
}

class ScriptRuntime {
  boolean enabled = false;
  String bundleName = "";
  String bundleNames = "";
  float frameBudgetMs = 0.8;
  ScriptClock clock = new ScriptClock();
  ScriptBlackboard blackboard = new ScriptBlackboard();
  GameActionBus actionBus = new GameActionBus();
  TriggerEngine triggerEngine = new TriggerEngine();
  AIScriptEngine aiEngine = new AIScriptEngine();
  String lastError = "";

  void reset() {
    enabled = false;
    bundleName = "";
    bundleNames = "";
    lastError = "";
    clock.reset();
    blackboard.reset();
    triggerEngine.clear();
    aiEngine.clear();
  }

  void resetForNewGame(GameState gs, JSONObject mapRoot) {
    reset();
    if (mapRoot == null) {
      return;
    }
    ArrayList<String> triggerBundleNames = new ArrayList<String>();
    ArrayList<String> aiBundleNames = new ArrayList<String>();
    JSONArray bundleArr = mapRoot.getJSONArray("scriptBundles");
    if (bundleArr != null && bundleArr.size() > 0) {
      for (int i = 0; i < bundleArr.size(); i++) {
        JSONObject bo = bundleArr.getJSONObject(i);
        if (bo == null || !bo.getBoolean("enabled", true)) continue;
        String path = trim(bo.getString("path", ""));
        if (path.length() <= 0) path = trim(bo.getString("id", ""));
        if (path.length() <= 0) path = trim(bo.getString("bundle", ""));
        if (path.length() <= 0) continue;
        triggerBundleNames.add(path);
      }
    }
    bundleName = "";
    aiBundleNames.addAll(triggerBundleNames);
    if (triggerBundleNames.size() <= 0 && aiBundleNames.size() <= 0 && mapRoot.getJSONArray("scriptTriggers") == null) {
      return;
    }
    try {
      JSONObject mergedTriggerRoot = new JSONObject();
      JSONArray mergedTriggers = new JSONArray();
      JSONArray localTriggerArr = mapRoot.getJSONArray("scriptTriggers");
      if (localTriggerArr != null) {
        for (int i = 0; i < localTriggerArr.size(); i++) {
          JSONObject t = localTriggerArr.getJSONObject(i);
          if (t == null) continue;
          JSONObject cp = parseJSONObject(t.toString());
          if (cp == null) continue;
          String id = cp.getString("id", "map_trigger_" + i);
          cp.setString("id", "map/" + id);
          mergedTriggers.append(cp);
        }
      }
      ArrayList<String> activeNames = new ArrayList<String>();
      for (int i = 0; i < triggerBundleNames.size(); i++) {
        String bn = triggerBundleNames.get(i);
        JSONObject triggerRoot = loadJSONObject("scripts/triggers/" + bn + ".json");
        if (triggerRoot == null) continue;
        activeNames.add(bn);
        JSONArray arr = triggerRoot.getJSONArray("triggers");
        if (arr == null) continue;
        for (int ti = 0; ti < arr.size(); ti++) {
          JSONObject t = arr.getJSONObject(ti);
          if (t == null) continue;
          JSONObject cp = parseJSONObject(t.toString());
          if (cp == null) continue;
          String id = cp.getString("id", "trigger_" + ti);
          cp.setString("id", "bundle/" + bn + "/" + id);
          mergedTriggers.append(cp);
        }
      }
      mergedTriggerRoot.setJSONArray("triggers", mergedTriggers);
      triggerEngine.loadFromJson(mergedTriggerRoot);
      for (int i = 0; i < aiBundleNames.size(); i++) {
        JSONObject aiRoot = loadJSONObject("scripts/ai/" + aiBundleNames.get(i) + ".json");
        if (aiRoot != null) {
          aiEngine.loadFromJson(aiRoot);
          if (aiEngine.enabled) break;
        }
      }
      bundleNames = join(activeNames.toArray(new String[0]), ",");
      if (bundleNames.length() <= 0 && bundleName.length() > 0) bundleNames = bundleName;
      enabled = triggerEngine.rules.size() > 0 || aiEngine.enabled;
      if (enabled) {
        gs.orderLabel = "[SCRIPT] " + (bundleNames.length() > 0 ? bundleNames : "map-local");
      }
    }
    catch (Exception ex) {
      lastError = ex.getMessage();
      enabled = false;
      println("[SCRIPT] load failed: " + lastError);
    }
  }

  void tick(float dt, GameState gs) {
    if (!enabled || gs == null || gs.gameEnded) {
      return;
    }
    long startNs = System.nanoTime();
    blackboard.beginTick();
    clock.advance(dt);
    triggerEngine.tick(gs, clock, blackboard, actionBus);
    aiEngine.tick(dt, gs, clock, blackboard, actionBus, triggerEngine);
    float spent = (System.nanoTime() - startNs) / 1000000.0;
    gs.profileScriptMs = lerp(gs.profileScriptMs, spent, 0.15);
    gs.scriptActionsLastTick = blackboard.actionsExecutedLastTick;
    gs.scriptActionsTotal = blackboard.actionsExecutedTotal;
    if (spent > frameBudgetMs) {
      gs.scriptBudgetOverrunCount++;
    }
  }

  boolean ownsEnemyAi() {
    return enabled && aiEngine.enabled && aiEngine.ownsEnemyAi;
  }

  String activeAiStateLabel() {
    if (!enabled || !aiEngine.enabled || aiEngine.threads.size() <= 0) return "-";
    AiThreadRuntime t = aiEngine.threads.get(0);
    return t.currentStateId;
  }
}
