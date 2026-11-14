import Toybox.Lang;

// Pure scoring rules: no device calls, so the (:test) functions cover every rule.
// Sources for the design choices are in PLAN_v2.html, section 4.
module Scoring {

    // Order of the readiness parts. Each part is 0 to 100 (100 = best) or null when not available.
    enum {
        PART_BODY_BATTERY,
        PART_CALM,        // 100 minus the Garmin stress score
        PART_SLEEP,
        PART_HOUR,        // personal score of this part of the day
        PART_PLACE,       // personal score of this place
        PART_DND,
        PART_TEMP,
        PART_COUNT
    }

    // Start weights, sum 100. Sleep and stress lead because their effect on attention has the best evidence.
    const READY_WEIGHTS = [25, 20, 15, 15, 10, 10, 5] as Array<Number>;

    const NEUTRAL_SCORE = 50;          // shown when no input is available
    const LEVEL_GOOD_MIN = 70;         // green from this score
    const LEVEL_FAIR_MIN = 40;         // amber from this score, red below

    // Focus Score weights, sum 100: time on task, wrist stillness, calm heart rate.
    const FOCUS_WEIGHTS = [50, 30, 20] as Array<Number>;

    const GATE_MIN_BPM = 100;          // lowest heart rate target of the break gate
    const GATE_ABOVE_REST_BPM = 30;    // or this much above resting heart rate, if that is higher
    const RECOVERED_ABOVE_REST_BPM = 20; // in the break: heart rate back within this much of rest = recovered
    // Phone use during focus lowers the score: each exit from the phone app, and each 6 s away from it.
    // The cap keeps one bad block from erasing the whole score.
    const PHONE_EXIT_POINTS = 5;
    const PHONE_AWAY_S_PER_POINT = 6;
    const PHONE_PENALTY_MAX = 30;
    const DEFAULT_REST_BPM = 60;       // used when the user profile has no resting heart rate

    const START_BLOCK_MIN = 24;        // Biwer 2023: 24 min study, 6 min break
    const MIN_BLOCK_MIN = 15;
    const MAX_BLOCK_MIN = 90;          // design cap, not a scientific limit
    const BLOCK_STEP_MIN = 5;
    const BREAK_DIVISOR = 4;           // break = one quarter of the block (same ratio as 24 + 6)
    const MIN_BREAK_S = 300;
    const MAX_BREAK_S = 900;           // Albulescu 2022: hard work can need more than 10 min
    const GROW_SCORE = 70;             // 3 sessions in a row at or above: block grows
    const SHRINK_SCORE = 50;           // 2 sessions in a row below: block shrinks

    function clampN(v as Number, lo as Number, hi as Number) as Number {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    // Weighted mean of the parts that are present. Missing parts do not pull the score down.
    function weightedMean(parts as Array<Number?>, weights as Array<Number>) as Number {
        var sum = 0;
        var weightSum = 0;
        for (var i = 0; i < parts.size() && i < weights.size(); i++) {
            var p = parts[i];
            if (p != null) {
                sum += clampN(p, 0, 100) * weights[i];
                weightSum += weights[i];
            }
        }
        if (weightSum == 0) { return NEUTRAL_SCORE; }
        return (sum + weightSum / 2) / weightSum;
    }

    function readiness(parts as Array<Number?>) as Number {
        return weightedMean(parts, READY_WEIGHTS);
    }

    // One short tip for the weakest input. The order is the order of what the user can change now.
    function tip(parts as Array<Number?>) as String {
        var dnd = parts[PART_DND];
        var calm = parts[PART_CALM];
        var battery = parts[PART_BODY_BATTERY];
        var sleep = parts[PART_SLEEP];
        if (calm != null && calm < 40) { return "Stress high: breathe"; }
        if (dnd != null && dnd < 50) { return "Turn on DND"; }
        if (battery != null && battery < 30) { return "Low energy: go easy"; }
        if (sleep != null && sleep < 40) { return "Short night: go easy"; }
        return "Good to go";
    }

    function levelWord(score_0_100 as Number) as String {
        if (score_0_100 >= LEVEL_GOOD_MIN) { return "Ready"; }
        if (score_0_100 >= LEVEL_FAIR_MIN) { return "Fair"; }
        return "Low";
    }

    // Stillness 0 to 100. Restless for half of the time or more gives 0.
    function stillness(restless_s as Number, elapsed_s as Number) as Number {
        if (elapsed_s <= 0) { return 100; }
        return clampN(100 - (200 * restless_s) / elapsed_s, 0, 100);
    }

    // Calm heart rate 0 to 100: 100 up to rest + 15 bpm, 0 from rest + 45 bpm.
    function calmHeart(meanHr_bpm as Number?, rest_bpm as Number) as Number? {
        if (meanHr_bpm == null) { return null; }
        var over = meanHr_bpm - (rest_bpm + 15);
        return clampN(100 - (over * 100) / 30, 0, 100);
    }

    function focusScore(done_s as Number, planned_s as Number, restless_s as Number,
                        meanHr_bpm as Number?, rest_bpm as Number) as Number {
        var completion = planned_s > 0 ? clampN((done_s * 100) / planned_s, 0, 100) : 0;
        var parts = [completion, stillness(restless_s, done_s), calmHeart(meanHr_bpm, rest_bpm)] as Array<Number?>;
        return weightedMean(parts, FOCUS_WEIGHTS);
    }

    function gateTarget(rest_bpm as Number?) as Number {
        var rest = rest_bpm != null ? rest_bpm : DEFAULT_REST_BPM;
        var target = rest + GATE_ABOVE_REST_BPM;
        return target > GATE_MIN_BPM ? target : GATE_MIN_BPM;
    }

    // The break is for recovery. A heart rate back near rest says the body is ready for the next block.
    function recovered(hr_bpm as Number?, rest_bpm as Number) as Boolean {
        return hr_bpm != null && hr_bpm <= rest_bpm + RECOVERED_ABOVE_REST_BPM;
    }

    function phonePenalty(exits as Number, away_s as Number) as Number {
        if (exits <= 0 && away_s <= 0) { return 0; }
        return clampN(exits * PHONE_EXIT_POINTS + away_s / PHONE_AWAY_S_PER_POINT, 0, PHONE_PENALTY_MAX);
    }

    function breakSeconds(block_s as Number) as Number {
        return clampN(block_s / BREAK_DIVISOR, MIN_BREAK_S, MAX_BREAK_S);
    }

    // The personal block length. scores: oldest first, newest last.
    function nextBlockMin(block_min as Number, scores as Array<Number>) as Number {
        var n = scores.size();
        var next = block_min;
        if (n >= 3 && scores[n - 1] >= GROW_SCORE && scores[n - 2] >= GROW_SCORE && scores[n - 3] >= GROW_SCORE) {
            next = block_min + BLOCK_STEP_MIN;
        } else if (n >= 2 && scores[n - 1] < SHRINK_SCORE && scores[n - 2] < SHRINK_SCORE) {
            next = block_min - BLOCK_STEP_MIN;
        }
        return clampN(next, MIN_BLOCK_MIN, MAX_BLOCK_MIN);
    }

    // Streak in days. A skipped break gate costs the streak.
    function nextStreak(streak_days as Number, lastDay as Number?, today as Number, gateSkipped as Boolean) as Number {
        if (gateSkipped) { return 0; }
        if (lastDay == null) { return 1; }
        if (today == lastDay) { return streak_days > 0 ? streak_days : 1; }
        if (today == lastDay + 1) { return streak_days + 1; }
        return 1;
    }

    function progress(done as Number, total as Number) as Float {
        if (total <= 0) { return 0.0; }
        var p = done.toFloat() / total.toFloat();
        if (p < 0.0) { return 0.0; }
        if (p > 1.0) { return 1.0; }
        return p;
    }
}
