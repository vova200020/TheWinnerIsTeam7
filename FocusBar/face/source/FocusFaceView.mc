import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// 260×260 MIP layout (spec §2.1): time, date, 270° focus arc + score, state label.
class FocusFaceView extends WatchUi.WatchFace {
    private var _cx as Number = 130;
    private var _cy as Number = 130;
    private var _r as Number = 130;
    private var _shownAt as Number = 0;

    function initialize() {
        WatchFace.initialize();
    }

    function onShow() as Void {
        FocusLink.subscribe(method(:onLinkChanged));
    }

    function onLinkChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        _r = (_cx < _cy) ? _cx : _cy;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var score = FocusScore.lastScore();
        var state = FocusScore.lastState();
        var thr = FocusScore.lastThreshold();
        var link = FocusLink.read();
        if (link != null) {
            // The FocusBar app's measurement: same number as in the app.
            score = link[0] as Number?;
            state = link[1] as Number;
            thr = link[2] as Number;
        } else if (Store.propBool("demoMode", false)) {
            // Stage: deterministic climb 45 → 82 during the first minute on screen.
            if (_shownAt == 0) { _shownAt = Time.now().value(); }
            var t = Time.now().value() - _shownAt;
            score = (t >= 60) ? 82 : 45 + (37 * t) / 60;
            thr = 65;
            state = (score >= thr) ? FocusScore.STATE_WINDOW : FocusScore.STATE_NORMAL;
        }
        var color = (score != null && state != FocusScore.STATE_LEARNING)
            ? ((state == FocusScore.STATE_WINDOW) ? FocusUi.C_GOOD : FocusUi.levelColor(score as Number))
            : Graphics.COLOR_DK_GRAY;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        FocusUi.drawArcBar(dc, _cx, _cy, _r - 9, 10, (state == FocusScore.STATE_LEARNING) ? null : score, thr, color);

        // Date + time
        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var clock = System.getClockTime();
        var h = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - (_r * 0.44).toNumber(), Graphics.FONT_TINY,
            Lang.format("$1$ $2$ $3$", [now.day_of_week, now.month, now.day]), center);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy, Graphics.FONT_NUMBER_HOT,
            h.format("%d") + ":" + clock.min.format("%02d"), center);

        // One calm line: the state as a FocusPeak term chip, then the score.
        var ly = _cy + (_r * 0.44).toNumber();
        if (state == FocusScore.STATE_LEARNING || score == null) {
            FocusUi.chip(dc, _cx, ly, "Learning", FocusUi.C_MUTED);
        } else if (state == FocusScore.STATE_WINDOW) {
            FocusUi.chipValue(dc, _cx, ly, "Focus window", FocusUi.C_GOOD, (score as Number).format("%d"));
        } else {
            FocusUi.chipValue(dc, _cx, ly, FocusUi.levelWord(score as Number), color, (score as Number).format("%d"));
        }
    }
}
