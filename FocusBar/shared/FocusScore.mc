import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.Time;

// Focus Readiness score (spec §1). Runs in the background process every 5 min.
//
//   z_s   = clamp((value_s − baseline_mean_s) / baseline_sd_s, ±3) · direction_s
//   raw   = Σ w_s·z_s / Σ w_s   (only over signals that have data)
//   score = clamp(50 + 15·raw, 0, 100), smoothed with EMA α = 0.3
//
// MVP signals (spec §9): Stress (HRV-derived), Body Battery, heart rate.
// Baseline = recent history (≈ last 1–3 days, capped sample count to stay under the watchdog).
(:background :glance)
module FocusScore {
    enum State { STATE_LEARNING = 0, STATE_LOW = 1, STATE_NORMAL = 2, STATE_WINDOW = 3 }

    const W_STRESS = 0.35;
    const W_BODY_BATTERY = 0.20;
    const W_HEART_RATE = 0.15;
    const W_PULSE_OX = 0.10;        // gate: only penalises a drop below your normal
    const W_TEMPERATURE = 0.05;     // context: stable = good, any big deviation = worse
    const W_PRESSURE = 0.05;        // barometer: unusually high OR low for you = harder to focus

    // How a signal's z-score counts toward "better than usual".
    const MODE_HIGHER = 1;          // higher is better
    const MODE_LOWER = -1;          // lower is better
    const MODE_STABLE = 0;          // closest to your normal is best
    const MODE_GATE_LOW = 2;        // only drops below normal count (never a bonus)

    const TREND_MAX = 288;           // 24 h of 5-min samples
    const DEFAULT_THRESHOLD = 65;    // until we have enough personal history
    const MIN_THRESHOLD = 55;
    const MAX_THRESHOLD = 90;
    const WINDOW_TICKS = 2;          // ≥ 10 min above threshold
    const LOW_SCORE = 40;
    const MAX_SAMPLES = 600;
    const FRESH_SEC = 1800;          // current value must be ≤ 30 min old
    const BASELINE_SEC = 259200;     // 3 days
    const EMA_ALPHA = 0.3;

    // ---------------------------------------------------------------- compute

    function compute() as Number? {
        if (!(Toybox has :SensorHistory)) { return null; }
        var acc = [0.0, 0.0] as Array<Float>;   // [Σ w·z, Σ w]
        var opts = {
            :period => new Time.Duration(BASELINE_SEC),
            :order => SensorHistory.ORDER_NEWEST_FIRST
        };
        if (SensorHistory has :getStressHistory) {
            addSignal(acc, SensorHistory.getStressHistory(opts), W_STRESS, MODE_LOWER, 5.0, FRESH_SEC);
        }
        if (SensorHistory has :getBodyBatteryHistory) {
            addSignal(acc, SensorHistory.getBodyBatteryHistory(opts), W_BODY_BATTERY, MODE_HIGHER, 5.0, FRESH_SEC);
        }
        if (SensorHistory has :getHeartRateHistory) {
            addSignal(acc, SensorHistory.getHeartRateHistory(opts), W_HEART_RATE, MODE_LOWER, 3.0, FRESH_SEC);
        }
        // Pulse Ox readings are sparse (often overnight), so accept one up to 12 h old.
        if (SensorHistory has :getOxygenSaturationHistory) {
            addSignal(acc, SensorHistory.getOxygenSaturationHistory(opts), W_PULSE_OX, MODE_GATE_LOW, 1.0, 12 * 3600);
        }
        if (SensorHistory has :getTemperatureHistory) {
            addSignal(acc, SensorHistory.getTemperatureHistory(opts), W_TEMPERATURE, MODE_STABLE, 0.5, FRESH_SEC);
        }
        // Barometer (Pa). Compared with YOUR recent normal, not a fixed band: ambient pressure
        // falls ~12 hPa per 100 m of altitude, so a fixed "too low" would just mean "lives high up".
        // SD floor 150 Pa (1.5 hPa) so normal weather wobble doesn't count.
        if (SensorHistory has :getPressureHistory) {
            addSignal(acc, SensorHistory.getPressureHistory(opts), W_PRESSURE, MODE_STABLE, 150.0, FRESH_SEC);
        }
        if (acc[1] <= 0.0) { return null; }
        return clampScore(50.0 + 15.0 * acc[0] / acc[1]);
    }

    // One pass: latest value + Welford mean/variance of the history. Skips null samples.
    function addSignal(acc as Array<Float>, iter as SensorHistory.SensorHistoryIterator?,
                       weight as Float, mode as Number, sdFloor as Float, freshSec as Number) as Void {
        if (iter == null) { return; }
        var now = Time.now().value();
        var cur = null;
        var n = 0;
        var mean = 0.0;
        var m2 = 0.0;
        var s = iter.next();
        for (var i = 0; s != null && i < MAX_SAMPLES; i++) {
            var d = s.data;
            if (d != null) {
                var v = d.toFloat();
                if (n == 0 && s.when != null && now - (s.when as Time.Moment).value() <= freshSec) {
                    cur = v;
                }
                n++;
                var delta = v - mean;
                mean += delta / n;
                m2 += delta * (v - mean);
            }
            s = iter.next();
        }
        if (cur == null || n < 10) { return; }
        var sd = Math.sqrt(m2 / (n - 1)).toFloat();
        if (sd < sdFloor) { sd = sdFloor; }
        var z = (cur - mean) / sd;
        if (z > 3.0) { z = 3.0; }
        if (z < -3.0) { z = -3.0; }
        var good = z;
        if (mode == MODE_LOWER) { good = -z; }
        else if (mode == MODE_STABLE) { good = -z.abs(); }
        else if (mode == MODE_GATE_LOW) { good = (z < 0.0) ? z : 0.0; }
        acc[0] += weight * good;
        acc[1] += weight;
    }

    // Demo data: a 30-minute wave so the window opens on cue during a pitch.
    function demoScore(now as Number) as Number {
        var phase = (now % 1800).toFloat() / 1800.0 * 2.0 * Math.PI;
        return clampScore(52.0 + 33.0 * Math.sin(phase));
    }

    function clampScore(v as Numeric) as Number {
        var n = Math.round(v).toNumber();
        return (n < 0) ? 0 : ((n > 100) ? 100 : n);
    }

    // ---------------------------------------------------------------- tick

    // Full background step: compute, smooth, update trend + window state in Storage.
    function tick(demo as Boolean) as Dictionary<String, Number> {
        var now = Time.now().value();
        var target = demo ? demoScore(now) : compute();
        Store.put("updatedAt", now);

        if (target == null) {
            Store.put("state", STATE_LEARNING);
            Store.put("aboveCount", 0);
            return { "st" => STATE_LEARNING };
        }

        var prev = Application.Storage.getValue("lastScore");
        var score = (prev instanceof Number && !demo)
            ? clampScore(EMA_ALPHA * target + (1.0 - EMA_ALPHA) * prev)
            : target;

        var trend = Store.getArray("scoreTrend");
        trend.add(score);
        if (trend.size() > TREND_MAX) {
            trend = trend.slice(trend.size() - TREND_MAX, null);
        }
        var thr = threshold(trend);
        var above = (score >= thr) ? Store.getNum("aboveCount", 0) + 1 : 0;

        var state = STATE_NORMAL;
        if (above >= WINDOW_TICKS) {
            state = STATE_WINDOW;
        } else if (score < LOW_SCORE) {
            state = STATE_LOW;
        }

        Store.put("lastScore", score);
        Store.put("scoreTrend", trend);
        Store.put("aboveCount", above);
        Store.put("threshold", thr);
        Store.put("state", state);
        return { "s" => score, "st" => state, "th" => thr };
    }

    // The user's own 70th percentile (spec §1.5), via a 5-point histogram: O(n), no sort.
    function threshold(trend as Array<Application.Storage.ValueType>) as Number {
        var n = trend.size();
        if (n < 12) { return DEFAULT_THRESHOLD; }
        var hist = new [21];
        for (var i = 0; i < 21; i++) { hist[i] = 0; }
        for (var i = 0; i < n; i++) {
            var v = trend[i];
            if (v instanceof Number) {
                var b = v / 5;
                hist[b] = (hist[b] as Number) + 1;
            }
        }
        var rank = (n * 7 + 9) / 10;   // ceil(0.7·n)
        var seen = 0;
        var thr = DEFAULT_THRESHOLD;
        for (var b = 0; b < 21; b++) {
            seen += hist[b] as Number;
            if (seen >= rank) {
                thr = b * 5;
                break;
            }
        }
        if (thr < MIN_THRESHOLD) { thr = MIN_THRESHOLD; }
        if (thr > MAX_THRESHOLD) { thr = MAX_THRESHOLD; }
        return thr;
    }

    // ---------------------------------------------------------------- readers for UI

    function lastScore() as Number? {
        var v = Application.Storage.getValue("lastScore");
        return (v instanceof Number) ? v : null;
    }

    function lastState() as Number {
        return Store.getNum("state", STATE_LEARNING);
    }

    function lastThreshold() as Number {
        return Store.getNum("threshold", DEFAULT_THRESHOLD);
    }
}
