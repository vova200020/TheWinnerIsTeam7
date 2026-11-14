import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Session end (spec §3.5): self-report 1–5 → XP/awards → summary (2 pages).
module EndFlow {
    const REPORT_LABELS = ["", "Scattered", "Distracted", "Okay", "Focused", "Deep flow"];

    function end(save as Boolean) as Void {
        var s = gSession;
        if (s == null) { return; }
        s.finish(save);
        var summary = s.summary();
        gSession = null;
        if (!save) {
            Comms.send({ "t" => "session_end", "dur" => summary["sec"] as Number, "avg" => 0, "self" => 0,
                         "discarded" => 1 });
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // back to home
            return;
        }
        var view = new SelfReportView();
        WatchUi.switchToView(view, new SelfReportDelegate(view, summary), WatchUi.SLIDE_LEFT);
    }

    function complete(summary as Dictionary, report as Number) as Void {
        var result = Progress.record(summary, report);
        Comms.send(endMessage(summary, report, result));
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 120)] as Array<Attention.VibeProfile>);
        }
        var view = new SummaryView(summary, result);
        WatchUi.switchToView(view, new SummaryDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // session_end with everything the phone shows in its session detail (spec §4.2, §8 Session).
    function endMessage(s as Dictionary, report as Number, r as Dictionary) as Dictionary {
        var awards = r["awards"] as Array<String>;
        var joined = "";
        for (var i = 0; i < awards.size(); i++) {
            joined += (i > 0 ? "," : "") + awards[i];
        }
        return {
            "t" => "session_end",
            "dur" => s["sec"], "avg" => s["avg"], "self" => report,
            "tag" => (s["tag"] as String).toLower(), "level" => Comms.levelName(s["level"] as Number),
            "start" => s["start"], "len" => s["len"],
            "peak" => s["peak"], "low" => s["low"],
            "breaks" => s["breaks"], "nudges" => s["nudges"], "fade" => s["fade"],
            "hr" => s["hr"], "hrmax" => s["hrmax"], "hrv" => s["hrv"],
            "curve" => s["curve"], "step" => s["step"], "th" => FocusScore.lastThreshold(),
            "xp" => r["xp"], "awards" => joined,
            "week" => r["week"], "goal" => r["goal"],
            "lat" => s["lat"], "lon" => s["lon"]   // null if no fix (indoors); the phone fills in
        };
    }
}

// Shared layout helpers for round screens.
module Layout {
    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    // True if a centered line of text at height y fits inside a circle of radius `safe`
    // (checks the circle's width at the text's top and bottom edges).
    function fits(dc as Graphics.Dc, s as String, font as Graphics.FontType, cy as Number,
                  y as Number, safe as Number) as Boolean {
        var halfH = dc.getFontHeight(font) / 2;
        var dy = (y - cy).abs() + halfH;
        if (dy >= safe) { return false; }
        var halfChord = Math.sqrt(safe * safe - dy * dy);
        return dc.getTextWidthInPixels(s, font) / 2 <= halfChord;
    }

    function text(dc as Graphics.Dc, x as Numeric, y as Numeric, font as Graphics.FontType,
                  s as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, CENTER);
    }
}

class SelfReportView extends WatchUi.View {
    var value as Number = 4;

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Thin 5-segment ring hugging the bezel.
        dc.setPenWidth(6);
        for (var i = 0; i < 5; i++) {
            var a0 = 225 - i * 54 - 3;
            dc.setColor(i < value ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r - 5, Graphics.ARC_CLOCKWISE, a0, a0 - 48);
        }

        // Everything else must stay inside this circle, whatever the device's font sizes.
        var safe = r - 18;
        var title = "HOW FOCUSED?";
        var label = EndFlow.REPORT_LABELS[value] as String;
        var titleFont = Graphics.FONT_XTINY;
        var labelFont = Graphics.FONT_TINY;
        var titleH = dc.getFontHeight(titleFont);
        var labelH = dc.getFontHeight(labelFont);

        // Largest number font whose block (title + number + label) fits ~75% of the safe diameter.
        var fonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE];
        var numFont = fonts[fonts.size() - 1] as Graphics.FontType;
        for (var i = 0; i < fonts.size(); i++) {
            var f = fonts[i] as Graphics.FontType;
            if (titleH + dc.getFontHeight(f) + labelH <= safe * 3 / 2) { numFont = f; break; }
        }
        var numH = dc.getFontHeight(numFont);
        var top = cy - (titleH + numH + labelH) / 2;

        var ty = top + titleH / 2;
        if (!Layout.fits(dc, title, titleFont, cy, ty, safe)) { title = "FOCUS?"; }
        Layout.text(dc, cx, ty, titleFont, title, Graphics.COLOR_LT_GRAY);
        Layout.text(dc, cx, top + titleH + numH / 2, numFont, value.format("%d"), Graphics.COLOR_WHITE);
        var ly = top + titleH + numH + labelH / 2;
        Layout.text(dc, cx, ly, labelFont, label, Graphics.COLOR_GREEN);

        // Hint only if there's room inside the safe circle.
        var hint = "UP/DOWN  START";
        var hy = ly + labelH / 2 + titleH / 2 + 2;
        if (Layout.fits(dc, hint, titleFont, cy, hy, safe)) {
            Layout.text(dc, cx, hy, titleFont, hint, Graphics.COLOR_DK_GRAY);
        }
    }
}

class SelfReportDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SelfReportView;
    private var _summary as Dictionary;

    function initialize(view as SelfReportView, summary as Dictionary) {
        BehaviorDelegate.initialize();
        _view = view;
        _summary = summary;
    }

    function onPreviousPage() as Boolean { return change(1); }
    function onNextPage() as Boolean { return change(-1); }

    private function change(d as Number) as Boolean {
        var v = _view.value + d;
        _view.value = (v < 1) ? 1 : ((v > 5) ? 5 : v);
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        EndFlow.complete(_summary, _view.value);
        return true;
    }

    function onBack() as Boolean {
        EndFlow.complete(_summary, 0);   // skip the report, still record the session
        return true;
    }
}

// Page 0: result (arc = average focus). Page 1: body + focus curve.
class SummaryView extends WatchUi.View {
    var page as Number = 0;
    private var _s as Dictionary<String, Object>;
    private var _r as Dictionary<String, Object>;

    function initialize(summary as Dictionary, result as Dictionary) {
        View.initialize();
        _s = summary as Dictionary<String, Object>;
        _r = result as Dictionary<String, Object>;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        if (page == 0) {
            drawResult(dc, cx, cy, r);
        } else {
            drawBody(dc, cx, cy, r);
        }
        // Page dots
        for (var i = 0; i < 2; i++) {
            dc.setColor(i == page ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 6 + i * 12, cy + r - 12, 3);
        }
    }

    private function drawResult(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        var avg = num(_s["avg"]);
        var thr = FocusScore.lastThreshold();
        FocusUi.drawArcBar(dc, cx, cy, r - 9, 10, avg, thr, FocusUi.levelColor(avg));

        var cb = _r["comeback"];
        var comeback = (cb instanceof Boolean) && cb;
        FocusUi.chip(dc, cx, cy - (r * 0.60).toNumber(), comeback ? "Welcome back" : "Focus score",
            comeback ? FocusUi.C_GOOD : FocusUi.C_FG);
        Layout.text(dc, cx, cy - (r * 0.34).toNumber(), Graphics.FONT_NUMBER_MEDIUM,
            SessionView.formatTime(num(_s["sec"])), Graphics.COLOR_WHITE);
        Layout.text(dc, cx, cy - (r * 0.07).toNumber(), Graphics.FONT_XTINY,
            str(_s["tag"]) + "  " + Comms.levelName(num(_s["level"])).toUpper(), Graphics.COLOR_LT_GRAY);

        // Stat row: value over label
        var vy = cy + (r * 0.15).toNumber();
        var ly = cy + (r * 0.31).toNumber();
        var dx = (r * 0.42).toNumber();
        stat(dc, cx - dx, vy, ly, num(_s["avg"]).format("%d"), "avg");
        stat(dc, cx, vy, ly, num(_s["peak"]).format("%d"), "peak");
        stat(dc, cx + dx, vy, ly, num(_s["breaks"]).format("%d"), "breaks");

        Layout.text(dc, cx, cy + (r * 0.50).toNumber(), Graphics.FONT_TINY,
            "+" + str(_r["xp"]) + " XP", FocusUi.C_WARN);
        var awards = _r["awards"] as Array<String>;
        if (awards.size() > 0) {
            FocusUi.chip(dc, cx, cy + (r * 0.66).toNumber(), awards[0], FocusUi.C_WARN);
        } else {
            Layout.text(dc, cx, cy + (r * 0.66).toNumber(), Graphics.FONT_XTINY,
                str(_r["week"]) + "/" + str(_r["goal"]) + " this week", Graphics.COLOR_WHITE);
        }
    }

    private function drawBody(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        FocusUi.chip(dc, cx, cy - (r * 0.62).toNumber(), "Focus score", FocusUi.C_FG);

        // Focus curve, 0–100, with the user's threshold as a dotted line.
        var x0 = cx - (r * 0.72).toNumber();
        var w = (r * 1.44).toNumber();
        var y0 = cy - (r * 0.46).toNumber();
        var h = (r * 0.52).toNumber();
        var curve = _s["curve"] as Array<Number>;
        var thr = FocusScore.lastThreshold();
        var ty = cy0(y0, h, thr);
        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        for (var x = x0; x < x0 + w; x += 6) { dc.drawPoint(x, ty); }
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(x0, y0 + h, x0 + w, y0 + h);
        var n = curve.size();
        if (n >= 2) {
            dc.setPenWidth(3);
            for (var i = 1; i < n; i++) {
                var xa = x0 + (w * (i - 1)) / (n - 1);
                var xb = x0 + (w * i) / (n - 1);
                var a = curve[i - 1];
                var b = curve[i];
                dc.setColor(FocusUi.levelColor(b), Graphics.COLOR_TRANSPARENT);
                dc.drawLine(xa, cy0(y0, h, a), xb, cy0(y0, h, b));
            }
        } else {
            Layout.text(dc, cx, y0 + h / 2, Graphics.FONT_XTINY, "Too short for a curve", Graphics.COLOR_DK_GRAY);
        }

        // Body stats
        var vy = cy + (r * 0.24).toNumber();
        var ly = cy + (r * 0.40).toNumber();
        var dx = (r * 0.42).toNumber();
        var hr = num(_s["hr"]);
        var hrv = num(_s["hrv"]);
        stat(dc, cx - dx, vy, ly, hr > 0 ? hr.format("%d") : "--", "bpm");
        stat(dc, cx, vy, ly, hrv > 0 ? hrv.format("%d") : "--", "HRV");
        stat(dc, cx + dx, vy, ly, num(_s["low"]).format("%d"), "low");

        var nudges = num(_s["nudges"]);
        Layout.text(dc, cx, cy + (r * 0.62).toNumber(), Graphics.FONT_XTINY,
            nudges == 0 ? "No dips: steady focus" : nudges + " dip" + (nudges > 1 ? "s" : "") + ", "
                + num(_s["breaks"]) + " break" + (num(_s["breaks"]) == 1 ? "" : "s"),
            Graphics.COLOR_LT_GRAY);
    }

    // Curve y for a 30–100 scale (scores rarely go below 30; zooming shows the dips).
    private function cy0(y0 as Number, h as Number, v as Number) as Number {
        var c = (v < 30) ? 30 : ((v > 100) ? 100 : v);
        return y0 + h - (h * (c - 30)) / 70;
    }

    private function stat(dc as Graphics.Dc, x as Number, vy as Number, ly as Number,
                          value as String, label as String) as Void {
        Layout.text(dc, x, vy, Graphics.FONT_TINY, value, Graphics.COLOR_WHITE);
        Layout.text(dc, x, ly, Graphics.FONT_XTINY, label, Graphics.COLOR_LT_GRAY);
    }

    private function num(v as Object?) as Number {
        return (v instanceof Number) ? v : 0;
    }
}

function str(v as Object?) as String {
    return (v == null) ? "" : v.toString();
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SummaryView;

    function initialize(view as SummaryView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean { return flip(); }
    function onPreviousPage() as Boolean { return flip(); }

    private function flip() as Boolean {
        _view.page = 1 - _view.page;
        WatchUi.requestUpdate();
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
