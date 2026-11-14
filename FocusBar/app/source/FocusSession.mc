import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// A running focus session (spec §3.3–3.4).
//
// Live score = the pre-session readiness score (background) + live deviation from this
// session's own first minutes:
//   raw = 0.45·z(RMSSD) + 0.25·(−z(HR)) + 0.30·stillness      (renormalised over what's available)
//   target = startScore + 15·raw, then EMA α = 0.3 every 10 s.
// Recorded as an activity with a per-second custom FIT field so it shows in Garmin Connect.
class FocusSession {
    const IBI_MAX = 90;               // ≈ 60–90 s of beats
    const DROP_POINTS = 15;
    const SNOOZE_SEC = 15 * 60;

    // Setup
    var tagIdx as Number;
    var lenMin as Number;             // 0 = open
    var level as Number;              // 0 light, 1 medium, 2 deep
    var demo as Boolean;
    var startHour as Number;

    // Live state
    var elapsed as Number = 0;        // active seconds (breaks excluded)
    var score as Float = 50.0;
    var hr as Number? = null;
    var rmssd as Float? = null;
    var calibrating as Boolean = true;
    var onBreak as Boolean = false;
    var breaks as Number = 0;
    var nudges as Number = 0;
    var toast as String? = null;
    var toastUntil as Number = 0;

    // Stats
    private var _sum as Float = 0.0;
    private var _n as Number = 0;
    private var _peak as Number = 0;
    private var _low as Number = 100;
    private var _startEpoch as Number = 0;
    private var _hrSum as Number = 0;
    private var _hrN as Number = 0;
    private var _hrMax as Number = 0;
    private var _rmSum as Float = 0.0;
    private var _rmN as Number = 0;
    private var _firstNudgeMin as Number = -1;
    // One GPS fix per session (spec §3.3), not continuous tracking: battery + privacy.
    private var _lat as Float? = null;
    private var _lon as Float? = null;
    private var _gpsOn as Boolean = false;
    // Focus curve: one averaged point per bucket (60 s; 10 s on stage), max 180 points.
    private var _curve as Array<Number> = [] as Array<Number>;
    private var _bucketSec as Number = 60;
    private var _bucketSum as Float = 0.0;
    private var _bucketN as Number = 0;

    // Baseline (first minutes of the session)
    private var _baseSec as Number;
    private var _every as Number;       // score update period (s)
    private var _bRm as Array<Float> = [] as Array<Float>;
    private var _bHr as Array<Float> = [] as Array<Float>;
    private var _rmMean as Float = 0.0;
    private var _rmSd as Float = 1.0;
    private var _hrMean as Float = 0.0;
    private var _hrSd as Float = 1.0;

    // Break-nudge state
    private var _firstWindowSec as Number;
    private var _sustainSec as Number;
    private var _firstSum as Float = 0.0;
    private var _firstN as Number = 0;
    private var _firstAvg as Float? = null;
    private var _dropSec as Number = 0;
    private var _snoozeUntil as Number = 0;
    private var _fadeNudged as Boolean = false;
    private var _lenNotified as Boolean = false;
    private var _demoDipDone as Boolean = false;

    // Sensors
    private var _ibi as Array<Number> = [] as Array<Number>;
    private var _accSum as Float = 0.0;
    private var _accSumSq as Float = 0.0;
    private var _accN as Number = 0;
    private var _stillness as Float? = null;

    private var _timer as Timer.Timer?;
    private var _rec as ActivityRecording.Session?;
    private var _scoreField as FitContributor.Field?;
    private var _avgField as FitContributor.Field?;

    function initialize(tag as Number, len as Number, lvl as Number) {
        tagIdx = tag;
        lenMin = len;
        level = lvl;
        demo = Store.propBool("demoMode", false);
        startHour = Days.hourNow();
        // Demo mode compresses the timeline so the whole story fits in a 3-minute pitch.
        // Stage timeline: calibrate 10 s, dip at 30 s, "Take 5?" at ~45–55 s.
        _every = demo ? 5 : 10;
        _bucketSec = demo ? 10 : 60;
        _baseSec = demo ? 10 : 180;
        _firstWindowSec = demo ? 20 : 600;
        _sustainSec = demo ? 10 : 300;
        var s = FocusScore.lastScore();
        score = ((s != null) ? s : 55).toFloat();
    }

    function tagName() as String {
        return SessionSetup.TAGS[tagIdx] as String;
    }

    // ---------------------------------------------------------------- lifecycle

    function begin() as Void {
        Store.put("sessionActive", true);
        _startEpoch = Time.now().value();
        startRecording();
        if (Toybox has :Position) {
            try {
                Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
                _gpsOn = true;
            } catch (e) {
            }
        }
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>);
        if (Sensor has :registerSensorDataListener) {
            try {
                Sensor.registerSensorDataListener(method(:onSensorData), {
                    :period => 1,
                    :accelerometer => { :enabled => true, :sampleRate => 25 },
                    :heartBeatIntervals => { :enabled => true }
                });
            } catch (e) {
                // Sensor busy/unsupported: we still have HR from Sensor.Info.
            }
        }
        var t = new Timer.Timer();
        t.start(method(:onSecond), 1000, true);
        _timer = t;
        Comms.send({ "t" => "session_start", "tag" => tagName().toLower(),
                     "level" => Comms.levelName(level), "len" => lenMin });
    }

    private function startRecording() as Void {
        if (!(Toybox has :ActivityRecording)) { return; }
        try {
            var rec = ActivityRecording.createSession({
                :name => "Focus",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            });
            _scoreField = rec.createField("focus_score", 0, FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "pts" });
            _avgField = rec.createField("avg_focus", 1, FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "pts" });
            rec.start();
            _rec = rec;
        } catch (e) {
            _rec = null;   // e.g. another activity is recording; the session still works
        }
    }

    function onPosition(info as Position.Info) as Void {
        _gpsOn = false;
        if (info.position == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) { return; }
        var deg = (info.position as Position.Location).toDegrees();
        _lat = deg[0].toFloat();
        _lon = deg[1].toFloat();
    }

    // Stops everything. save=false discards the activity.
    function finish(save as Boolean) as Void {
        if (_gpsOn) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
            _gpsOn = false;
        }
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        if (Sensor has :unregisterSensorDataListener) { Sensor.unregisterSensorDataListener(); }
        Sensor.setEnabledSensors([] as Array<Sensor.SensorType>);
        if (_rec != null) {
            var rec = _rec as ActivityRecording.Session;
            try {
                if (rec.isRecording()) { rec.stop(); }
                if (save && elapsed >= 60) {
                    if (_avgField != null) { (_avgField as FitContributor.Field).setData(avgScore()); }
                    rec.save();
                } else {
                    rec.discard();
                }
            } catch (e) {
            }
            _rec = null;
        }
        Store.put("sessionActive", false);
    }

    // ---------------------------------------------------------------- breaks

    function startBreak() as Void {
        onBreak = true;
        breaks++;
        if (_rec != null && (_rec as ActivityRecording.Session).isRecording()) {
            (_rec as ActivityRecording.Session).stop();   // pauses the timer
        }
    }

    function endBreak() as Void {
        onBreak = false;
        _dropSec = 0;
        _demoDipDone = true;
        score = (score + 15.0 > 100.0) ? 100.0 : score + 15.0;   // fresh start after a break
        if (_rec != null && !(_rec as ActivityRecording.Session).isRecording()) {
            (_rec as ActivityRecording.Session).start();
        }
    }

    function keepGoing() as Void {
        _snoozeUntil = elapsed + SNOOZE_SEC;
        _dropSec = 0;
    }

    // ---------------------------------------------------------------- sensors

    function onSensorData(data as Sensor.SensorData) as Void {
        var hrd = data.heartRateData;
        if (hrd != null && hrd.heartBeatIntervals != null) {
            var beats = hrd.heartBeatIntervals as Array<Number>;
            for (var i = 0; i < beats.size(); i++) {
                var b = beats[i];
                if (b != null && b > 300 && b < 2000) { _ibi.add(b); }   // drop artifacts
            }
            if (_ibi.size() > IBI_MAX) { _ibi = _ibi.slice(_ibi.size() - IBI_MAX, null); }
        }
        var acc = data.accelerometerData;
        if (acc != null && acc.x != null && acc.y != null && acc.z != null) {
            var xs = acc.x as Array<Number>;
            var ys = acc.y as Array<Number>;
            var zs = acc.z as Array<Number>;
            var n = xs.size();
            if (ys.size() < n) { n = ys.size(); }
            if (zs.size() < n) { n = zs.size(); }
            for (var i = 0; i < n; i++) {
                var x = xs[i].toFloat();
                var y = ys[i].toFloat();
                var z = zs[i].toFloat();
                var m = Math.sqrt(x * x + y * y + z * z).toFloat();
                _accSum += m;
                _accSumSq += m * m;
                _accN++;
            }
        }
    }

    // ---------------------------------------------------------------- per second

    function onSecond() as Void {
        var info = Sensor.getInfo();
        hr = (info.heartRate != null) ? info.heartRate as Number : null;
        if (hr != null && !onBreak) {
            var h = hr as Number;
            _hrSum += h;
            _hrN++;
            if (h > _hrMax) { _hrMax = h; }
        }

        if (!onBreak) {
            elapsed++;
            if (elapsed % _every == 0) {
                updateScore();
                checkNudges();
            }
            if (_scoreField != null) {
                (_scoreField as FitContributor.Field).setData(score.toNumber());
            }
            if (lenMin > 0 && !_lenNotified && elapsed >= lenMin * 60) {
                _lenNotified = true;
                vibrate(2);
                showToast("Goal reached!");
            }
        }
        if (toast != null && System.getTimer() > toastUntil) { toast = null; }
        WatchUi.requestUpdate();
    }

    private function updateScore() as Void {
        rmssd = computeRmssd();
        _stillness = computeStillness();

        if (calibrating) {
            if (rmssd != null) { _bRm.add(rmssd as Float); }
            if (hr != null) { _bHr.add((hr as Number).toFloat()); }
            if (elapsed >= _baseSec) {
                var r = meanSd(_bRm, 3.0);
                _rmMean = r[0];
                _rmSd = r[1];
                var h = meanSd(_bHr, 2.0);
                _hrMean = h[0];
                _hrSd = h[1];
                calibrating = false;
            }
        }

        var raw = 0.0;
        var w = 0.0;
        if (!calibrating) {
            if (rmssd != null && _bRm.size() >= 3) {
                raw += 0.45 * clamp3(((rmssd as Float) - _rmMean) / _rmSd);
                w += 0.45;
            }
            if (hr != null && _bHr.size() >= 3) {
                raw += 0.25 * -clamp3(((hr as Number) - _hrMean) / _hrSd);
                w += 0.25;
            }
        }
        if (_stillness != null) {
            raw += 0.30 * (_stillness as Float);
            w += 0.30;
        }
        var startScore = FocusScore.lastScore();
        var anchor = ((startScore != null) ? startScore : 55).toFloat();
        var target = anchor + ((w > 0.0) ? 15.0 * raw / w : 0.0);

        if (demo && !_demoDipDone && elapsed >= 30) {
            target -= 35.0;   // scripted dip so the break nudge fires during the pitch
        }

        var alpha = demo ? 0.5 : 0.3;
        score = (1.0 - alpha) * score + alpha * target;
        if (score < 0.0) { score = 0.0; }
        if (score > 100.0) { score = 100.0; }

        var s = score.toNumber();
        _sum += score;
        _n++;
        if (s > _peak) { _peak = s; }
        if (s < _low) { _low = s; }
        if (rmssd != null) {
            _rmSum += rmssd as Float;
            _rmN++;
        }
        _bucketSum += score;
        _bucketN++;
        if (elapsed % _bucketSec == 0 && _bucketN > 0 && _curve.size() < 180) {
            _curve.add((_bucketSum / _bucketN).toNumber());
            _bucketSum = 0.0;
            _bucketN = 0;
        }
    }

    // RMSSD over the beat buffer, in ms.
    private function computeRmssd() as Float? {
        var n = _ibi.size();
        if (n < 10) { return null; }
        var sum = 0.0;
        for (var i = 1; i < n; i++) {
            var d = (_ibi[i] - _ibi[i - 1]).toFloat();
            sum += d * d;
        }
        return Math.sqrt(sum / (n - 1)).toFloat();
    }

    // Inverted U (spec §1.1): moderately still is best; dead still may mean drowsy.
    // Std-dev of accel magnitude over the last 10 s, in milli-g.
    private function computeStillness() as Float? {
        if (_accN < 20) { return null; }
        var mean = _accSum / _accN;
        var variance = _accSumSq / _accN - mean * mean;
        var sd = (variance > 0.0) ? Math.sqrt(variance).toFloat() : 0.0;
        _accSum = 0.0;
        _accSumSq = 0.0;
        _accN = 0;
        if (sd < 8.0) { return 0.3; }      // very still: fine, but watch for drowsiness
        if (sd < 60.0) { return 1.0; }     // calm, small movements (typing, writing)
        if (sd < 180.0) { return 0.0; }
        return -1.5;                       // fidgeting / moving around
    }

    // ---------------------------------------------------------------- nudges (spec §3.4)

    private function checkNudges() as Void {
        if (elapsed <= _firstWindowSec) {
            _firstSum += score;
            _firstN++;
            return;
        }
        if (_firstAvg == null && _firstN > 0) { _firstAvg = _firstSum / _firstN; }

        if (_firstAvg != null && score <= (_firstAvg as Float) - DROP_POINTS) {
            _dropSec += _every;
        } else {
            _dropSec = 0;
        }
        if (elapsed < _snoozeUntil) { return; }

        if (_dropSec >= _sustainSec) {
            Progress.learnFade(elapsed / 60);
            nudge();
        } else if (!demo && !_fadeNudged && elapsed >= Progress.fadeMinutes() * 60) {
            _fadeNudged = true;
            nudge();
        }
    }

    private function nudge() as Void {
        nudges++;
        if (_firstNudgeMin < 0) { _firstNudgeMin = elapsed / 60; }
        _dropSec = 0;
        _snoozeUntil = elapsed + SNOOZE_SEC;   // no double nudge while the prompt is open
        vibrate(1);
        BreakFlow.showNudge();
    }

    // ---------------------------------------------------------------- summary

    function avgScore() as Number {
        return (_n > 0) ? (_sum / _n).toNumber() : score.toNumber();
    }

    function summary() as Dictionary {
        return {
            "min" => elapsed / 60,
            "sec" => elapsed,
            "start" => _startEpoch,
            "avg" => avgScore(),
            "peak" => (_peak > 0) ? _peak : score.toNumber(),
            "low" => (_n > 0) ? _low : score.toNumber(),
            "breaks" => breaks,
            "nudges" => nudges,
            "fade" => _firstNudgeMin,
            "hr" => (_hrN > 0) ? _hrSum / _hrN : 0,
            "hrmax" => _hrMax,
            "hrv" => (_rmN > 0) ? (_rmSum / _rmN).toNumber() : 0,
            "curve" => _curve,
            "step" => _bucketSec,
            "level" => level,
            "hour" => startHour,
            "tag" => tagName(),
            "len" => lenMin,
            "lat" => _lat,
            "lon" => _lon
        };
    }

    // ---------------------------------------------------------------- helpers

    function showToast(msg as String) as Void {
        toast = msg;
        toastUntil = System.getTimer() + 4000;
    }

    private function vibrate(times as Number) as Void {
        if (!(Attention has :vibrate)) { return; }
        var p = [new Attention.VibeProfile(70, 300)] as Array<Attention.VibeProfile>;
        if (times > 1) {
            p.add(new Attention.VibeProfile(0, 200));
            p.add(new Attention.VibeProfile(70, 300));
        }
        Attention.vibrate(p);
    }

    private function clamp3(z as Float) as Float {
        return (z > 3.0) ? 3.0 : ((z < -3.0) ? -3.0 : z);
    }

    private function meanSd(a as Array<Float>, floor as Float) as [Float, Float] {
        var n = a.size();
        if (n == 0) { return [0.0, floor]; }
        var sum = 0.0;
        for (var i = 0; i < n; i++) { sum += a[i]; }
        var mean = sum / n;
        var sq = 0.0;
        for (var i = 0; i < n; i++) { sq += (a[i] - mean) * (a[i] - mean); }
        var sd = (n > 1) ? Math.sqrt(sq / (n - 1)).toFloat() : floor;
        return [mean, (sd < floor) ? floor : sd];
    }
}
