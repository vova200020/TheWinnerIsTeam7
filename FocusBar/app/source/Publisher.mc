import Toybox.Complications;
import Toybox.Lang;

// Publishes the focus score as a public complication: the single source of truth that the
// FocusBar face displays (and can launch this app from via Complications.exitTo()).
//   value      = score (or "--" while learning)
//   shortLabel = "<STATE> <threshold>", STATE = WINDOW | FOCUS | LOW | LEARN  (e.g. "WINDOW 65")
(:background)
module Publisher {
    function publish() as Void {
        if (!(Toybox has :Complications)) { return; }
        var score = FocusScore.lastScore();
        var state = FocusScore.lastState();
        var label = "FOCUS";
        if (state == FocusScore.STATE_WINDOW) { label = "WINDOW"; }
        else if (state == FocusScore.STATE_LOW) { label = "LOW"; }
        else if (state == FocusScore.STATE_LEARNING || score == null) { label = "LEARN"; }
        try {
            Complications.updateComplication(0, {
                :value => (score != null && label != "LEARN") ? score : "--",
                :shortLabel => label + " " + FocusScore.lastThreshold()
            });
        } catch (e) {
        }
    }
}
