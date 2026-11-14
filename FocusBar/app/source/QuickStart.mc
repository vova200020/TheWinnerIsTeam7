import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Opened by tapping the watch face: one press starts a session with your usual settings.
// START = go · UP = change tag · DOWN = change length · BACK = back to the face.
class QuickStartView extends WatchUi.View {
    var tagIdx as Number;
    var lenIdx as Number;

    function initialize() {
        View.initialize();
        tagIdx = SessionSetup.lastTag();
        var len = Progress.lastLength(tagIdx);
        lenIdx = 2;
        for (var i = 0; i < SessionSetup.LENGTHS.size(); i++) {
            if ((SessionSetup.LENGTHS[i] as Number) == len) { lenIdx = i; }
        }
    }

    function length() as Number {
        return SessionSetup.LENGTHS[lenIdx] as Number;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var score = FocusScore.lastScore();
        var state = FocusScore.lastState();
        var learning = state == FocusScore.STATE_LEARNING || score == null;
        FocusUi.drawArcBar(dc, cx, cy, r - 9, 10, learning ? null : score, FocusScore.lastThreshold(),
            FocusUi.stateColor(state));

        var ty = cy - (r * 0.56).toNumber();
        if (learning) {
            FocusUi.chip(dc, cx, ty, "Ready", FocusUi.C_FG);
        } else if (state == FocusScore.STATE_WINDOW) {
            FocusUi.chipValue(dc, cx, ty, "Focus window", FocusUi.C_GOOD, (score as Number).format("%d"));
        } else {
            FocusUi.chipValue(dc, cx, ty, FocusUi.levelWord(score as Number), FocusUi.levelColor(score as Number),
                (score as Number).format("%d"));
        }
        Layout.text(dc, cx, cy - (r * 0.26).toNumber(), Graphics.FONT_MEDIUM,
            SessionSetup.TAGS[tagIdx] as String, Graphics.COLOR_WHITE);
        Layout.text(dc, cx, cy + (r * 0.02).toNumber(), Graphics.FONT_SMALL,
            SessionSetup.lengthLabel(length()) + "  " + Comms.levelName(Store.propNum("detoxLevel", 2)).toUpper(),
            Graphics.COLOR_LT_GRAY);

        // START button affordance (fēnix START is top-right).
        var by = cy + (r * 0.34).toNumber();
        dc.setColor(FocusUi.C_CALM, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - (r * 0.42).toNumber(), by - 18, (r * 0.84).toNumber(), 36, 18);
        Layout.text(dc, cx, by, Graphics.FONT_SMALL, "START", Graphics.COLOR_BLACK);
        Layout.text(dc, cx, cy + (r * 0.62).toNumber(), Graphics.FONT_XTINY, "UP tag  DOWN length", Graphics.COLOR_DK_GRAY);
    }
}

class QuickStartDelegate extends WatchUi.BehaviorDelegate {
    private var _view as QuickStartView;

    function initialize(view as QuickStartView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        SessionSetup.launch(_view.tagIdx, _view.length());
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return onSelect();
    }

    function onPreviousPage() as Boolean {   // UP: next tag
        _view.tagIdx = (_view.tagIdx + 1) % SessionSetup.TAGS.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() as Boolean {       // DOWN: next length
        _view.lenIdx = (_view.lenIdx + 1) % SessionSetup.LENGTHS.size();
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        HomeMenu.push();
        return true;
    }
}
