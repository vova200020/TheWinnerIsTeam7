import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

// Tap the face → open the FocusBar app directly (no trip through the activity/app list).
// The FocusBar app publishes a public complication; Complications.exitTo() launches its owner.
class FocusFaceDelegate extends WatchUi.WatchFaceDelegate {
    const LABEL = "FocusBar Focus";

    function initialize() {
        WatchFaceDelegate.initialize();
    }

    function onPress(evt as WatchUi.ClickEvent) as Boolean {
        var id = FocusLink.findId();
        if (id == null) { return false; }   // app not installed: let the system handle the tap
        Complications.exitTo(id);
        return true;
    }
}
