import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.UserProfile;
import Toybox.WatchUi;

// HR-to-unlock, "earn your scroll" (spec §5).
// Target: max(resting + 35, 100) bpm, CAPPED at 60% of age-predicted max (never hard effort).
// Hold 45 s (+15 s for each repeat unlock today). The ring pauses below target, never resets.
// No reliable HR, or the user prefers it → 60 s breathing alternative (accessibility, beta-blockers).
module UnlockFlow {
    const BASE_HOLD = 45;
    const EXTRA_HOLD = 15;
    const UNLOCK_MINS = 5;

    function start(app as String) as Void {
        var view = new UnlockView(app, Store.propBool("unlockAlt", false));
        WatchUi.pushView(view, new UnlockDelegate(view), WatchUi.SLIDE_UP);
    }

    function targetHr() as Number {
        var p = UserProfile.getProfile();
        var resting = (p.restingHeartRate != null) ? p.restingHeartRate as Number : 60;
        var age = 35;
        if (p.birthYear != null) {
            var year = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year as Number;
            var by = p.birthYear as Number;
            if (by > 1900 && by < year) { age = year - by; }
        }
        var cap = ((220 - age) * 0.6).toNumber();
        var demo = Store.propBool("demoMode", false);
        var target = resting + (demo ? 20 : 35);       // stage: ~20 s of jumping jacks
        var floor = demo ? 90 : 100;
        if (target < floor) { target = floor; }
        return (target > cap) ? cap : target;
    }

    function unlocksToday() as Number {
        return (Store.getNum("unlockDay", 0) == Days.today()) ? Store.getNum("unlockCount", 0) : 0;
    }

    // Stage mode: 15 s hold so a judge can do it live; real use: 45 s (+15 per repeat).
    function holdSeconds() as Number {
        if (Store.propBool("demoMode", false)) { return 15; }
        return BASE_HOLD + EXTRA_HOLD * unlocksToday();
    }

    function grant(app as String) as Void {
        Store.put("unlockDay", Days.today());
        Store.put("unlockCount", unlocksToday() + 1);
        Comms.send({ "t" => "unlock_granted", "app" => app, "mins" => UNLOCK_MINS });
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(80, 150),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(80, 300)
            ] as Array<Attention.VibeProfile>);
        }
    }
}

class UnlockView extends WatchUi.View {
    const NO_HR_LIMIT = 10;
    const ALT_SEC = 60;

    var app as String;
    var alt as Boolean;
    var done as Boolean = false;
    var hr as Number? = null;
    var noHrSec as Number = 0;
    private var _target as Number;
    private var _hold as Number;
    private var _held as Number = 0;
    private var _altLeft as Number = ALT_SEC;
    private var _altStartMs as Number = 0;
    private var _timer as Timer.Timer?;

    function initialize(appName as String, useAlt as Boolean) {
        View.initialize();
        app = appName;
        alt = useAlt;
        _target = UnlockFlow.targetHr();
        _hold = UnlockFlow.holdSeconds();
    }

    function onShow() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>);
        var t = new Timer.Timer();
        t.start(method(:onTick), 200, true);
        _timer = t;
    }

    function onHide() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        if (gSession == null) { Sensor.setEnabledSensors([] as Array<Sensor.SensorType>); }
    }

    function switchToAlt() as Void {
        alt = true;
        _altLeft = Store.propBool("demoMode", false) ? 15 : ALT_SEC;
        _altStartMs = System.getTimer();
    }

    private var _tickCount as Number = 0;

    function onTick() as Void {
        _tickCount++;
        if (!done && _tickCount % 5 == 0) {   // once per second
            if (alt) {
                if (_altStartMs == 0) { _altStartMs = System.getTimer(); }
                _altLeft--;
                if (_altLeft <= 0) { succeed(); }
            } else {
                var info = Sensor.getInfo();
                hr = (info.heartRate != null) ? info.heartRate as Number : null;
                if (hr == null) {
                    noHrSec++;   // unreliable signal: never block the user on bad data
                } else {
                    noHrSec = 0;
                    if ((hr as Number) >= _target) { _held++; }
                    if (_held >= _hold) { succeed(); }
                }
            }
        }
        WatchUi.requestUpdate();
    }

    private function succeed() as Void {
        done = true;
        UnlockFlow.grant(app);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (alt && !done) {
            var ms = (_altStartMs == 0) ? 0 : System.getTimer() - _altStartMs;
            BreakFlow.drawBreath(dc, ms, "Unlock: breathe", _altLeft);
            return;
        }

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var r = (cx < cy) ? cx : cy;
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // Progress ring
        dc.setPenWidth(12);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r - 10);
        var frac = done ? 1.0 : _held.toFloat() / _hold;
        if (frac > 0.0) {
            var above = hr != null && (hr as Number) >= _target;
            dc.setColor((done || above) ? FocusUi.C_GOOD : FocusUi.C_WARN,
                Graphics.COLOR_TRANSPARENT);
            var end = 90 - (360 * frac).toNumber();
            if (frac >= 1.0) {
                dc.drawCircle(cx, cy, r - 10);
            } else {
                dc.drawArc(cx, cy, r - 10, Graphics.ARC_CLOCKWISE, 90, (end < 0) ? end + 360 : end);
            }
        }

        if (done) {
            FocusUi.chip(dc, cx, cy - (r * 0.30).toNumber(), "Break", FocusUi.C_GOOD);
            dc.setColor(FocusUi.C_FG, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "Unlocked", j);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + 20, Graphics.FONT_XTINY, shortApp() + " for " + UnlockFlow.UNLOCK_MINS + " min", j);
            return;
        }

        FocusUi.chip(dc, cx, cy - (r * 0.55).toNumber(), "Move to unlock", FocusUi.C_WARN);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (r * 0.15).toNumber(), Graphics.FONT_NUMBER_MEDIUM,
            (hr != null) ? (hr as Number).format("%d") : "--", j);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.17).toNumber(), Graphics.FONT_XTINY, shortApp() + ": target " + _target + " bpm", j);
        dc.drawText(cx, cy + (r * 0.35).toNumber(), Graphics.FONT_XTINY, "hold " + (_hold - _held) + " s more", j);

        if (noHrSec >= NO_HR_LIMIT) {
            dc.setColor(FocusUi.C_WARN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (r * 0.56).toNumber(), Graphics.FONT_XTINY, "No HR. START: breathe", j);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (r * 0.56).toNumber(), Graphics.FONT_XTINY, "START: breathe instead", j);
        }
    }

    private function shortApp() as String {
        // "com.instagram.android" → "instagram"
        var s = app;
        var i = s.find(".");
        if (i != null) {
            s = s.substring(i + 1, s.length()) as String;
            var k = s.find(".");
            if (k != null) { s = s.substring(0, k) as String; }
        }
        return s;
    }
}

class UnlockDelegate extends WatchUi.BehaviorDelegate {
    private var _view as UnlockView;

    function initialize(view as UnlockView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        if (_view.done) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (!_view.alt) {
            _view.switchToAlt();
        }
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
