class Camera {
  float x;
  float y;
  float speed = 480;
  float zoom = 1.0;
  float wheelZoomStep = 1.08;
  float minZoom = 0.6;
  float maxZoom = 2.2;
  int viewportW;
  int viewportH;
  int worldW;
  int worldH;
  int edgeThreshold = 20;

  Camera(int viewportW, int viewportH, int worldW, int worldH) {
    this.viewportW = viewportW;
    this.viewportH = viewportH;
    this.worldW = worldW;
    this.worldH = worldH;
  }

  void update(float dt, int mx, int my, int edgeDetectW, int edgeDetectH, boolean allowEdgeScroll) {
    if (!allowEdgeScroll) {
      return;
    }
    float dx = 0;
    float dy = 0;
    if (mx <= edgeThreshold) {
      dx -= speed;
    } else if (mx >= edgeDetectW - edgeThreshold) {
      dx += speed;
    }
    if (my <= edgeThreshold) {
      dy -= speed;
    } else if (my >= edgeDetectH - edgeThreshold) {
      dy += speed;
    }
    x += dx * dt;
    y += dy * dt;
    clampToBounds();
  }

  void jumpCenterTo(float worldX, float worldY) {
    x = worldX - visibleWorldW() * 0.5;
    y = worldY - visibleWorldH() * 0.5;
    clampToBounds();
  }

  void clampToBounds() {
    zoom = constrain(zoom, effectiveMinZoom(), maxZoom);
    x = constrain(x, 0, max(0, worldW - visibleWorldW()));
    y = constrain(y, 0, max(0, worldH - visibleWorldH()));
  }

  PVector worldToScreen(float wx, float wy) {
    return new PVector((wx - x) * zoom, (wy - y) * zoom);
  }

  PVector screenToWorld(float sx, float sy) {
    return new PVector(sx / zoom + x, sy / zoom + y);
  }

  float visibleWorldW() {
    return viewportW / zoom;
  }

  float visibleWorldH() {
    return viewportH / zoom;
  }

  void zoomAt(float wheelAmount, float focusScreenX, float focusScreenY) {
    PVector focusWorldBefore = screenToWorld(focusScreenX, focusScreenY);
    zoom *= pow(wheelZoomStep, -wheelAmount);
    zoom = constrain(zoom, effectiveMinZoom(), maxZoom);
    x = focusWorldBefore.x - focusScreenX / zoom;
    y = focusWorldBefore.y - focusScreenY / zoom;
    clampToBounds();
  }

  float effectiveMinZoom() {
    float fitX = viewportW / float(max(1, worldW));
    float fitY = viewportH / float(max(1, worldH));
    return max(minZoom, max(fitX, fitY));
  }
}
