import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Watch face (spec §2). The face only draws cached values; the background service computes.
(:background)
class FocusFaceApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (Toybox has :Background) {
            Background.registerForTemporalEvent(new Time.Duration(5 * 60));
        }
        // First run: compute once so the face isn't empty for 5 minutes.
        if (Time.now().value() - Store.getNum("updatedAt", 0) > 300) {
            FocusScore.tick(Store.propBool("demoMode", false));
        }
        return [new FocusFaceView(), new FocusFaceDelegate()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new FocusFaceService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() as Void {
        FocusScore.tick(Store.propBool("demoMode", false));
        WatchUi.requestUpdate();
    }
}

(:background)
class FocusFaceService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var res = FocusScore.tick(Store.propBool("demoMode", false));
        Background.exit(res as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
    }
}
