import Toybox.Communications;
import Toybox.Lang;

// Watch → phone messages (spec §4.2). The phone companion enforces DND / app blocking.
// With no phone app connected these fail silently; the watch side keeps working.
module Comms {
    function send(msg as Dictionary) as Void {
        if (!(Communications has :transmit)) { return; }
        try {
            Communications.transmit(msg as Dictionary<Communications.TransmitKeyType, Communications.TransmitType>, null, new CommsListener());
        } catch (e) {
        }
    }

    const LEVELS = ["light", "medium", "deep"];

    function levelName(level as Number) as String {
        return (level >= 0 && level < 3) ? LEVELS[level] as String : "light";
    }
}

class CommsListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
    }

    function onError() as Void {
    }
}
