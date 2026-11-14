import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// The shell: owns the 1 s timer, feeds the sensors into the session and stores the result.
class FocusPeakApp extends Application.AppBase {
    // Demo mode timings: the whole loop fits into one minute of a pitch.
    const DEMO_FOCUS_S = 30;
    const DEMO_BREAK_S = 15;
    const DEMO_GATE_HOLD_S = 3;
    const GATE_HOLD_S = 10;             // seconds at the target heart rate that open the gate
    const READY_REFRESH_S = 60;         // readiness inputs change slowly, and history reads are slow on a real watch
    const RESTLESS_SHOW_S = 5;          // how long the "Restless" hint stays on the focus screen
    const PAGE_COUNT = 4;               // Ready screen pages: readiness, your best, inputs, settings
    const PAGE_INPUTS = 2;
    const PAGE_SETTINGS = 3;

    var session as Session;
    var sensors as Sensors;
    var store as Store;
    var recorder as Recorder;
    var link as PhoneLink;

    var readyParts as Array<Number?> = [null, null, null, null, null, null, null] as Array<Number?>;
    var readyScore as Number = Scoring.NEUTRAL_SCORE;
    var restlessShow_s as Number = 0;
    var page as Number = 0;
    var place as Number = -1;           // index of the saved place at the current position, or -1
    var climbed_m as Number = 0;        // metres gained since the gate screen came up
    var breakSteps as Number = 0;       // steps walked since the break began
    var phoneExits as Number = 0;       // times the user left the phone app during this block
    var phoneAway_s as Number = 0;      // seconds away from the phone app during this block
    // False while a menu or a question covers the main view. A redraw request in that time makes
    // the watch restart the menu each second, and the menu then does not react to the buttons.
    var viewVisible as Boolean = true;

    private var _timer as Timer.Timer? = null;
    private var _tickCount as Number = 0;
    private var _gateAlt_m as Float? = null;
    private var _breakSteps0 as Number? = null;

    function initialize() {
        AppBase.initialize();
        session = new Session();
        sensors = new Sensors();
        store = new Store();
        recorder = new Recorder();
        link = new PhoneLink();
    }

    function onStart(state as Dictionary?) as Void {
        sensors.demo = store.demo;
        sensors.start();
        link.enabled = store.linkOn;
        link.serverOn = store.serverOn;
        System.println("start: demo " + store.demo + ", phone link " + store.linkOn + ", server link " + store.serverOn);
        link.start();
        refreshReady();
        var t = new Timer.Timer();
        t.start(method(:onTick), 1000, true);
        _timer = t;
    }

    function onStop(state as Dictionary?) as Void {
        var t = _timer;
        if (t != null) { t.stop(); }
        recorder.finish(false);     // a block that the app exit cuts off is not saved
        sensors.stop();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new FocusView(), new FocusDelegate()];
    }

    function onTick() as Void {
        _tickCount++;
        sensors.setPulseOx(session.state == ST_READY && page == PAGE_INPUTS);
        sensors.sample(session.state);
        if (session.state == ST_READY && _tickCount % READY_REFRESH_S == 0) { refreshReady(); }
        if (session.state == ST_FOCUS) {
            if (sensors.restless) { restlessShow_s = RESTLESS_SHOW_S; }
            else if (restlessShow_s > 0) { restlessShow_s--; }
        }
        climbed_m = 0;
        var alt = sensors.altitude_m;
        var gateAlt = _gateAlt_m;
        if (session.state == ST_EARN && alt != null && gateAlt != null) {
            climbed_m = (alt - gateAlt).toNumber();
        }
        var ev = session.tick(sensors.hr_bpm, sensors.restless, climbed_m);
        var stepsNow = sensors.steps;
        if (session.state != ST_BREAK) {
            _breakSteps0 = null;
            breakSteps = 0;
        } else if (stepsNow != null) {
            var s0 = _breakSteps0;
            if (s0 == null) { s0 = stepsNow; _breakSteps0 = stepsNow; }
            breakSteps = stepsNow - s0;
            if (breakSteps < 0) { breakSteps = 0; }     // the day counter resets at midnight
        }
        if (ev != EV_NONE) { wakeScreen(); }
        if (ev == EV_FOCUS_DONE) {
            _gateAlt_m = sensors.altitude_m;
            vibrate(2);
        } else if (ev == EV_GATE_OPEN) {
            vibrate(1);
        } else if (ev == EV_BREAK_DONE) {
            vibrate(3);
        }
        saveIfFinished();
        link.tick(session, sensors.hr_bpm, breakSteps);
        if (viewVisible && needsRedraw(ev)) { WatchUi.requestUpdate(); }
    }

    // Redraw only when the screen content can have changed: fewer redraws, a calmer and faster app.
    private function needsRedraw(ev as Number) as Boolean {
        if (ev != EV_NONE) { return true; }
        var st = session.state;
        if (st == ST_EARN || st == ST_BREAK) { return true; }                  // live heart rate, countdown
        if (st == ST_FOCUS) {
            return store.demo || restlessShow_s > 0 || session.focusLeft_s() % 60 == 59 || session.elapsed_s % 15 == 0;
        }
        if (st == ST_READY) { return page == PAGE_INPUTS || _tickCount % READY_REFRESH_S == 0; }   // Inputs page is live
        return false;                                                           // Summary does not change
    }

    // The phone app read the sleep of last night from Apple Health and sent the hours.
    function onSleep(hours as Float) as Void {
        store.setSleep(hours, today());
        if (session.state == ST_READY) { refreshReady(); }
    }

    // The phone app saw the user leave it during focus. The backend passes the totals of this block.
    function onPhoneUse(exits as Number, away_s as Number) as Void {
        if (session.state == ST_FOCUS || session.state == ST_EARN || session.state == ST_BREAK) {
            phoneExits = exits;
            phoneAway_s = away_s;
        }
    }

    function today() as Number {
        return Time.today().value() / 86400;
    }

    function refreshReady() as Void {
        sensors.refreshSlow();
        place = store.placeFor(sensors.lat_deg, sensors.lon_deg, false);
        var stress = sensors.stress_0_100;
        var dnd = sensors.dndOn;
        var part = Baseline.dayPart(System.getClockTime().hour);
        var parts = [null, null, null, null, null, null, null] as Array<Number?>;
        parts[Scoring.PART_BODY_BATTERY] = sensors.bodyBattery_0_100;
        parts[Scoring.PART_CALM] = stress != null ? 100 - stress : null;
        parts[Scoring.PART_SLEEP] = Messages.sleepPart(store.sleepFor(today()));
        parts[Scoring.PART_HOUR] = Baseline.meanOf(store.partSum[part], store.partN[part]);
        parts[Scoring.PART_PLACE] = place >= 0 ? Baseline.meanOf(store.placeSum[place], store.placeN[place]) : null;
        parts[Scoring.PART_DND] = dnd != null ? (dnd ? 100 : 0) : null;
        parts[Scoring.PART_TEMP] = Baseline.tempPart(sensors.temp_c, store.usualTemp_c(), store.tempN);
        readyParts = parts;
        readyScore = Scoring.readiness(parts);
    }

    function startFocus() as Void {
        var focus_s = store.demo ? DEMO_FOCUS_S : store.blockMin * 60;
        var break_s = store.demo ? DEMO_BREAK_S : Scoring.breakSeconds(focus_s);
        var rest = sensors.rest_bpm;
        var rest_bpm = rest != null ? rest : Scoring.DEFAULT_REST_BPM;
        session.start(focus_s, break_s, Scoring.gateTarget(rest),
                      store.demo ? DEMO_GATE_HOLD_S : GATE_HOLD_S, rest_bpm);
        restlessShow_s = 0;
        phoneExits = 0;
        phoneAway_s = 0;
        page = 0;
        _gateAlt_m = null;
        // A running recording makes the watch treat the block like an activity, so its display setting
        // for activities (always on) applies. A demo block is recorded too, but it is discarded at the end.
        recorder.start();
        vibrate(1);
    }

    function saveIfFinished() as Void {
        if (session.state == ST_SUMMARY && !session.saved) {
            session.applyPenalty(Scoring.phonePenalty(phoneExits, phoneAway_s));
            place = store.placeFor(sensors.lat_deg, sensors.lon_deg, true);
            store.addSession(session.score, session.completed, session.gateSkipped,
                             today(),
                             Baseline.dayPart(System.getClockTime().hour), place, sensors.temp_c);
            session.saved = true;
            recorder.finish(!store.demo);
            link.sendSummary(Messages.summary(session.score, (session.elapsed_s + 59) / 60,
                                              place >= 0 ? store.placeName[place] : "",
                                              store.streak_days, store.blockMin));
        }
    }

    function nextPage(step as Number) as Void {
        page = (page + step + PAGE_COUNT) % PAGE_COUNT;
    }

    function setDemo(on as Boolean) as Void {
        store.setDemo(on);
        sensors.demo = on;
        sensors.clearFast();
        sensors.requestFix();
        refreshReady();
    }

    function setLink(on as Boolean) as Void {
        store.setLink(on);
        link.enabled = on;
    }

    function setServer(on as Boolean) as Void {
        store.setServer(on);
        link.serverOn = on;
    }

    function resetData() as Void {
        store.resetData();
        link.enabled = false;
        link.serverOn = false;
        sensors.demo = false;
        sensors.clearFast();
        sensors.requestFix();
        session.reset();
        refreshReady();
    }

    // Lights the screen at each phase change, so the user sees what the vibration means.
    function wakeScreen() as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (e) {
                // An AMOLED watch refuses a backlight that stays on too long (burn-in protection).
                System.println("backlight refused");
            }
        }
    }

    function vibrate(pulses as Number) as Void {
        if (Attention has :vibrate) {
            var pattern = [] as Array<Attention.VibeProfile>;
            for (var i = 0; i < pulses; i++) {
                pattern.add(new Attention.VibeProfile(80, 250));
                pattern.add(new Attention.VibeProfile(0, 150));
            }
            Attention.vibrate(pattern);
        }
    }
}

function getApp() as FocusPeakApp {
    return Application.getApp() as FocusPeakApp;
}
