import Toybox.Complications;
import Toybox.Lang;

// Reads the FocusBar app's published complication (see app/source/Publisher.mc), so the face
// shows exactly what the app measured. Returns null when the app isn't installed.
module FocusLink {
    const LABEL = "FocusBar Focus";
    var cachedId as Complications.Id? = null;

    function findId() as Complications.Id? {
        if (cachedId != null) { return cachedId; }
        if (!(Toybox has :Complications)) { return null; }
        var it = Complications.getComplications();
        var c = it.next();
        while (c != null) {
            var label = c.longLabel;
            if (label != null && label.equals(LABEL)) {
                cachedId = c.complicationId;
                return cachedId;
            }
            c = it.next();
        }
        return null;
    }

    function subscribe(callback as Method(id as Complications.Id) as Void) as Void {
        var id = findId();
        if (id == null) { return; }
        Complications.registerComplicationChangeCallback(callback);
        Complications.subscribeToUpdates(id);
    }

    // [score or null, state, threshold]
    function read() as Array? {
        var id = findId();
        if (id == null) { return null; }
        var c = Complications.getComplication(id);
        var label = c.shortLabel;
        if (label == null) { return null; }   // the app hasn't published yet
        // "WINDOW 65" → state word + threshold
        var space = label.find(" ");
        var word = (space != null) ? label.substring(0, space) as String : label;
        var thr = FocusScore.DEFAULT_THRESHOLD;
        if (space != null) {
            var t = (label.substring(space + 1, label.length()) as String).toNumber();
            if (t != null) { thr = t; }
        }
        var state = FocusScore.STATE_NORMAL;
        if (word.equals("WINDOW")) { state = FocusScore.STATE_WINDOW; }
        else if (word.equals("LOW")) { state = FocusScore.STATE_LOW; }
        else if (word.equals("LEARN")) { state = FocusScore.STATE_LEARNING; }
        var v = c.value;
        var score = (v instanceof Number) ? v : null;
        return [score, state, thr];
    }
}
