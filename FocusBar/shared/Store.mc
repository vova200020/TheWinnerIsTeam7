import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Null-safe, type-coercing access to Storage and Properties (monkey-c-pitfalls §3, §4, §9).
(:background :glance)
module Store {
    function getNum(key as String, def as Number) as Number {
        var v = Application.Storage.getValue(key);
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Long || v instanceof Double) { return v.toNumber(); }
        return def;
    }

    function getFloat(key as String, def as Float) as Float {
        var v = Application.Storage.getValue(key);
        if (v instanceof Float || v instanceof Number || v instanceof Double || v instanceof Long) { return v.toFloat(); }
        return def;
    }

    function getBool(key as String, def as Boolean) as Boolean {
        var v = Application.Storage.getValue(key);
        return (v instanceof Boolean) ? v : def;
    }

    function getArray(key as String) as Array<Application.Storage.ValueType> {
        var v = Application.Storage.getValue(key);
        if (v instanceof Array) { return v as Array<Application.Storage.ValueType>; }
        return [] as Array<Application.Storage.ValueType>;
    }

    function put(key as String, value as Application.Storage.ValueType) as Void {
        try {
            Application.Storage.setValue(key, value);
        } catch (e) {
            // StorageFullException etc. Never crash the app over persistence.
        }
    }

    // ---- Settings (Properties): may arrive as String or be missing.
    function propNum(key as String, def as Number) as Number {
        var v = readProp(key);
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Long || v instanceof Double) { return v.toNumber(); }
        if (v instanceof String) {
            var n = v.toNumber();
            return (n != null) ? n : def;
        }
        return def;
    }

    function propBool(key as String, def as Boolean) as Boolean {
        var v = readProp(key);
        if (v instanceof Boolean) { return v; }
        if (v instanceof Number) { return v != 0; }
        if (v instanceof String) { return v.equals("true") || v.equals("1"); }
        return def;
    }

    function setProp(key as String, value as Application.Properties.ValueType) as Void {
        try {
            Application.Properties.setValue(key, value);
        } catch (e) {
        }
    }

    function readProp(key as String) as Application.Properties.ValueType or Null {
        try {
            return Application.Properties.getValue(key);
        } catch (e) {
            return null;
        }
    }
}

// Local-time day keys (yyyymmdd). Never epoch/86400, which gives UTC days (pitfalls §11).
(:background :glance)
module Days {
    function key(m as Time.Moment) as Number {
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        return (i.year as Number) * 10000 + (i.month as Number) * 100 + (i.day as Number);
    }

    function today() as Number {
        return key(Time.now());
    }

    // Anchored at local noon so DST shifts never land on the wrong day.
    function daysAgo(n as Number) as Number {
        return key(Time.today().add(new Time.Duration(12 * 3600 - n * 86400)));
    }

    // Day key of this week's Monday.
    function weekStart() as Number {
        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dow = i.day_of_week as Number;   // 1 = Sunday … 7 = Saturday
        return daysAgo((dow + 5) % 7);
    }

    function hourNow() as Number {
        return Gregorian.info(Time.now(), Time.FORMAT_SHORT).hour as Number;
    }

    function secondsIntoDay() as Number {
        var i = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return (i.hour as Number) * 3600 + (i.min as Number) * 60 + (i.sec as Number);
    }
}
