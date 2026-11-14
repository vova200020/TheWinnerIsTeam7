import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Calm always-on companion of FocusPeak: date, time, one readiness ring, one short line.
// All positions are fractions of the screen size, so 260 px (Fenix 7 Pro) and 416 px (Forerunner 265) both fit.
class FocusPeakFaceView extends WatchUi.WatchFace {
    // Vertical positions as a share of the height. They keep each line inside the round safe area.
    const Y_DATE = 0.28;
    const Y_TIME = 0.50;
    const Y_READY = 0.72;

    const C_GOOD = Graphics.COLOR_GREEN;
    const C_WARN = Graphics.COLOR_YELLOW;     // 0xFFAA00: amber on these displays
    const C_BAD = Graphics.COLOR_RED;
    const C_TEXT = Graphics.COLOR_WHITE;
    const C_DIM = Graphics.COLOR_LT_GRAY;
    const C_TRACK = Graphics.COLOR_DK_GRAY;

    // Thin ring: the face is a glance, the ring must not compete with the time.
    const RING_PEN_DIVISOR = 52;
    // Burn-in shift step: the low-power time moves by this share of the width each minute.
    const SHIFT_DIVISOR = 40;
    const MINUTES_PER_HOUR = 60;
    const NO_MINUTE = -1;

    private var _sleeping as Boolean = false;
    // Minute of the day of the last SensorHistory read: one read per minute keeps the face cheap.
    private var _cacheMinute as Number = NO_MINUTE;
    private var _cacheScore as Number? = null;

    function initialize() {
        WatchFace.initialize();
    }

    // Low power: the system updates the face once per minute and expects few lit pixels.
    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();
        var timeText = formatTime(clock.hour, clock.min, settings.is24Hour);

        if (_sleeping) {
            drawSleepTime(dc, timeText, clock.min, needsBurnInProtection(settings));
            return;
        }

        var minuteOfDay = clock.hour * MINUTES_PER_HOUR + clock.min;
        if (minuteOfDay != _cacheMinute) {
            _cacheScore = FaceScore.readiness(readBodyBattery(), readStress());
            _cacheMinute = minuteOfDay;
        }
        var score = _cacheScore;

        drawRing(dc, score);
        line(dc, Y_DATE, Graphics.FONT_TINY, dateText(), C_DIM);
        line(dc, Y_TIME, Graphics.FONT_NUMBER_HOT, timeText, C_TEXT);
        if (score != null) {
            line(dc, Y_READY, Graphics.FONT_XTINY, FaceScore.word(score) + " " + score.format("%d"), C_DIM);
        }
    }

    // Only the time, smaller and dim. On AMOLED it also moves a few pixels each minute against burn-in.
    private function drawSleepTime(dc as Graphics.Dc, timeText as String, minute as Number, burnIn as Boolean) as Void {
        var w = dc.getWidth();
        var x = w / 2;
        var y = (dc.getHeight() * Y_TIME).toNumber();
        var font = Graphics.FONT_NUMBER_MEDIUM;
        if (burnIn) {
            var step = w / SHIFT_DIVISOR;
            x += (minute % 3 - 1) * step;
            y += ((minute / 3) % 3 - 1) * step;
            font = Graphics.FONT_NUMBER_MILD;
        }
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, timeText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function needsBurnInProtection(settings as System.DeviceSettings) as Boolean {
        if (settings has :requiresBurnInProtection) {
            return settings.requiresBurnInProtection == true;
        }
        return false;
    }

    private function formatTime(hour as Number, minute as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var h12 = hour % 12;
        if (h12 == 0) { h12 = 12; }
        return h12.format("%d") + ":" + minute.format("%02d");
    }

    // For example "SAT 14".
    private function dateText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return (info.day_of_week as String).toUpper() + " " + (info.day as Number).format("%d");
    }

    private function readBodyBattery() as Number? {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            return firstValue(SensorHistory.getBodyBatteryHistory({ :period => 1 }));
        }
        return null;
    }

    private function readStress() as Number? {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            return firstValue(SensorHistory.getStressHistory({ :period => 1 }));
        }
        return null;
    }

    // The newest sample, or null: the iterator, the sample and its data can each be missing.
    private function firstValue(it as SensorHistory.SensorHistoryIterator?) as Number? {
        if (it == null) { return null; }
        var s = it.next();
        if (s == null || s.data == null) { return null; }
        return (s.data as Numeric).toNumber();
    }

    private function levelColor(score as Number) as Graphics.ColorType {
        var lv = FaceScore.level(score);
        if (lv == FaceScore.LEVEL_GOOD) { return C_GOOD; }
        if (lv == FaceScore.LEVEL_FAIR) { return C_WARN; }
        return C_BAD;
    }

    // Grey track always; the colored arc only when a score exists, clockwise from 12 o'clock.
    private function drawRing(dc as Graphics.Dc, score as Number?) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var pen = w / RING_PEN_DIVISOR;
        if (pen < 2) { pen = 2; }
        var r = w / 2 - pen / 2 - 1;
        dc.setPenWidth(pen);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        if (score != null) {
            var deg = 360 * score / FaceScore.SCORE_MAX;
            dc.setColor(levelColor(score), Graphics.COLOR_TRANSPARENT);
            if (deg >= 360) {
                dc.drawCircle(cx, cy, r);
            } else if (deg > 0) {
                // drawArc with equal start and end draws a full circle, so deg 0 draws nothing.
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, (90 - deg + 360) % 360);
            }
        }
        dc.setPenWidth(1);
    }

    private function line(dc as Graphics.Dc, yShare as Float, font as Graphics.FontType,
                          text as String, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, (dc.getHeight() * yShare).toNumber(), font, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
