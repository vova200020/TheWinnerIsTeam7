import Toybox.Lang;
import Toybox.WatchUi;

// Buttons: START = go on, BACK = stop (with a question when it costs something),
// UP and DOWN = pages of the Ready screen, hold UP = menu.
class FocusDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var app = getApp();
        var state = app.session.state;
        if (state == ST_READY && app.page == app.PAGE_SETTINGS) {
            return onMenu();
        }
        if (state == ST_READY) {
            app.startFocus();
        } else if (state == ST_SUMMARY) {
            app.session.reset();
            app.refreshReady();
        }
        WatchUi.requestUpdate();
        return true;
    }

    // Touch, mapped by hand. Without these the watch turns a gesture into a behavior in its own way,
    // and on the Forerunner 265 that felt slow and wrong. A handled gesture returns true, so the
    // behavior functions below run only for the buttons.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return onSelect();
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) { return turnPage(1); }
        if (dir == WatchUi.SWIPE_DOWN) { return turnPage(-1); }
        if (dir == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return true;
    }

    function onNextPage() as Boolean {
        return turnPage(1);
    }

    function onPreviousPage() as Boolean {
        return turnPage(-1);
    }

    function onBack() as Boolean {
        var app = getApp();
        var state = app.session.state;
        if (state == ST_READY) {
            if (app.page != 0) {
                app.page = 0;
                WatchUi.requestUpdate();
                return true;
            }
            return false;   // leave the app
        }
        if (state == ST_FOCUS) {
            ask("End focus now?", :endFocus);
        } else if (state == ST_EARN) {
            ask("Skip? Streak resets", :skipGate);
        } else if (state == ST_BREAK) {
            app.session.endBreak();
            app.saveIfFinished();
        } else {
            app.session.reset();
            app.refreshReady();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        var app = getApp();
        var menu = new WatchUi.Menu2({ :title => "FocusPeak" });
        menu.addItem(new WatchUi.ToggleMenuItem("Demo mode", null, :demo, app.store.demo, null));
        menu.addItem(new WatchUi.ToggleMenuItem("Phone link", null, :link, app.store.linkOn, null));
        menu.addItem(new WatchUi.ToggleMenuItem("Server link", "simulator", :server, app.store.serverOn, null));
        var hasFix = app.sensors.lat_deg != null;
        menu.addItem(new WatchUi.MenuItem("Name this place", hasFix ? null : "No GPS fix yet", :place, null));
        menu.addItem(new WatchUi.MenuItem("Reset data", null, :reset, null));
        WatchUi.pushView(menu, new SettingsDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    private function turnPage(step as Number) as Boolean {
        var app = getApp();
        if (app.session.state != ST_READY) { return false; }
        app.nextPage(step);
        WatchUi.requestUpdate();
        return true;
    }

    private function ask(question as String, action as Symbol) as Void {
        WatchUi.pushView(new WatchUi.Confirmation(question), new AskDelegate(action), WatchUi.SLIDE_IMMEDIATE);
    }
}

class AskDelegate extends WatchUi.ConfirmationDelegate {
    private var _action as Symbol;

    function initialize(action as Symbol) {
        ConfirmationDelegate.initialize();
        _action = action;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            var app = getApp();
            if (_action == :endFocus) {
                app.session.endEarly();
                app.saveIfFinished();
            } else if (_action == :skipGate) {
                app.session.skipGate();
            }
        }
        return true;
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var app = getApp();
        var id = item.getId();
        if (id == :demo && item instanceof WatchUi.ToggleMenuItem) {
            app.setDemo(item.isEnabled());
        } else if (id == :link && item instanceof WatchUi.ToggleMenuItem) {
            app.setLink(item.isEnabled());
        } else if (id == :server && item instanceof WatchUi.ToggleMenuItem) {
            app.setServer(item.isEnabled());
        } else if (id == :place) {
            if (app.sensors.lat_deg == null) { return; }
            var menu = new WatchUi.Menu2({ :title => "This place is" });
            for (var i = 0; i < Baseline.PLACE_LABELS.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(Baseline.PLACE_LABELS[i], null, i, null));
            }
            WatchUi.pushView(menu, new PlaceDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :reset) {
            app.resetData();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}

// The user picks a label from a short list: no typing on the watch.
class PlaceDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var app = getApp();
        var id = item.getId();
        if (id instanceof Lang.Number && id >= 0 && id < Baseline.PLACE_LABELS.size()) {
            var place = app.store.placeFor(app.sensors.lat_deg, app.sensors.lon_deg, true);
            app.store.namePlace(place, Baseline.PLACE_LABELS[id]);
            app.refreshReady();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
