class UnitDef {
  String id;
  float speed;
  float radius;
  int hp;
}

class BuildingDef {
  String id;
  int tileW;
  int tileH;
  float buildTime;
  int cost;
}

class ResourcePool {
  int credits;

  ResourcePool(int credits) {
    this.credits = credits;
  }

  boolean canAfford(int cost) {
    return credits >= cost;
  }

  boolean spend(int cost) {
    if (!canAfford(cost)) {
      return false;
    }
    credits -= cost;
    return true;
  }
}

enum UnitOrderType {
  NONE,
  MOVE,
  ATTACK,
  ATTACK_MOVE
}

enum UnitState {
  IDLE,
  MOVING,
  ATTACKING,
  CHASING
}
