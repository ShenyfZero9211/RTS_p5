class EditorScriptDialog {
  EditorState s;
  EditorUI ui;
  boolean visible = false;
  int activeTab = 0; // 0 = map triggers, 1 = bundle bindings
  int selectedTrigger = -1;
  int selectedCondition = -1;
  int selectedAction = -1;
  int selectedBundle = -1;
  int spawnUnitEditField = 0;
  boolean bundleEditMode = false;
  String editingBundlePath = "";
  String editingBundleName = "";
  ArrayList<EditorScriptTrigger> bundleEditTriggers = new ArrayList<EditorScriptTrigger>();
  boolean bundleEditDirty = false;
  boolean bundleExitArmed = false;
  int lastBundleClickIndex = -1;
  int lastBundleClickAtMs = -999999;
  boolean condTypePickerOpen = false;
  boolean actionTypePickerOpen = false;

  final String[] condTypes = new String[] {
    "timeElapsed", "resourceAtLeast", "unitCountCmp", "buildingExists", "switchIs"
  };
  final String[] actionTypes = new String[] {
    "spawnUnit", "grantResource", "setSwitch", "showMessage", "issueAttackWave", "winOrLose"
  };

  EditorScriptDialog(EditorState state, EditorUI uiRef) {
    s = state;
    ui = uiRef;
  }

  void openDialog() {
    visible = true;
    if (selectedTrigger < 0 && s.scriptTriggers.size() > 0) selectedTrigger = 0;
    if (selectedBundle < 0 && s.scriptBundles.size() > 0) selectedBundle = 0;
    clampSelection();
  }

  void closeDialog() {
    visible = false;
    condTypePickerOpen = false;
    actionTypePickerOpen = false;
    bundleEditMode = false;
    editingBundlePath = "";
    editingBundleName = "";
    bundleEditTriggers.clear();
    bundleEditDirty = false;
    bundleExitArmed = false;
  }

  void toggle() {
    if (visible) closeDialog();
    else openDialog();
  }

  void clampSelection() {
    ArrayList<EditorScriptTrigger> src = triggerSource();
    if (src.size() <= 0) {
      selectedTrigger = -1;
      selectedCondition = -1;
      selectedAction = -1;
    } else {
      selectedTrigger = constrain(selectedTrigger, 0, src.size() - 1);
      EditorScriptTrigger t = src.get(selectedTrigger);
      if (t.conditions.size() <= 0) selectedCondition = -1;
      else selectedCondition = constrain(selectedCondition, 0, t.conditions.size() - 1);
      if (t.actions.size() <= 0) selectedAction = -1;
      else selectedAction = constrain(selectedAction, 0, t.actions.size() - 1);
    }
    if (s.scriptBundles.size() <= 0) selectedBundle = -1;
    else selectedBundle = constrain(selectedBundle, 0, s.scriptBundles.size() - 1);
  }

  EditorScriptTrigger activeTrigger() {
    ArrayList<EditorScriptTrigger> src = triggerSource();
    if (selectedTrigger < 0 || selectedTrigger >= src.size()) return null;
    return src.get(selectedTrigger);
  }

  ArrayList<EditorScriptTrigger> triggerSource() {
    return bundleEditMode ? bundleEditTriggers : s.scriptTriggers;
  }

  String scriptTitle() {
    if (bundleEditMode) {
      String id = editingBundleName.length() > 0 ? editingBundleName : editingBundlePath;
      return "Script Editor (Editing scriptbundle: " + id + ")";
    }
    return "Script Editor (Trigger DSL)";
  }

  void markBundleDirtyIfEditing() {
    if (bundleEditMode) {
      bundleEditDirty = true;
      bundleExitArmed = false;
    }
  }

  boolean tryExitBundleEdit() {
    if (!bundleEditMode) return true;
    if (!bundleEditDirty) {
      bundleEditMode = false;
      editingBundlePath = "";
      editingBundleName = "";
      bundleEditTriggers.clear();
      bundleExitArmed = false;
      return true;
    }
    if (!bundleExitArmed) {
      bundleExitArmed = true;
      s.setStatus("Unsaved bundle edits. Press ESC/Back again to discard, or Ctrl+S to save.");
      return false;
    }
    bundleEditMode = false;
    editingBundlePath = "";
    editingBundleName = "";
    bundleEditTriggers.clear();
    bundleEditDirty = false;
    bundleExitArmed = false;
    s.setStatus("Discarded unsaved bundle edits.");
    return true;
  }

  boolean hit(float x, float y, float w, float h, int mx, int my) {
    return mx >= x && mx <= x + w && my >= y && my <= y + h;
  }

  String condSummary(EditorScriptCondition c) {
    if (c == null || c.data == null) return "-";
    String type = c.data.getString("type", "");
    if ("timeElapsed".equals(type)) return "sec>=" + nf(c.data.getFloat("seconds", 0), 1, 1);
    if ("resourceAtLeast".equals(type)) return c.data.getString("faction", "player") + " $" + c.data.getInt("credits", 0);
    if ("unitCountCmp".equals(type)) return c.data.getString("faction", "enemy") + " " + c.data.getString("unit", "rifleman") + " " + c.data.getString("op", ">=") + " " + c.data.getInt("value", 0);
    if ("buildingExists".equals(type)) return c.data.getString("faction", "enemy") + " " + c.data.getString("building", "base");
    if ("switchIs".equals(type)) return c.data.getString("key", "flag") + "=" + c.data.getBoolean("value", true);
    return type;
  }

  String actionSummary(EditorScriptAction a) {
    if (a == null || a.data == null) return "-";
    String type = a.data.getString("type", "");
    if ("spawnUnit".equals(type)) return a.data.getString("faction", "enemy") + " " + a.data.getString("unit", "rifleman") + " x" + a.data.getInt("count", 1) + " @" + a.data.getString("positionMode", "nearFactionSpawn");
    if ("grantResource".equals(type)) return a.data.getString("faction", "player") + " +" + a.data.getInt("credits", 0);
    if ("setSwitch".equals(type)) return a.data.getString("key", "flag") + "=" + a.data.getBoolean("value", true);
    if ("showMessage".equals(type)) return a.data.getString("message", "");
    if ("issueAttackWave".equals(type)) return a.data.getString("faction", "enemy") + " x" + a.data.getInt("count", 6);
    if ("winOrLose".equals(type)) return a.data.getString("result", "VICTORY");
    return type;
  }

  EditorScriptCondition createDefaultCondition() {
    EditorScriptCondition c = new EditorScriptCondition();
    c.data.setString("type", "timeElapsed");
    c.data.setFloat("seconds", 30);
    return c;
  }

  EditorScriptAction createDefaultAction() {
    EditorScriptAction a = new EditorScriptAction();
    a.data.setString("type", "showMessage");
    a.data.setString("message", "Script message");
    return a;
  }

  void resetConditionDefaults(EditorScriptCondition c, String type) {
    c.data = new JSONObject();
    c.data.setString("type", type);
    if ("timeElapsed".equals(type)) c.data.setFloat("seconds", 30);
    else if ("resourceAtLeast".equals(type)) {
      c.data.setString("faction", "player");
      c.data.setInt("credits", 200);
    } else if ("unitCountCmp".equals(type)) {
      c.data.setString("faction", "enemy");
      c.data.setString("unit", "rifleman");
      c.data.setString("op", ">=");
      c.data.setInt("value", 6);
    } else if ("buildingExists".equals(type)) {
      c.data.setString("faction", "enemy");
      c.data.setString("building", "base");
    } else if ("switchIs".equals(type)) {
      c.data.setString("key", "flag");
      c.data.setBoolean("value", true);
    }
  }

  void resetActionDefaults(EditorScriptAction a, String type) {
    a.data = new JSONObject();
    a.data.setString("type", type);
    if ("spawnUnit".equals(type)) {
      a.data.setString("faction", "enemy");
      a.data.setString("unit", "rifleman");
      a.data.setInt("count", 3);
      a.data.setString("positionMode", "nearFactionSpawn");
      a.data.setInt("tileX", 0);
      a.data.setInt("tileY", 0);
      a.data.setFloat("worldX", 0);
      a.data.setFloat("worldY", 0);
    } else if ("grantResource".equals(type)) {
      a.data.setString("faction", "player");
      a.data.setInt("credits", 300);
    } else if ("setSwitch".equals(type)) {
      a.data.setString("key", "flag");
      a.data.setBoolean("value", true);
    } else if ("showMessage".equals(type)) {
      a.data.setString("message", "Script message");
    } else if ("issueAttackWave".equals(type)) {
      a.data.setString("faction", "enemy");
      a.data.setInt("count", 8);
    } else if ("winOrLose".equals(type)) {
      a.data.setString("result", "VICTORY");
    }
  }

  void render() {
    if (!visible) return;
    clampSelection();
    pushStyle();
    fill(0, 0, 0, 160);
    noStroke();
    rect(0, 0, width, height);
    float x = 70;
    float y = 52;
    float w = width - 140;
    float h = height - 104;
    fill(28, 33, 42);
    stroke(90, 110, 135);
    rect(x, y, w, h, 8);
    noStroke();
    fill(225);
    textSize(22);
    textAlign(LEFT, TOP);
    text(scriptTitle(), x + 14, y + 10);
    textSize(14);
    fill(180, 200, 225);
    text("Bundles: " + s.scriptBundles.size(), x + 14, y + 34);
    fill(230, 120, 120);
    text("[ESC] Close", x + w - 110, y + 14);
    drawBtn(x + 360, y + 8, 130, 28, activeTab == 0 ? "[Map Triggers]" : "Map Triggers");
    drawBtn(x + 496, y + 8, 130, 28, activeTab == 1 ? "[Bundles]" : "Bundles");
    if (bundleEditMode) {
      drawBtn(x + w - 280, y + 8, 76, 28, "Save");
      drawBtn(x + w - 198, y + 8, 76, 28, "Back");
    }

    float bodyY = y + 58;
    float bodyH = h - 70;
    float leftW = w * 0.27;
    float midW = w * 0.34;
    float rightW = w - leftW - midW - 24;
    float leftX = x + 10;
    float midX = leftX + leftW + 8;
    float rightX = midX + midW + 8;
    if (activeTab == 0) {
      panel(leftX, bodyY, leftW, bodyH, "Map Triggers");
      panel(midX, bodyY, midW, bodyH, "Conditions");
      panel(rightX, bodyY, rightW, bodyH, "Actions");
      renderTriggerPanel(leftX, bodyY, leftW, bodyH);
      renderConditionPanel(midX, bodyY, midW, bodyH);
      renderActionPanel(rightX, bodyY, rightW, bodyH);
      renderTypePickers(midX, rightX, bodyY, bodyH);
    } else {
      panel(leftX, bodyY, w - 20, bodyH, "Bundle Bindings");
      renderBundlePanel(leftX, bodyY, w - 20, bodyH);
    }
    popStyle();
  }

  void renderBundlePanel(float x, float y, float w, float h) {
    float btnY = y + h - 34;
    drawBtn(x + 8, btnY, 52, 24, "+B");
    drawBtn(x + 64, btnY, 52, 24, "-B");
    drawBtn(x + 120, btnY, 72, 24, "Path");
    drawBtn(x + 196, btnY, 72, 24, "Name");
    drawBtn(x + 272, btnY, 72, 24, "Enable");
    drawBtn(x + 348, btnY, 72, 24, "Pri");
    float yy = y + 28;
    for (int i = 0; i < s.scriptBundles.size() && i < 20; i++) {
      EditorScriptBundleBinding b = s.scriptBundles.get(i);
      if (i == selectedBundle) {
        fill(58, 80, 110);
        rect(x + 6, yy - 2, w - 12, 20, 4);
      }
      fill(225);
      textSize(13);
      text((i + 1) + ". " + (b.name.length() > 0 ? b.name : "(noname)") + "  path=" + b.path + "  en=" + b.enabled + "  p=" + b.priority, x + 10, yy);
      yy += 20;
    }
  }

  void renderTypePickers(float midX, float rightX, float bodyY, float bodyH) {
    if (condTypePickerOpen) {
      float px = midX + 124;
      float py = bodyY + bodyH - 34 - condTypes.length * 20 - 4;
      float pw = 140;
      float ph = condTypes.length * 20 + 4;
      fill(32, 40, 52);
      stroke(85, 110, 140);
      rect(px, py, pw, ph, 4);
      noStroke();
      for (int i = 0; i < condTypes.length; i++) {
        fill(215);
        textSize(11);
        text(condTypes[i], px + 8, py + 5 + i * 20);
      }
    }
    if (actionTypePickerOpen) {
      float px = rightX + 124;
      float py = bodyY + bodyH - 34 - actionTypes.length * 20 - 4;
      float pw = 140;
      float ph = actionTypes.length * 20 + 4;
      fill(32, 40, 52);
      stroke(85, 110, 140);
      rect(px, py, pw, ph, 4);
      noStroke();
      for (int i = 0; i < actionTypes.length; i++) {
        fill(215);
        textSize(11);
        text(actionTypes[i], px + 8, py + 5 + i * 20);
      }
    }
  }

  void panel(float x, float y, float w, float h, String title) {
    noStroke();
    fill(20, 24, 31);
    rect(x, y, w, h, 5);
    fill(165, 190, 220);
    textSize(14);
    text(title, x + 8, y + 6);
  }

  void renderTriggerPanel(float x, float y, float w, float h) {
    float btnY = y + h - 34;
    drawBtn(x + 8, btnY, 54, 24, "+Trig");
    drawBtn(x + 66, btnY, 54, 24, "-Trig");
    drawBtn(x + 124, btnY, 54, 24, "Dup");
    drawBtn(x + 182, btnY, 98, 24, "Bundle");
    float yy = y + 28;
    ArrayList<EditorScriptTrigger> src = triggerSource();
    for (int i = 0; i < src.size() && i < 15; i++) {
      EditorScriptTrigger t = src.get(i);
      if (i == selectedTrigger) {
        fill(58, 80, 110);
        rect(x + 6, yy - 2, w - 12, 20, 4);
      }
      fill(230);
      textSize(13);
      text((i + 1) + ". " + t.id + "  p=" + t.priority + " cd=" + t.cooldownMs, x + 10, yy);
      yy += 20;
    }
    EditorScriptTrigger t = activeTrigger();
    if (t != null) {
      renderTriggerEditor(t, x + 8, y + h - 84, w - 16, 46);
    }
  }

  void renderTriggerEditor(EditorScriptTrigger t, float x, float y, float w, float h) {
    fill(24, 30, 38);
    rect(x, y - 4, w, h, 4);
    fill(150, 185, 210);
    textSize(12);
    text("cooldownMs:" + t.cooldownMs + "  priority:" + t.priority + "  preserve:" + t.preserve, x + 6, y + 2);
    drawBtn(x + 6, y + 22, 36, 18, "CD-");
    drawBtn(x + 46, y + 22, 36, 18, "CD+");
    drawBtn(x + 86, y + 22, 32, 18, "P-");
    drawBtn(x + 122, y + 22, 32, 18, "P+");
    drawBtn(x + 158, y + 22, 74, 18, "Preserve");
  }

  void renderConditionPanel(float x, float y, float w, float h) {
    EditorScriptTrigger t = activeTrigger();
    float btnY = y + h - 34;
    drawBtn(x + 8, btnY, 54, 24, "+Con");
    drawBtn(x + 66, btnY, 54, 24, "-Con");
    drawBtn(x + 124, btnY, 70, 24, "Type");
    if (t == null) return;
    float yy = y + 28;
    for (int i = 0; i < t.conditions.size() && i < 12; i++) {
      if (i == selectedCondition) {
        fill(58, 80, 110);
        rect(x + 6, yy - 2, w - 12, 20, 4);
      }
      fill(225);
      textSize(13);
      text((i + 1) + ". " + condSummary(t.conditions.get(i)), x + 10, yy);
      yy += 20;
    }
    EditorScriptCondition c = (selectedCondition >= 0 && selectedCondition < t.conditions.size()) ? t.conditions.get(selectedCondition) : null;
    if (c != null) renderConditionEditor(c, x + 8, y + h - 84, w - 16, 46);
  }

  void renderActionPanel(float x, float y, float w, float h) {
    EditorScriptTrigger t = activeTrigger();
    float btnY = y + h - 34;
    drawBtn(x + 8, btnY, 54, 24, "+Act");
    drawBtn(x + 66, btnY, 54, 24, "-Act");
    drawBtn(x + 124, btnY, 70, 24, "Type");
    if (t == null) return;
    float yy = y + 28;
    for (int i = 0; i < t.actions.size() && i < 12; i++) {
      if (i == selectedAction) {
        fill(58, 80, 110);
        rect(x + 6, yy - 2, w - 12, 20, 4);
      }
      fill(225);
      textSize(13);
      text((i + 1) + ". " + actionSummary(t.actions.get(i)), x + 10, yy);
      yy += 20;
    }
    EditorScriptAction a = (selectedAction >= 0 && selectedAction < t.actions.size()) ? t.actions.get(selectedAction) : null;
    if (a != null) renderActionEditor(a, x + 8, y + h - 84, w - 16, 46);
  }

  void renderConditionEditor(EditorScriptCondition c, float x, float y, float w, float h) {
    fill(24, 30, 38);
    rect(x, y - 4, w, h, 4);
    fill(150, 185, 210);
    textSize(12);
    String type = c.data.getString("type", "");
    if ("timeElapsed".equals(type)) text("seconds: " + nf(c.data.getFloat("seconds", 0), 1, 1), x + 6, y + 2);
    else if ("resourceAtLeast".equals(type)) text("credits: " + c.data.getInt("credits", 0) + "  faction:" + c.data.getString("faction", "player"), x + 6, y + 2);
    else if ("unitCountCmp".equals(type)) text("value: " + c.data.getInt("value", 0) + "  op:" + c.data.getString("op", ">=") + "  faction:" + c.data.getString("faction", "enemy"), x + 6, y + 2);
    else if ("buildingExists".equals(type)) text("building: " + c.data.getString("building", "base") + "  faction:" + c.data.getString("faction", "enemy"), x + 6, y + 2);
    else if ("switchIs".equals(type)) text("key: " + c.data.getString("key", "flag") + "  value:" + c.data.getBoolean("value", true), x + 6, y + 2);
    drawBtn(x + 6, y + 22, 30, 18, "-");
    drawBtn(x + 40, y + 22, 30, 18, "+");
    drawBtn(x + 74, y + 22, 58, 18, condToggleLabel(type));
  }

  void renderActionEditor(EditorScriptAction a, float x, float y, float w, float h) {
    fill(24, 30, 38);
    rect(x, y - 4, w, h, 4);
    fill(150, 185, 210);
    textSize(12);
    String type = a.data.getString("type", "");
    if ("spawnUnit".equals(type)) {
      text("count:" + a.data.getInt("count", 1) + " faction:" + a.data.getString("faction", "enemy")
        + " unit:" + a.data.getString("unit", "rifleman") + " pos:" + a.data.getString("positionMode", "nearFactionSpawn"), x + 6, y + 2);
      text("tile(" + a.data.getInt("tileX", 0) + "," + a.data.getInt("tileY", 0) + ") world(" + int(a.data.getFloat("worldX", 0)) + "," + int(a.data.getFloat("worldY", 0)) + ")", x + 6, y + 14);
    }
    else if ("grantResource".equals(type)) text("credits: " + a.data.getInt("credits", 0) + "  faction:" + a.data.getString("faction", "player"), x + 6, y + 2);
    else if ("setSwitch".equals(type)) text("key: " + a.data.getString("key", "flag") + "  value:" + a.data.getBoolean("value", true), x + 6, y + 2);
    else if ("showMessage".equals(type)) text("message: " + a.data.getString("message", ""), x + 6, y + 2);
    else if ("issueAttackWave".equals(type)) text("count: " + a.data.getInt("count", 6) + "  faction:" + a.data.getString("faction", "enemy"), x + 6, y + 2);
    else if ("winOrLose".equals(type)) text("result: " + a.data.getString("result", "VICTORY"), x + 6, y + 2);
    drawBtn(x + 6, y + 22, 30, 18, "-");
    drawBtn(x + 40, y + 22, 30, 18, "+");
    drawBtn(x + 74, y + 22, 58, 18, actionToggleLabel(type));
  }

  String condToggleLabel(String type) {
    if ("switchIs".equals(type) || "buildingExists".equals(type)) return "Bool";
    if ("unitCountCmp".equals(type)) return "Cycle";
    return "Apply";
  }

  String actionToggleLabel(String type) {
    if ("spawnUnit".equals(type)) {
      String[] f = new String[] { "Count", "Faction", "Unit", "Pos", "X", "Y" };
      return f[constrain(spawnUnitEditField, 0, f.length - 1)];
    }
    if ("setSwitch".equals(type)) return "Bool";
    if ("winOrLose".equals(type)) return "Cycle";
    if ("showMessage".equals(type)) return "Preset";
    return "Apply";
  }

  void drawBtn(float x, float y, float w, float h, String t) {
    fill(55, 75, 98);
    rect(x, y, w, h, 3);
    fill(235);
    textSize(12);
    textAlign(CENTER, CENTER);
    text(t, x + w * 0.5f, y + h * 0.52f);
    textAlign(LEFT, TOP);
  }

  boolean onMousePressed(int mx, int my, int button) {
    if (!visible) return false;
    if (button != LEFT) return true;
    float x = 70;
    float y = 52;
    float w = width - 140;
    float h = height - 104;
    if (!hit(x, y, w, h, mx, my)) {
      if (bundleEditMode && !tryExitBundleEdit()) return true;
      closeDialog();
      return true;
    }
    float bodyY = y + 58;
    float bodyH = h - 70;
    float leftW = w * 0.27;
    float midW = w * 0.34;
    float rightW = w - leftW - midW - 24;
    float leftX = x + 10;
    float midX = leftX + leftW + 8;
    float rightX = midX + midW + 8;

    if (bundleEditMode && hit(x + w - 280, y + 8, 76, 28, mx, my)) {
      saveCurrentBundleEdits();
      return true;
    }
    if (bundleEditMode && hit(x + w - 198, y + 8, 76, 28, mx, my)) {
      tryExitBundleEdit();
      return true;
    }

    if (hit(x + 360, y + 8, 130, 28, mx, my)) {
      activeTab = 0;
      return true;
    }
    if (hit(x + 496, y + 8, 130, 28, mx, my)) {
      activeTab = 1;
      return true;
    }

    if (activeTab == 1) {
      return handleBundleClick(leftX, bodyY, w - 20, bodyH, mx, my);
    }

    if (handleTypePickerClick(mx, my, midX, rightX, bodyY, bodyH)) {
      return true;
    }
    if (hit(leftX + 8, bodyY + bodyH - 34, 54, 24, mx, my)) {
      ui.mutationWillHappen();
      EditorScriptTrigger t = new EditorScriptTrigger();
      t.id = "trigger_" + (s.scriptTriggers.size() + 1);
      t.cooldownMs = 5000;
      t.conditions.add(createDefaultCondition());
      t.actions.add(createDefaultAction());
      ArrayList<EditorScriptTrigger> src = triggerSource();
      t.id = "trigger_" + (src.size() + 1);
      src.add(t);
      markBundleDirtyIfEditing();
      selectedTrigger = src.size() - 1;
      selectedCondition = 0;
      selectedAction = 0;
      return true;
    }
    if (hit(leftX + 66, bodyY + bodyH - 34, 54, 24, mx, my)) {
      ArrayList<EditorScriptTrigger> src = triggerSource();
      if (selectedTrigger >= 0 && selectedTrigger < src.size()) {
        ui.mutationWillHappen();
        src.remove(selectedTrigger);
        markBundleDirtyIfEditing();
        clampSelection();
      }
      return true;
    }
    if (hit(leftX + 124, bodyY + bodyH - 34, 54, 24, mx, my)) {
      EditorScriptTrigger t = activeTrigger();
      if (t != null) {
        ui.mutationWillHappen();
        EditorScriptTrigger cp = t.copy();
        cp.id = cp.id + "_copy";
        s.scriptTriggers.add(cp);
        markBundleDirtyIfEditing();
        selectedTrigger = s.scriptTriggers.size() - 1;
        clampSelection();
      }
      return true;
    }
    if (hit(leftX + 182, bodyY + bodyH - 34, 98, 24, mx, my)) return true;
    if (tweakTriggerByClick(leftX + 8, bodyY + bodyH - 84, mx, my)) {
      return true;
    }
    if (mx >= leftX + 6 && mx <= leftX + leftW - 6 && my >= bodyY + 26 && my < bodyY + bodyH - 36) {
      int idx = (int)((my - (bodyY + 28)) / 20.0);
      ArrayList<EditorScriptTrigger> src = triggerSource();
      if (idx >= 0 && idx < src.size()) {
        selectedTrigger = idx;
        selectedCondition = 0;
        selectedAction = 0;
      }
      return true;
    }

    EditorScriptTrigger t = activeTrigger();
    if (t == null) return true;
    if (hit(midX + 8, bodyY + bodyH - 34, 54, 24, mx, my)) {
      ui.mutationWillHappen();
      t.conditions.add(createDefaultCondition());
      markBundleDirtyIfEditing();
      selectedCondition = t.conditions.size() - 1;
      return true;
    }
    if (hit(midX + 66, bodyY + bodyH - 34, 54, 24, mx, my)) {
      if (selectedCondition >= 0 && selectedCondition < t.conditions.size()) {
        ui.mutationWillHappen();
        t.conditions.remove(selectedCondition);
        markBundleDirtyIfEditing();
        clampSelection();
      }
      return true;
    }
    if (hit(midX + 124, bodyY + bodyH - 34, 70, 24, mx, my)) {
      if (selectedCondition >= 0 && selectedCondition < t.conditions.size()) {
        condTypePickerOpen = !condTypePickerOpen;
        actionTypePickerOpen = false;
      }
      return true;
    }
    if (tweakSelectedByClick(midX + 8, rightX + 8, bodyY + bodyH - 84, mx, my)) {
      return true;
    }
    if (mx >= midX + 6 && mx <= midX + midW - 6 && my >= bodyY + 26 && my < bodyY + bodyH - 36) {
      int idx = (int)((my - (bodyY + 28)) / 20.0);
      if (idx >= 0 && idx < t.conditions.size()) selectedCondition = idx;
      return true;
    }

    if (hit(rightX + 8, bodyY + bodyH - 34, 54, 24, mx, my)) {
      ui.mutationWillHappen();
      t.actions.add(createDefaultAction());
      markBundleDirtyIfEditing();
      selectedAction = t.actions.size() - 1;
      return true;
    }
    if (hit(rightX + 66, bodyY + bodyH - 34, 54, 24, mx, my)) {
      if (selectedAction >= 0 && selectedAction < t.actions.size()) {
        ui.mutationWillHappen();
        t.actions.remove(selectedAction);
        markBundleDirtyIfEditing();
        clampSelection();
      }
      return true;
    }
    if (hit(rightX + 124, bodyY + bodyH - 34, 70, 24, mx, my)) {
      if (selectedAction >= 0 && selectedAction < t.actions.size()) {
        actionTypePickerOpen = !actionTypePickerOpen;
        condTypePickerOpen = false;
      }
      return true;
    }
    if (tweakSelectedByClick(midX + 8, rightX + 8, bodyY + bodyH - 84, mx, my)) {
      return true;
    }
    if (mx >= rightX + 6 && mx <= rightX + rightW - 6 && my >= bodyY + 26 && my < bodyY + bodyH - 36) {
      int idx = (int)((my - (bodyY + 28)) / 20.0);
      if (idx >= 0 && idx < t.actions.size()) selectedAction = idx;
      return true;
    }
    condTypePickerOpen = false;
    actionTypePickerOpen = false;
    return true;
  }

  boolean tweakTriggerByClick(float trigEditX, float editY, int mx, int my) {
    EditorScriptTrigger t = activeTrigger();
    if (t == null) return false;
    boolean cdMinusHit = hit(trigEditX + 6, editY + 22, 36, 18, mx, my);
    boolean cdPlusHit = hit(trigEditX + 46, editY + 22, 36, 18, mx, my);
    boolean pMinusHit = hit(trigEditX + 86, editY + 22, 32, 18, mx, my);
    boolean pPlusHit = hit(trigEditX + 122, editY + 22, 32, 18, mx, my);
    boolean preserveHit = hit(trigEditX + 158, editY + 22, 74, 18, mx, my);
    if (!(cdMinusHit || cdPlusHit || pMinusHit || pPlusHit || preserveHit)) return false;
    ui.mutationWillHappen();
    if (cdMinusHit) t.cooldownMs = max(0, t.cooldownMs - 500);
    else if (cdPlusHit) t.cooldownMs += 500;
    else if (pMinusHit) t.priority -= 10;
    else if (pPlusHit) t.priority += 10;
    else if (preserveHit) {
      t.preserve = !t.preserve;
    }
    markBundleDirtyIfEditing();
    return true;
  }

  boolean tweakSelectedByClick(float condEditX, float actEditX, float editY, int mx, int my) {
    EditorScriptTrigger t = activeTrigger();
    if (t == null) return false;
    boolean changed = false;
    if (selectedCondition >= 0 && selectedCondition < t.conditions.size()) {
      EditorScriptCondition c = t.conditions.get(selectedCondition);
      String type = c.data.getString("type", "");
      boolean minusHit = hit(condEditX + 6, editY + 22, 30, 18, mx, my);
      boolean plusHit = hit(condEditX + 40, editY + 22, 30, 18, mx, my);
      boolean toggleHit = hit(condEditX + 74, editY + 22, 58, 18, mx, my);
      if (minusHit || plusHit || toggleHit) {
        ui.mutationWillHappen();
        int sgn = minusHit ? -1 : 1;
        if ("timeElapsed".equals(type)) c.data.setFloat("seconds", max(0, c.data.getFloat("seconds", 0) + sgn * 5));
        else if ("resourceAtLeast".equals(type)) c.data.setInt("credits", max(0, c.data.getInt("credits", 0) + sgn * 50));
        else if ("unitCountCmp".equals(type)) c.data.setInt("value", max(0, c.data.getInt("value", 0) + sgn));
        else if ("buildingExists".equals(type) && toggleHit) c.data.setString("faction", "player".equals(c.data.getString("faction", "enemy")) ? "enemy" : "player");
        else if ("switchIs".equals(type) && toggleHit) c.data.setBoolean("value", !c.data.getBoolean("value", true));
        changed = true;
        markBundleDirtyIfEditing();
      }
    }
    if (selectedAction >= 0 && selectedAction < t.actions.size()) {
      EditorScriptAction a = t.actions.get(selectedAction);
      String type = a.data.getString("type", "");
      boolean minusHit = hit(actEditX + 6, editY + 22, 30, 18, mx, my);
      boolean plusHit = hit(actEditX + 40, editY + 22, 30, 18, mx, my);
      boolean toggleHit = hit(actEditX + 74, editY + 22, 58, 18, mx, my);
      if (minusHit || plusHit || toggleHit) {
        ui.mutationWillHappen();
        int sgn = minusHit ? -1 : 1;
        if ("spawnUnit".equals(type)) {
          if (toggleHit) {
            spawnUnitEditField = (spawnUnitEditField + 1) % 6;
          } else if (spawnUnitEditField == 0) {
            a.data.setInt("count", max(1, a.data.getInt("count", 1) + sgn));
          } else if (spawnUnitEditField == 1) {
            a.data.setString("faction", "player".equals(a.data.getString("faction", "enemy")) ? "enemy" : "player");
          } else if (spawnUnitEditField == 2) {
            int idx = max(0, s.unitIds.indexOf(a.data.getString("unit", "rifleman")));
            if (s.unitIds.size() > 0) {
              idx = (idx + (sgn > 0 ? 1 : -1) + s.unitIds.size()) % s.unitIds.size();
              a.data.setString("unit", s.unitIds.get(idx));
            }
          } else if (spawnUnitEditField == 3) {
            String[] modes = new String[] { "nearFactionSpawn", "tilePoint", "worldPoint" };
            int midx = 0;
            String current = a.data.getString("positionMode", "nearFactionSpawn");
            for (int i = 0; i < modes.length; i++) if (modes[i].equals(current)) midx = i;
            midx = (midx + (sgn > 0 ? 1 : -1) + modes.length) % modes.length;
            a.data.setString("positionMode", modes[midx]);
          } else if (spawnUnitEditField == 4) {
            if ("worldPoint".equals(a.data.getString("positionMode", "nearFactionSpawn"))) a.data.setFloat("worldX", max(0, a.data.getFloat("worldX", 0) + sgn * 40));
            else a.data.setInt("tileX", max(0, a.data.getInt("tileX", 0) + sgn));
          } else if (spawnUnitEditField == 5) {
            if ("worldPoint".equals(a.data.getString("positionMode", "nearFactionSpawn"))) a.data.setFloat("worldY", max(0, a.data.getFloat("worldY", 0) + sgn * 40));
            else a.data.setInt("tileY", max(0, a.data.getInt("tileY", 0) + sgn));
          }
        } else if ("issueAttackWave".equals(type)) a.data.setInt("count", max(1, a.data.getInt("count", 1) + sgn));
        else if ("grantResource".equals(type)) a.data.setInt("credits", max(0, a.data.getInt("credits", 0) + sgn * 100));
        else if ("setSwitch".equals(type) && toggleHit) a.data.setBoolean("value", !a.data.getBoolean("value", true));
        else if ("showMessage".equals(type) && toggleHit) {
          String old = a.data.getString("message", "Script message");
          a.data.setString("message", old.endsWith("!") ? "Script message" : old + "!");
        } else if ("winOrLose".equals(type) && toggleHit) {
          String r = a.data.getString("result", "VICTORY");
          if ("VICTORY".equals(r)) r = "DEFEAT";
          else if ("DEFEAT".equals(r)) r = "DRAW";
          else r = "VICTORY";
          a.data.setString("result", r);
        }
        changed = true;
        markBundleDirtyIfEditing();
      }
    }
    return changed;
  }

  boolean handleBundleClick(float x, float y, float w, float h, int mx, int my) {
    float btnY = y + h - 34;
    if (hit(x + 8, btnY, 52, 24, mx, my)) {
      ui.mutationWillHappen();
      EditorScriptBundleBinding b = new EditorScriptBundleBinding();
      b.id = "bundle_" + (s.scriptBundles.size() + 1);
      b.name = b.id;
      b.path = "default_battle";
      s.scriptBundles.add(b);
      selectedBundle = s.scriptBundles.size() - 1;
      return true;
    }
    if (hit(x + 64, btnY, 52, 24, mx, my)) {
      if (selectedBundle >= 0 && selectedBundle < s.scriptBundles.size()) {
        ui.mutationWillHappen();
        s.scriptBundles.remove(selectedBundle);
        clampSelection();
      }
      return true;
    }
    if (mx >= x + 6 && mx <= x + w - 6 && my >= y + 26 && my < y + h - 36) {
      int idx = (int)((my - (y + 28)) / 20.0);
      if (idx >= 0 && idx < s.scriptBundles.size()) {
        selectedBundle = idx;
        int now = millis();
        if (lastBundleClickIndex == idx && now - lastBundleClickAtMs <= 350) {
          openBundleEditor(s.scriptBundles.get(idx));
          lastBundleClickIndex = -1;
          lastBundleClickAtMs = -999999;
          return true;
        }
        lastBundleClickIndex = idx;
        lastBundleClickAtMs = now;
      }
    }
    if (selectedBundle < 0 || selectedBundle >= s.scriptBundles.size()) return true;
    EditorScriptBundleBinding b = s.scriptBundles.get(selectedBundle);
    if (hit(x + 120, btnY, 72, 24, mx, my)) {
      ui.mutationWillHappen();
      if ("default_battle".equals(b.path)) b.path = "spawn_player_rifle_5s";
      else if ("spawn_player_rifle_5s".equals(b.path)) b.path = "custom_bundle";
      else b.path = "default_battle";
      if (b.id.length() <= 0) b.id = b.path;
      return true;
    }
    if (hit(x + 196, btnY, 72, 24, mx, my)) {
      ui.mutationWillHappen();
      b.name = b.path + "_name";
      return true;
    }
    if (hit(x + 272, btnY, 72, 24, mx, my)) {
      ui.mutationWillHappen();
      b.enabled = !b.enabled;
      return true;
    }
    if (hit(x + 348, btnY, 72, 24, mx, my)) {
      ui.mutationWillHappen();
      b.priority += 10;
      if (b.priority > 1000) b.priority = 0;
      return true;
    }
    return true;
  }

  void openBundleEditor(EditorScriptBundleBinding b) {
    if (b == null) return;
    String path = trim(b.path == null || b.path.length() <= 0 ? b.id : b.path);
    if (path.length() <= 0) {
      s.setStatus("Bundle path/id empty.");
      return;
    }
    JSONObject root = loadJSONObject(sketchPath("../RTS_p5/data/scripts/triggers/" + path + ".json"));
    if (root == null) {
      s.setStatus("Bundle file not found: " + path + ".json");
      return;
    }
    JSONArray arr = root.getJSONArray("triggers");
    bundleEditTriggers.clear();
    if (arr != null) {
      for (int i = 0; i < arr.size(); i++) {
        JSONObject trigObj = arr.getJSONObject(i);
        if (trigObj == null) continue;
        EditorScriptTrigger t = new EditorScriptTrigger();
        t.id = trigObj.getString("id", "trigger_" + (i + 1));
        t.preserve = trigObj.getBoolean("preserve", true);
        t.cooldownMs = max(0, trigObj.getInt("cooldownMs", 0));
        t.priority = trigObj.getInt("priority", 0);
        t.conditions.clear();
        t.actions.clear();
        JSONArray conds = trigObj.getJSONArray("conditions");
        if (conds != null) {
          for (int ci = 0; ci < conds.size(); ci++) {
            JSONObject c = conds.getJSONObject(ci);
            if (c == null) continue;
            JSONObject cp = parseJSONObject(c.toString());
            if (cp == null) cp = new JSONObject();
            t.conditions.add(new EditorScriptCondition(cp));
          }
        }
        JSONArray acts = trigObj.getJSONArray("actions");
        if (acts != null) {
          for (int ai = 0; ai < acts.size(); ai++) {
            JSONObject a = acts.getJSONObject(ai);
            if (a == null) continue;
            JSONObject ap = parseJSONObject(a.toString());
            if (ap == null) ap = new JSONObject();
            t.actions.add(new EditorScriptAction(ap));
          }
        }
        bundleEditTriggers.add(t);
      }
    }
    editingBundlePath = path;
    editingBundleName = b.name == null ? "" : b.name;
    bundleEditMode = true;
    bundleEditDirty = false;
    bundleExitArmed = false;
    activeTab = 0;
    selectedTrigger = bundleEditTriggers.size() > 0 ? 0 : -1;
    selectedCondition = 0;
    selectedAction = 0;
    s.setStatus("Editing scriptbundle: " + path);
  }

  void saveCurrentBundleEdits() {
    if (!bundleEditMode || editingBundlePath.length() <= 0) return;
    if (!validateTriggerList(bundleEditTriggers)) {
      return;
    }
    JSONObject out = new JSONObject();
    JSONArray arr = new JSONArray();
    for (EditorScriptTrigger t : bundleEditTriggers) {
      JSONObject o = new JSONObject();
      o.setString("id", t.id == null ? "" : t.id);
      o.setBoolean("preserve", t.preserve);
      o.setInt("cooldownMs", max(0, t.cooldownMs));
      o.setInt("priority", t.priority);
      JSONArray conds = new JSONArray();
      for (EditorScriptCondition c : t.conditions) {
        JSONObject cp = parseJSONObject(c.data == null ? "{}" : c.data.toString());
        if (cp == null) cp = new JSONObject();
        conds.append(cp);
      }
      JSONArray acts = new JSONArray();
      for (EditorScriptAction a : t.actions) {
        JSONObject ap = parseJSONObject(a.data == null ? "{}" : a.data.toString());
        if (ap == null) ap = new JSONObject();
        acts.append(ap);
      }
      o.setJSONArray("conditions", conds);
      o.setJSONArray("actions", acts);
      arr.append(o);
    }
    out.setJSONArray("triggers", arr);
    saveJSONObject(out, sketchPath("../RTS_p5/data/scripts/triggers/" + editingBundlePath + ".json"));
    bundleEditDirty = false;
    bundleExitArmed = false;
    s.setStatus("Saved scriptbundle: " + editingBundlePath + ".json");
  }

  boolean validateTriggerList(ArrayList<EditorScriptTrigger> list) {
    ArrayList<String> ids = new ArrayList<String>();
    for (int i = 0; i < list.size(); i++) {
      EditorScriptTrigger t = list.get(i);
      String id = t.id == null ? "" : trim(t.id);
      if (id.length() <= 0) {
        s.setStatus("Save blocked: bundle trigger #" + (i + 1) + " missing id.");
        return false;
      }
      if (ids.contains(id)) {
        s.setStatus("Save blocked: duplicated trigger id " + id);
        return false;
      }
      ids.add(id);
      if (t.conditions.size() <= 0 || t.actions.size() <= 0) {
        s.setStatus("Save blocked: trigger " + id + " missing condition/action.");
        return false;
      }
    }
    return true;
  }

  boolean handleTypePickerClick(int mx, int my, float midX, float rightX, float bodyY, float bodyH) {
    EditorScriptTrigger t = activeTrigger();
    if (condTypePickerOpen) {
      float px = midX + 124;
      float py = bodyY + bodyH - 34 - condTypes.length * 20 - 4;
      if (hit(px, py, 140, condTypes.length * 20 + 4, mx, my)) {
        int idx = (int)((my - (py + 2)) / 20.0);
        if (idx >= 0 && idx < condTypes.length && t != null && selectedCondition >= 0 && selectedCondition < t.conditions.size()) {
          ui.mutationWillHappen();
          resetConditionDefaults(t.conditions.get(selectedCondition), condTypes[idx]);
        }
        condTypePickerOpen = false;
        return true;
      }
      condTypePickerOpen = false;
    }
    if (actionTypePickerOpen) {
      float px = rightX + 124;
      float py = bodyY + bodyH - 34 - actionTypes.length * 20 - 4;
      if (hit(px, py, 140, actionTypes.length * 20 + 4, mx, my)) {
        int idx = (int)((my - (py + 2)) / 20.0);
        if (idx >= 0 && idx < actionTypes.length && t != null && selectedAction >= 0 && selectedAction < t.actions.size()) {
          ui.mutationWillHappen();
          resetActionDefaults(t.actions.get(selectedAction), actionTypes[idx]);
        }
        actionTypePickerOpen = false;
        return true;
      }
      actionTypePickerOpen = false;
    }
    return false;
  }

  boolean onKeyPressed(char k, int keyCode) {
    if (!visible) return false;
    boolean ctrl = keyEvent != null && keyEvent.isControlDown();
    if (bundleEditMode && ctrl && (keyCode == java.awt.event.KeyEvent.VK_S)) {
      saveCurrentBundleEdits();
      return true;
    }
    if (bundleEditMode && (k == 's' || k == 'S')) {
      saveCurrentBundleEdits();
      return true;
    }
    if (keyCode == ESC) {
      key = 0;
      if (bundleEditMode && !tryExitBundleEdit()) return true;
      if (!bundleEditMode) {
        closeDialog();
      }
      return true;
    }
    return true;
  }
}
