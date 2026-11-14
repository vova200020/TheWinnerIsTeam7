import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance (playbook §1: progress where people already look).
(:glance)
class FocusGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var score = FocusScore.lastScore();
        var state = FocusScore.lastState();
        var color = FocusUi.stateColor(state);

        var weekCount = (Store.getNum("weekKey", 0) == Days.weekStart()) ? Store.getNum("weekCount", 0) : 0;
        var goal = Store.propNum("weeklyGoal", 5);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var title = "FOCUS " + ((score != null && state != FocusScore.STATE_LEARNING) ? score.format("%d") : "--");
        dc.drawText(0, h * 0.12, Graphics.FONT_GLANCE, title, Graphics.TEXT_JUSTIFY_LEFT);

        FocusUi.drawHBar(dc, 0, (h * 0.52).toNumber(), (w * 0.9).toNumber(), 8,
            (state == FocusScore.STATE_LEARNING) ? null : score, FocusScore.lastThreshold(), color);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 0.68, Graphics.FONT_GLANCE,
            weekCount + "/" + goal + " this week", Graphics.TEXT_JUSTIFY_LEFT);
    }
}
