class InputSystem {
  GameState state;
  boolean draggingSelect = false;
  boolean draggingMinimap = false;
  PVector dragStart = new PVector();
  PVector dragEnd = new PVector();
  int lastSelectClickMs = -10000;
  String lastSelectUnitType = "";
  static final int DOUBLE_CLICK_MS = 280;

  InputSystem(GameState state) {
    this.state = state;
  }

  void update(float dt) {
    if (state.map == null) {
      return;
    }
    if (state.hardCursorLock && state.cursorLock != null) {
      state.cursorLock.keepInsideWindow(surface, state.screenW, state.screenH, focused);
    }
    int clampedMouseX = constrain(mouseX, 0, state.screenW - 1);
    int clampedMouseY = constrain(mouseY, 0, state.screenH - 1);

    PVector w = state.camera.screenToWorld(clampedMouseX, clampedMouseY);
    state.buildSystem.updatePreview(w, state.map);

    state.camera.update(dt, clampedMouseX, clampedMouseY, state.screenW, state.screenH, true);
  }

  void onMousePressed(int mx, int my, int button) {
    if (state.gameEnded) {
      state.handleGameEndOverlayClick(mx, my, button);
      return;
    }
    if (button == LEFT && mx >= state.worldViewW) {
      if (state.ui.beginClick(state, mx, my)) {
        return;
      }
    }
    if (button == LEFT && state.ui.minimap.contains(mx, my)) {
      PVector world = state.ui.minimap.minimapToWorld(mx, my, state.map);
      if (state.attackMoveArmed && state.selectedUnits.size() > 0) {
        boolean queue = isShiftDown();
        state.issueAttackMoveCommand(world, queue);
        return;
      }
      state.camera.jumpCenterTo(world.x, world.y);
      draggingMinimap = true;
      return;
    }
    if (button == RIGHT && state.ui.minimap.contains(mx, my)) {
      PVector miniWorld = state.ui.minimap.minimapToWorld(mx, my, state.map);
      boolean queue = isShiftDown();
      if (state.selectedUnits.size() == 0 && state.selectedBuilding != null && state.selectedStructureOffersTrainMenu()) {
        state.setSelectedBuildingRally(miniWorld);
      } else if (state.selectedUnits.size() > 0) {
        if (state.attackMoveArmed) {
          state.issueAttackMoveCommand(miniWorld, queue);
        } else {
          state.issueMoveCommand(miniWorld, queue);
        }
      }
      return;
    }
    if (button == RIGHT && mx >= state.worldViewW) {
      if (state.ui.handleRightClickQueueCancel(state, mx, my)) {
        return;
      }
    }

    if (mx >= state.worldViewW) {
      return;
    }

    PVector world = state.camera.screenToWorld(mx, my);
    if (button == LEFT) {
      if (state.attackMoveArmed) {
        state.issueAttackMoveCommand(world, false);
        return;
      }
      if (state.buildSystem.active) {
        if (!state.canPlaceSelectedBuildInExploredArea()) {
          state.buildSystem.lastFailReason = tr("ui.buildUnexplored");
          return;
        }
        boolean ok = state.buildSystem.queueBuildIfValid(state.map, state.buildings, state.activeFaction, state.resources);
        if (ok) {
          state.cancelBuildPlacement();
          state.orderLabel = tr("order.buildPlaced");
        }
        return;
      }
      draggingSelect = true;
      dragStart.set(world);
      dragEnd.set(world);
    } else if (button == RIGHT) {
      if (state.buildSystem.active) {
        state.cancelBuildPlacement();
        return;
      }
      if (state.selectedUnits.size() == 0 && state.selectedBuilding != null && state.selectedStructureOffersTrainMenu()) {
        state.setSelectedBuildingRally(world);
        return;
      }
      if (state.selectedUnits.size() == 0) {
        state.orderLabel = tr("order.noSelection");
        return;
      }
      boolean queue = isShiftDown();
      if (state.issueHarvestOrderToSelectedMiners(world)) {
        return;
      }
      Unit target = state.findNearestUnitAt(world, 24);
      if (target != null && target.faction != state.activeFaction && state.selectedUnits.size() > 0) {
        state.issueAttackUnitCommand(target);
      } else {
        Building bt = state.findNearestBuildingAt(world, 18, true);
        if (bt != null && bt.faction != state.activeFaction) {
          state.issueAttackBuildingCommand(bt);
          return;
        }
        if (state.attackMoveArmed) {
          state.issueAttackMoveCommand(world, queue);
        } else {
          state.issueMoveCommand(world, queue);
        }
      }
    }
  }

  void onMouseDragged(int mx, int my, int button) {
    if (draggingMinimap && button == LEFT) {
      int clampedX = constrain(mx, state.ui.minimap.x, state.ui.minimap.x + state.ui.minimap.w);
      int clampedY = constrain(my, state.ui.minimap.y, state.ui.minimap.y + state.ui.minimap.h);
      PVector world = state.ui.minimap.minimapToWorld(clampedX, clampedY, state.map);
      state.camera.jumpCenterTo(world.x, world.y);
      return;
    }
    if (!draggingSelect || button != LEFT) {
      return;
    }
    dragEnd.set(state.camera.screenToWorld(mx, my));
  }

  void onMouseReleased(int mx, int my, int button) {
    if (button == LEFT) {
      if (state.ui.endClick(state, mx, my)) {
        state.ui.releaseBuildButtonPress();
        return;
      }
      state.ui.releaseBuildButtonPress();
    }
    if (button == LEFT && draggingMinimap) {
      draggingMinimap = false;
      return;
    }
    if (button != LEFT || !draggingSelect) {
      return;
    }
    draggingSelect = false;
    dragEnd.set(state.camera.screenToWorld(mx, my));
    float minX = min(dragStart.x, dragEnd.x);
    float minY = min(dragStart.y, dragEnd.y);
    float maxX = max(dragStart.x, dragEnd.x);
    float maxY = max(dragStart.y, dragEnd.y);

    boolean isClick = abs(maxX - minX) < 6 && abs(maxY - minY) < 6;
    if (isClick) {
      boolean shift = isShiftDown();
      Unit best = null;
      float bestD = 1e9;
      for (Unit u : state.units) {
        float d = dist(u.pos.x, u.pos.y, dragEnd.x, dragEnd.y);
        if (u.faction == state.activeFaction && d <= u.radius + 8 && d < bestD) {
          bestD = d;
          best = u;
        }
      }
      if (best != null) {
        if (shift) {
          if (state.editingControlGroup >= 0) {
            int groupEdit = state.toggleUnitInEditingControlGroup(best);
            if (groupEdit < 0) {
              best.selected = false;
              state.selectedUnits.remove(best);
              state.orderLabel = tr("order.groupMemberRemoved");
            } else if (groupEdit > 0) {
              if (!best.selected) {
                best.selected = true;
                if (!state.selectedUnits.contains(best)) {
                  state.selectedUnits.add(best);
                }
              }
              state.orderLabel = tr("order.groupMemberAdded");
            }
          } else {
            if (best.selected) {
              best.selected = false;
              state.selectedUnits.remove(best);
            } else {
              best.selected = true;
              if (!state.selectedUnits.contains(best)) {
                state.selectedUnits.add(best);
              }
            }
          }
          return;
        }
        state.clearSelection();
        int now = millis();
        boolean isDouble = now - lastSelectClickMs <= DOUBLE_CLICK_MS && best.unitType.equals(lastSelectUnitType);
        if (isDouble) {
          selectAllVisibleSameType(best.unitType);
        } else {
          best.selected = true;
          state.selectedUnits.add(best);
        }
        lastSelectClickMs = now;
        lastSelectUnitType = best.unitType;
        return;
      }
      state.clearSelection();
      Building bb = state.findNearestBuildingAt(dragEnd, 10, true);
      if (bb != null && bb.faction == state.activeFaction) {
        bb.selected = true;
        state.selectedBuilding = bb;
      }
      return;
    }
    state.clearSelection();
    ArrayList<Unit> miners = new ArrayList<Unit>();
    ArrayList<Unit> others = new ArrayList<Unit>();
    for (Unit u : state.units) {
      boolean inBox = u.pos.x >= minX && u.pos.x <= maxX && u.pos.y >= minY && u.pos.y <= maxY;
      if (inBox && u.faction == state.activeFaction) {
        if ("miner".equals(u.unitType)) {
          miners.add(u);
        } else {
          others.add(u);
        }
      }
    }
    // 预判选择策略：有非矿工就优先非矿工；否则选矿工。
    ArrayList<Unit> pick = others.size() > 0 ? others : miners;
    for (Unit u : pick) {
      u.selected = true;
      state.selectedUnits.add(u);
    }
  }

  void onKeyPressed(char key, int keyCode) {
    if (state.gameEnded) {
      return;
    }
    if (state.map == null) {
      return;
    }
    if (key >= '0' && key <= '9') {
      int groupNo = int(key - '0');
      if (isCtrlDown()) {
        int count = state.assignSelectionToControlGroup(groupNo);
        state.orderLabel = tr("order.groupSaved") + " #" + groupNo + " (" + count + ")";
      } else {
        int count = state.recallControlGroup(groupNo);
        if (count > 0) {
          state.orderLabel = tr("order.groupRecalled") + " #" + groupNo + " (" + count + ")";
        } else {
          state.orderLabel = tr("order.groupEmpty") + " #" + groupNo;
        }
      }
      return;
    }
    if (key == 'q' || key == 'Q') {
      state.tryTrainHotkey(0);
      return;
    }
    if (key == 'w' || key == 'W') {
      state.tryTrainHotkey(1);
      return;
    }
    if (key == 'e' || key == 'E') {
      state.tryTrainHotkey(2);
      return;
    }
    if (key == 'a' || key == 'A') {
      state.setAttackMoveArmed(!state.attackMoveArmed);
      return;
    }
    if (key == 'l' || key == 'L') {
      state.hardCursorLock = !state.hardCursorLock;
      state.orderLabel = state.hardCursorLock ? tr("order.cursorLockOn") : tr("order.cursorLockOff");
      return;
    }
    if (key == 'p' || key == 'P') {
      state.debugShowPaths = !state.debugShowPaths;
      state.orderLabel = state.debugShowPaths ? tr("order.debugOn") : tr("order.debugOff");
      return;
    }
    if (keyCode == DELETE) {
      if (!state.buildSystem.active) {
        state.trySellSelectedBuilding();
      }
      return;
    }
  }

  void onMouseWheel(float amount, int mx, int my) {
    if ( state.map == null || state.camera == null) {
      return;
    }
    if (mx >= state.worldViewW) {
      if (state.ui.onMouseWheel(amount, mx, my)) {
        return;
      }
    }
    if (mx >= state.worldViewW) {
      return;
    }
    int clampedX = constrain(mx, 0, state.worldViewW - 1);
    int clampedY = constrain(my, 0, state.screenH - 1);
    state.camera.zoomAt(amount, clampedX, clampedY);
  }

  boolean isCtrlDown() {
    if (keyEvent != null && keyEvent.isControlDown()) {
      return true;
    }
    return keyPressed && keyCode == CONTROL;
  }

  boolean isShiftDown() {
    if (keyEvent != null && keyEvent.isShiftDown()) {
      return true;
    }
    return keyPressed && keyCode == SHIFT;
  }

  void renderSelectionBox() {
    if (!draggingSelect) {
      return;
    }
    PVector s0 = state.camera.worldToScreen(dragStart.x, dragStart.y);
    PVector s1 = state.camera.worldToScreen(dragEnd.x, dragEnd.y);
    noFill();
    stroke(120, 255, 120);
    rect(min(s0.x, s1.x), min(s0.y, s1.y), abs(s1.x - s0.x), abs(s1.y - s0.y));
  }

  void selectAllVisibleSameType(String unitType) {
    if (unitType == null || unitType.length() == 0) {
      return;
    }
    state.clearSelection();
    for (Unit u : state.units) {
      if (u.hp <= 0 || u.faction != state.activeFaction) {
        continue;
      }
      if (!unitType.equals(u.unitType)) {
        continue;
      }
      PVector s = state.camera.worldToScreen(u.pos.x, u.pos.y);
      if (s.x < 0 || s.x > state.worldViewW || s.y < 0 || s.y > state.screenH) {
        continue;
      }
      u.selected = true;
      state.selectedUnits.add(u);
    }
  }
}
