import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// The running focus session survives view changes (nudges, breaks, unlock challenges).
var gSession as FocusSession? = null;

(:background :glance)
class FocusApp extends Application.AppBase {
    private var _fromFace as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    // NOTE: onStart also runs in the background and glance processes; foreground-only
    // setup lives in getInitialView().
    function onStart(state as Dictionary?) as Void {
        // Tapped on the FocusBar face → Complications.exitTo() → straight to quick start.
        _fromFace = state != null && state.hasKey(:launchedFromComplication);
    }

    function onStop(state as Dictionary?) as Void {
    }

    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (Toybox has :Background) {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        }
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
        if (Time.now().value() - Store.getNum("updatedAt", 0) > 300) {
            FocusScore.tick(Store.propBool("demoMode", false));
        }
        Publisher.publish();
        if (_fromFace && gSession == null) {
            var quick = new QuickStartView();
            return [quick, new QuickStartDelegate(quick)];
        }
        var view = new HomeView();
        return [view, new HomeDelegate()];
    }

    (:glance :typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new FocusGlance()];
    }

    (:typecheck(disableGlanceCheck))
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new FocusService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    // Phone → watch protocol (spec §4.2). Only "unlock_request" is handled on the watch.
    (:typecheck([disableBackgroundCheck, disableGlanceCheck]))
    function onPhoneMessage(msg as Communications.PhoneAppMessage) as Void {
        var data = msg.data;
        if (!(data instanceof Dictionary)) { return; }
        var t = data["t"];
        if (t instanceof String && t.equals("unlock_request")) {
            var app = data["app"];
            UnlockFlow.start((app instanceof String) ? app : "app");
        } else if (t instanceof String && t.equals("schedule")) {
            Schedule.store(data["sessions"] as Object?);
            WatchUi.requestUpdate();
        }
    }
}
