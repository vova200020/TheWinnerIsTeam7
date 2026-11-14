import Toybox.Lang;
import Toybox.Math;

// The personal baseline: pure rules for "when and where does this user focus best".
module Baseline {
    const PART_NAMES = ["Morning", "Afternoon", "Evening", "Night"] as Array<String>;
    const PART_COUNT = 4;

    const PLACE_RADIUS_M = 150.0;      // two fixes inside this distance are the same place
    const MAX_PLACES = 5;              // storage stays small, and 5 covers home, work and study places
    const PLACE_LABELS = ["Home", "Library", "Campus", "Office", "Cafe"] as Array<String>;

    const LEARN_SESSIONS = 14;         // the baseline is called "learned" after this many blocks
    const M_PER_DEG = 111320.0;        // metres in one degree of latitude

    const TEMP_MIN_SAMPLES = 3;        // sessions before the usual temperature means something
    const TEMP_POINTS_PER_C = 15;      // readiness points lost for each degree away from the usual value

    const GATE_CLIMB_M = 3;            // one floor of stairs also opens the break gate

    // Morning 5 to 11, afternoon 12 to 16, evening 17 to 21, night 22 to 4.
    function dayPart(hour as Number) as Number {
        if (hour >= 5 && hour < 12) { return 0; }
        if (hour >= 12 && hour < 17) { return 1; }
        if (hour >= 17 && hour < 22) { return 2; }
        return 3;
    }

    function meanOf(sum as Number, n as Number) as Number? {
        if (n <= 0) { return null; }
        return (sum + n / 2) / n;
    }

    // Index of the best mean, or -1 when no entry has data.
    function bestIndex(sums as Array<Number>, counts as Array<Number>) as Number {
        var best = -1;
        var bestMean = -1;
        for (var i = 0; i < sums.size() && i < counts.size(); i++) {
            var m = meanOf(sums[i], counts[i]);
            if (m != null && m > bestMean) {
                bestMean = m;
                best = i;
            }
        }
        return best;
    }

    // Flat-earth distance: exact enough below a few kilometres.
    function distance_m(lat1_deg as Double, lon1_deg as Double, lat2_deg as Double, lon2_deg as Double) as Float {
        var dLat = (lat2_deg - lat1_deg) * M_PER_DEG;
        var dLon = (lon2_deg - lon1_deg) * M_PER_DEG * Math.cos(Math.toRadians(lat1_deg));
        return Math.sqrt(dLat * dLat + dLon * dLon).toFloat();
    }

    // Index of the nearest saved place inside the radius, or -1.
    function findPlace(lats as Array<Double>, lons as Array<Double>, lat_deg as Double, lon_deg as Double) as Number {
        var best = -1;
        var bestDist = PLACE_RADIUS_M;
        for (var i = 0; i < lats.size() && i < lons.size(); i++) {
            var d = distance_m(lats[i], lons[i], lat_deg, lon_deg);
            if (d <= bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    // The watch sensor reads warm because it touches the skin, so only the change against the
    // user's own usual value counts.
    function tempPart(temp_c as Float?, usual_c as Float?, samples as Number) as Number? {
        if (temp_c == null || usual_c == null || samples < TEMP_MIN_SAMPLES) { return null; }
        var diff = temp_c - usual_c;
        if (diff < 0) { diff = -diff; }
        return Scoring.clampN(100 - (diff * TEMP_POINTS_PER_C).toNumber(), 0, 100);
    }
}
