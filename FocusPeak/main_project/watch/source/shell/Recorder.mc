import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;

// Saves a focus block as an activity, so it shows in Garmin Connect on the phone with its
// heart rate graph. A recording also keeps the app in front, like a workout.
class Recorder {
    private var _rec as ActivityRecording.Session? = null;

    function initialize() {
    }

    function start() as Void {
        if (!(Toybox has :ActivityRecording) || _rec != null) { return; }
        var rec = ActivityRecording.createSession({
            :name => "Focus",
            :sport => Activity.SPORT_GENERIC,
            :subSport => Activity.SUB_SPORT_GENERIC
        });
        rec.start();
        _rec = rec;
    }

    function finish(keep as Boolean) as Void {
        var rec = _rec;
        if (rec == null) { return; }
        if (rec.isRecording()) { rec.stop(); }
        if (keep) { rec.save(); } else { rec.discard(); }
        _rec = null;
    }
}
