import Toybox.Lang;

// Pure readiness math of the watch face. No device calls here, so the unit tests run it with fixed inputs.
// The weights match the Body Battery and calm parts of the watch app (Scoring.READY_WEIGHTS),
// so the face and the app show the same number when only these two inputs exist.
module FaceScore {

    const WEIGHT_BATTERY = 25;
    const WEIGHT_CALM = 20;

    const LEVEL_GOOD_MIN = 70;         // same thresholds as the watch app, so the colors agree
    const LEVEL_FAIR_MIN = 40;

    const LEVEL_LOW = 0;
    const LEVEL_FAIR = 1;
    const LEVEL_GOOD = 2;

    const SCORE_MAX = 100;

    // Weighted mean of the inputs that exist. A missing input does not pull the score down.
    // Returns null when no input exists, so the face can show nothing instead of a made-up value.
    function readiness(bodyBattery_0_100 as Number?, stress_0_100 as Number?) as Number? {
        var sum = 0;
        var weightSum = 0;
        if (bodyBattery_0_100 != null) {
            sum += clamp(bodyBattery_0_100) * WEIGHT_BATTERY;
            weightSum += WEIGHT_BATTERY;
        }
        if (stress_0_100 != null) {
            sum += (SCORE_MAX - clamp(stress_0_100)) * WEIGHT_CALM;
            weightSum += WEIGHT_CALM;
        }
        if (weightSum == 0) { return null; }
        // Integer rounding to nearest: plain division would always round down.
        return (sum + weightSum / 2) / weightSum;
    }

    function level(score as Number) as Number {
        if (score >= LEVEL_GOOD_MIN) { return LEVEL_GOOD; }
        if (score >= LEVEL_FAIR_MIN) { return LEVEL_FAIR; }
        return LEVEL_LOW;
    }

    function word(score as Number) as String {
        var lv = level(score);
        if (lv == LEVEL_GOOD) { return "Ready"; }
        if (lv == LEVEL_FAIR) { return "Fair"; }
        return "Low";
    }

    // Sensor history can hold values outside 0..100 on some firmware; keep the ring inside one turn.
    function clamp(v as Number) as Number {
        if (v < 0) { return 0; }
        if (v > SCORE_MAX) { return SCORE_MAX; }
        return v;
    }
}
