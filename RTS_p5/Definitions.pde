class UnitDef {
  String id;
  String role;
  float speed;
  float radius;
  int hp;
  float attackRange = 95;
  float attackDamage = 8;
  float attackCooldown = 0.6;
  int cost = 60;
  float trainTime = 2.0;
  float sightRange = 220;
  boolean usesProjectile = false;
  float projectileSpeed = 260;
  boolean canHarvest = false;
  int harvestAmount = 20;
  float harvestTime = 1.2;
}

class BuildingDef {
  String id;
  String category;
  int tileW;
  int tileH;
  float buildTime;
  int cost;
  String[] prerequisites;
  boolean canTrainUnits = false;
  String[] trainableUnits;
  boolean isDropoff = false;
  boolean isMainBase = false;
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
