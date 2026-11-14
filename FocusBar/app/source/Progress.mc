import Toybox.Application;
import Toybox.Lang;

// Gamification (spec §7, habit-design-playbook §4–5):
// weekly goal (counts weeks, not days), cumulative totals that can't be lost,
// a comeback bonus as the biggest reward, milestones/awards, and no shaming.
module Progress {
    const XP_COMEBACK = 25;
    const XP_PER_BREAK = 5;
    const XP_DEEP = 10;
    const MAX_REPORTS = 30;

    const AWARD_CODES = ["FIRST", "DEEP1", "EARLY", "NIGHT", "MARATHON", "HOURS10", "FIFTY", "WEEK"];
    const AWARD_NAMES = ["First Focus", "Deep Diver", "Early Bird", "Night Owl", "Marathon",
                         "10 Hours Focused", "50 Sessions", "Goal Week"];

    function weekCount() as Number {
        return (Store.getNum("weekKey", 0) == Days.weekStart()) ? Store.getNum("weekCount", 0) : 0;
    }

    function weeklyGoal() as Number {
        var g = Store.propNum("weeklyGoal", 5);
        return (g < 1) ? 1 : g;
    }

    function xp() as Number { return Store.getNum("xp", 0); }
    function totalSessions() as Number { return Store.getNum("totalSessions", 0); }
    function totalMinutes() as Number { return Store.getNum("totalMinutes", 0); }
    function awards() as Array<Application.Storage.ValueType> { return Store.getArray("awards"); }

    function awardName(code as String) as String {
        for (var i = 0; i < AWARD_CODES.size(); i++) {
            if (code.equals(AWARD_CODES[i] as String)) { return AWARD_NAMES[i] as String; }
        }
        return code;
    }

    // Learned "fade point": average minutes into a session when focus declines (default 50).
    function fadeMinutes() as Number {
        return Store.getFloat("fadeMin", 50.0).toNumber();
    }

    function learnFade(minutes as Number) as Void {
        var f = Store.getFloat("fadeMin", 50.0);
        Store.put("fadeMin", 0.8 * f + 0.2 * minutes);
    }

    function lastLength(tagIdx as Number) as Number {
        return Store.getNum("len" + tagIdx, 50);
    }

    // Records a finished session. `s` comes from FocusSession.summary().
    // Returns { "xp", "awards" (Array<String>), "comeback", "week", "goal" }.
    function record(s as Dictionary, report as Number) as Dictionary {
        var minutes = s["min"] as Number;
        var breaks = s["breaks"] as Number;
        var level = s["level"] as Number;
        var startHour = s["hour"] as Number;
        var today = Days.today();

        // XP: 1 per minute + bonuses
        var gained = minutes;
        var last = Store.getNum("lastDay", 0);
        var comeback = last != 0 && last != today && last != Days.daysAgo(1);
        if (comeback) { gained += XP_COMEBACK; }
        gained += XP_PER_BREAK * breaks;
        if (level == 2) { gained += XP_DEEP; }
        Store.put("xp", xp() + gained);
        Store.put("lastDay", today);

        var sessions = totalSessions() + 1;
        var mins = totalMinutes() + minutes;
        Store.put("totalSessions", sessions);
        Store.put("totalMinutes", mins);
        if (level == 2) { Store.put("deepCount", Store.getNum("deepCount", 0) + 1); }

        // Weekly goal: resets each Monday, the weeks-met count never goes down.
        var wk = Days.weekStart();
        var count = (Store.getNum("weekKey", 0) == wk) ? Store.getNum("weekCount", 0) : 0;
        count++;
        Store.put("weekKey", wk);
        Store.put("weekCount", count);
        var goal = weeklyGoal();
        var newAwards = [] as Array<String>;
        if (count == goal) {
            Store.put("weeksMet", Store.getNum("weeksMet", 0) + 1);
            grant("WEEK", newAwards);
        }

        // Awards
        grant("FIRST", newAwards);
        if (level == 2) { grant("DEEP1", newAwards); }
        if (startHour >= 5 && startHour < 7) { grant("EARLY", newAwards); }
        if (startHour >= 22 || startHour < 4) { grant("NIGHT", newAwards); }
        if (minutes >= 90 && breaks == 0) { grant("MARATHON", newAwards); }
        if (mins >= 600) { grant("HOURS10", newAwards); }
        if (sessions >= 50) { grant("FIFTY", newAwards); }

        // Self-reports for the weekly weight calibration (spec §1.4; runs phone-side).
        if (report > 0) {
            var reports = Store.getArray("reports");
            reports.add([report, s["avg"] as Number] as Array<Application.Storage.ValueType>);
            if (reports.size() > MAX_REPORTS) { reports = reports.slice(reports.size() - MAX_REPORTS, null); }
            Store.put("reports", reports);
        }

        return { "xp" => gained, "awards" => newAwards, "comeback" => comeback, "week" => count, "goal" => goal };
    }

    // Grants an award once. Returns nothing; appends the display name if new.
    function grant(code as String, out as Array<String>) as Void {
        var list = awards();
        for (var i = 0; i < list.size(); i++) {
            var c = list[i];
            if (c instanceof String && c.equals(code)) { return; }
        }
        list.add(code);
        Store.put("awards", list);
        out.add(awardName(code));
    }
}
