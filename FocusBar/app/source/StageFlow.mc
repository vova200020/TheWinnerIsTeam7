import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Stage mode (demo only): opens the focus window on cue and shows the same prompt the
// background service sends, because a 5-minute background timer can't be timed on stage.
module StageFlow {
    function openWindow() as Void {
        Store.put("lastScore", 82);
        Store.put("threshold", 65);
        Store.put("aboveCount", FocusScore.WINDOW_TICKS);
        Store.put("state", FocusScore.STATE_WINDOW);
        Store.put("updatedAt", Time.now().value());
        Publisher.publish();   // the face turns green too
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(70, 400)] as Array<Attention.VibeProfile>);
        }
        WatchUi.pushView(new PromptView(82), new PromptDelegate(), WatchUi.SLIDE_UP);
    }
}

class PromptView extends WatchUi.View {
    private var _score as Number;

    function initialize(score as Number) {
        View.initialize();
        _score = score;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        FocusUi.drawArcBar(dc, cx, cy, r - 9, 10, _score, 65, FocusUi.C_GOOD);
        FocusUi.chip(dc, cx, cy - (r * 0.56).toNumber(), "Focus window", FocusUi.C_GOOD);
        dc.setColor(FocusUi.C_FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (r * 0.20).toNumber(), Graphics.FONT_NUMBER_MEDIUM, _score.format("%d"), j);
        dc.setColor(FocusUi.C_GOOD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.08).toNumber(), Graphics.FONT_TINY, "Ready to focus", j);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.32).toNumber(), Graphics.FONT_TINY, "Start a session?", j);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.58).toNumber(), Graphics.FONT_XTINY, "START: yes   BACK: later", j);
    }
}

class PromptDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        SessionSetup.start();
        return true;
    }
}
