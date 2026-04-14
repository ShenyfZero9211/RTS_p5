import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Date;

class BenchmarkRuntime {
  boolean enabled = false;
  boolean autoStartGame = true;
  boolean autoExit = true;
  float durationSec = 120.0;
  float warmupSec = 10.0;
  float orbitPeriodSec = 24.0;
  String runId = "";
  String battleIntensity = "heavy";
  String troopProfile = "balanced";
  boolean manualControl = false;
  String manualEndKey = "F10";
  boolean manualAutoFrontline = false;
  /** Runtime toggle (W); initialized from JSON in beginIfNeeded. */
  boolean manualAutoFrontlineRuntime = false;
  long lastManualReinforceMs = 0;
  static final int MANUAL_REINFORCE_COOLDOWN_MS = 900;
  boolean manualFinishRequested = false;
  float reinforceIntervalSec = -1;
  int reinforceCountPerFaction = -1;
  String outputCsv = "../benchmarks/runtime_metrics.csv";
  boolean started = false;
  boolean finished = false;
  float elapsed = 0;

  ArrayList<Float> frameMsSamples = new ArrayList<Float>();
  float sumInputMs = 0;
  float sumBuildMs = 0;
  float sumUnitsMs = 0;
  float sumFogMs = 0;
  float sumCombatMs = 0;
  float sumAiMs = 0;
  float sumScriptMs = 0;
  float sumUiMs = 0;
  int subsystemSamples = 0;

  void loadConfig() {
    JSONObject root = loadJSONObject("data/benchmark_runtime.json");
    if (root == null) {
      enabled = false;
      return;
    }
    enabled = root.getBoolean("enabled", false);
    autoStartGame = root.getBoolean("autoStartGame", autoStartGame);
    autoExit = root.getBoolean("autoExit", autoExit);
    durationSec = max(5.0, root.getFloat("durationSec", durationSec));
    warmupSec = constrain(root.getFloat("warmupSec", warmupSec), 0.0, durationSec * 0.9);
    orbitPeriodSec = max(6.0, root.getFloat("orbitPeriodSec", orbitPeriodSec));
    runId = root.getString("runId", "");
    battleIntensity = root.getString("battleIntensity", battleIntensity);
    battleIntensity = trim(battleIntensity.toLowerCase());
    if (!"medium".equals(battleIntensity) && !"heavy".equals(battleIntensity) && !"extreme".equals(battleIntensity)) {
      battleIntensity = "heavy";
    }
    troopProfile = root.getString("troopProfile", troopProfile);
    troopProfile = trim(troopProfile.toLowerCase());
    if (!"balanced".equals(troopProfile) && !"anti-armor".equals(troopProfile) && !"swarm".equals(troopProfile)) {
      troopProfile = "balanced";
    }
    manualControl = root.getBoolean("manualControl", manualControl);
    manualEndKey = root.getString("manualEndKey", manualEndKey);
    if (manualEndKey == null || manualEndKey.length() <= 0) {
      manualEndKey = "F10";
    }
    manualAutoFrontline = root.getBoolean("manualAutoFrontline", manualAutoFrontline);
    reinforceIntervalSec = root.getFloat("reinforceIntervalSec", reinforceIntervalSec);
    reinforceCountPerFaction = root.getInt("reinforceCountPerFaction", reinforceCountPerFaction);
    outputCsv = root.getString("outputCsv", outputCsv);
  }

  void beginIfNeeded(GameEngine engine) {
    if (!enabled || started || engine == null) return;
    started = true;
    if (autoStartGame && engine.mode == AppMode.MENU) {
      // benchmark.ps1 copies the chosen template into data/map_test.json before --run
      engine.state.defaultMapJson = "map_test.json";
      if (engine.startNewGame()) {
        engine.state.prepareBenchmarkBattlefield(battleIntensity, troopProfile);
        if (reinforceIntervalSec > 0.5) {
          engine.state.benchmarkReinforceInterval = reinforceIntervalSec;
          engine.state.benchmarkReinforceTimer = reinforceIntervalSec;
        }
        if (reinforceCountPerFaction >= 0) {
          engine.state.benchmarkReinforceCount = reinforceCountPerFaction;
        }
        manualAutoFrontlineRuntime = manualAutoFrontline;
        engine.mode = AppMode.PLAYING;
      } else {
        println("[BENCH-RUNTIME] failed to start game");
        finished = true;
        if (autoExit) {
          engine.wantExit = true;
        }
      }
    }
  }

  void update(GameEngine engine, float rawFrameMs) {
    if (!enabled || finished || engine == null || engine.state == null || !engine.state.sessionReady()) {
      return;
    }
    elapsed += rawFrameMs / 1000.0;
    if (!manualControl) {
      driveCamera(engine.state, elapsed);
      engine.state.sustainBenchmarkFrontline(rawFrameMs / 1000.0);
    } else {
      if (manualAutoFrontlineRuntime) {
        // Optional: keep AI frontline pressure while still allowing manual player control.
        engine.state.sustainBenchmarkFrontline(rawFrameMs / 1000.0);
      } else {
        // Default manual mode keeps reinforcement waves but avoids overriding player orders.
        engine.state.updateBenchmarkReinforcementTimer(rawFrameMs / 1000.0);
      }
    }

    if (elapsed >= warmupSec) {
      frameMsSamples.add(rawFrameMs);
      sumInputMs += engine.state.profileInputMs;
      sumBuildMs += engine.state.profileBuildMs;
      sumUnitsMs += engine.state.profileUnitsMs;
      sumFogMs += engine.state.profileFogMs;
      sumCombatMs += engine.state.profileCombatMs;
      sumAiMs += engine.state.profileAiMs;
      sumScriptMs += engine.state.profileScriptMs;
      sumUiMs += engine.state.profileUiMs;
      subsystemSamples++;
    }

    if (manualFinishRequested || elapsed >= durationSec) {
      writeResults(engine);
      finished = true;
      if (autoExit) {
        engine.wantExit = true;
      }
    }
  }

  void driveCamera(GameState gs, float t) {
    if (gs == null || gs.camera == null || gs.map == null) return;
    float cx = gs.map.worldWidthPx() * 0.5;
    float cy = gs.map.worldHeightPx() * 0.5;
    float rx = gs.map.worldWidthPx() * 0.36;
    float ry = gs.map.worldHeightPx() * 0.32;
    float a = TWO_PI * ((t % orbitPeriodSec) / orbitPeriodSec);
    gs.camera.jumpCenterTo(cx + cos(a) * rx, cy + sin(a * 1.3) * ry);
  }

  void writeResults(GameEngine engine) {
    ensureParentDir(outputCsv);
    String[] lines = null;
    try {
      File f = new File(sketchPath(outputCsv));
      if (f.exists()) {
        lines = loadStrings(outputCsv);
      }
    } catch (Exception ex) {
      lines = null;
    }
    ArrayList<String> out = new ArrayList<String>();
    String header = "run_id,timestamp,map,fixed_step_hz,max_steps_per_frame,duration_sec,warmup_sec,samples,avg_fps,p50_frame_ms,p95_frame_ms,p99_frame_ms,max_frame_ms,avg_input_ms,avg_build_ms,avg_units_ms,avg_fog_ms,avg_combat_ms,avg_ai_ms,avg_script_ms,avg_ui_ms,enemy_ai_profile,battle_intensity,reinforce_interval_sec,reinforce_count_per_faction,troop_profile,notes";
    if (lines == null || lines.length <= 0) {
      out.add(header);
    } else {
      for (String l : lines) out.add(l);
      if (!out.get(0).equals(header)) {
        out.add(0, header);
      }
    }

    float p50 = percentile(frameMsSamples, 0.50);
    float p95 = percentile(frameMsSamples, 0.95);
    float p99 = percentile(frameMsSamples, 0.99);
    float maxMs = maxOf(frameMsSamples);
    float avgMs = mean(frameMsSamples);
    float avgFps = avgMs > 0 ? 1000.0 / avgMs : 0;
    float div = max(1, subsystemSamples);
    String rid = runId.length() > 0 ? runId : "runtime-" + millis();
    String ts = new SimpleDateFormat("yyyyMMdd-HHmmss").format(new Date());
    String mapName = "map_test.json";
    String row =
      csv(rid) + "," +
      csv(ts) + "," +
      csv(mapName) + "," +
      engine.timeSystem.fixedStepHz + "," +
      engine.timeSystem.maxStepsPerFrame + "," +
      nf(durationSec, 1, 2) + "," +
      nf(warmupSec, 1, 2) + "," +
      frameMsSamples.size() + "," +
      nf(avgFps, 1, 2) + "," +
      nf(p50, 1, 3) + "," +
      nf(p95, 1, 3) + "," +
      nf(p99, 1, 3) + "," +
      nf(maxMs, 1, 3) + "," +
      nf(sumInputMs / div, 1, 3) + "," +
      nf(sumBuildMs / div, 1, 3) + "," +
      nf(sumUnitsMs / div, 1, 3) + "," +
      nf(sumFogMs / div, 1, 3) + "," +
      nf(sumCombatMs / div, 1, 3) + "," +
      nf(sumAiMs / div, 1, 3) + "," +
      nf(sumScriptMs / div, 1, 3) + "," +
      nf(sumUiMs / div, 1, 3) + "," +
      csv(engine.enemyAiProfile) + "," +
      csv(battleIntensity) + "," +
      nf(engine.state.benchmarkReinforceInterval, 1, 2) + "," +
      engine.state.benchmarkReinforceCount + "," +
      csv(engine.state.benchmarkTroopProfile) + "," +
      csv(manualControl ? "manual-runtime" : "auto-runtime");
    out.add(row);
    saveStrings(outputCsv, out.toArray(new String[0]));
    println("[BENCH-RUNTIME] wrote: " + outputCsv);
  }

  void requestManualFinish() {
    if (!enabled || finished || !manualControl) return;
    manualFinishRequested = true;
  }

  boolean isManualControlActive() {
    return enabled && started && !finished && manualControl;
  }

  void toggleManualAutoFrontline(GameState gs) {
    if (!isManualControlActive() || gs == null) {
      return;
    }
    manualAutoFrontlineRuntime = !manualAutoFrontlineRuntime;
    gs.orderLabel = manualAutoFrontlineRuntime
      ? "BENCH auto frontline ON (W: toggle)"
      : "BENCH auto frontline OFF (W: toggle)";
  }

  /** Same as timed reinforcement wave; respects cooldown. Returns false if throttled. */
  boolean tryManualReinforcement(GameState gs) {
    if (!isManualControlActive() || gs == null || !gs.benchmarkScenarioActive) {
      return false;
    }
    long now = millis();
    if (now - lastManualReinforceMs < MANUAL_REINFORCE_COOLDOWN_MS) {
      return false;
    }
    lastManualReinforceMs = now;
    gs.spawnBenchmarkReinforcements();
    return true;
  }

  float remainingSeconds() {
    return max(0, durationSec - elapsed);
  }

  void ensureParentDir(String path) {
    try {
      File f = new File(sketchPath(path));
      File parent = f.getParentFile();
      if (parent != null && !parent.exists()) {
        parent.mkdirs();
      }
    } catch (Exception ex) {
      println("[BENCH-RUNTIME] mkdir failed: " + ex.getMessage());
    }
  }

  String csv(String s) {
    if (s == null) return "";
    String t = s.replace("\"", "\"\"");
    if (t.indexOf(',') >= 0 || t.indexOf('"') >= 0) return "\"" + t + "\"";
    return t;
  }

  float mean(ArrayList<Float> vals) {
    if (vals == null || vals.size() <= 0) return 0;
    float s = 0;
    for (float v : vals) s += v;
    return s / vals.size();
  }

  float maxOf(ArrayList<Float> vals) {
    if (vals == null || vals.size() <= 0) return 0;
    float m = vals.get(0);
    for (int i = 1; i < vals.size(); i++) m = max(m, vals.get(i));
    return m;
  }

  float percentile(ArrayList<Float> vals, float p) {
    if (vals == null || vals.size() <= 0) return 0;
    float[] arr = new float[vals.size()];
    for (int i = 0; i < vals.size(); i++) arr[i] = vals.get(i);
    java.util.Arrays.sort(arr);
    int idx = int(constrain(floor((arr.length - 1) * p), 0, arr.length - 1));
    return arr[idx];
  }
}
