"""FocusPeak local backend: relay between the watch and the phone page, the journal of the user,
and the community features.

Run:   python server.py              (then open http://127.0.0.1:8787 in a browser)
       python server.py --lan        (also reachable from a phone on the same Wi-Fi)
       python server.py --fresh      (forget the saved data and start from the example data)
       python server.py --pin        (really lock an Android phone on USB during focus: see phone_lock.py)
Test:  python -m pytest test_server.py -q

Standard library only. Data is example data until a watch posts a session. It is saved in data.json.
Privacy rules that this server enforces:
  - it receives a place LABEL only, never coordinates;
  - a session at "Home" is in the user's own journal, but it is never shown to other users.
"""
import datetime as dt
import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = 8787
HERE = Path(__file__).resolve().parent
PHONE_PAGE = HERE.parent / "phone" / "index.html"
DATA_FILE = HERE / "data.json"
PRIVATE_PLACES = {"home", ""}          # labels that never reach the community views
MAX_FEED = 50
MAX_JOURNAL = 200
ME = "You"
TEAM_GOAL_MIN = 1200                   # weekly focus minutes of the whole friend group
PART_NAMES = ["Morning", "Afternoon", "Evening", "Night"]

# Example journal: (days ago, hour, score, minutes, place). A user who works best in the morning
# at the library, the same story as the demo mode of the watch.
EXAMPLE_JOURNAL = [
    (13, 9, 78, 24, "Library"), (12, 20, 58, 24, "Home"), (11, 10, 81, 24, "Library"),
    (10, 14, 72, 24, "Campus"), (9, 9, 84, 24, "Library"), (8, 23, 55, 19, "Home"),
    (7, 15, 74, 24, "Campus"), (6, 9, 86, 29, "Library"), (5, 19, 66, 24, "Home"),
    (4, 13, 76, 29, "Campus"), (3, 10, 80, 29, "Library"), (2, 18, 65, 24, "Home"),
    (1, 9, 83, 29, "Library"), (1, 15, 74, 29, "Campus"),
]


def day_part(hour):
    """Morning 5 to 11, afternoon 12 to 16, evening 17 to 21, night 22 to 4 (same rule as the watch)."""
    if 5 <= hour < 12:
        return 0
    if 12 <= hour < 17:
        return 1
    if 17 <= hour < 22:
        return 2
    return 3


def mean(values):
    return round(sum(values) / len(values)) if values else 0


class Community:
    """The state of the server. Pure logic: no network code, so the tests call it directly."""

    def __init__(self, now=None, data_file=None):
        self.lock = threading.RLock()
        self.data_file = data_file
        self.now = now or dt.datetime.now          # injectable clock for the tests
        self.seq = 0                               # grows with each watch message: the phone polls for changes
        self.last_state = {"t": "state", "s": "ready"}
        self.last_state_time_s = time.time()
        self.last_summary = None
        self.sleep_hours = None                    # posted by the phone, returned to the watch
        self.in_session = False                    # a block runs: focus, earn or break
        self.away = {"exits": 0, "away_s": 0}       # phone use during the focus of the running block
        self.streak = 4
        self.next_min = 29
        self.friends = {"Maya": [310, 972, 12], "Arjun": [265, 790, 10], "Sam": [190, 592, 8]}  # min, score sum, n
        self.places = {"Central Library": [1008, 12, 5], "Campus Hall": [684, 9, 4], "Corner Cafe": [427, 7, 3]}
        self.feed = [
            {"id": 1, "user": "Maya", "score": 86, "min": 34, "place": "Central Library", "ago": "20 min ago", "kudos": 2},
            {"id": 2, "user": "Arjun", "score": 78, "min": 24, "place": "Campus Hall", "ago": "1 h ago", "kudos": 1},
            {"id": 3, "user": "Sam", "score": 71, "min": 24, "place": "", "ago": "2 h ago", "kudos": 0},
        ]
        self.next_id = 4
        today = self.now().date()
        self.journal = [{"day": (today - dt.timedelta(days=d)).isoformat(), "hour": h, "score": s, "min": m, "place": p}
                        for d, h, s, m, p in EXAMPLE_JOURNAL]
        self._load()

    # ---- persistence -------------------------------------------------------------------------
    def _load(self):
        if not self.data_file or not Path(self.data_file).exists():
            return
        try:
            saved = json.loads(Path(self.data_file).read_text(encoding="utf-8"))
            for key in ("streak", "next_min", "friends", "places", "feed", "next_id", "journal", "sleep_hours"):
                if key in saved:
                    setattr(self, key, saved[key])
        except (ValueError, OSError):
            pass        # a broken file must not stop the demo: start from the example data

    def _save(self):
        if not self.data_file:
            return
        data = {k: getattr(self, k) for k in
                ("streak", "next_min", "friends", "places", "feed", "next_id", "journal", "sleep_hours")}
        Path(self.data_file).write_text(json.dumps(data), encoding="utf-8")

    # ---- watch side --------------------------------------------------------------------------
    @staticmethod
    def is_shared_place(place):
        return isinstance(place, str) and place.strip().lower() not in PRIVATE_PLACES

    def on_watch_message(self, msg):
        """Takes one contract message from the watch. Returns the reply for the watch."""
        if not isinstance(msg, dict) or msg.get("t") not in ("state", "summary"):
            raise ValueError("unknown message")
        with self.lock:
            if msg["t"] == "state":
                state = msg.get("s")
                if state == "focus" and not self.in_session:
                    self.away = {"exits": 0, "away_s": 0}       # a new block starts clean
                self.in_session = state in ("focus", "earn", "break")
                self.last_state = msg
                self.last_state_time_s = time.time()
            else:
                self._add_session(msg)
                self.last_summary = msg
                self.in_session = False
                self._save()
            self.seq += 1
            # The watch owns the Focus score, so it gets the phone use of this block with each reply.
            reply = {"t": "sleep", "hours": self.sleep_hours} if self.sleep_hours is not None else {"t": "ok"}
            reply.update(self.away)
            return reply

    def _add_session(self, msg):
        score = int(msg.get("score", 0))
        minutes = int(msg.get("min", 0))
        if not 0 <= score <= 100 or not 0 <= minutes <= 24 * 60:
            raise ValueError("score or minutes out of range")
        place = msg.get("place", "")
        place = place.strip() if isinstance(place, str) else ""
        now = self.now()
        self.journal.append({"day": now.date().isoformat(), "hour": now.hour, "score": score, "min": minutes, "place": place,
                             "exits": self.away["exits"], "away_s": self.away["away_s"]})
        del self.journal[:-MAX_JOURNAL]
        if isinstance(msg.get("streak"), int):
            self.streak = msg["streak"]
        if isinstance(msg.get("next_min"), int):
            self.next_min = msg["next_min"]
        shared = place if self.is_shared_place(place) else ""
        if shared:
            stats = self.places.setdefault(shared, [0, 0, 1])
            stats[0] += score
            stats[1] += 1
        self.feed.insert(0, {"id": self.next_id, "user": ME, "score": score, "min": minutes, "place": shared,
                             "ago": "Just now", "kudos": 0})
        self.next_id += 1
        del self.feed[MAX_FEED:]

    # ---- phone side --------------------------------------------------------------------------
    def set_sleep(self, hours):
        hours = float(hours)
        if not 0 <= hours <= 24:
            raise ValueError("hours out of range")
        with self.lock:
            self.sleep_hours = hours
            self._save()

    def phone_away(self, seconds):
        """The phone app reports that the user left it during focus and came back after `seconds`."""
        seconds = int(seconds)
        if not 0 <= seconds <= 4 * 3600:
            raise ValueError("seconds out of range")
        with self.lock:
            if self.in_session:
                self.away["exits"] += 1
                self.away["away_s"] += seconds
            return dict(self.away)

    def add_kudos(self, item_id):
        with self.lock:
            for item in self.feed:
                if item["id"] == item_id:
                    item["kudos"] += 1
                    self._save()
                    return item["kudos"]
        raise ValueError("unknown feed item")

    def state(self):
        with self.lock:
            return {"seq": self.seq, "state": self.last_state,
                    "age_s": round(time.time() - self.last_state_time_s, 1), "summary": self.last_summary,
                    "away": dict(self.away)}

    def _my_week(self):
        """Sessions of the last 7 days, today included."""
        first = (self.now().date() - dt.timedelta(days=6)).isoformat()
        return [s for s in self.journal if s["day"] >= first]

    def me(self):
        """The journal and the personal baseline of the user. Own data: Home is included here."""
        with self.lock:
            today = self.now().date()
            week = []
            for back in range(6, -1, -1):
                day = today - dt.timedelta(days=back)
                rows = [s for s in self.journal if s["day"] == day.isoformat()]
                week.append({"day": day.strftime("%a"), "min": sum(s["min"] for s in rows),
                             "score": mean([s["score"] for s in rows])})
            parts = []
            for i, name in enumerate(PART_NAMES):
                scores = [s["score"] for s in self.journal if day_part(s["hour"]) == i]
                if scores:
                    parts.append({"name": name, "score": mean(scores), "n": len(scores)})
            by_place = {}
            for s in self.journal:
                if s["place"]:
                    by_place.setdefault(s["place"], []).append(s["score"])
            places = [{"name": p, "score": mean(v), "n": len(v)} for p, v in by_place.items()]
            sessions = [dict(s, part=PART_NAMES[day_part(s["hour"])]) for s in reversed(self.journal[-30:])]
            return {"sessions": sessions, "week": week, "streak": self.streak, "next_min": self.next_min,
                    "total": len(self.journal), "sleep_hours": self.sleep_hours,
                    "parts": sorted(parts, key=lambda r: r["score"], reverse=True),
                    "places": sorted(places, key=lambda r: r["score"], reverse=True)}

    def leaderboard(self):
        with self.lock:
            rows = [{"user": user, "min": m, "score": round(s / n) if n else 0, "sessions": n}
                    for user, (m, s, n) in self.friends.items()]
            mine = self._my_week()
            rows.append({"user": ME, "min": sum(s["min"] for s in mine), "score": mean([s["score"] for s in mine]),
                         "sessions": len(mine)})
        return sorted(rows, key=lambda r: r["min"], reverse=True)

    def challenge(self):
        total = sum(r["min"] for r in self.leaderboard())
        return {"name": "Team week", "goal_min": TEAM_GOAL_MIN, "total_min": total,
                "percent": min(100, round(100 * total / TEAM_GOAL_MIN))}

    def shared_places(self):
        with self.lock:
            rows = [{"place": p, "score": round(s / n) if n else 0, "sessions": n, "users": u}
                    for p, (s, n, u) in self.places.items()]
        return sorted(rows, key=lambda r: r["score"], reverse=True)

    def community_feed(self):
        with self.lock:
            return [dict(item) for item in self.feed]


COMMUNITY = None    # made in main(), so the tests do not touch data.json
PHONE_LOCK = None   # made in main() with --pin


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0 or length > 4096:        # contract messages are small
            raise ValueError("bad length")
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_OPTIONS(self):
        self._send(204, b"")

    def do_GET(self):
        path = self.path.split("?")[0]
        routes = {"/api/state": COMMUNITY.state, "/api/me": COMMUNITY.me, "/api/leaderboard": COMMUNITY.leaderboard,
                  "/api/places": COMMUNITY.shared_places, "/api/feed": COMMUNITY.community_feed,
                  "/api/challenge": COMMUNITY.challenge}
        if path in ("/", "/index.html"):
            self._send(200, PHONE_PAGE.read_bytes(), "text/html; charset=utf-8")
        elif path in routes:
            self._send(200, routes[path]())
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.split("?")[0]
        try:
            body = self._json_body()
            if path == "/api/msg":
                reply = COMMUNITY.on_watch_message(body)
                if PHONE_LOCK and body.get("t") == "state":
                    PHONE_LOCK.apply_async(body.get("s"))
                elif PHONE_LOCK and body.get("t") == "summary":
                    PHONE_LOCK.apply_async("summary")
                self._send(200, reply)
            elif path == "/api/unlock":
                if PHONE_LOCK:
                    PHONE_LOCK.release()
                self._send(200, {"t": "ok"})
            elif path == "/api/sleep":
                COMMUNITY.set_sleep(body.get("hours"))
                self._send(200, {"t": "ok"})
            elif path == "/api/away":
                self._send(200, COMMUNITY.phone_away(body.get("seconds")))
            elif path == "/api/kudos":
                self._send(200, {"kudos": COMMUNITY.add_kudos(body.get("id"))})
            else:
                self._send(404, {"error": "not found"})
        except (ValueError, TypeError, AttributeError, json.JSONDecodeError) as err:
            self._send(400, {"error": str(err)})

    def log_message(self, fmt, *args):
        if "POST" in (args[0] if args else ""):     # the phone polls the GET routes each second
            super().log_message(fmt, *args)


def main():
    global COMMUNITY, PHONE_LOCK
    if "--fresh" in sys.argv and DATA_FILE.exists():
        DATA_FILE.unlink()
    COMMUNITY = Community(data_file=DATA_FILE)
    # Default: this laptop only. "--lan" also lets a phone on the same Wi-Fi open the page.
    host = "0.0.0.0" if "--lan" in sys.argv else "127.0.0.1"
    print(f"FocusPeak backend on http://127.0.0.1:{PORT} (host {host}, Ctrl+C stops it)", flush=True)
    if "--pin" in sys.argv:
        from phone_lock import PhoneLock
        PHONE_LOCK = PhoneLock()
        print("phone lock:", "on, adb at " + PHONE_LOCK.adb if PHONE_LOCK.adb else "adb not found, lock is off", flush=True)
    try:
        ThreadingHTTPServer((host, PORT), Handler).serve_forever()
    finally:
        if PHONE_LOCK:
            PHONE_LOCK.release()


if __name__ == "__main__":
    main()
