class InputSystem {
  GameState state;
  boolean draggingSelect = false;
  boolean draggingMinimap = false;
  PVector dragStart = new PVector();
  PVector dragEnd = new PVector();

  InputSystem(GameState state) {
    this.state = state;
  }

  void update(float dt) {
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
      return;
    }
    if (button == LEFT && mx >= state.worldViewW) {
      if (state.ui.handleClick(state, mx, my)) {
        return;
      }
    }

    if (button == LEFT && state.ui.minimap.contains(mx, my)) {
      PVector world = state.ui.minimap.minimapToWorld(mx, my, state.map);
      state.camera.jumpCenterTo(world.x, world.y);
      draggingMinimap = true;
      return;
    }

    if (mx >= state.worldViewW) {
      return;
    }

    PVector world = state.camera.screenToWorld(mx, my);
    if (button == LEFT) {
      if (state.attackMoveArmed) {
        state.commandSystem.attackMoveSelected(state, state.selectedUnits, world, false);
        state.orderLabel = "AttackMove";
        state.addOrderMarker(world, true);
        state.attackMoveArmed = false;
        return;
      }
      if (state.buildSystem.active) {
        boolean ok = state.buildSystem.queueBuildIfValid(state.map, state.buildings, state.activeFaction, state.resources);
        if (ok) {
          state.buildSystem.active = false;
          state.ui.clearBuildButtonState();
          state.orderLabel = "BuildPlaced";
        }
        return;
      }
      draggingSelect = true;
      dragStart.set(world);
      dragEnd.set(world);
    } else if (button == RIGHT) {
      if (state.buildSystem.active) {
        state.buildSystem.active = false;
        state.buildSystem.lastFailReason = "";
        state.ui.clearBuildButtonState();
        state.orderLabel = "BuildPlace(Cancel)";
        return;
      }
      if (state.selectedUnits.size() == 0) {
        state.orderLabel = "NoSelection";
        return;
      }
      boolean queue = keyPressed && keyCode == SHIFT;
      if (state.issueHarvestOrderToSelectedMiners(world)) {
        return;
      }
      Unit target = state.findNearestUnitAt(world, 24);
      if (target != null && target.faction != state.activeFaction && state.selectedUnits.size() > 0) {
        state.clearSelectedHarvestOrders();
        state.commandSystem.attackSelected(state.selectedUnits, target);
        state.orderLabel = "Attack";
        state.addOrderMarker(target.pos.copy(), true);
      } else {
        Building bt = state.findNearestBuildingAt(world, 18, true);
        if (bt != null && bt.faction != state.activeFaction) {
          state.clearSelectedHarvestOrders();
          state.commandSystem.attackSelectedBuilding(state.selectedUnits, bt);
          PVector bc = new PVector(bt.pos.x + bt.tileW * state.map.tileSize * 0.5, bt.pos.y + bt.tileH * state.map.tileSize * 0.5);
          state.orderLabel = "AttackBuilding";
          state.addOrderMarker(bc, true);
          return;
        }
        if (state.attackMoveArmed) {
          state.clearSelectedHarvestOrders();
          state.commandSystem.attackMoveSelected(state, state.selectedUnits, world, queue);
          state.orderLabel = "AttackMove";
          state.addOrderMarker(world, true);
          state.attackMoveArmed = false;
        } else {
          state.clearSelectedHarvestOrders();
          state.commandSystem.moveSelected(state, state.selectedUnits, world, queue);
          state.orderLabel = queue ? "QueueMove" : "Move";
          state.addOrderMarker(world, false);
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
    state.clearSelection();
    float minX = min(dragStart.x, dragEnd.x);
    float minY = min(dragStart.y, dragEnd.y);
    float maxX = max(dragStart.x, dragEnd.x);
    float maxY = max(dragStart.y, dragEnd.y);

    boolean isClick = abs(maxX - minX) < 6 && abs(maxY - minY) < 6;
    if (isClick) {
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
        best.selected = true;
        state.selectedUnits.add(best);
        return;
      }
      Building bb = state.findNearestBuildingAt(dragEnd, 10, true);
      if (bb != null && bb.faction == state.activeFaction) {
        bb.selected = true;
        state.selectedBuilding = bb;
      }
      return;
    }
    for (Unit u : state.units) {
      boolean inBox = u.pos.x >= minX && u.pos.x <= maxX && u.pos.y >= minY && u.pos.y <= maxY;
      if (inBox && u.faction == state.activeFaction) {
        u.selected = true;
        state.selectedUnits.add(u);
      }
    }
  }

  void onKeyPressed(char key, int keyCode) {
    if (state.gameEnded) {
      return;
    }
    if (key == 'q' || key == 'Q') {
      state.trainUnitAtSelectedBuilding("miner");
      return;
    }
    if (key == 'w' || key == 'W') {
      state.trainUnitAtSelectedBuilding("rifleman");
      return;
    }
    if (key == 'e' || key == 'E') {
      state.trainUnitAtSelectedBuilding("rocketeer");
      return;
    }
    if (key == 'a' || key == 'A') {
      state.attackMoveArmed = !state.attackMoveArmed;
      state.orderLabel = state.attackMoveArmed ? "AttackMove(Armed)" : "AttackMove(Cancel)";
      return;
    }
    if (key == 'l' || key == 'L') {
      state.hardCursorLock = !state.hardCursorLock;
      state.orderLabel = state.hardCursorLock ? "CursorLock(ON)" : "CursorLock(OFF)";
      return;
    }
    if (key == 'p' || key == 'P') {
      state.debugShowPaths = !state.debugShowPaths;
      state.orderLabel = state.debugShowPaths ? "DebugPaths(ON)" : "DebugPaths(OFF)";
      return;
    }
    if (key == '1') {
      state.activeFaction = Faction.PLAYER;
    } else if (key == '2') {
      state.activeFaction = Faction.ENEMY;
    }
  }

  void onMouseWheel(float amount, int mx, int my) {
    if (mx >= state.worldViewW) {
      return;
    }
    int clampedX = constrain(mx, 0, state.worldViewW - 1);
    int clampedY = constrain(my, 0, state.screenH - 1);
    state.camera.zoomAt(amount, clampedX, clampedY);
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
}
