class TimeSystem {
  float minDt = 0.001;
  float maxDt = 0.05;
  int fixedStepHz = 60;
  int maxStepsPerFrame = 4;
  float gameSpeed = 1.0;
  float gameSpeedDefault = 1.0;
  float gameSpeedMin = 0.5;
  float gameSpeedMax = 2.0;
  float gameSpeedStep = 0.25;

  float computeRawDt(int nowMillis, int lastMillis) {
    return min(maxDt, max(minDt, (nowMillis - lastMillis) / 1000.0));
  }

  float gameplayDt(float rawDt) {
    return rawDt * gameSpeed;
  }

  void loadFromUiJson() {
    JSONObject root = loadJSONObject("ui.json");
    if (root == null) {
      return;
    }
    gameSpeedDefault = root.getFloat("gameSpeedDefault", gameSpeedDefault);
    gameSpeedMin = root.getFloat("gameSpeedMin", gameSpeedMin);
    gameSpeedMax = root.getFloat("gameSpeedMax", gameSpeedMax);
    gameSpeedStep = root.getFloat("gameSpeedStep", gameSpeedStep);
    fixedStepHz = root.getInt("fixedStepHz", fixedStepHz);
    maxStepsPerFrame = root.getInt("maxStepsPerFrame", maxStepsPerFrame);
    gameSpeedDefault = constrain(gameSpeedDefault, 0.1, 4.0);
    gameSpeedMin = constrain(gameSpeedMin, 0.1, 4.0);
    gameSpeedMax = constrain(gameSpeedMax, gameSpeedMin, 6.0);
    gameSpeedStep = constrain(gameSpeedStep, 0.05, 1.0);
    fixedStepHz = int(constrain(fixedStepHz, 15, 240));
    maxStepsPerFrame = int(constrain(maxStepsPerFrame, 1, 12));
    gameSpeed = constrain(gameSpeedDefault, gameSpeedMin, gameSpeedMax);
  }

  void cycleSpeed() {
    float next = gameSpeed + gameSpeedStep;
    if (next > gameSpeedMax + 1e-6) {
      next = gameSpeedMin;
    }
    gameSpeed = constrain(next, gameSpeedMin, gameSpeedMax);
  }

  String speedLabel() {
    return nf(gameSpeed, 1, 2) + "x";
  }

  float fixedStepSeconds() {
    return 1.0 / max(1, fixedStepHz);
  }
}
