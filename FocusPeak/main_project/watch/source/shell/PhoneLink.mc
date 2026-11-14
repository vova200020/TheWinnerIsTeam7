import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// The one owner of the link to the phone app. The watch app never waits for it:
// with no phone, messages are dropped and every screen works as before.
class PhoneLink {
    const BUSY_TIMEOUT_S = 10;          // a transmit with no answer after this time is given up

    // Off by default: the simulator shows an error dialog for each transmit when no phone is on ADB.
    var enabled as Boolean = false;

    // The same messages as HTTP POST to the local backend (backend/server.py). Made for the simulator:
    // a real watch sends web requests through the phone, and those need a public HTTPS address.
    // shortcut: fixed local address, change it to the tunnel address for a real watch.
    const SERVER_URL = "http://127.0.0.1:8787/api/msg";
    var serverOn as Boolean = false;

    var sent as Number = 0;
    var failed as Number = 0;
    var lastCode as Number = 0;         // last HTTP response code of the server link (negative = Connect IQ error)

    private var _busy as Boolean = false;
    private var _busy_s as Number = 0;
    private var _state as Messages.Message? = null;     // only the newest state is worth sending
    private var _summary as Messages.Message? = null;   // a summary is never replaced by a state
    private var _lastState as Number = -1;
    private var _sinceSend_s as Number = 0;

    function initialize() {
    }

    function start() as Void {
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhone));
        }
    }

    function onPhone(msg as Communications.PhoneAppMessage) as Void {
        var hours = Messages.parseSleep(msg.data);
        if (hours != null) { getApp().onSleep(hours); }
    }

    // Once per second: sends the state when it changes, and again at the period of that state.
    function tick(s as Session, hr_bpm as Number?, steps as Number) as Void {
        if (_busy) {
            _busy_s++;
            if (_busy_s > BUSY_TIMEOUT_S) { _busy = false; }
        }
        _sinceSend_s++;
        var period = Messages.period_s(s.state);
        var changed = s.state != _lastState;
        if (s.state != ST_SUMMARY && (changed || (period > 0 && _sinceSend_s >= period))) {
            _state = Messages.state(s, hr_bpm, steps);
            _sinceSend_s = 0;
        }
        _lastState = s.state;
        pump();
    }

    function sendSummary(m as Messages.Message) as Void {
        _summary = m;
        pump();
    }

    function done(ok as Boolean) as Void {
        _busy = false;
        if (ok) { sent++; } else { failed++; }
        pump();
    }

    private function pump() as Void {
        if (_busy || !(Communications has :transmit)) { return; }
        if (!enabled && !serverOn) {
            _state = null;
            _summary = null;
            return;
        }
        if (!System.getDeviceSettings().phoneConnected) {
            if (_state != null) { System.println("link: phone not connected, state dropped"); }
            _state = null;      // an old state is worse than no state
            return;
        }
        var m = _summary;
        if (m != null) {
            _summary = null;
        } else {
            m = _state;
            _state = null;
        }
        if (m == null) { return; }
        _busy = true;
        _busy_s = 0;
        System.println("link: send " + m["t"] + " " + (m.hasKey("s") ? m["s"] : "") + (serverOn ? " -> server" : " -> phone"));
        if (serverOn) {
            Communications.makeWebRequest(SERVER_URL, m as Dictionary<Object, Object>, {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            }, method(:onWeb));
        } else {
            Communications.transmit(m as Dictionary<Communications.TransmitKeyType, Communications.TransmitType>, null, new LinkListener(self));
        }
    }

    // The reply of the backend can carry the sleep hours that the phone page posted.
    function onWeb(code as Number, data as Dictionary or String or Null) as Void {
        lastCode = code;
        System.println("link: server answered " + code);
        var hours = Messages.parseSleep(data);
        if (hours != null) { getApp().onSleep(hours); }
        var phone = Messages.parsePhone(data);
        if (phone != null) { getApp().onPhoneUse(phone[0], phone[1]); }
        done(code == 200);
    }
}

class LinkListener extends Communications.ConnectionListener {
    private var _link as PhoneLink;

    function initialize(link as PhoneLink) {
        ConnectionListener.initialize();
        _link = link;
    }

    function onComplete() as Void {
        _link.done(true);
    }

    function onError() as Void {
        _link.done(false);
    }
}
