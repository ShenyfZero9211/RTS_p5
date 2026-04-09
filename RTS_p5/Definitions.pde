class UnitDef {
  String id;
  String role;
  float speed;
  float radius;
  int hp;
  float attackRange = 95;
  float attackDamage = 8;
  float attackCooldown = 0.6;
  boolean canAttack = true;
  int cost = 60;
  float trainTime = 2.0;
  float sightRange = 220;
  boolean usesProjectile = false;
  float projectileSpeed = 260;
  boolean canHarvest = false;
  int harvestAmount = 20;
  float harvestTime = 1.2;
  boolean autoDefend = true;
  int supplyCost = 1;
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
  float sellRefundRatio = 0.5;
  boolean isTower = false;
  float towerAttackRange = 220;
  float towerDamage = 14;
  float towerCooldown = 1.1;
  float towerProjectileSpeed = 260;
  SpawnPointDef[] spawnPoints = new SpawnPointDef[0];
  boolean useLegacySpawnFallback = true;
  float spawnClearancePad = 3.0;
  int supplyCapBonus = 0;
  int creditCapBonus = 0;
}

class SpawnPointDef {
  String mode = "localTile";
  float x = 0;
  float y = 0;
}

class ResourcePool {
  int credits;
  int creditCap = 999999;

  ResourcePool(int credits, int creditCap) {
    this.credits = credits;
    this.creditCap = max(0, creditCap);
    this.credits = constrain(this.credits, 0, this.creditCap);
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

  int addCredits(int amount) {
    if (amount <= 0) {
      return 0;
    }
    int before = credits;
    credits = min(creditCap, credits + amount);
    return credits - before;
  }

  void setCreditCap(int cap) {
    creditCap = max(0, cap);
    credits = constrain(credits, 0, creditCap);
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
