import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Planned sessions pushed by the phone from #focus calendar events (spec §3.1, §4.2):
// { "t": "schedule", "sessions": [ { "start": epochSec, "len": min, "tag": "writing" } ] }
module Schedule {
    const MAX = 5;

    function store(sessions as Object?) as Void {
        var out = [] as Array<Application.Storage.ValueType>;
        if (sessions instanceof Array) {
            for (var i = 0; i < sessions.size() && out.size() < MAX; i++) {
                var s = sessions[i];
                if (!(s instanceof Dictionary)) { continue; }
                var start = s["start"];
                var len = s["len"];
                var tag = s["tag"];
                if (start instanceof Number) {
                    out.add([start, (len instanceof Number) ? len : 50,
                             (tag instanceof String) ? tag : "focus"] as Array<Application.Storage.ValueType>);
                }
            }
        }
        Store.put("schedule", out);
    }

    // "Next: Thu 14:00 writing", or null when nothing is planned.
    function nextLabel() as String? {
        var now = Time.now().value();
        var list = Store.getArray("schedule");
        var best = null;
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            if (!(e instanceof Array) || e.size() < 3) { continue; }
            var start = e[0];
            if (!(start instanceof Number) || start + 600 < now) { continue; }
            if (best == null || start < ((best as Array)[0] as Number)) { best = e; }
        }
        if (best == null) { return null; }
        var b = best as Array;
        var info = Gregorian.info(new Time.Moment(b[0] as Number), Time.FORMAT_MEDIUM);
        return "Next: " + info.day_of_week + " " + (info.hour as Number).format("%02d") + ":"
            + (info.min as Number).format("%02d") + " " + (b[2] as String);
    }
}
