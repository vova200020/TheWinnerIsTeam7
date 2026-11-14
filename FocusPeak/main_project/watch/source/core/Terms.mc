import Toybox.Lang;

// The shared terms of FocusPeak. The phone app has the same table in focuspeak-phone/src/terms.js:
// change the two together.
//
// Why: a concept must look the same on the wrist and on the phone, so the user recognizes it and
// never has to guess if a word on one screen means the same as another word on the other screen.
// Each term has one word, one color and one shape (a pill-shaped box), on both devices.
module Terms {
    const READY = "Ready";
    const FOCUS = "Focus";
    const EARN = "Move to unlock";
    const BREAK = "Break";
    const SCORE = "Focus score";
    const STREAK = "Streak";
    const BLOCK = "Block";

    // The same hex values as the phone theme. A 64-color display shows the nearest color it has.
    const C_NEUTRAL = 0xEEF1F5;
    const C_FOCUS = 0x4DA3FF;
    const C_EARN = 0xFFB020;
    const C_REST = 0x3DDC84;
    const C_BAD = 0xFF6B5E;

    // The dark fill inside a box: the term color at about 15 %.
    function tint(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) * 15 / 100;
        var g = ((color >> 8) & 0xFF) * 15 / 100;
        var b = (color & 0xFF) * 15 / 100;
        return (r << 16) | (g << 8) | b;
    }
}
