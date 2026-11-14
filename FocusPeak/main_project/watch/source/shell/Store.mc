import Toybox.Lang;
import Toybox.Application;
import Toybox.Time;

// What the app keeps on the watch between runs. Nothing here leaves the watch.
// In demo mode the fields hold example data and nothing is written, so the real log stays clean.
class Store {
    const MAX_SCORES = 30;      // enough for the block-length rule and a 14-day view

    var demo as Boolean = false;
    var linkOn as Boolean = false;      // send messages to the phone app
    var serverOn as Boolean = false;    // send messages to the local backend
    var blockMin as Number = Scoring.START_BLOCK_MIN;
    var streak_days as Number = 0;
    var lastDay as Number? = null;
    var scores as Array<Number> = [] as Array<Number>;
    var total as Number = 0;                                        // sessions in the baseline

    var partSum as Array<Number> = [0, 0, 0, 0] as Array<Number>;   // per part of the day
    var partN as Array<Number> = [0, 0, 0, 0] as Array<Number>;

    var placeLat as Array<Double> = [] as Array<Double>;
    var placeLon as Array<Double> = [] as Array<Double>;
    var placeName as Array<String> = [] as Array<String>;
    var placeSum as Array<Number> = [] as Array<Number>;
    var placeN as Array<Number> = [] as Array<Number>;

    var tempSum_c as Float = 0.0;
    var tempN as Number = 0;

    var sleep_h as Float? = null;       // hours of sleep that the phone sent
    var sleepDay as Number? = null;     // the day it was sent for: sleep of another day is not used

    function initialize() {
        var v = Application.Storage.getValue("demo");
        if (v instanceof Lang.Boolean) { demo = v; }
        v = Application.Storage.getValue("link");
        if (v instanceof Lang.Boolean) { linkOn = v; }
        v = Application.Storage.getValue("server");
        if (v instanceof Lang.Boolean) { serverOn = v; }
        if (demo) { loadExample(); } else { load(); }
    }

    function setDemo(on as Boolean) as Void {
        demo = on;
        Application.Storage.setValue("demo", on);
        if (on) { loadExample(); } else { load(); }
    }

    function setLink(on as Boolean) as Void {
        linkOn = on;
        Application.Storage.setValue("link", on);
    }

    function setServer(on as Boolean) as Void {
        serverOn = on;
        Application.Storage.setValue("server", on);
    }

    function usualTemp_c() as Float? {
        return tempN > 0 ? tempSum_c / tempN : null;
    }

    function setSleep(hours as Float, today as Number) as Void {
        sleep_h = hours;
        sleepDay = today;
        if (!demo) {
            Application.Storage.setValue("sleepH", hours);
            Application.Storage.setValue("sleepDay", today);
        }
    }

    function sleepFor(today as Number) as Float? {
        return (demo || sleepDay == today) ? sleep_h : null;
    }

    // Index of the saved place at this position. A new place is added while there is room.
    function placeFor(lat_deg as Double?, lon_deg as Double?, create as Boolean) as Number {
        if (lat_deg == null || lon_deg == null) { return -1; }
        var i = Baseline.findPlace(placeLat, placeLon, lat_deg, lon_deg);
        if (i < 0 && create && placeLat.size() < Baseline.MAX_PLACES) {
            placeLat.add(lat_deg);
            placeLon.add(lon_deg);
            placeName.add("Place " + (placeLat.size()));
            placeSum.add(0);
            placeN.add(0);
            i = placeLat.size() - 1;
            save();
        }
        return i;
    }

    function namePlace(i as Number, name as String) as Void {
        if (i >= 0 && i < placeName.size()) {
            placeName[i] = name;
            save();
        }
    }

    // A block that the user ended early is scored, but it does not earn a streak day.
    function addSession(score as Number, completed as Boolean, gateSkipped as Boolean, today as Number,
                        part as Number, place as Number, temp_c as Float?) as Void {
        scores.add(score);
        if (scores.size() > MAX_SCORES) { scores = scores.slice(1, null); }
        if (completed) {
            streak_days = Scoring.nextStreak(streak_days, lastDay, today, gateSkipped);
            lastDay = today;
        }
        blockMin = Scoring.nextBlockMin(blockMin, scores);
        total++;
        if (part >= 0 && part < Baseline.PART_COUNT) {
            partSum[part] += score;
            partN[part]++;
        }
        if (place >= 0 && place < placeSum.size()) {
            placeSum[place] += score;
            placeN[place]++;
        }
        if (temp_c != null) {
            tempSum_c += temp_c;
            tempN++;
        }
        save();
    }

    function resetData() as Void {
        Application.Storage.clearValues();
        demo = false;
        linkOn = false;
        serverOn = false;
        load();
    }

    private function save() as Void {
        if (demo) { return; }
        Application.Storage.setValue("scores", scores as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("streak", streak_days);
        Application.Storage.setValue("lastDay", lastDay);
        Application.Storage.setValue("blockMin", blockMin);
        Application.Storage.setValue("total", total);
        Application.Storage.setValue("partSum", partSum as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("partN", partN as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("placeLat", placeLat as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("placeLon", placeLon as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("placeName", placeName as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("placeSum", placeSum as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("placeN", placeN as Array<Application.Storage.ValueType>);
        Application.Storage.setValue("tempSum", tempSum_c);
        Application.Storage.setValue("tempN", tempN);
    }

    private function load() as Void {
        blockMin = num("blockMin", Scoring.START_BLOCK_MIN);
        streak_days = num("streak", 0);
        var d = Application.Storage.getValue("lastDay");
        lastDay = (d instanceof Lang.Number) ? d : null;
        total = num("total", 0);
        tempN = num("tempN", 0);
        var t = Application.Storage.getValue("tempSum");
        tempSum_c = (t instanceof Lang.Float) ? t : 0.0;
        scores = arr("scores") as Array<Number>;
        var ps = arr("partSum") as Array<Number>;
        var pn = arr("partN") as Array<Number>;
        if (ps.size() == Baseline.PART_COUNT && pn.size() == Baseline.PART_COUNT) {
            partSum = ps;
            partN = pn;
        } else {
            partSum = [0, 0, 0, 0] as Array<Number>;
            partN = [0, 0, 0, 0] as Array<Number>;
        }
        placeLat = arr("placeLat") as Array<Double>;
        placeLon = arr("placeLon") as Array<Double>;
        placeName = arr("placeName") as Array<String>;
        placeSum = arr("placeSum") as Array<Number>;
        placeN = arr("placeN") as Array<Number>;
        var sh = Application.Storage.getValue("sleepH");
        sleep_h = (sh instanceof Lang.Float) ? sh : null;
        var sd = Application.Storage.getValue("sleepDay");
        sleepDay = (sd instanceof Lang.Number) ? sd : null;
    }

    // Example data: 14 blocks of a user who works best in the morning at the library.
    private function loadExample() as Void {
        blockMin = 29;
        streak_days = 4;
        lastDay = Time.today().value() / 86400 - 1;     // the example streak ran until yesterday, so today adds a day
        total = 14;
        scores = [78, 84, 61, 88, 72, 58, 79, 84] as Array<Number>;
        partSum = [492, 296, 189, 55] as Array<Number>;      // means 82, 74, 63, 55
        partN = [6, 4, 3, 1] as Array<Number>;
        placeLat = [51.0447d, 51.0780d, 51.0300d] as Array<Double>;
        placeLon = [-114.0719d, -114.1300d, -114.0900d] as Array<Double>;
        placeName = ["Library", "Campus", "Home"] as Array<String>;
        placeSum = [504, 304, 244] as Array<Number>;         // means 84, 76, 61
        placeN = [6, 4, 4] as Array<Number>;
        tempSum_c = 29.0 * 14;
        tempN = 14;
        sleep_h = 6.4;
        sleepDay = null;
    }

    private function num(key as String, fallback as Number) as Number {
        var v = Application.Storage.getValue(key);
        return (v instanceof Lang.Number) ? v : fallback;
    }

    private function arr(key as String) as Array {
        var v = Application.Storage.getValue(key);
        if (v instanceof Lang.Array) { return v as Array; }
        return [] as Array;
    }
}
