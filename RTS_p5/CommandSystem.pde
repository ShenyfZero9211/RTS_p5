class CommandSystem {
  void moveSelected(GameState state, ArrayList<Unit> selectedUnits, PVector target, boolean queue) {
    if (selectedUnits.size() == 0) {
      return;
    }
    PVector anchor = state.pathfinder.resolveGoalWorld(target, state.buildings);
    PVector center = new PVector();
    for (Unit u : selectedUnits) {
      center.add(u.pos);
    }
    center.div(selectedUnits.size());

    PVector forward = PVector.sub(anchor, center);
    if (forward.magSq() < 1) {
      forward = new PVector(1, 0);
    }
    forward.normalize();
    PVector right = new PVector(-forward.y, forward.x);

    int cols = ceil(sqrt(selectedUnits.size()));
    int rows = ceil(selectedUnits.size() / float(cols));
    float spacing = 26;
    ArrayList<PVector> slots = new ArrayList<PVector>();
    ArrayList<String> usedTileKeys = new ArrayList<String>();

    for (int i = 0; i < selectedUnits.size(); i++) {
      int col = i % cols;
      int row = i / cols;
      float colOffset = (col - (cols - 1) * 0.5) * spacing;
      float rowOffset = (row - (rows - 1) * 0.5) * spacing;
      PVector slotOffset = PVector.add(PVector.mult(right, colOffset), PVector.mult(forward, rowOffset));
      PVector slot = PVector.add(anchor, slotOffset);
      PVector snapped = state.findNearestOpenSlot(slot, usedTileKeys);
      slots.add(snapped);
      usedTileKeys.add(state.tileKeyForWorld(snapped));
    }

    ArrayList<Unit> pending = new ArrayList<Unit>();
    for (Unit u : selectedUnits) {
      pending.add(u);
    }
    for (PVector slot : slots) {
      Unit closest = null;
      float best = 1e9;
      for (Unit u : pending) {
        float d = PVector.dist(u.pos, slot);
        if (d < best) {
          best = d;
          closest = u;
        }
      }
      if (closest != null) {
        closest.issueMove(slot, state, queue);
        pending.remove(closest);
      }
    }
  }

  void attackSelected(ArrayList<Unit> selectedUnits, Unit target) {
    for (Unit u : selectedUnits) {
      u.issueAttack(target);
    }
  }

  void attackMoveSelected(GameState state, ArrayList<Unit> selectedUnits, PVector target, boolean queue) {
    if (selectedUnits.size() == 0) {
      return;
    }
    PVector anchor = state.pathfinder.resolveGoalWorld(target, state.buildings);
    PVector center = new PVector();
    for (Unit u : selectedUnits) {
      center.add(u.pos);
    }
    center.div(selectedUnits.size());
    PVector forward = PVector.sub(anchor, center);
    if (forward.magSq() < 1) {
      forward = new PVector(1, 0);
    }
    forward.normalize();
    PVector right = new PVector(-forward.y, forward.x);
    int cols = ceil(sqrt(selectedUnits.size()));
    int rows = ceil(selectedUnits.size() / float(cols));
    float spacing = 26;
    ArrayList<PVector> slots = new ArrayList<PVector>();
    ArrayList<String> usedTileKeys = new ArrayList<String>();
    for (int i = 0; i < selectedUnits.size(); i++) {
      int col = i % cols;
      int row = i / cols;
      float colOffset = (col - (cols - 1) * 0.5) * spacing;
      float rowOffset = (row - (rows - 1) * 0.5) * spacing;
      PVector slotOffset = PVector.add(PVector.mult(right, colOffset), PVector.mult(forward, rowOffset));
      PVector slot = PVector.add(anchor, slotOffset);
      PVector snapped = state.findNearestOpenSlot(slot, usedTileKeys);
      slots.add(snapped);
      usedTileKeys.add(state.tileKeyForWorld(snapped));
    }
    ArrayList<Unit> pending = new ArrayList<Unit>();
    for (Unit u : selectedUnits) {
      pending.add(u);
    }
    for (PVector slot : slots) {
      Unit closest = null;
      float best = 1e9;
      for (Unit u : pending) {
        float d = PVector.dist(u.pos, slot);
        if (d < best) {
          best = d;
          closest = u;
        }
      }
      if (closest != null) {
        closest.issueAttackMove(slot, state, queue);
        pending.remove(closest);
      }
    }
  }
}
