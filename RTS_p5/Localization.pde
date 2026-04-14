import java.util.Locale;

enum LanguageMode {
  AUTO,
  ZH,
  EN
}

class Localization {
  LanguageMode mode = LanguageMode.AUTO;
  HashMap<String, String> zh = new HashMap<String, String>();
  HashMap<String, String> en = new HashMap<String, String>();
  String settingsPath = "data/settings_user.json";

  Localization() {
    initDict();
  }

  void initDict() {
    put("app.title", "RTS 指挥", "RTS Command");
    put("menu.title", "RTS 指挥", "RTS Command");
    put("menu.subtitle", "金属倒角战术界面原型", "Metal & rivets tactical UI");
    put("menu.play", "进入游戏", "Start");
    put("menu.play.sub", "开始/继续当前会话", "Start or resume session");
    put("menu.settings", "设置", "Settings");
    put("menu.settings.sub", "会话选项", "Session options");
    put("menu.exit", "退出", "Exit");
    put("menu.exit.sub", "退出应用", "Exit application");
    put("menu.back", "返回", "Back");
    put("menu.back.sub", "回到主菜单", "Back to main");
    put("menu.resume", "返回游戏", "Resume game");
    put("menu.resume.sub", "继续当前对局", "Continue current match");
    put("menu.returnMain", "返回主菜单", "Return to main menu");
    put("menu.returnMain.sub", "结束本局并回到开始界面", "End match and return to start screen");
    put("menu.settings.title", "设置（仅本次会话，语言会持久化）", "Settings (session, language persists)");
    put("menu.fog.toggle", "切换战争迷雾", "Toggle fog");
    put("menu.fog.toggle.sub", "预览开关", "Preview toggle");
    put("menu.speed", "游戏速度", "Game speed");
    put("menu.speed.sub", "切换速度倍率", "Cycle speed multiplier");
    put("menu.profiling", "性能面板", "Profiling overlay");
    put("menu.profiling.sub", "切换运行时调试显示", "Toggle runtime debug overlay");
    put("menu.lang.auto", "语言：系统默认", "Language: System default");
    put("menu.lang.zh", "语言：中文", "Language: Chinese");
    put("menu.lang.en", "语言：英文", "Language: English");
    put("menu.lang.label", "语言", "Language");
    put("menu.persist.hint", "语言保存到 data/settings_user.json", "Language is saved to data/settings_user.json");
    put("menu.mapSelect.title", "选择地图", "Choose map");
    put("menu.mapSelect.subtitle", "从 data 文件夹读取的地图 JSON", "Map JSON files found in data/");
    put("menu.mapSelect.empty", "未找到有效地图（需含 rows/width/height/tileSize）", "No valid maps (need rows, width, height, tileSize)");
    put("menu.mapSelect.start", "开始", "Start");
    put("menu.mapSelect.start.sub", "使用所选地图开局", "Start with selected map");
    put("menu.mapSelect.back", "返回", "Back");
    put("menu.mapSelect.back.sub", "回到主菜单", "Return to main menu");
    put("menu.mapSelect.up", "▲", "▲");
    put("menu.mapSelect.down", "▼", "▼");

    put("overlay.defeat", "被击败", "DEFEAT");
    put("overlay.victory", "胜利", "VICTORY");
    put("overlay.draw", "平局", "DRAW");
    put("overlay.desc", "一方单位与建筑被全部摧毁。", "All units and buildings destroyed on one side.");
    put("overlay.replay", "重玩", "Replay");
    put("overlay.menu", "主菜单", "Main menu");

    put("ui.construct", "建造", "CONSTRUCT");
    put("ui.train", "训练", "TRAIN");
    put("ui.commands", "命令", "COMMANDS");
    put("ui.selectStructure", "选择建筑以显示命令", "select a structure");
    put("ui.buildError", "建造错误", "Build error");
    put("ui.buildUnexplored", "未探索区域不可建造", "Cannot build in unexplored area");
    put("ui.locked", "未解锁", "LOCKED");
    put("ui.lowCredits", "资金不足", "LOW CREDITS");
    put("ui.lowSupply", "人口不足", "LOW SUPPLY");
    put("ui.supply", "人口", "Supply");
    put("ui.creditsCap", "资金上限", "Credits cap");
    put("ui.constructing", "建造中", "Constructing");
    put("ui.training", "训练中", "Training");
    put("ui.sell", "出售", "SELL");
    put("ui.sellRefund", "出售返还", "Sell refund");
    put("ui.faction", "阵营", "Faction");
    put("ui.unitsSelected", "已选单位", "Units selected");
    put("ui.order", "命令", "Order");
    put("ui.buildQueue", "建造队列", "BuildQ");
    put("ui.enemyAi", "敌方AI", "EnemyAI");
    put("ui.waveTimer", "进攻计时", "WaveT");
    put("ui.last", "最近动作", "Last");
    put("ui.building", "建筑", "Building");
    put("ui.category", "类别", "Category");
    put("ui.unit", "单位", "Unit");
    put("ui.group", "编队", "Group");
    put("ui.hint.idle1", "选择主基地可打开建造面板。", "Select your Command Post (base)");
    put("ui.hint.idle2", "选择兵营可打开训练面板。", "Select Barracks to train units.");
    put("ui.hint.controls", "左键选择/放置，右键移动/攻击。", "LMB Select/Place, RMB Move/Attack.");

    put("order.none", "无", "None");
    put("order.gameOver", "游戏结束", "GameOver");
    put("order.selectProducer", "请选择生产建筑", "SelectProducer");
    put("order.noTrainHere", "该建筑不可训练", "NoTrainHere");
    put("order.unitNotInRoster", "该单位不可在此训练", "UnitNotInRoster");
    put("order.needCredits", "资金不足", "NeedCredits");
    put("order.needSupply", "人口不足", "NeedSupply");
    put("order.train", "训练", "Train");
    put("order.trainCancel", "取消训练", "TrainCancel");
    put("order.attackMove", "A动", "AttackMove");
    put("order.buildPlaced", "已放置建造", "BuildPlaced");
    put("order.buildCancel", "取消建造放置", "BuildPlace(Cancel)");
    put("order.noSelection", "未选择单位", "NoSelection");
    put("order.attack", "攻击", "Attack");
    put("order.attackBuilding", "攻击建筑", "AttackBuilding");
    put("order.move", "移动", "Move");
    put("order.queueMove", "队列移动", "QueueMove");
    put("order.attackMoveArmed", "A动已就绪", "AttackMove(Armed)");
    put("order.attackMoveCancel", "A动取消", "AttackMove(Cancel)");
    put("order.cursorLockOn", "光标锁定(开)", "CursorLock(ON)");
    put("order.cursorLockOff", "光标锁定(关)", "CursorLock(OFF)");
    put("order.debugOn", "路径调试(开)", "DebugPaths(ON)");
    put("order.debugOff", "路径调试(关)", "DebugPaths(OFF)");
    put("order.sold", "已出售", "Sold");
    put("order.harvest", "采集", "Harvest");
    put("order.buildArmed", "建造放置(就绪)", "BuildPlace(Armed)");
    put("order.buildQueueMinus", "建造队列-1", "BuildQueue-1");
    put("order.rallySet", "已设置集结点", "RallyPointSet");
    put("order.groupSaved", "编队已保存", "GroupSaved");
    put("order.groupRecalled", "编队已选中", "GroupRecalled");
    put("order.groupEmpty", "编队为空", "GroupEmpty");
    put("order.groupMemberAdded", "已加入当前编队", "AddedToActiveGroup");
    put("order.groupMemberRemoved", "已移出当前编队", "RemovedFromActiveGroup");
  }

  void put(String key, String zhText, String enText) {
    zh.put(key, zhText);
    en.put(key, enText);
  }

  void loadUserSettings() {
    JSONObject root = loadJSONObject(settingsPath);
    if (root == null) {
      return;
    }
    String m = root.getString("language", "auto").toLowerCase();
    if ("zh".equals(m)) {
      mode = LanguageMode.ZH;
    } else if ("en".equals(m)) {
      mode = LanguageMode.EN;
    } else {
      mode = LanguageMode.AUTO;
    }
  }

  void saveUserSettings() {
    JSONObject root = loadJSONObject(settingsPath);
    if (root == null) {
      root = new JSONObject();
    }
    root.setString("language", modeCode(mode));
    saveJSONObject(root, settingsPath);
  }

  String modeCode(LanguageMode m) {
    if (m == LanguageMode.ZH) {
      return "zh";
    }
    if (m == LanguageMode.EN) {
      return "en";
    }
    return "auto";
  }

  LanguageMode effectiveMode() {
    if (mode != LanguageMode.AUTO) {
      return mode;
    }
    Locale loc = Locale.getDefault();
    String lang = loc == null ? "en" : loc.getLanguage();
    if (lang != null && lang.toLowerCase().startsWith("zh")) {
      return LanguageMode.ZH;
    }
    return LanguageMode.EN;
  }

  String t(String key) {
    LanguageMode em = effectiveMode();
    String s = em == LanguageMode.ZH ? zh.get(key) : en.get(key);
    if (s == null) {
      s = en.get(key);
    }
    return s == null ? key : s;
  }
}

String tr(String key) {
  if (i18n == null) {
    return key;
  }
  return i18n.t(key);
}
