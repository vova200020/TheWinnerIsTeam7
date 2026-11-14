import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

// Background service (spec §2.2): every 5 min compute the score and, when the focus
// window opens, ask the user to start a session. Rate-limited and respectful.
(:background)
class FocusService extends System.ServiceDelegate {
    const PROMPT_GAP_SEC = 90 * 60;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var res = FocusScore.tick(Store.propBool("demoMode", false));
        maybePrompt(res);
        Publisher.publish();
        Background.exit(res as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
    }

    private function maybePrompt(res as Dictionary<String, Number>) as Void {
        if (res["st"] != FocusScore.STATE_WINDOW) { return; }
        if (!Store.propBool("promptsOn", true)) { return; }
        if (Store.getBool("sessionActive", false)) { return; }
        if (Store.getNum("snoozeDay", 0) == Days.today()) { return; }
        var now = Time.now().value();
        if (now - Store.getNum("lastPromptAt", 0) < PROMPT_GAP_SEC) { return; }
        if (isSleepTime()) { return; }

        Store.put("lastPromptAt", now);
        var score = res["s"];
        Background.requestApplicationWake(
            "Focus window open (" + ((score != null) ? score.format("%d") : "") + "). Start a session?");
    }

    // No prompts between the user's configured bedtime and wake time.
    private function isSleepTime() as Boolean {
        var profile = UserProfile.getProfile();
        var sleep = profile.sleepTime;
        var wake = profile.wakeTime;
        if (sleep == null || wake == null) { return false; }
        var s = (sleep as Time.Duration).value();
        var w = (wake as Time.Duration).value();
        var t = Days.secondsIntoDay();
        return (s > w) ? (t >= s || t < w) : (t >= s && t < w);
    }
}
