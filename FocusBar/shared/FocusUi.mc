import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Shared drawing for the focus bar (face, app home, session, glance).
(:glance)
module FocusUi {
    // FocusPeak palette (FocusPeak/main_project/watch/source/core/Terms.mc). A 64-color MIP
    // display shows the nearest color it has.
    const C_FG = 0xEEF1F5;
    const C_MUTED = 0xAAAAAA;
    const C_GOOD = 0x3DDC84;     // rest / good level
    const C_WARN = 0xFFB020;     // earn / fair level / streak
    const C_BAD = 0xFF6B5E;      // low level
    const C_CALM = 0x4DA3FF;     // focus / block

    // Same thresholds as FocusPeak and the phone: ≥70 good, ≥40 fair, below that low.
    function levelColor(score as Number) as Number {
        if (score >= 70) { return C_GOOD; }
        if (score >= 40) { return C_WARN; }
        return C_BAD;
    }

    function levelWord(score as Number) as String {
        if (score >= 70) { return "Ready"; }
        if (score >= 40) { return "Fair"; }
        return "Low";
    }

    function stateColor(state as Number) as Number {
        if (state == FocusScore.STATE_WINDOW) { return C_GOOD; }
        if (state == FocusScore.STATE_NORMAL) { return C_WARN; }
        if (state == FocusScore.STATE_LOW) { return C_BAD; }
        return Graphics.COLOR_DK_GRAY;
    }

    function stateLabel(state as Number) as String {
        if (state == FocusScore.STATE_WINDOW) { return "Focus window open"; }
        if (state == FocusScore.STATE_NORMAL) { return "Fair"; }
        if (state == FocusScore.STATE_LOW) { return "Low"; }
        return "Learning you...";
    }

    // Thin full ring from 12 o'clock, clockwise (FocusPeak face), plus a tick at the user's
    // focus threshold. `r`/`width` describe the band the caller reserved; the ring hugs its outer edge.
    function drawArcBar(dc as Graphics.Dc, cx as Number, cy as Number, r as Number, width as Number,
                        score as Number?, thr as Number, color as Number) as Void {
        var pen = dc.getWidth() / 52;
        if (pen < 2) { pen = 2; }
        var rr = r + width / 2 - pen / 2;
        dc.setPenWidth(pen);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, rr);
        if (score != null && score > 0) {
            var deg = (360 * score) / 100;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (deg >= 360) {
                dc.drawCircle(cx, cy, rr);
            } else {
                dc.drawArc(cx, cy, rr, Graphics.ARC_CLOCKWISE, 90, (90 - deg + 360) % 360);
            }
        }
        // Threshold tick: a short radial line just inside the ring.
        var a = Math.toRadians(90 - (360.0 * thr) / 100.0);
        var r1 = rr - pen * 3;
        var r2 = rr + pen / 2;
        dc.setPenWidth(2);
        dc.setColor(C_FG, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + r1 * Math.cos(a), cy - r1 * Math.sin(a), cx + r2 * Math.cos(a), cy - r2 * Math.sin(a));
        dc.setPenWidth(1);
    }

    // A shared term in its pill (FocusPeak chip): ~15 % fill, outline and text in the term color.
    // Returns the width of the box.
    function chipAt(dc as Graphics.Dc, x as Number, yCenter as Number, text as String, color as Number) as Number {
        var font = Graphics.FONT_XTINY;
        var w = dc.getWidth();
        var h = dc.getFontHeight(font) + w / 65;
        var boxW = dc.getTextWidthInPixels(text, font) + 2 * (w / 22);
        var y = yCenter - h / 2;
        dc.setColor(tint(color), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, boxW, h, h / 2);
        dc.setPenWidth(1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, boxW, h, h / 2);
        dc.drawText(x + boxW / 2, yCenter, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return boxW;
    }

    function chipWidth(dc as Graphics.Dc, text as String) as Number {
        return dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) + 2 * (dc.getWidth() / 22);
    }

    // Centred chip.
    function chip(dc as Graphics.Dc, cx as Number, yCenter as Number, text as String, color as Number) as Void {
        chipAt(dc, cx - chipWidth(dc, text) / 2, yCenter, text, color);
    }

    // "[Ready] 78" centred as one group.
    function chipValue(dc as Graphics.Dc, cx as Number, yCenter as Number, text as String, color as Number,
                       value as String) as Void {
        var font = Graphics.FONT_XTINY;
        var gap = dc.getWidth() / 40;
        var total = chipWidth(dc, text) + gap + dc.getTextWidthInPixels(value, font);
        var x = cx - total / 2;
        var boxW = chipAt(dc, x, yCenter, text, color);
        dc.setColor(C_FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + boxW + gap, yCenter, font, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // The term color at about 15 %: the dark fill inside a chip.
    function tint(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) * 15 / 100;
        var g = ((color >> 8) & 0xFF) * 15 / 100;
        var b = (color & 0xFF) * 15 / 100;
        return (r << 16) | (g << 8) | b;
    }

    // Horizontal variant for glances.
    function drawHBar(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number,
                      score as Number?, thr as Number, color as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
        if (score != null) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, (w * score) / 100, h);
        }
        var tx = x + (w * thr) / 100;
        dc.setColor(C_FG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(tx - 1, y - 3, 3, h + 6);
    }
}
