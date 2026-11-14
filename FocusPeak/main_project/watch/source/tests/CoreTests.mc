import Toybox.Lang;
import Toybox.Test;

// Known-answer tests of the core. Run: monkeyc -t, then monkeydo /t (simulator open).
module CoreTests {

    (:test)
    function testReadinessIgnoresMissingParts(logger as Test.Logger) as Boolean {
        // Body Battery 80 (weight 25) and calm 60 (weight 20): (80*25 + 60*20) / 45 = 71.1
        var parts = [80, 60, null, null, null, null, null] as Array<Number?>;
        var r = Scoring.readiness(parts);
        logger.debug("readiness = " + r);
        var none = [null, null, null, null, null, null, null] as Array<Number?>;
        return r == 71 && Scoring.readiness(none) == Scoring.NEUTRAL_SCORE;
    }

    (:test)
    function testTipOrder(logger as Test.Logger) as Boolean {
        var stressed = [80, 20, null, null, null, 0, null] as Array<Number?>;
        var dndOff = [80, 80, null, null, null, 0, null] as Array<Number?>;
        var fine = [80, 80, null, null, null, 100, null] as Array<Number?>;
        return Scoring.tip(stressed).equals("Stress high: breathe")
            && Scoring.tip(dndOff).equals("Turn on DND")
            && Scoring.tip(fine).equals("Good to go");
    }

    (:test)
    function testFocusScoreKnownAnswers(logger as Test.Logger) as Boolean {
        // Full block, never restless, calm heart: 100.
        var perfect = Scoring.focusScore(1440, 1440, 0, 65, 60);
        // Half of the block, restless a quarter of the time, no heart rate:
        // completion 50, stillness 50 -> (50*50 + 50*30) / 80 = 50.
        var half = Scoring.focusScore(720, 1440, 180, null, 60);
        logger.debug("perfect = " + perfect + ", half = " + half);
        return perfect == 100 && half == 50;
    }

    (:test)
    function testGateAndBreakRules(logger as Test.Logger) as Boolean {
        return Scoring.gateTarget(55) == 100        // 55 + 30 = 85, the floor of 100 wins
            && Scoring.gateTarget(80) == 110
            && Scoring.gateTarget(null) == 100
            && Scoring.breakSeconds(24 * 60) == 360  // 24 min -> 6 min
            && Scoring.breakSeconds(10 * 60) == 300  // floor 5 min
            && Scoring.breakSeconds(90 * 60) == 900; // cap 15 min
    }

    (:test)
    function testBlockGrowsAndShrinks(logger as Test.Logger) as Boolean {
        return Scoring.nextBlockMin(24, [80, 75, 90] as Array<Number>) == 29
            && Scoring.nextBlockMin(24, [80, 40, 90] as Array<Number>) == 24
            && Scoring.nextBlockMin(24, [90, 45, 30] as Array<Number>) == 19
            && Scoring.nextBlockMin(90, [80, 75, 90] as Array<Number>) == 90
            && Scoring.nextBlockMin(15, [10, 20] as Array<Number>) == 15;
    }

    (:test)
    function testStreak(logger as Test.Logger) as Boolean {
        return Scoring.nextStreak(0, null, 100, false) == 1
            && Scoring.nextStreak(3, 100, 100, false) == 3
            && Scoring.nextStreak(3, 100, 101, false) == 4
            && Scoring.nextStreak(3, 100, 103, false) == 1
            && Scoring.nextStreak(3, 100, 101, true) == 0;
    }

    (:test)
    function testSessionFullPath(logger as Test.Logger) as Boolean {
        var s = new Session();
        s.start(5, 3, 100, 2, 60);            // 5 s focus, 3 s break, gate 100 bpm held 2 s
        var ev = EV_NONE;
        for (var i = 0; i < 5; i++) { ev = s.tick(65, false, 0); }
        if (ev != EV_FOCUS_DONE || s.state != ST_EARN || s.score != 100 || !s.completed) { return false; }
        s.tick(90, false, 0);                    // below the target: no hold
        s.tick(105, false, 0);
        s.tick(95, false, 0);                    // drop resets the hold
        if (s.state != ST_EARN) { return false; }
        s.tick(105, false, 0);
        ev = s.tick(110, false, 0);
        if (ev != EV_GATE_OPEN || s.state != ST_BREAK) { return false; }
        s.tick(null, false, 0);
        s.tick(null, false, 0);
        ev = s.tick(null, false, 0);
        return ev == EV_BREAK_DONE && s.state == ST_SUMMARY && !s.gateSkipped;
    }

    (:test)
    function testSessionEarlyEndAndSkip(logger as Test.Logger) as Boolean {
        var s = new Session();
        s.start(10, 3, 100, 2, 60);
        for (var i = 0; i < 5; i++) { s.tick(65, false, 0); }
        s.endEarly();
        // Half done, still, calm: (50*50 + 100*30 + 100*20) / 100 = 75.
        if (s.state != ST_SUMMARY || s.score != 75 || s.completed) { return false; }

        var t = new Session();
        t.start(1, 3, 100, 2, 60);
        t.tick(65, false, 0);
        t.skipGate();
        return t.state == ST_BREAK && t.gateSkipped && t.breakLeft_s == 3;
    }

    (:test)
    function testStairsOpenGate(logger as Test.Logger) as Boolean {
        var s = new Session();
        s.start(1, 3, 100, 10, 60);
        s.tick(65, false, 0);
        s.tick(80, false, 2);                 // 2 m: not a full floor
        if (s.state != ST_EARN) { return false; }
        var ev = s.tick(80, false, 3);        // 3 m with a heart rate below the target
        return ev == EV_GATE_OPEN && s.state == ST_BREAK && !s.gateSkipped;
    }

    (:test)
    function testDayPartAndBest(logger as Test.Logger) as Boolean {
        var sums = [0, 300, 160, 0] as Array<Number>;     // afternoon mean 75, evening mean 80
        var counts = [0, 4, 2, 0] as Array<Number>;
        var none = [0, 0, 0, 0] as Array<Number>;
        return Baseline.dayPart(5) == 0 && Baseline.dayPart(11) == 0 && Baseline.dayPart(12) == 1
            && Baseline.dayPart(17) == 2 && Baseline.dayPart(22) == 3 && Baseline.dayPart(3) == 3
            && Baseline.bestIndex(sums, counts) == 2
            && Baseline.bestIndex(none, none) == -1
            && Baseline.meanOf(300, 4) == 75 && Baseline.meanOf(0, 0) == null;
    }

    (:test)
    function testPlaces(logger as Test.Logger) as Boolean {
        // 0.001 degree of latitude is 111.3 m. At latitude 51 the same step in longitude is 70.1 m.
        var d = Baseline.distance_m(51.0d, -114.0d, 51.001d, -114.0d);
        var e = Baseline.distance_m(51.0d, -114.0d, 51.0d, -114.001d);
        logger.debug("north = " + d + " m, east = " + e + " m");
        var lats = [51.0d, 51.01d] as Array<Double>;
        var lons = [-114.0d, -114.0d] as Array<Double>;
        return d > 111.0 && d < 111.6 && e > 69.8 && e < 70.4
            && Baseline.findPlace(lats, lons, 51.001d, -114.0d) == 0       // 111 m: same place
            && Baseline.findPlace(lats, lons, 51.0099d, -114.0d) == 1
            && Baseline.findPlace(lats, lons, 51.005d, -114.0d) == -1;     // 557 m from both
    }

    (:test)
    function testTempPart(logger as Test.Logger) as Boolean {
        return Baseline.tempPart(30.0, 29.0, 5) == 85
            && Baseline.tempPart(27.0, 29.0, 5) == 70
            && Baseline.tempPart(30.0, 29.0, 2) == null       // too few sessions
            && Baseline.tempPart(null, 29.0, 5) == null;
    }

    (:test)
    function testSleepMessage(logger as Test.Logger) as Boolean {
        var ok = { "t" => "sleep", "hours" => 6.4 } as Dictionary;
        var whole = { "t" => "sleep", "hours" => 7 } as Dictionary;
        var wrongType = { "t" => "state", "hours" => 6.4 } as Dictionary;
        var tooLong = { "t" => "sleep", "hours" => 30.0 } as Dictionary;
        var text = { "t" => "sleep", "hours" => "6.4" } as Dictionary;
        var h = Messages.parseSleep(ok);
        return h != null && h > 6.39 && h < 6.41
            && Messages.parseSleep(whole) == 7.0
            && Messages.parseSleep(wrongType) == null
            && Messages.parseSleep(tooLong) == null
            && Messages.parseSleep(text) == null
            && Messages.parseSleep("sleep") == null
            && Messages.parseSleep(null) == null;
    }

    (:test)
    function testSleepPart(logger as Test.Logger) as Boolean {
        return Messages.sleepPart(8.0) == 100
            && Messages.sleepPart(6.0) == 50
            && Messages.sleepPart(3.0) == 0
            && Messages.sleepPart(9.5) == 100
            && Messages.sleepPart(null) == null;
    }

    (:test)
    function testStateMessages(logger as Test.Logger) as Boolean {
        var s = new Session();
        var ready = Messages.state(s, null, 0);
        s.start(1440, 360, 104, 10, 58);
        s.tick(65, false, 0);
        var focus = Messages.state(s, 65, 0);
        if (!"ready".equals(ready["s"]) || !"focus".equals(focus["s"])
            || focus["left_s"] != 1439 || focus["planned_s"] != 1440) { return false; }
        s.endEarly();
        s.start(1, 360, 104, 10, 58);
        s.tick(65, false, 0);
        var earn = Messages.state(s, null, 0);     // no heart rate yet: 0, never null
        s.skipGate();
        var brk = Messages.state(s, 70, 0);
        return "earn".equals(earn["s"]) && earn["hr"] == 0 && earn["target"] == 104 && earn["rest"] == 58
            && "break".equals(brk["s"]) && brk["left_s"] == 360 && brk["planned_s"] == 360
            && brk["hr"] == 70 && brk["rest"] == 58 && brk["ok"] == 1 && brk["steps"] == 0
            && Messages.period_s(ST_FOCUS) == 60 && Messages.period_s(ST_EARN) == 2
            && Messages.period_s(ST_READY) == 0;
    }

    (:test)
    function testRecovered(logger as Test.Logger) as Boolean {
        return Scoring.recovered(78, 58)          // exactly rest + 20
            && !Scoring.recovered(79, 58)
            && !Scoring.recovered(null, 58);
    }

    (:test)
    function testPhonePenalty(logger as Test.Logger) as Boolean {
        var s = new Session();
        s.start(1, 3, 100, 2, 60);
        s.tick(65, false, 0);                       // score 100
        s.applyPenalty(Scoring.phonePenalty(2, 35)); // 2 exits = 10, 35 s = 5 -> 15
        s.applyPenalty(10);                          // a second call changes nothing
        var reply = { "t" => "ok", "exits" => 2, "away_s" => 35 } as Dictionary;
        var p = Messages.parsePhone(reply);
        return Scoring.phonePenalty(0, 0) == 0
            && Scoring.phonePenalty(1, 0) == 5
            && Scoring.phonePenalty(2, 35) == 15
            && Scoring.phonePenalty(3, 600) == 30    // cap
            && s.score == 85 && s.penalty == 15
            && p != null && p[0] == 2 && p[1] == 35
            && Messages.parsePhone({ "t" => "ok" } as Dictionary) == null
            && Messages.parsePhone("x") == null;
    }
}
