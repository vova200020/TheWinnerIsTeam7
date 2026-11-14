import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Minimal session screen (spec §3.3): big elapsed time, live focus bar, tag.
class SessionView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var s = gSession;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (s == null) { return; }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        var score = s.score.toNumber();
        var thr = FocusScore.lastThreshold();
        var color = FocusUi.levelColor(score);
        FocusUi.drawArcBar(dc, cx, cy, r - 9, 10, score, thr, color);

        FocusUi.chip(dc, cx, cy - (r * 0.52).toNumber(), "Focus", FocusUi.C_CALM);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (r * 0.12).toNumber(), Graphics.FONT_NUMBER_MEDIUM, formatTime(s.elapsed), j);

        dc.setColor(FocusUi.C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.14).toNumber(), Graphics.FONT_XTINY,
            s.tagName() + "  " + Comms.levelName(s.level).toUpper() + (s.lenMin > 0 ? "  " + s.lenMin + "m" : ""), j);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.36).toNumber(), Graphics.FONT_SMALL, "Focus " + score, j);

        var line = (s.hr != null) ? (s.hr as Number) + " bpm" : "-- bpm";
        if (s.rmssd != null) { line += "  HRV " + (s.rmssd as Float).toNumber(); }
        if (s.calibrating) { line = "Calibrating to you..."; }
        if (s.toast != null) { line = s.toast as String; }
        dc.setColor(s.toast != null ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.58).toNumber(), Graphics.FONT_XTINY, line, j);
    }

    static function formatTime(sec as Number) as String {
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        return (h > 0) ? h + ":" + m.format("%02d") + ":" + s.format("%02d") : m + ":" + s.format("%02d");
    }
}

// START or BACK opens the pause menu, so a stray press can't end a session.
class SessionDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        openMenu();
        return true;
    }

    function onBack() as Boolean {
        openMenu();
        return true;
    }

    private function openMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Session" });
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, null));
        menu.addItem(new WatchUi.MenuItem("Take a break", "5 min, timer paused", :brk, null));
        menu.addItem(new WatchUi.MenuItem("End & save", null, :end, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        WatchUi.pushView(menu, new SessionMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class SessionMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :resume) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :brk) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            BreakFlow.startBreak();
        } else if (id == :end) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            EndFlow.end(true);
        } else if (id == :discard) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            EndFlow.end(false);
        }
    }
}
