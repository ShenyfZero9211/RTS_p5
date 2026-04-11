import java.awt.Toolkit;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.StringSelection;
import java.util.Collections;

/** Handle kind + list index for placed buildings/units. */
class EditorSelectHandle {
  static final int KIND_BUILDING = 0;
  static final int KIND_UNIT = 1;
  int kind;
  int index;
  EditorSelectHandle(int kind, int index) {
    this.kind = kind;
    this.index = index;
  }
}

/**
 * Multi-select buildings/units; serialize to JSON for clipboard.
 */
class EditorMapSelection {
  final ArrayList<EditorSelectHandle> handles = new ArrayList<EditorSelectHandle>();

  void clear() {
    handles.clear();
  }

  boolean isEmpty() {
    return handles.size() <= 0;
  }

  void removeHandle(EditorSelectHandle h) {
    for (int i = handles.size() - 1; i >= 0; i--) {
      EditorSelectHandle x = handles.get(i);
      if (x.kind == h.kind && x.index == h.index) {
        handles.remove(i);
        return;
      }
    }
  }

  boolean has(int kind, int index) {
    for (EditorSelectHandle h : handles) {
      if (h.kind == kind && h.index == index) return true;
    }
    return false;
  }

  void add(int kind, int index) {
    if (has(kind, index)) return;
    handles.add(new EditorSelectHandle(kind, index));
  }

  void toggle(int kind, int index) {
    if (has(kind, index)) {
      for (int i = handles.size() - 1; i >= 0; i--) {
        EditorSelectHandle h = handles.get(i);
        if (h.kind == kind && h.index == index) {
          handles.remove(i);
          break;
        }
      }
    } else {
      handles.add(new EditorSelectHandle(kind, index));
    }
  }

  /** Re-index handles after list mutation (indices shifted). */
  void reindexAfterRemoveBuilding(int removedIndex) {
    for (int i = handles.size() - 1; i >= 0; i--) {
      EditorSelectHandle h = handles.get(i);
      if (h.kind == EditorSelectHandle.KIND_BUILDING) {
        if (h.index == removedIndex) handles.remove(i);
        else if (h.index > removedIndex) h.index--;
      }
    }
  }

  void reindexAfterRemoveUnit(int removedIndex) {
    for (int i = handles.size() - 1; i >= 0; i--) {
      EditorSelectHandle h = handles.get(i);
      if (h.kind == EditorSelectHandle.KIND_UNIT) {
        if (h.index == removedIndex) handles.remove(i);
        else if (h.index > removedIndex) h.index--;
      }
    }
  }

  boolean rectIntersectsBuilding(EditorState s, EditorPlacedBuilding b, float minX, float minY, float maxX, float maxY) {
    int[] sz = s.buildingSizeById.get(b.type);
    int bw = sz == null ? 1 : max(1, sz[0]);
    int bh = sz == null ? 1 : max(1, sz[1]);
    float ts = s.tileSize;
    float bx0 = b.tx * ts;
    float by0 = b.ty * ts;
    float bx1 = bx0 + bw * ts;
    float by1 = by0 + bh * ts;
    return !(bx1 < minX || bx0 > maxX || by1 < minY || by0 > maxY);
  }

  boolean pointInRect(float px, float py, float minX, float minY, float maxX, float maxY) {
    return px >= minX && px <= maxX && py >= minY && py <= maxY;
  }

  void selectBox(EditorState s, float minWx, float minWy, float maxWx, float maxWy, boolean additive) {
    if (!additive) {
      clear();
    }
    float loX = min(minWx, maxWx);
    float hiX = max(minWx, maxWx);
    float loY = min(minWy, maxWy);
    float hiY = max(minWy, maxWy);
    float ts = s.tileSize;
    for (int i = 0; i < s.initialBuildings.size(); i++) {
      EditorPlacedBuilding b = s.initialBuildings.get(i);
      if (rectIntersectsBuilding(s, b, loX, loY, hiX, hiY)) {
        add(EditorSelectHandle.KIND_BUILDING, i);
      }
    }
    for (int i = 0; i < s.initialUnits.size(); i++) {
      EditorPlacedUnit u = s.initialUnits.get(i);
      if (pointInRect(u.worldCX, u.worldCY, loX, loY, hiX, hiY)) {
        add(EditorSelectHandle.KIND_UNIT, i);
      }
    }
  }

  /** Pick nearest unit or building center under world point; returns true if hit. */
  boolean pickAtWorld(EditorState s, float wx, float wy, boolean shift, float maxDist) {
    float ts = s.tileSize;
    float bestD = maxDist * maxDist;
    int bestKind = -1;
    int bestIdx = -1;
    for (int i = 0; i < s.initialUnits.size(); i++) {
      EditorPlacedUnit u = s.initialUnits.get(i);
      float d = sq(u.worldCX - wx) + sq(u.worldCY - wy);
      if (d < bestD) {
        bestD = d;
        bestKind = EditorSelectHandle.KIND_UNIT;
        bestIdx = i;
      }
    }
    for (int i = 0; i < s.initialBuildings.size(); i++) {
      EditorPlacedBuilding b = s.initialBuildings.get(i);
      int[] sz = s.buildingSizeById.get(b.type);
      int bw = sz == null ? 1 : max(1, sz[0]);
      int bh = sz == null ? 1 : max(1, sz[1]);
      float cx = (b.tx + bw * 0.5f) * ts;
      float cy = (b.ty + bh * 0.5f) * ts;
      float d = sq(cx - wx) + sq(cy - wy);
      if (d < bestD) {
        bestD = d;
        bestKind = EditorSelectHandle.KIND_BUILDING;
        bestIdx = i;
      }
    }
    if (bestKind < 0) {
      if (!shift) clear();
      return false;
    }
    if (shift) {
      toggle(bestKind, bestIdx);
    } else {
      clear();
      add(bestKind, bestIdx);
    }
    return true;
  }

  JSONObject serialize(EditorState s) {
    JSONObject root = new JSONObject();
    root.setString("rtsMapEditorClip", "1");
    JSONArray ba = new JSONArray();
    JSONArray ua = new JSONArray();
    for (EditorSelectHandle h : handles) {
      if (h.kind == EditorSelectHandle.KIND_BUILDING && h.index >= 0 && h.index < s.initialBuildings.size()) {
        EditorPlacedBuilding b = s.initialBuildings.get(h.index);
        JSONObject o = new JSONObject();
        o.setString("faction", b.faction);
        o.setString("type", b.type);
        o.setInt("x", b.tx);
        o.setInt("y", b.ty);
        ba.append(o);
      } else if (h.kind == EditorSelectHandle.KIND_UNIT && h.index >= 0 && h.index < s.initialUnits.size()) {
        EditorPlacedUnit u = s.initialUnits.get(h.index);
        JSONObject o = new JSONObject();
        o.setString("faction", u.faction);
        o.setString("type", u.type);
        o.setFloat("worldCX", u.worldCX);
        o.setFloat("worldCY", u.worldCY);
        o.setInt("x", (int)floor(u.worldCX / s.tileSize));
        o.setInt("y", (int)floor(u.worldCY / s.tileSize));
        ua.append(o);
      }
    }
    root.setJSONArray("initialBuildings", ba);
    root.setJSONArray("initialUnits", ua);
    return root;
  }

  void writeClipboard(String json) {
    try {
      Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
      cb.setContents(new StringSelection(json), null);
    }
    catch (Exception e) {
      // ignore
    }
  }

  String readClipboard() {
    try {
      Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
      if (cb.isDataFlavorAvailable(DataFlavor.stringFlavor)) {
        return (String)cb.getData(DataFlavor.stringFlavor);
      }
    }
    catch (Exception e) {
      // ignore
    }
    return null;
  }

  void copy(EditorState s) {
    if (handles.size() <= 0) return;
    String json = serialize(s).toString();
    writeClipboard(json);
  }

  /** Cut: copy JSON then remove selected (indices descending). */
  void cut(EditorState s) {
    copy(s);
    removeSelectedFromMap(s);
  }

  void removeSelectedFromMap(EditorState s) {
    ArrayList<Integer> bi = new ArrayList<Integer>();
    ArrayList<Integer> ui = new ArrayList<Integer>();
    for (EditorSelectHandle h : handles) {
      if (h.kind == EditorSelectHandle.KIND_BUILDING) bi.add(h.index);
      else ui.add(h.index);
    }
    bi.sort(Collections.reverseOrder());
    ui.sort(Collections.reverseOrder());
    for (int idx : bi) {
      if (idx >= 0 && idx < s.initialBuildings.size()) {
        s.initialBuildings.remove(idx);
      }
    }
    for (int idx : ui) {
      if (idx >= 0 && idx < s.initialUnits.size()) {
        s.initialUnits.remove(idx);
      }
    }
    clear();
  }

  /** @param root from sketch parseJSONObject(clipboardString) */
  int applyPastePayload(EditorState s, EditorTools tools, JSONObject root, int anchorTx, int anchorTy) {
    if (root == null || !root.hasKey("rtsMapEditorClip")) return 0;
    JSONArray ba = root.getJSONArray("initialBuildings");
    JSONArray ua = root.getJSONArray("initialUnits");
    float ts = s.tileSize;
    int minTX = 999999;
    int minTY = 999999;
    if (ba != null) {
      for (int i = 0; i < ba.size(); i++) {
        JSONObject o = ba.getJSONObject(i);
        minTX = min(minTX, o.getInt("x", 0));
        minTY = min(minTY, o.getInt("y", 0));
      }
    }
    if (ua != null) {
      for (int i = 0; i < ua.size(); i++) {
        JSONObject o = ua.getJSONObject(i);
        float wcx;
        float wcy;
        if (o.hasKey("worldCX") && o.hasKey("worldCY")) {
          wcx = o.getFloat("worldCX");
          wcy = o.getFloat("worldCY");
        } else {
          wcx = (o.getInt("x", 0) + 0.5f) * ts;
          wcy = (o.getInt("y", 0) + 0.5f) * ts;
        }
        minTX = min(minTX, (int)floor(wcx / ts));
        minTY = min(minTY, (int)floor(wcy / ts));
      }
    }
    if (minTX == 999999) return 0;
    int dx = anchorTx - minTX;
    int dy = anchorTy - minTY;
    int n = 0;
    if (ba != null) {
      for (int i = 0; i < ba.size(); i++) {
        JSONObject o = ba.getJSONObject(i);
        int tx = o.getInt("x", 0) + dx;
        int ty = o.getInt("y", 0) + dy;
        int[] sz = s.buildingSizeById.get(o.getString("type", "base"));
        int bw = sz == null ? 1 : max(1, sz[0]);
        int bh = sz == null ? 1 : max(1, sz[1]);
        if (tx >= 0 && ty >= 0 && tx + bw <= s.mapWidth && ty + bh <= s.mapHeight) {
          s.initialBuildings.add(new EditorPlacedBuilding(
            o.getString("faction", "player"),
            o.getString("type", "base"),
            tx, ty
            ));
          n++;
        }
      }
    }
    if (ua != null) {
      for (int i = 0; i < ua.size(); i++) {
        JSONObject o = ua.getJSONObject(i);
        float owcx;
        float owcy;
        if (o.hasKey("worldCX") && o.hasKey("worldCY")) {
          owcx = o.getFloat("worldCX");
          owcy = o.getFloat("worldCY");
        } else {
          owcx = (o.getInt("x", 0) + 0.5f) * ts;
          owcy = (o.getInt("y", 0) + 0.5f) * ts;
        }
        float nwcx = owcx + dx * ts;
        float nwcy = owcy + dy * ts;
        if (tools.tryPlaceUnit(
          o.getString("faction", "player"),
          o.getString("type", "rifleman"),
          nwcx, nwcy, false
          )) {
          n++;
        }
      }
    }
    return n;
  }
}
