"""Known-answer tests of the backend logic. Run: python -m pytest test_server.py -q"""
import datetime as dt

import pytest

from server import Community, ME, TEAM_GOAL_MIN, day_part

NOW = dt.datetime(2026, 11, 14, 10, 30)      # a Saturday morning


def make(**kw):
    return Community(now=lambda: NOW, **kw)


def summary(score=80, minutes=24, place="Central Library", streak=5, next_min=29):
    return {"t": "summary", "score": score, "min": minutes, "place": place, "streak": streak, "next_min": next_min}


def my_row(c):
    return next(r for r in c.leaderboard() if r["user"] == ME)


def test_day_part_matches_the_watch_rule():
    assert [day_part(h) for h in (5, 11, 12, 16, 17, 21, 22, 4)] == [0, 0, 1, 1, 2, 2, 3, 3]


def test_state_is_relayed_and_sequence_grows():
    c = make()
    assert c.state()["state"]["s"] == "ready"
    assert c.on_watch_message({"t": "state", "s": "focus", "left_s": 1440, "planned_s": 1440}) == {"t": "ok", "exits": 0, "away_s": 0}
    s = c.state()
    assert s["seq"] == 1 and s["state"]["s"] == "focus" and s["state"]["left_s"] == 1440


def test_example_journal_gives_the_demo_story():
    me = make().me()
    assert me["total"] == 14 and me["streak"] == 4 and me["next_min"] == 29
    assert me["parts"][0]["name"] == "Morning" and me["parts"][0]["score"] == 82      # (78+81+84+86+80+83)/6
    assert me["places"][0] == {"name": "Library", "score": 82, "n": 6}
    assert [d["day"] for d in me["week"]] == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    assert me["week"][-1]["min"] == 0                                                 # nothing today yet
    assert me["week"][-2] == {"day": "Fri", "min": 58, "score": 78}                   # 29 + 29 min, (83+74)/2


def test_summary_updates_journal_feed_leaderboard_and_place():
    c = make()
    before = my_row(c)
    c.on_watch_message(summary())
    after = my_row(c)
    assert after["min"] == before["min"] + 24 and after["sessions"] == before["sessions"] + 1
    top = c.community_feed()[0]
    assert (top["user"], top["score"], top["min"], top["place"], top["kudos"]) == (ME, 80, 24, "Central Library", 0)
    library = next(p for p in c.shared_places() if p["place"] == "Central Library")
    assert library["sessions"] == 13 and library["score"] == round((1008 + 80) / 13)
    me = c.me()
    assert me["total"] == 15 and me["streak"] == 5 and me["week"][-1] == {"day": "Sat", "min": 24, "score": 80}
    assert me["sessions"][0]["part"] == "Morning"


def test_home_is_in_my_journal_but_never_shared():
    c = make()
    c.on_watch_message(summary(score=90, place="Home"))
    assert all(p["place"].lower() != "home" for p in c.shared_places())
    assert c.community_feed()[0]["place"] == ""
    assert c.me()["sessions"][0]["place"] == "Home"


def test_kudos_and_challenge():
    c = make()
    assert c.add_kudos(1) == 3
    with pytest.raises(ValueError):
        c.add_kudos(999)
    ch = c.challenge()
    total = sum(r["min"] for r in c.leaderboard())
    assert ch["goal_min"] == TEAM_GOAL_MIN and ch["total_min"] == total and ch["percent"] == min(100, round(100 * total / TEAM_GOAL_MIN))


def test_sleep_goes_back_to_the_watch():
    c = make()
    c.set_sleep(6.4)
    assert c.on_watch_message({"t": "state", "s": "ready"}) == {"t": "sleep", "hours": 6.4, "exits": 0, "away_s": 0}
    assert c.me()["sleep_hours"] == 6.4


def test_data_survives_a_restart(tmp_path):
    path = tmp_path / "data.json"
    c = make(data_file=path)
    c.on_watch_message(summary(score=91))
    c.add_kudos(2)
    again = make(data_file=path)
    assert again.me()["total"] == 15 and again.community_feed()[0]["score"] == 91
    assert next(i for i in again.community_feed() if i["id"] == 2)["kudos"] == 2


def test_broken_data_file_falls_back_to_the_example(tmp_path):
    path = tmp_path / "data.json"
    path.write_text("{not json", encoding="utf-8")
    assert make(data_file=path).me()["total"] == 14


@pytest.mark.parametrize("bad", [None, "text", {"t": "other"}, summary(score=500)])
def test_bad_messages_are_refused(bad):
    with pytest.raises(ValueError):
        make().on_watch_message(bad)


def test_bad_sleep_is_refused():
    with pytest.raises(ValueError):
        make().set_sleep(30)


# ---- phone lock (app pinning over adb) ----
from phone_lock import PhoneLock, task_id_of, wants_lock

IN_FRONT = "    topResumedActivity=ActivityRecord{219194579 u0 host.exp.exponent/.experience.ExperienceActivity t41620}\n"
OTHER_APP = "    topResumedActivity=ActivityRecord{1 u0 com.android.chrome/.Main t7}\n"


def test_task_id_only_when_the_app_is_in_front():
    assert task_id_of(IN_FRONT) == 41620
    assert task_id_of(OTHER_APP) is None
    assert task_id_of("no activity line") is None


def test_which_states_lock():
    assert [wants_lock(s) for s in ("focus", "earn", "break", "ready", "summary", None)] == [True, True, False, False, False, None]


def test_lock_pins_once_and_releases():
    calls = []

    def run(*args):
        calls.append(args)
        return IN_FRONT

    lock = PhoneLock(adb="adb", run=run)
    lock.apply("focus")
    lock.apply("focus")                      # no second pin
    lock.apply("earn")                       # still locked: nothing to do
    assert calls == [("dumpsys", "activity", "activities"), ("am", "task", "lock", "41620")] and lock.locked
    lock.apply("break")
    assert calls[-1] == ("am", "task", "lock", "stop") and not lock.locked


def test_no_pin_when_another_app_is_in_front():
    calls = []

    def run(*args):
        calls.append(args)
        return OTHER_APP

    lock = PhoneLock(adb="adb", run=run)
    lock.apply("focus")
    assert not lock.locked and ("am", "task", "lock", "7") not in calls


# ---- phone use during focus ----
def test_phone_use_is_counted_per_block_and_reaches_the_watch():
    c = make()
    assert c.phone_away(20) == {"exits": 0, "away_s": 0}                 # no block runs: not counted
    c.on_watch_message({"t": "state", "s": "focus", "left_s": 1440, "planned_s": 1440})
    c.phone_away(20)
    c.phone_away(15)
    reply = c.on_watch_message({"t": "state", "s": "earn", "hr": 90, "target": 100, "rest": 58})
    assert (reply["exits"], reply["away_s"]) == (2, 35)                  # the watch lowers its score with this
    c.on_watch_message(summary(score=70))
    assert (c.me()["sessions"][0]["exits"], c.me()["sessions"][0]["away_s"]) == (2, 35)
    c.on_watch_message({"t": "state", "s": "ready"})
    reply = c.on_watch_message({"t": "state", "s": "focus", "left_s": 1440, "planned_s": 1440})
    assert (reply["exits"], reply["away_s"]) == (0, 0)                   # the next block starts clean


def test_bad_away_time_is_refused():
    with pytest.raises(ValueError):
        make().phone_away(-5)

