import java.awt.MouseInfo;
import java.awt.Point;
import java.awt.Robot;
import java.awt.AWTException;
import java.awt.Frame;
import java.awt.Insets;
import java.awt.Window;
import java.awt.Component;
import java.lang.reflect.Method;
import javax.swing.SwingUtilities;

class CursorLock {
  Robot robot;
  boolean available = true;
  boolean warnedNoFrame = false;

  CursorLock() {
    try {
      robot = new Robot();
    } catch (AWTException e) {
      available = false;
      println("CursorLock unavailable: " + e.getMessage());
    }
  }

  void keepInsideWindow(PSurface surface, int screenW, int screenH, boolean sketchFocused) {
    if (!available) {
      return;
    }
    if (!sketchFocused || surface == null) {
      return;
    }

    Window win = resolveSketchWindow(surface);
    if (win == null) {
      if (!warnedNoFrame) {
        println("CursorLock: could not resolve sketch window (try JAVA2D default renderer, not P2D/P3D).");
        warnedNoFrame = true;
      }
      return;
    }

    Point loc = win.getLocationOnScreen();
    Insets insets = win.getInsets();
    int left = loc.x + insets.left;
    int top = loc.y + insets.top;
    int clientW = win.getWidth() - insets.left - insets.right;
    int clientH = win.getHeight() - insets.top - insets.bottom;
    int right = left + max(0, clientW - 1);
    int bottom = top + max(0, clientH - 1);

    Point p = MouseInfo.getPointerInfo().getLocation();
    if (p.x >= left && p.x <= right && p.y >= top && p.y <= bottom) {
      return;
    }

    int newX = constrain(p.x, left, right);
    int newY = constrain(p.y, top, bottom);
    robot.mouseMove(newX, newY);
  }

  Window resolveSketchWindow(PSurface surface) {
    Object nativeObj = surface.getNative();
    Frame frameFromNative = tryGetFrameFromObject(nativeObj);
    if (frameFromNative != null) {
      return frameFromNative;
    }
    if (nativeObj instanceof Window) {
      return (Window) nativeObj;
    }
    if (nativeObj instanceof Component) {
      return SwingUtilities.getWindowAncestor((Component) nativeObj);
    }
    return null;
  }

  Frame tryGetFrameFromObject(Object obj) {
    if (obj == null) {
      return null;
    }
    try {
      Method m = obj.getClass().getMethod("getFrame");
      Object out = m.invoke(obj);
      if (out instanceof Frame) {
        return (Frame) out;
      }
    } catch (Exception ignored) {
    }
    return null;
  }
}
