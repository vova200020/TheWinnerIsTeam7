import Toybox.Lang;

// The message contract between the watch and the phone app. Pure: builds and reads dictionaries only.
// The same contract is in phone/LINK.md and phone/index.html: change the three together.
module Messages {
    // How often a state repeats while it does not change. The phone counts down by itself between messages.
    const FOCUS_EVERY_S = 60;
    const EARN_EVERY_S = 2;            // the live heart rate is the point of this screen
    const BREAK_EVERY_S = 5;           // the phone shows the live heart rate recovery in the break

    const SLEEP_ZERO_H = 4.0;          // sleep part 0 at or below this many hours
    const SLEEP_POINTS_PER_H = 25;     // 100 at 8 hours or more

    typedef Message as Dictionary<String, String or Number>;

    function period_s(state as Number) as Number {
        if (state == ST_FOCUS) { return FOCUS_EVERY_S; }
        if (state == ST_EARN) { return EARN_EVERY_S; }
        if (state == ST_BREAK) { return BREAK_EVERY_S; }
        return 0;   // Ready and Summary: only when the state changes
    }

    // steps: steps walked since the break began (0 outside the break).
    function state(s as Session, hr_bpm as Number?, steps as Number) as Message {
        if (s.state == ST_FOCUS) {
            return { "t" => "state", "s" => "focus", "left_s" => s.focusLeft_s(), "planned_s" => s.planned_s } as Message;
        }
        if (s.state == ST_EARN) {
            return { "t" => "state", "s" => "earn", "hr" => (hr_bpm != null ? hr_bpm : 0),
                     "target" => s.target_bpm, "rest" => s.rest_bpm } as Message;
        }
        if (s.state == ST_BREAK) {
            return { "t" => "state", "s" => "break", "left_s" => s.breakLeft_s, "planned_s" => s.break_s,
                     "hr" => (hr_bpm != null ? hr_bpm : 0), "rest" => s.rest_bpm, "steps" => steps,
                     "ok" => (Scoring.recovered(hr_bpm, s.rest_bpm) ? 1 : 0) } as Message;
        }
        return { "t" => "state", "s" => "ready" } as Message;
    }

    function summary(score as Number, focus_min as Number, place as String, streak_days as Number, next_min as Number) as Message {
        return { "t" => "summary", "score" => score, "min" => focus_min, "place" => place,
                 "streak" => streak_days, "next_min" => next_min } as Message;
    }

    // Reads {"t":"sleep","hours":6.4} from the phone. Anything else gives null: the phone is a trust boundary.
    function parseSleep(data as Object?) as Float? {
        if (!(data instanceof Lang.Dictionary)) { return null; }
        var t = data["t"];
        if (!(t instanceof Lang.String) || !t.equals("sleep")) { return null; }
        var h = data["hours"];
        var hours = null;
        if (h instanceof Lang.Float) { hours = h; }
        else if (h instanceof Lang.Double) { hours = h.toFloat(); }
        else if (h instanceof Lang.Number) { hours = h.toFloat(); }
        if (hours == null || hours < 0.0 || hours > 24.0) { return null; }
        return hours;
    }

    // Sleep part of the readiness, 0 to 100: 4 h or less gives 0, 8 h or more gives 100.
    function sleepPart(hours as Float?) as Number? {
        if (hours == null) { return null; }
        return Scoring.clampN(((hours - SLEEP_ZERO_H) * SLEEP_POINTS_PER_H).toNumber(), 0, 100);
    }

    // Reads the phone use of the running block from a backend reply: [exits, seconds away], or null.
    function parsePhone(data as Object?) as Array<Number>? {
        if (!(data instanceof Lang.Dictionary)) { return null; }
        var exits = data["exits"];
        var away = data["away_s"];
        if (!(exits instanceof Lang.Number) || !(away instanceof Lang.Number) || exits < 0 || away < 0) { return null; }
        return [exits, away] as Array<Number>;
    }
}
