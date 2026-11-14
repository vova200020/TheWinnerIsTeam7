"""Real lock of an Android phone for the demo: Android app pinning, driven over USB with adb.

While a focus block runs, the phone app is pinned: Home, Recents and the notification shade do not
work, so the user cannot leave the app. At the break the pin is released.

This is a demo path. It needs the phone on a USB cable with USB debugging on. A store app does the
same with its own code (startLockTask in a native module, or an accessibility service).
"""
import re
import shutil
import subprocess
import threading
from pathlib import Path

APP_PACKAGE = "host.exp.exponent"       # Expo Go, which shows the FocusPeak app
LOCK_STATES = {"focus", "earn"}         # watch states in which the phone is locked
ADB_TIMEOUT_S = 6
WINGET_ADB = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages"
              / "Google.PlatformTools_Microsoft.Winget.Source_8wekyb3d8bbwe/platform-tools/adb.exe")


def find_adb():
    found = shutil.which("adb")
    if found:
        return found
    return str(WINGET_ADB) if WINGET_ADB.exists() else None


def task_id_of(dumpsys_text, package=APP_PACKAGE):
    """The task id of the app when it is the resumed activity, else None.

    The app is pinned only when it is in front: a pin of a background task would trap the user
    in a screen they did not choose.
    """
    for line in dumpsys_text.splitlines():
        if "topResumedActivity" in line or "mResumedActivity" in line:
            if package not in line:
                return None
            match = re.search(r"\bt(\d+)\}", line)
            return int(match.group(1)) if match else None
    return None


def wants_lock(state):
    """True, False, or None when the message does not change the lock."""
    if not isinstance(state, str):
        return None
    return state in LOCK_STATES


class PhoneLock:
    def __init__(self, adb=None, run=None):
        self.adb = adb or find_adb()
        self.run = run or self._run           # injectable for the tests
        self.locked = False
        self.mutex = threading.Lock()

    def _run(self, *args):
        out = subprocess.run([self.adb, "shell", *args], capture_output=True, text=True, timeout=ADB_TIMEOUT_S)
        return out.stdout

    def apply(self, state):
        """Called for each watch state. Pins or releases only when the wanted lock changes."""
        want = wants_lock(state)
        if want is None or not self.adb:
            return
        with self.mutex:
            if want == self.locked:
                return
            try:
                if want:
                    task = task_id_of(self.run("dumpsys", "activity", "activities"))
                    if task is None:
                        print("phone lock: the app is not in front, no pin", flush=True)
                        return
                    self.run("am", "task", "lock", str(task))
                else:
                    self.run("am", "task", "lock", "stop")
                self.locked = want
                print("phone lock:", "PINNED" if want else "released", flush=True)
            except (OSError, subprocess.SubprocessError) as err:
                print("phone lock: adb failed:", err, flush=True)

    def apply_async(self, state):
        threading.Thread(target=self.apply, args=(state,), daemon=True).start()

    def release(self):
        """Emergency unlock from the phone app, and at server exit: never leave a phone pinned."""
        if not self.adb:
            return
        with self.mutex:
            try:
                self.run("am", "task", "lock", "stop")
                self.locked = False
                print("phone lock: released", flush=True)
            except (OSError, subprocess.SubprocessError) as err:
                print("phone lock: adb failed:", err, flush=True)
