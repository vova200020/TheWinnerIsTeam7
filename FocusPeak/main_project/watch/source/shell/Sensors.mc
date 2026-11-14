import Toybox.Lang;
import Toybox.Sensor;
import Toybox.SensorHistory;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Position;
import Toybox.System;
import Toybox.UserProfile;

// The one owner of the watch sensors. With demo = true it plays synthetic values with the
// same fields, so every screen works in the simulator and on stage.
class Sensors {
    // Wrist movement between two 1 s samples that counts as restless, summed over x, y, z (milli-g).
    const RESTLESS_DELTA_MG = 250;

    // Demo values: a rested, calm user in a known place, whose heart rate climbs at the break gate.
    const DEMO_REST_BPM = 58;
    const DEMO_CALM_BPM = 64;
    const DEMO_PEAK_BPM = 124;
    const DEMO_RISE_BPM_PER_S = 5;
    const DEMO_FALL_BPM_PER_S = 3;
    const DEMO_BODY_BATTERY = 74;
    const DEMO_STRESS = 22;
    const DEMO_TEMP_C = 29.5;
    const DEMO_SPO2_PCT = 97;
    const DEMO_ALT_M = 1045.0;         // Calgary
    const DEMO_LAT_DEG = 51.0447d;     // the "Library" of the example data
    const DEMO_LON_DEG = -114.0719d;

    var demo as Boolean = false;

    var hr_bpm as Number? = null;
    var restless as Boolean = false;
    var altitude_m as Float? = null;       // barometer
    var temp_c as Float? = null;           // watch temperature sensor (reads warm on the wrist)
    var spo2_pct as Number? = null;        // Pulse Ox
    var steps as Number? = null;           // step count of the day
    var lat_deg as Double? = null;         // GPS, one fix
    var lon_deg as Double? = null;

    var bodyBattery_0_100 as Number? = null;
    var stress_0_100 as Number? = null;
    var dndOn as Boolean? = null;
    var rest_bpm as Number? = null;

    private var _lastAccel_mg as Array<Number>? = null;
    private var _demoTick as Number = 0;

    function initialize() {
    }

    private var _pulseOxOn as Boolean = false;

    function start() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>);
        requestFix();
    }

    // Pulse Ox costs battery and needs a still arm, so it runs only while the Inputs page shows it.
    function setPulseOx(on as Boolean) as Void {
        if (on == _pulseOxOn || !(Sensor has :SENSOR_ONBOARD_PULSE_OXIMETRY)) { return; }
        _pulseOxOn = on;
        var list = [Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>;
        if (on) { list.add(Sensor.SENSOR_ONBOARD_PULSE_OXIMETRY); }
        Sensor.setEnabledSensors(list);
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    // One GPS fix is enough to label the place. GPS then turns itself off.
    function requestFix() as Void {
        if (demo) { return; }
        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        var pos = info.position;
        var acc = info.accuracy;
        if (pos != null && acc != null && acc != Position.QUALITY_NOT_AVAILABLE) {
            var deg = pos.toDegrees();
            lat_deg = deg[0].toDouble();
            lon_deg = deg[1].toDouble();
        }
    }

    // Fast values, once per second.
    function sample(state as Number) as Void {
        if (demo) {
            sampleDemo(state);
            return;
        }
        var info = Sensor.getInfo();
        var hr = info.heartRate;
        if (hr == null) {
            var act = Activity.getActivityInfo();
            if (act != null) { hr = act.currentHeartRate; }
        }
        hr_bpm = hr;
        altitude_m = info.altitude;
        temp_c = info.temperature;
        spo2_pct = info.oxygenSaturation;
        if (state == ST_BREAK || steps == null) { steps = ActivityMonitor.getInfo().steps; }

        var accel = info.accel;
        restless = false;
        if (accel != null && accel.size() >= 3) {
            var last = _lastAccel_mg;
            if (last != null) {
                var delta = absN(accel[0] - last[0]) + absN(accel[1] - last[1]) + absN(accel[2] - last[2]);
                restless = delta > RESTLESS_DELTA_MG;
            }
            _lastAccel_mg = [accel[0], accel[1], accel[2]] as Array<Number>;
        }
    }

    // Slow values for the readiness bar.
    function refreshSlow() as Void {
        if (demo) {
            bodyBattery_0_100 = DEMO_BODY_BATTERY;
            stress_0_100 = DEMO_STRESS;
            dndOn = true;
            rest_bpm = DEMO_REST_BPM;
            temp_c = DEMO_TEMP_C;
            spo2_pct = DEMO_SPO2_PCT;
            altitude_m = DEMO_ALT_M;
            lat_deg = DEMO_LAT_DEG;
            lon_deg = DEMO_LON_DEG;
            return;
        }
        bodyBattery_0_100 = readBodyBattery();
        stress_0_100 = readStress();
        dndOn = System.getDeviceSettings().doNotDisturb;
        rest_bpm = UserProfile.getProfile().restingHeartRate;
    }

    // Used when demo mode changes: demo values must not stay on the real screens.
    function clearFast() as Void {
        hr_bpm = null;
        altitude_m = null;
        temp_c = null;
        spo2_pct = null;
        lat_deg = null;
        lon_deg = null;
    }

    private function sampleDemo(state as Number) as Void {
        _demoTick++;
        var hr = hr_bpm != null ? hr_bpm : DEMO_CALM_BPM;
        if (state == ST_EARN) {
            hr += DEMO_RISE_BPM_PER_S;
            if (hr > DEMO_PEAK_BPM) { hr = DEMO_PEAK_BPM; }
        } else {
            hr -= DEMO_FALL_BPM_PER_S;
            if (hr < DEMO_CALM_BPM) { hr = DEMO_CALM_BPM + (_demoTick % 3); }
        }
        hr_bpm = hr;
        var st = steps != null ? steps : 4000;
        steps = state == ST_BREAK ? st + 2 : st;   // a slow walk in the demo break
        // A short fidget every 20 s, so the stillness part of the score is not a flat 100.
        restless = (state == ST_FOCUS) && (_demoTick % 20 == 0);
    }

    private function readBodyBattery() as Number? {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) { return (s.data as Numeric).toNumber(); }
            }
        }
        return null;
    }

    private function readStress() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info has :stressScore) {
            var score = info.stressScore;
            if (score != null) { return score; }
        }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            var it = SensorHistory.getStressHistory({ :period => 1 });
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) { return (s.data as Numeric).toNumber(); }
            }
        }
        return null;
    }

    private function absN(v as Number) as Number {
        return v < 0 ? -v : v;
    }
}
