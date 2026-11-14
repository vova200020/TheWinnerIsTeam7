import Toybox.Lang;
import Toybox.Test;

// Known-answer tests of FaceScore. Run: monkeyc -t, then monkeydo /t (simulator open).
module FaceTests {

    (:test)
    function testBatteryAndCalm(logger as Test.Logger) as Boolean {
        // Body Battery 80 (weight 25), stress 40 so calm 60 (weight 20): (2000 + 1200) / 45 = 71.1
        var r = FaceScore.readiness(80, 40);
        logger.debug("readiness = " + r);
        return r == 71;
    }

    (:test)
    function testOnlyBattery(logger as Test.Logger) as Boolean {
        return FaceScore.readiness(50, null) == 50;
    }

    (:test)
    function testOnlyStress(logger as Test.Logger) as Boolean {
        // Stress 30 gives calm 70.
        return FaceScore.readiness(null, 30) == 70;
    }

    (:test)
    function testNothingIsNull(logger as Test.Logger) as Boolean {
        return FaceScore.readiness(null, null) == null;
    }

    (:test)
    function testOutOfRangeIsClamped(logger as Test.Logger) as Boolean {
        return FaceScore.readiness(150, null) == 100 && FaceScore.readiness(-5, null) == 0;
    }

    (:test)
    function testThresholdWords(logger as Test.Logger) as Boolean {
        return FaceScore.word(70).equals("Ready")
            && FaceScore.word(69).equals("Fair")
            && FaceScore.word(40).equals("Fair")
            && FaceScore.word(39).equals("Low")
            && FaceScore.word(0).equals("Low");
    }
}
