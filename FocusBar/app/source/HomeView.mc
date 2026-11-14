import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// App home: readiness bar, weekly goal, XP. START begins a session.
class HomeView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        var center = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        var score = FocusScore.lastScore();
        var state = FocusScore.lastState();
        var learning = state == FocusScore.STATE_LEARNING || score == null;
        var color = FocusUi.stateColor(state);
        FocusUi.drawArcBar(dc, cx, cy, r - 9, 10, learning ? null : score, FocusScore.lastThreshold(), color);

        FocusUi.chip(dc, cx, cy - (r * 0.55).toNumber(), "Focus score", FocusUi.C_FG);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (r * 0.22).toNumber(), Graphics.FONT_NUMBER_MEDIUM,
            learning ? "--" : (score as Number).format("%d"), center);
        dc.drawText(cx, cy + (r * 0.08).toNumber(), Graphics.FONT_XTINY, FocusUi.stateLabel(state), center);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.32).toNumber(), Graphics.FONT_TINY,
            Progress.weekCount() + "/" + Progress.weeklyGoal() + " this week", center);
        var next = Schedule.nextLabel();
        dc.setColor(next != null ? FocusUi.C_CALM : FocusUi.C_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.52).toNumber(), Graphics.FONT_XTINY,
            (next != null) ? next : Progress.xp() + " XP  " + Progress.totalSessions() + " sessions", center);

        FocusUi.chip(dc, cx, cy + (r * 0.72).toNumber(), "START: Focus", FocusUi.C_CALM);
    }
}

class HomeDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        SessionSetup.start();
        return true;
    }

    function onMenu() as Boolean {
        HomeMenu.push();
        return true;
    }
}

module HomeMenu {
    function push() as Void {
        var menu = new WatchUi.Menu2({ :title => "FocusBar" });
        if (Store.propBool("demoMode", false)) {
            menu.addItem(new WatchUi.MenuItem("Open focus window", "Stage: on cue", :window, null));
        }
        menu.addItem(new WatchUi.MenuItem("Start session", null, :start, null));
        menu.addItem(new WatchUi.MenuItem("HR unlock (demo)", "Earn your scroll", :unlock, null));
        menu.addItem(new WatchUi.MenuItem("Awards", Progress.awards().size() + " earned", :awards, null));
        menu.addItem(new WatchUi.MenuItem("Stats",
            Progress.totalMinutes() / 60 + " h focused, " + Store.getNum("weeksMet", 0) + " goal weeks", :stats, null));
        menu.addItem(new WatchUi.ToggleMenuItem("Snooze prompts today", null, :snooze,
            Store.getNum("snoozeDay", 0) == Days.today(), null));
        menu.addItem(new WatchUi.ToggleMenuItem("Demo mode", null, :demo, Store.propBool("demoMode", false), null));
        WatchUi.pushView(menu, new HomeMenuDelegate(), WatchUi.SLIDE_UP);
    }
}

class HomeMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :window) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            StageFlow.openWindow();
        } else if (id == :start) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            SessionSetup.start();
        } else if (id == :unlock) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            UnlockFlow.start("com.instagram.android");
        } else if (id == :awards) {
            WatchUi.pushView(new AwardsView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :snooze) {
            Store.put("snoozeDay", (item as WatchUi.ToggleMenuItem).isEnabled() ? Days.today() : 0);
        } else if (id == :demo) {
            var on = (item as WatchUi.ToggleMenuItem).isEnabled();
            Store.setProp("demoMode", on);
            FocusScore.tick(on);
            Publisher.publish();
        }
    }
}

class AwardsView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var list = Progress.awards();
        var lh = dc.getFontHeight(Graphics.FONT_XTINY) + 2;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, Graphics.FONT_TINY, "Awards", j);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (list.size() == 0) {
            dc.drawText(cx, dc.getHeight() / 2, Graphics.FONT_XTINY, "Your first session\nearns one", j);
            return;
        }
        var n = (list.size() > 8) ? 8 : list.size();
        for (var i = 0; i < n; i++) {
            var code = list[i];
            dc.drawText(cx, 70 + i * lh, Graphics.FONT_XTINY,
                (code instanceof String) ? Progress.awardName(code) : "?", j);
        }
    }
}
