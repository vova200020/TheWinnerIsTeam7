import Toybox.Lang;

// States of one focus session. Session.tick() owns every timed transition.
enum {
    ST_READY,
    ST_FOCUS,
    ST_EARN,      // move until the heart rate opens the break gate
    ST_BREAK,
    ST_SUMMARY
}

// What tick() reports to the shell, so the shell can vibrate.
enum {
    EV_NONE,
    EV_FOCUS_DONE,
    EV_GATE_OPEN,
    EV_BREAK_DONE
}

// One focus session as an explicit state machine. Pure: no device calls, one tick = one second.
class Session {
    var state as Number = ST_READY;

    var planned_s as Number = 0;
    var break_s as Number = 0;
    var target_bpm as Number = Scoring.GATE_MIN_BPM;
    var gateHold_s as Number = 10;      // seconds at or above the target that open the gate
    var rest_bpm as Number = Scoring.DEFAULT_REST_BPM;

    var elapsed_s as Number = 0;
    var restless_s as Number = 0;
    var hrSum as Number = 0;
    var hrCount as Number = 0;
    var hold_s as Number = 0;
    var breakLeft_s as Number = 0;
    var gateSkipped as Boolean = false;
    var completed as Boolean = false;   // the full focus block was done
    var score as Number = 0;
    var penalty as Number = 0;          // points taken off for phone use during focus
    var saved as Boolean = false;       // the shell sets this after it stores the summary

    function initialize() {
    }

    function start(plannedFocus_s as Number, breakLen_s as Number, gate_bpm as Number,
                   hold_s_ as Number, restHr_bpm as Number) as Void {
        planned_s = plannedFocus_s;
        break_s = breakLen_s;
        target_bpm = gate_bpm;
        gateHold_s = hold_s_;
        rest_bpm = restHr_bpm;
        elapsed_s = 0;
        restless_s = 0;
        hrSum = 0;
        hrCount = 0;
        hold_s = 0;
        breakLeft_s = 0;
        gateSkipped = false;
        completed = false;
        penalty = 0;
        score = 0;
        saved = false;
        state = ST_FOCUS;
    }

    function meanHr() as Number? {
        return hrCount > 0 ? hrSum / hrCount : null;
    }

    function focusLeft_s() as Number {
        return planned_s - elapsed_s;
    }

    // climbed_m: metres gained since the gate screen came up (barometer). Stairs also open the gate.
    function tick(hr_bpm as Number?, restless as Boolean, climbed_m as Number) as Number {
        if (state == ST_FOCUS) {
            elapsed_s++;
            if (restless) { restless_s++; }
            if (hr_bpm != null) { hrSum += hr_bpm; hrCount++; }
            if (elapsed_s >= planned_s) {
                completed = true;
                closeFocus();
                state = ST_EARN;
                return EV_FOCUS_DONE;
            }
        } else if (state == ST_EARN) {
            if (hr_bpm != null && hr_bpm >= target_bpm) { hold_s++; } else { hold_s = 0; }
            if (hold_s >= gateHold_s || climbed_m >= Baseline.GATE_CLIMB_M) {
                openBreak();
                return EV_GATE_OPEN;
            }
        } else if (state == ST_BREAK) {
            breakLeft_s--;
            if (breakLeft_s <= 0) {
                state = ST_SUMMARY;
                return EV_BREAK_DONE;
            }
        }
        return EV_NONE;
    }

    // The user stops the focus block before its end: score what was done, no break.
    function endEarly() as Void {
        if (state == ST_FOCUS) {
            closeFocus();
            state = ST_SUMMARY;
        }
    }

    // The user passes the gate without movement. The streak rule reads gateSkipped.
    function skipGate() as Void {
        if (state == ST_EARN) {
            gateSkipped = true;
            openBreak();
        }
    }

    // Applied once, when the block is saved.
    function applyPenalty(points as Number) as Void {
        if (points <= 0 || penalty > 0) { return; }
        penalty = points > score ? score : points;
        score -= penalty;
    }

    function endBreak() as Void {
        if (state == ST_BREAK) { state = ST_SUMMARY; }
    }

    function reset() as Void {
        state = ST_READY;
    }

    private function closeFocus() as Void {
        score = Scoring.focusScore(elapsed_s, planned_s, restless_s, meanHr(), rest_bpm);
    }

    private function openBreak() as Void {
        breakLeft_s = break_s;
        hold_s = 0;
        state = ST_BREAK;
    }
}
