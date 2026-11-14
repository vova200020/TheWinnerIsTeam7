import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One view. Each screen: a ring, one label, one big value, at most two short lines.
// All positions are fractions of the screen size, so 260 px (Fenix 7 Pro) and 416 px (Forerunner 265) both fit.
class FocusView extends WatchUi.View {
    // Vertical positions as a share of the height. They keep each line inside the round safe area.
    const Y_TAG = 0.12;
    const Y_LABEL = 0.23;
    const Y_BIG = 0.46;
    const Y_SUB = 0.69;
    const Y_HINT = 0.81;
    const Y_DOTS = 0.91;
    // Three-row screens (Your Best, Inputs).
    const Y_ROW1 = 0.38;
    const Y_ROW2 = 0.53;
    const Y_ROW3 = 0.68;

    const SPO2_LOW_PCT = 92;                  // below this the Pulse Ox value shows as a warning

    // State colors come from the shared term table, so the wrist and the phone match.
    const C_GOOD = Terms.C_REST;
    const C_WARN = Terms.C_EARN;
    const C_BAD = Terms.C_BAD;
    const C_CALM = Terms.C_FOCUS;
    const C_TEXT = Graphics.COLOR_WHITE;
    const C_DIM = Graphics.COLOR_LT_GRAY;
    const C_TRACK = Graphics.COLOR_DK_GRAY;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        getApp().viewVisible = true;
    }

    function onHide() as Void {
        getApp().viewVisible = false;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var app = getApp();
        var s = app.session;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (s.state == ST_READY) {
            if (app.page == 1) { drawBest(dc, app); }
            else if (app.page == 2) { drawInputs(dc, app); }
            else if (app.page == app.PAGE_SETTINGS) { drawSettings(dc, app); }
            else { drawReady(dc, app); }
            dots(dc, app.page, app.PAGE_COUNT);
        }
        else if (s.state == ST_FOCUS) { drawFocus(dc, app); }
        else if (s.state == ST_EARN) { drawEarn(dc, app); }
        else if (s.state == ST_BREAK) { drawBreak(dc, app); }
        else { drawSummary(dc, app); }

        if (app.store.demo) { line(dc, Y_TAG, Graphics.FONT_XTINY, "DEMO", C_WARN); }
    }

    private function drawReady(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var score = app.readyScore;
        var color = levelColor(score);
        ring(dc, score / 100.0, color);
        chip(dc, Y_LABEL, Terms.READY, Terms.C_NEUTRAL);
        line(dc, Y_BIG, Graphics.FONT_NUMBER_THAI_HOT, score.format("%d"), color);
        line(dc, Y_SUB, Graphics.FONT_TINY, Scoring.tip(app.readyParts), C_TEXT);
        chipValue(dc, Y_HINT, Terms.BLOCK, Terms.C_FOCUS, app.store.blockMin + " min");
    }

    // The personal baseline: best part of the day, best place, own block length.
    private function drawBest(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var st = app.store;
        ring(dc, Scoring.progress(st.total, Baseline.LEARN_SESSIONS), C_CALM);
        line(dc, Y_LABEL, Graphics.FONT_XTINY, "YOUR BEST", C_DIM);
        var part = Baseline.bestIndex(st.partSum, st.partN);
        if (part < 0) {
            line(dc, Y_ROW2, Graphics.FONT_SMALL, "Learning you", C_TEXT);
            line(dc, Y_ROW3, Graphics.FONT_XTINY, "first " + Baseline.LEARN_SESSIONS + " blocks", C_DIM);
            return;
        }
        var partMean = Baseline.meanOf(st.partSum[part], st.partN[part]);
        row(dc, Y_ROW1, Baseline.PART_NAMES[part], partMean);
        var place = Baseline.bestIndex(st.placeSum, st.placeN);
        if (place >= 0) {
            row(dc, Y_ROW2, st.placeName[place], Baseline.meanOf(st.placeSum[place], st.placeN[place]));
        } else {
            line(dc, Y_ROW2, Graphics.FONT_XTINY, "No place yet", C_DIM);
        }
        chipValue(dc, Y_ROW3, Terms.BLOCK, Terms.C_FOCUS, st.blockMin + " min");
        var seen = st.total < Baseline.LEARN_SESSIONS ? st.total : Baseline.LEARN_SESSIONS;
        line(dc, Y_HINT, Graphics.FONT_XTINY, seen + " of " + Baseline.LEARN_SESSIONS + " blocks", C_DIM);
    }

    // What the readiness score reads now: one line per group of sensors.
    private function drawInputs(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var sn = app.sensors;
        ring(dc, 0.0, C_TRACK);
        var lk = app.link;
        if (lk.enabled || lk.serverOn) {
            // Debug view of the link: messages sent, messages failed, last server code.
            line(dc, Y_LABEL, Graphics.FONT_XTINY, "LINK " + lk.sent + " ok " + lk.failed + " err " + lk.lastCode,
                 lk.failed > 0 ? C_WARN : C_GOOD);
        } else {
            line(dc, Y_LABEL, Graphics.FONT_XTINY, "INPUTS", C_DIM);
        }
        line(dc, Y_ROW1, Graphics.FONT_TINY, "HR " + numText(sn.hr_bpm) + "  Stress " + numText(sn.stress_0_100), C_TEXT);
        var temp = sn.temp_c;
        var spo2 = sn.spo2_pct;
        var spo2Low = spo2 != null && spo2 < SPO2_LOW_PCT;
        line(dc, Y_ROW2, Graphics.FONT_TINY,
             "Battery " + numText(sn.bodyBattery_0_100) + "  SpO2 " + numText(spo2) + "%",
             spo2Low ? C_WARN : C_TEXT);
        var dnd = sn.dndOn;
        var placeText = app.place >= 0 ? app.store.placeName[app.place] : (sn.lat_deg != null ? "New place" : "No GPS");
        line(dc, Y_ROW3, Graphics.FONT_TINY, "DND " + (dnd != null && dnd ? "on" : "off") + "  " + placeText,
             dnd != null && dnd ? C_TEXT : C_WARN);
        var alt = sn.altitude_m;
        var sleep = app.store.sleepFor(app.today());
        line(dc, Y_HINT, Graphics.FONT_XTINY,
             (temp != null ? temp.format("%.0f") : "--") + " C  " + (alt != null ? alt.format("%.0f") : "--") + " m  " + (sleep != null ? sleep.format("%.1f") : "--") + " h", C_DIM);
    }

    // The same menu as "hold UP", reachable with a normal START press.
    private function drawSettings(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var st = app.store;
        ring(dc, 0.0, C_TRACK);
        line(dc, Y_LABEL, Graphics.FONT_XTINY, "SETTINGS", C_DIM);
        line(dc, Y_ROW1, Graphics.FONT_TINY, "Demo " + onOff(st.demo), st.demo ? C_WARN : C_TEXT);
        line(dc, Y_ROW2, Graphics.FONT_TINY, "Phone link " + onOff(st.linkOn), C_TEXT);
        line(dc, Y_ROW3, Graphics.FONT_TINY, "Server link " + onOff(st.serverOn), C_TEXT);
        line(dc, Y_HINT, Graphics.FONT_XTINY, "START to change", C_DIM);
    }

    private function onOff(on as Boolean) as String {
        return on ? "on" : "off";
    }

    private function drawFocus(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var s = app.session;
        ring(dc, Scoring.progress(s.elapsed_s, s.planned_s), C_CALM);
        chip(dc, Y_LABEL, Terms.FOCUS, Terms.C_FOCUS);
        var left_s = s.focusLeft_s();
        if (app.store.demo) {
            line(dc, Y_BIG, Graphics.FONT_NUMBER_HOT, clock(left_s), C_TEXT);
            line(dc, Y_SUB, Graphics.FONT_XTINY, "left", C_DIM);
        } else {
            // Minutes only: a seconds counter pulls the eye, and this screen must stay calm.
            line(dc, Y_BIG, Graphics.FONT_NUMBER_THAI_HOT, ((left_s + 59) / 60).format("%d"), C_TEXT);
            line(dc, Y_SUB, Graphics.FONT_XTINY, "min left", C_DIM);
        }
        if (app.restlessShow_s > 0) { line(dc, Y_HINT, Graphics.FONT_XTINY, "Restless", C_WARN); }
    }

    private function drawEarn(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var s = app.session;
        var hr = app.sensors.hr_bpm;
        var reached = hr != null && hr >= s.target_bpm;
        var color = reached ? C_GOOD : C_WARN;
        var frac = hr != null ? Scoring.progress(hr - s.rest_bpm, s.target_bpm - s.rest_bpm) : 0.0;
        ring(dc, frac, color);
        chip(dc, Y_LABEL, Terms.EARN, Terms.C_EARN);
        line(dc, Y_BIG, Graphics.FONT_NUMBER_THAI_HOT, hr != null ? hr.format("%d") : "--", color);
        line(dc, Y_SUB, Graphics.FONT_XTINY, "target " + s.target_bpm + " bpm", C_DIM);
        if (reached) {
            line(dc, Y_HINT, Graphics.FONT_XTINY, "Hold " + (s.gateHold_s - s.hold_s) + " s", C_GOOD);
        } else if (app.climbed_m > 0) {
            line(dc, Y_HINT, Graphics.FONT_XTINY, "Stairs " + app.climbed_m + " of " + Baseline.GATE_CLIMB_M + " m", C_DIM);
        }
    }

    private function drawBreak(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var s = app.session;
        ring(dc, Scoring.progress(s.breakLeft_s, s.break_s), C_GOOD);
        chip(dc, Y_LABEL, Terms.BREAK, Terms.C_REST);
        line(dc, Y_BIG, Graphics.FONT_NUMBER_HOT, clock(s.breakLeft_s), C_TEXT);
        line(dc, Y_SUB, Graphics.FONT_TINY, s.gateSkipped ? "Gate skipped" : "Phone earned", s.gateSkipped ? C_WARN : C_GOOD);
        // Live recovery: the heart rate comes down, the steps of an active break go up.
        var hr = app.sensors.hr_bpm;
        if (hr != null) {
            var ok = Scoring.recovered(hr, s.rest_bpm);
            line(dc, Y_HINT, Graphics.FONT_XTINY, hr.format("%d") + " bpm  " + (ok ? "Recovered" : "+" + app.breakSteps + " steps"), ok ? C_GOOD : C_DIM);
        }
    }

    private function drawSummary(dc as Graphics.Dc, app as FocusPeakApp) as Void {
        var s = app.session;
        var color = levelColor(s.score);
        ring(dc, s.score / 100.0, color);
        chip(dc, Y_LABEL, Terms.SCORE, Terms.C_NEUTRAL);
        line(dc, Y_BIG, Graphics.FONT_NUMBER_THAI_HOT, s.score.format("%d"), color);
        var days = app.store.streak_days;
        chipValue(dc, Y_SUB, Terms.STREAK, Terms.C_EARN, days + (days == 1 ? " day" : " days"));
        if (s.penalty > 0) {
            line(dc, Y_HINT, Graphics.FONT_XTINY, "Phone " + app.phoneExits + "x  -" + s.penalty, C_WARN);
        } else {
            chipValue(dc, Y_HINT, Terms.BLOCK, Terms.C_FOCUS, app.store.blockMin + " min");
        }
    }

    private function levelColor(score_0_100 as Number) as Graphics.ColorType {
        if (score_0_100 >= Scoring.LEVEL_GOOD_MIN) { return C_GOOD; }
        if (score_0_100 >= Scoring.LEVEL_FAIR_MIN) { return C_WARN; }
        return C_BAD;
    }

    private function numText(v as Number?) as String {
        return v != null ? v.format("%d") : "--";
    }

    private function clock(t_s as Number) as String {
        if (t_s < 0) { t_s = 0; }
        return (t_s / 60).format("%d") + ":" + (t_s % 60).format("%02d");
    }

    private function line(dc as Graphics.Dc, yShare as Float, font as Graphics.FontType,
                          text as String, color as Graphics.ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, (dc.getHeight() * yShare).toNumber(), font, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A shared term in its box: the same word, color and pill shape as on the phone (see Terms.mc).
    // x: the left edge. Returns the width of the box.
    private function chipAt(dc as Graphics.Dc, x as Number, yCenter as Number, text as String, color as Number) as Number {
        var font = Graphics.FONT_XTINY;
        var w = dc.getWidth();
        var h = dc.getFontHeight(font) + w / 65;
        var boxW = dc.getTextWidthInPixels(text, font) + 2 * (w / 22);
        var y = yCenter - h / 2;
        dc.setColor(Terms.tint(color), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, boxW, h, h / 2);
        dc.setPenWidth(w >= 390 ? 2 : 1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(x, y, boxW, h, h / 2);
        dc.setPenWidth(1);
        dc.drawText(x + boxW / 2, yCenter, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return boxW;
    }

    private function chipWidth(dc as Graphics.Dc, text as String) as Number {
        return dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) + 2 * (dc.getWidth() / 22);
    }

    // A centred term box.
    private function chip(dc as Graphics.Dc, yShare as Float, text as String, color as Number) as Void {
        chipAt(dc, dc.getWidth() / 2 - chipWidth(dc, text) / 2, (dc.getHeight() * yShare).toNumber(), text, color);
    }

    // A term box with its value to the right, centred as one group: "[Block] 24 min".
    private function chipValue(dc as Graphics.Dc, yShare as Float, text as String, color as Number, value as String) as Void {
        var font = Graphics.FONT_XTINY;
        var gap = dc.getWidth() / 40;
        var total = chipWidth(dc, text) + gap + dc.getTextWidthInPixels(value, font);
        var x = dc.getWidth() / 2 - total / 2;
        var yCenter = (dc.getHeight() * yShare).toNumber();
        var boxW = chipAt(dc, x, yCenter, text, color);
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + boxW + gap, yCenter, font, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A name with its mean score, the score in the level color.
    private function row(dc as Graphics.Dc, yShare as Float, name as String, score as Number?) as Void {
        var cx = dc.getWidth() / 2;
        var y = (dc.getHeight() * yShare).toNumber();
        var gap = dc.getWidth() / 40;
        var scoreText = score != null ? score.format("%d") : "--";
        var font = Graphics.FONT_SMALL;
        var total = dc.getTextWidthInPixels(name, font) + gap * 2 + dc.getTextWidthInPixels(scoreText, font);
        var x = cx - total / 2;
        dc.setColor(C_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(score != null ? levelColor(score) : C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + total, y, font, scoreText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Page marker of the Ready screen: UP and DOWN change the page.
    private function dots(dc as Graphics.Dc, page as Number, count as Number) as Void {
        var w = dc.getWidth();
        var step = w / 22;
        var r = w / 90 + 1;
        var x = w / 2 - (step * (count - 1)) / 2;
        var y = (dc.getHeight() * Y_DOTS).toNumber();
        for (var i = 0; i < count; i++) {
            dc.setColor(i == page ? C_TEXT : C_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + i * step, y, r);
        }
    }

    // Progress ring at the edge of the round display, clockwise from 12 o'clock.
    private function ring(dc as Graphics.Dc, frac as Float, color as Graphics.ColorType) as Void {
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var pen = w / 22;
        var r = w / 2 - pen / 2 - 1;
        dc.setPenWidth(pen);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        var deg = (360 * frac).toNumber();
        if (deg <= 0) { dc.setPenWidth(1); return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (deg >= 360) {
            dc.drawCircle(cx, cy, r);
        } else {
            // drawArc with equal start and end draws a full circle, so deg 0 returns above.
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, (90 - deg + 360) % 360);
        }
        dc.setPenWidth(1);
    }
}
