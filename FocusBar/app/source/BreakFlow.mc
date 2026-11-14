import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// "Take 5?" nudge and the guided breathing break (spec §3.4).
module BreakFlow {
    const BREAK_SEC = 300;

    function showNudge() as Void {
        var menu = new WatchUi.Menu2({ :title => "Take 5?" });
        menu.addItem(new WatchUi.MenuItem("Break 5 min", "Breathe, timer paused", :brk, null));
        menu.addItem(new WatchUi.MenuItem("Keep going", "Ask again in 15 min", :keep, null));
        menu.addItem(new WatchUi.MenuItem("End session", null, :end, null));
        WatchUi.pushView(menu, new NudgeDelegate(), WatchUi.SLIDE_UP);
    }

    function startBreak() as Void {
        if (gSession == null) { return; }
        (gSession as FocusSession).startBreak();
        var view = new BreathView(BREAK_SEC, "Break");
        WatchUi.pushView(view, new BreathDelegate(view), WatchUi.SLIDE_UP);
    }

    // Box-ish breathing: 4 s in, 6 s out. Shared with the unlock alternative.
    function drawBreath(dc as Graphics.Dc, tMs as Number, title as String, remaining as Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var phase = tMs % 10000;
        var inhale = phase < 4000;
        var f = inhale ? phase / 4000.0 : 1.0 - (phase - 4000) / 6000.0;
        f = 0.5 - 0.5 * Math.cos(f * Math.PI);   // ease in/out

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var minR = (r * 0.18).toNumber();
        var maxR = (r * 0.62).toNumber();
        var unlock = title.find("Unlock") != null;
        var tc = unlock ? FocusUi.C_WARN : FocusUi.C_GOOD;
        // Solid dark shade of the term color (a 64-color display has no subtle tints).
        dc.setColor(unlock ? 0xAA5500 : Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, minR + ((maxR - minR) * f).toNumber());
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, maxR);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_SMALL, inhale ? "Breathe in" : "Breathe out", j);
        FocusUi.chip(dc, cx, cy - (r * 0.76).toNumber(), unlock ? "Move to unlock" : "Break", tc);
        dc.setColor(FocusUi.C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.78).toNumber(), Graphics.FONT_XTINY, SessionView.formatTime(remaining), j);
    }
}

class NudgeDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (id == :brk) {
            BreakFlow.startBreak();
        } else if (id == :keep) {
            if (gSession != null) { (gSession as FocusSession).keepGoing(); }
        } else if (id == :end) {
            EndFlow.end(true);
        }
    }

    function onBack() as Void {
        if (gSession != null) { (gSession as FocusSession).keepGoing(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// Guided breathing. Calls back via `onDone` when finished or cancelled.
class BreathView extends WatchUi.View {
    var onDone as Method? = null;
    private var _title as String;
    private var _total as Number;
    private var _startMs as Number = 0;
    private var _timer as Timer.Timer?;
    private var _done as Boolean = false;

    function initialize(totalSec as Number, title as String) {
        View.initialize();
        _total = totalSec;
        _title = title;
    }

    function onShow() as Void {
        if (_startMs == 0) { _startMs = System.getTimer(); }
        var t = new Timer.Timer();
        t.start(method(:onTick), 100, true);
        _timer = t;
    }

    function onHide() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
    }

    function onTick() as Void {
        if (!_done && remaining() <= 0) {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(60, 400)] as Array<Attention.VibeProfile>);
            }
            finish(true);
            return;
        }
        WatchUi.requestUpdate();
    }

    function remaining() as Number {
        var left = _total - (System.getTimer() - _startMs) / 1000;
        return (left < 0) ? 0 : left;
    }

    // completed=false when the user leaves early.
    function finish(completed as Boolean) as Void {
        if (_done) { return; }
        _done = true;
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (onDone != null) {
            (onDone as Method).invoke(completed);
        } else if (gSession != null) {
            var s = gSession as FocusSession;
            s.endBreak();
            s.showToast("Welcome back");
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var elapsedMs = (_startMs == 0) ? 0 : System.getTimer() - _startMs;
        BreakFlow.drawBreath(dc, elapsedMs, _title, remaining());
    }
}

class BreathDelegate extends WatchUi.BehaviorDelegate {
    private var _view as BreathView;

    function initialize(view as BreathView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        _view.finish(false);
        return true;
    }
}
