/** Clipped text and simple panel primitives for the side UI (Processing/Java).
 *  Instance methods (not static): Processing nests this inside the sketch class, where static inner types cannot call text()/textSize(). */
class UiWidgets {

  float drawLineClamped(String text, float x, float y, float maxW, int textSizePx) {
    textSize(textSizePx);
    String s = text;
    while (s.length() > 1 && textWidth(s) > maxW) {
      s = s.substring(0, s.length() - 1);
    }
    if (s.length() > 0 && !s.equals(text) && s.length() >= 2) {
      s = s.substring(0, max(1, s.length() - 2)) + "..";
    }
    text(s, x, y);
    return y + textSizePx * 1.2;
  }

  float drawTextBlock(String body, float x, float y, float w, float maxH, int textSizePx, float lineLead) {
    if (body == null || body.length() == 0) {
      return y;
    }
    textSize(textSizePx);
    float yy = y;
    String[] words = splitTokens(body, " ");
    String line = "";
    for (int i = 0; i < words.length; i++) {
      String tryLine = line.length() == 0 ? words[i] : line + " " + words[i];
      if (textWidth(tryLine) <= w) {
        line = tryLine;
      } else {
        if (line.length() > 0) {
          text(line, x, yy);
          yy += lineLead;
          if (yy + lineLead > y + maxH) {
            text("..", x, yy);
            return yy + lineLead;
          }
        }
        line = words[i];
      }
    }
    if (line.length() > 0) {
      text(line, x, yy);
      yy += lineLead;
    }
    return yy;
  }

  void pushClipRect(float x, float y, float w, float h) {
    pushStyle();
    clip(x, y, w, h);
  }

  void popClipRect() {
    noClip();
    popStyle();
  }

  void drawLabelBox(float x, float y, float w, float h, String title, String value) {
    noStroke();
    fill(22, 24, 28);
    rect(x, y, w, h, 4);
    stroke(60, 68, 78);
    strokeWeight(1);
    noFill();
    rect(x, y, w, h, 4);
    noStroke();
    fill(150, 160, 175);
    textSize(9);
    textAlign(LEFT, TOP);
    text(title, x + 6, y + 4);
    fill(235);
    textSize(11);
    String v = value == null ? "" : value;
    while (v.length() > 1 && textWidth(v) > w - 12) {
      v = v.substring(0, v.length() - 1);
    }
    text(v, x + 6, y + 17);
  }

  float drawList(float x, float y, float w, int rowH, String[] items, int offset, int maxRows, int textSizePx) {
    if (items == null) {
      return y;
    }
    int end = min(items.length, offset + maxRows);
    float yy = y;
    for (int i = offset; i < end; i++) {
      yy = drawLineClamped(items[i], x + 4, yy, w - 8, textSizePx);
    }
    return yy;
  }

  void drawChamferFill(float x, float y, float w, float h, float c, int col) {
    c = constrain(c, 2, min(w, h) * 0.35);
    noStroke();
    fill(col);
    beginShape();
    vertex(x + c, y);
    vertex(x + w - c, y);
    vertex(x + w, y + c);
    vertex(x + w, y + h - c);
    vertex(x + w - c, y + h);
    vertex(x + c, y + h);
    vertex(x, y + h - c);
    vertex(x, y + c);
    endShape(CLOSE);
  }

  void drawChamferStroke(float x, float y, float w, float h, float c, int col, float sw) {
    c = constrain(c, 2, min(w, h) * 0.35);
    noFill();
    stroke(col);
    strokeWeight(sw);
    beginShape();
    vertex(x + c, y);
    vertex(x + w - c, y);
    vertex(x + w, y + c);
    vertex(x + w, y + h - c);
    vertex(x + w - c, y + h);
    vertex(x + c, y + h);
    vertex(x, y + h - c);
    vertex(x, y + c);
    endShape(CLOSE);
  }

  void drawHitButton(UiHitButton b) {
    if (b == null) {
      return;
    }
    float c = b.chamfer;
    int baseFill = color(48, 48, 48);
    int strokeCol = color(70, 70, 70);
    float strokeW = 1;
    if (b.style == 1) {
      strokeCol = color(95, 130, 190);
    } else if (b.style == 2) {
      baseFill = color(92, 48, 48);
      strokeCol = color(255, 160, 140);
    } else if (b.style == 3) {
      baseFill = color(34, 38, 48);
      strokeCol = color(120, 140, 175);
    }
    if (!b.enabled) {
      baseFill = color(38, 38, 38);
      strokeCol = color(55, 55, 55);
    } else if (b.pressed) {
      baseFill = color(95, 130, 85);
      if (b.style == 1) {
        baseFill = color(85, 110, 150);
      }
      strokeCol = color(170, 255, 170);
      strokeW = 2;
    } else if (b.hovered) {
      baseFill = color(62, 62, 62);
      if (b.style == 1) {
        baseFill = color(58, 68, 92);
      }
      strokeCol = color(120, 170, 120);
      if (b.style == 1) {
        strokeCol = color(140, 180, 240);
      }
      if (b.style == 2) {
        strokeCol = color(255, 200, 190);
      }
      if (b.style == 3) {
        strokeCol = color(180, 200, 235);
      }
      strokeW = (b.style == 0 && b.emphasisArmed) ? 2 : 1;
    }
    if (b.emphasisArmed && b.enabled && !b.pressed) {
      strokeCol = color(130, 240, 130);
      strokeW = 2;
    }
    drawChamferFill(b.x, b.y, b.w, b.h, c, baseFill);
    drawChamferStroke(b.x, b.y, b.w, b.h, c, strokeCol, strokeW);

    float lx = b.x + b.labelInsetX;
    fill(b.enabled ? 240 : 140);
    textSize(11);
    textAlign(LEFT, TOP);
    if (b.label != null && b.label.length() > 0) {
      text(b.label, lx, b.y + 8);
    }
    fill(b.enabled ? 200 : 120);
    if (b.sublabel != null && b.sublabel.length() > 0) {
      text(b.sublabel, lx, b.y + 24);
    }
    fill(b.enabled ? 175 : 105);
    if (b.sublabel2 != null && b.sublabel2.length() > 0) {
      text(b.sublabel2, lx, b.y + 38);
    }
  }

  boolean hitContains(UiHitButton b, float mx, float my) {
    return b != null && mx >= b.x && mx <= b.x + b.w && my >= b.y && my <= b.y + b.h;
  }

  void drawDropdown(UiDropdown d, float mx, float my) {
    if (d == null) {
      return;
    }
    drawChamferFill(d.x, d.y, d.w, d.h, d.chamfer, color(34, 38, 48));
    drawChamferStroke(d.x, d.y, d.w, d.h, d.chamfer, color(120, 140, 175), 1);
    fill(220);
    textSize(11);
    textAlign(LEFT, TOP);
    text(d.label, d.x + 10, d.y + 8);
    fill(185, 205, 230);
    text(d.value, d.x + 10, d.y + 24);
    fill(170, 190, 220);
    text(d.expanded ? "▲" : "▼", d.x + d.w - 20, d.y + 20);

    if (!d.expanded || d.options == null || d.options.length == 0) {
      return;
    }
    float oy = d.y + d.h + 4;
    float oh = d.optionH * d.options.length;
    drawChamferFill(d.x, oy, d.w, oh, max(3, d.chamfer - 2), color(28, 32, 40));
    drawChamferStroke(d.x, oy, d.w, oh, max(3, d.chamfer - 2), color(95, 115, 145), 1);
    for (int i = 0; i < d.options.length; i++) {
      float ry = oy + d.optionH * i;
      boolean hovered = mx >= d.x && mx <= d.x + d.w && my >= ry && my <= ry + d.optionH;
      if (hovered) {
        noStroke();
        fill(58, 72, 96, 220);
        rect(d.x + 2, ry + 1, d.w - 4, d.optionH - 2, 3);
      }
      fill(i == d.selectedIndex ? color(155, 235, 165) : color(215));
      text(d.options[i], d.x + 10, ry + 7);
    }
  }

  boolean dropdownContainsHeader(UiDropdown d, float mx, float my) {
    return d != null && mx >= d.x && mx <= d.x + d.w && my >= d.y && my <= d.y + d.h;
  }

  int dropdownOptionAt(UiDropdown d, float mx, float my) {
    if (d == null || !d.expanded || d.options == null || d.options.length == 0) {
      return -1;
    }
    float oy = d.y + d.h + 4;
    if (mx < d.x || mx > d.x + d.w || my < oy || my > oy + d.optionH * d.options.length) {
      return -1;
    }
    int idx = int((my - oy) / d.optionH);
    if (idx < 0 || idx >= d.options.length) {
      return -1;
    }
    return idx;
  }

  void drawCornerRivets(float x, float y, float w, float h, float c) {
    noStroke();
    fill(90, 90, 90);
    float inset = max(6, c * 0.45);
    ellipse(x + inset, y + inset, 5, 5);
    ellipse(x + w - inset, y + inset, 5, 5);
    ellipse(x + inset, y + h - inset, 5, 5);
    ellipse(x + w - inset, y + h - inset, 5, 5);
    fill(55, 55, 55);
    ellipse(x + inset, y + inset, 2, 2);
    ellipse(x + w - inset, y + inset, 2, 2);
    ellipse(x + inset, y + h - inset, 2, 2);
    ellipse(x + w - inset, y + h - inset, 2, 2);
  }
}

class UiHitButton {
  float x, y, w, h;
  float chamfer = 4;
  float labelInsetX = 8;
  String label = "";
  String sublabel = "";
  String sublabel2 = "";
  boolean enabled = true;
  String actionId = "";
  int style;
  boolean hovered;
  boolean pressed;
  boolean emphasisArmed;
}

class UiDropdown {
  float x, y, w, h;
  float chamfer = 6;
  float optionH = 28;
  String label = "";
  String value = "";
  String[] options;
  int selectedIndex = 0;
  boolean expanded = false;
}
