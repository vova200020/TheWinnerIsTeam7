import Toybox.Lang;
import Toybox.WatchUi;

// Session setup (spec §3.2): two screens max, tag then length.
// Detox level comes from settings (default Deep).
module SessionSetup {
    const TAGS = ["Studying", "Journaling", "Book writing", "Coding", "Reading", "Other"];
    const LENGTHS = [0, 25, 50, 90];

    function start() as Void {
        if (gSession != null) { return; }
        var menu = new WatchUi.Menu2({ :title => "Focus on" });
        for (var i = 0; i < TAGS.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(TAGS[i] as String, null, i, null));
        }
        WatchUi.pushView(menu, new TagDelegate(), WatchUi.SLIDE_UP);
    }

    // Last tag the user picked (quick start default).
    function lastTag() as Number {
        var t = Store.getNum("lastTag", 3);   // default: Coding
        return (t >= 0 && t < TAGS.size()) ? t : 0;
    }

    // Creates and starts a session, replacing the current view with the session screen.
    function launch(tagIdx as Number, len as Number) as Void {
        if (gSession != null) { return; }
        Store.put("lastTag", tagIdx);
        Store.put("len" + tagIdx, len);
        var session = new FocusSession(tagIdx, len, Store.propNum("detoxLevel", 2));
        gSession = session;
        session.begin();
        WatchUi.switchToView(new SessionView(), new SessionDelegate(), WatchUi.SLIDE_LEFT);
    }

    function lengthLabel(len as Number) as String {
        return (len == 0) ? "Open" : len + " min";
    }
}

class TagDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var tagIdx = item.getId() as Number;
        var menu = new WatchUi.Menu2({ :title => "How long?" });
        var last = Progress.lastLength(tagIdx);
        var focus = 2;
        for (var i = 0; i < SessionSetup.LENGTHS.size(); i++) {
            var len = SessionSetup.LENGTHS[i] as Number;
            menu.addItem(new WatchUi.MenuItem(SessionSetup.lengthLabel(len), null, len, null));
            if (len == last) { focus = i; }
        }
        menu.setFocus(focus);   // default = what the user picked last time for this tag
        WatchUi.switchToView(menu, new LengthDelegate(tagIdx), WatchUi.SLIDE_LEFT);
    }
}

class LengthDelegate extends WatchUi.Menu2InputDelegate {
    private var _tagIdx as Number;

    function initialize(tagIdx as Number) {
        Menu2InputDelegate.initialize();
        _tagIdx = tagIdx;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        SessionSetup.launch(_tagIdx, item.getId() as Number);
    }
}
