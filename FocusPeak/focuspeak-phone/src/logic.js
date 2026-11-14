// Pure logic of the FocusPeak phone app, ported from main_project/phone/index.html.
// No React Native imports here: plain Node runs src/logic.test.mjs against this same file.
import { T } from './theme.js';

export const PARTS = ['Morning', 'Afternoon', 'Evening', 'Night'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MS_PER_DAY = 86400000;
export const EXAMPLE_SLEEP_H = 6.4;     // a native build reads this from the health store; here it is fixed
const TEAM_GOAL_MIN = 1200;             // same weekly group goal as the backend (server.py)

// Score thresholds of the watch and the web page: green is a good block, amber is fair, red is poor.
export const levelColor = (score) => (score >= 70 ? T.good : score >= 40 ? T.warn : T.bad);

export const clock = (sec) => {
  const s = Math.max(0, sec | 0);
  return ((s / 60) | 0) + ':' + String(s % 60).padStart(2, '0');
};

// Minutes as hours and minutes: 193 -> "3:13". Long totals in plain minutes make the reader do arithmetic.
export const hmm = (min) => {
  const m = Math.max(0, Math.round(min));
  return Math.floor(m / 60) + ':' + String(m % 60).padStart(2, '0');
};

// The person just above "You" on the board and the minutes needed to pass them, or null at the top.
// A near, concrete goal moves people more than a far total.
export function nextRival(board) {
  const i = board.findIndex((r) => r.user === 'You');
  if (i <= 0) return null;
  return { user: board[i - 1].user, min: board[i - 1].min - board[i].min + 1 };
}

export const mean = (list) => (list.length ? Math.round(list.reduce((a, b) => a + b, 0) / list.length) : 0);

// Morning 5 to 11, afternoon 12 to 16, evening 17 to 21, night 22 to 4 (same rule as the watch).
export const dayPart = (h) => (h >= 5 && h < 12 ? 0 : h >= 12 && h < 17 ? 1 : h >= 17 && h < 22 ? 2 : 3);

// "2026-11-14" from the backend becomes "Today", "Yesterday" or "Thu 12 Nov". Other text passes through.
// Manual names, not toLocaleDateString: the Intl data of the phone engine can differ from a browser.
export function dayText(d, now = new Date()) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d);
  if (!m) return d;
  const day = new Date(+m[1], +m[2] - 1, +m[3]);
  const back = Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - day) / MS_PER_DAY);
  if (back === 0) return 'Today';
  if (back === 1) return 'Yesterday';
  return WEEKDAYS[day.getDay()] + ' ' + day.getDate() + ' ' + MONTHS[day.getMonth()];
}

// Example data for the app without a backend: [days ago, hour, score, minutes, place].
const EXAMPLE = [[13, 9, 78, 24, 'Library'], [12, 20, 58, 24, 'Home'], [11, 10, 81, 24, 'Library'], [10, 14, 72, 24, 'Campus'],
  [9, 9, 84, 24, 'Library'], [8, 23, 55, 19, 'Home'], [7, 15, 74, 24, 'Campus'], [6, 9, 86, 29, 'Library'], [5, 19, 66, 24, 'Home'],
  [4, 13, 76, 29, 'Campus'], [3, 10, 80, 29, 'Library'], [2, 18, 65, 24, 'Home'], [1, 9, 83, 29, 'Library'], [1, 15, 74, 29, 'Campus']];

export function makeExampleData() {
  return {
    local: { streak: 4, next_min: 29, sessions: EXAMPLE.map(([ago, hour, score, min, place]) => ({ ago, hour, score, min, place })) },
    me: null,
    board: [{ user: 'Maya', min: 310, score: 81 }, { user: 'Arjun', min: 265, score: 79 }, { user: 'Sam', min: 190, score: 74 }],
    places: [{ place: 'Central Library', score: 84, users: 5 }, { place: 'Campus Hall', score: 76, users: 4 }, { place: 'Corner Cafe', score: 61, users: 3 }],
    feed: [{ id: 1, user: 'Maya', score: 86, min: 34, place: 'Central Library', ago: '20 min ago', kudos: 2 },
      { id: 2, user: 'Arjun', score: 78, min: 24, place: 'Campus Hall', ago: '1 h ago', kudos: 1 },
      { id: 3, user: 'Sam', score: 71, min: 24, place: '', ago: '2 h ago', kudos: 0 }],
    challenge: null,
  };
}

// Builds the same shape as GET /api/me from the local example sessions.
export function localMe(local, today = new Date()) {
  const week = [];
  for (let back = 6; back >= 0; back--) {
    const d = new Date(today);
    d.setDate(d.getDate() - back);
    const rows = local.sessions.filter((s) => s.ago === back);
    week.push({ day: WEEKDAYS[d.getDay()], min: rows.reduce((a, s) => a + s.min, 0), score: mean(rows.map((s) => s.score)) });
  }
  const group = (keyOf) => {
    const g = {};
    local.sessions.forEach((s) => { const k = keyOf(s); if (k) (g[k] = g[k] || []).push(s.score); });
    return Object.entries(g).map(([name, v]) => ({ name, score: mean(v), n: v.length })).sort((a, b) => b.score - a.score);
  };
  const sessions = local.sessions.slice().reverse().map((s) => ({
    score: s.score, min: s.min, place: s.place, part: PARTS[dayPart(s.hour)],
    day: s.ago === 0 ? 'Today' : s.ago === 1 ? 'Yesterday' : s.ago + ' days ago',
  }));
  return {
    sessions, week, streak: local.streak, next_min: local.next_min, total: local.sessions.length, sleep_hours: EXAMPLE_SLEEP_H,
    parts: group((s) => PARTS[dayPart(s.hour)]), places: group((s) => s.place),
  };
}

// Offline only: the summary of the simulator goes into the local journal and the feed, like the backend does.
export function addLocalSummary(data, m, hourNow, idNow) {
  return {
    ...data,
    local: {
      ...data.local, streak: m.streak, next_min: m.next_min,
      sessions: data.local.sessions.concat([{ ago: 0, hour: hourNow, score: m.score, min: m.min, place: m.place }]),
    },
    feed: [{ id: idNow, user: 'You', score: m.score, min: m.min, place: m.place === 'Home' ? '' : m.place, ago: 'Just now', kudos: 0 }]
      .concat(data.feed),
  };
}

export const weekMinutes = (me) => me.week.reduce((a, d) => a + d.min, 0);

// Break length shown in the recipe: a quarter of the block, kept between 5 and 15 min like the watch.
export const breakMinutes = (nextMin) => Math.min(15, Math.max(5, Math.round(nextMin / 4)));

// In live mode the backend leaderboard already holds "You"; offline the app adds the own row.
export function buildBoard(data, me, isLive) {
  const mine = { user: 'You', min: weekMinutes(me), score: mean(me.week.filter((d) => d.min).map((d) => d.score)) };
  return (isLive ? data.board : data.board.concat([mine])).slice().sort((a, b) => b.min - a.min);
}

export function challengeOf(data, board) {
  if (data.challenge) return data.challenge;
  const total = board.reduce((a, r) => a + r.min, 0);
  return { name: 'Team week', goal_min: TEAM_GOAL_MIN, total_min: total, percent: Math.min(100, Math.round((100 * total) / TEAM_GOAL_MIN)) };
}

// ---- stage and lock --------------------------------------------------------------------------
export const READY_VIEW = {
  ringFrac: 0, ringColor: T.calm, state: 'READY', term: 'READY', big: '--', sub: '',
  title: 'Start a focus block on your watch', text: 'This phone locks while you focus. You earn it back with your heart rate.',
  wantLock: false, locked: false,
};
export const NEW_LOCK = { override: false, last: '' };

const clamp01 = (x) => Math.min(1, Math.max(0, Number.isFinite(x) ? x : 0));

// Phone use during focus lowers the Focus score. Same rule as the watch (Scoring.mc): 5 points for
// each exit from this app, 1 point for each 6 s away, 30 points at most.
export const phonePenalty = (exits, awayS) => (exits <= 0 && awayS <= 0 ? 0 : Math.min(30, exits * 5 + Math.floor(awayS / 6)));
export const NEW_AWAY = { exits: 0, sec: 0, leftAt: 0 };
export function awayNote(away) {
  if (!away || away.exits <= 0) return '';
  return 'You left the app ' + away.exits + (away.exits === 1 ? ' time' : ' times') + ' (' + clock(away.sec) + ' away). Focus score -' + phonePenalty(away.exits, away.sec) + '.';
}

// The break is for recovery: show the live heart rate from the watch when the message carries it.
export function breakText(m) {
  if (!m.hr) return 'Enjoy the break. The phone locks again at the next block.';
  const steps = m.steps ? ' · ' + m.steps + ' steps' : '';
  return m.ok ? 'Heart rate ' + m.hr + ' bpm' + steps + '. Recovered: you are ready for the next block.'
              : 'Heart rate ' + m.hr + ' bpm' + steps + '. Recovering. A short walk helps.';
}

// One watch message in, the next screen out. Returns { view, lock, vibrate, isSummary }.
// The caller does the side effects (vibrate, journal update), so this function stays testable.
export function applyMessage(view, lock, m) {
  const key = m.t === 'summary' ? 'summary' : m.s;
  let next = view;
  let vibrate = false;
  let newLock = lock;
  if (key !== lock.last) {          // a new phase ends an emergency unlock, and the phone buzzes at the break
    vibrate = key === 'break';
    newLock = { override: key === 'earn' ? lock.override : false, last: key };
  }
  if (m.t === 'state' && m.s === 'focus') {
    next = { ringFrac: clamp01(1 - m.left_s / m.planned_s), ringColor: T.calm, state: 'FOCUS', term: 'FOCUS', big: String(Math.ceil(m.left_s / 60)),
      sub: 'min left', title: 'Phone locked', text: 'Your watch runs a focus block. Put this phone face down.', wantLock: true };
  } else if (m.t === 'state' && m.s === 'earn') {
    const ok = m.hr >= m.target;
    next = { ringFrac: clamp01((m.hr - m.rest) / (m.target - m.rest)), ringColor: ok ? T.good : T.warn, state: 'MOVE TO UNLOCK', term: 'EARN',
      big: m.hr ? String(m.hr) : '--', sub: 'target ' + m.target + ' bpm', title: ok ? 'Hold it there' : 'Earn your break',
      text: 'Jumping jacks, stairs or a fast walk. Your heart rate opens the phone.', wantLock: true };
  } else if (m.t === 'state' && m.s === 'break') {
    next = { ringFrac: clamp01(m.left_s / m.planned_s), ringColor: T.good, state: 'BREAK', term: 'BREAK', big: clock(m.left_s), sub: 'min left',
      title: 'Phone earned', text: breakText(m), wantLock: false };
  } else if (m.t === 'state' && m.s === 'ready') {
    next = { ...READY_VIEW };
  } else if (m.t === 'summary') {
    next = { ringFrac: clamp01(m.score / 100), ringColor: levelColor(m.score), state: 'FOCUS SCORE', term: 'SCORE', big: String(m.score),
      sub: 'streak ' + m.streak + (m.streak === 1 ? ' day' : ' days'), title: 'Block done', text: 'The session is in your journal.', wantLock: false };
  }
  return { view: { ...next, locked: next.wantLock && !newLock.override }, lock: newLock, vibrate, isSummary: m.t === 'summary' };
}

// The 3 s emergency hold: unlock until the watch moves to a new phase.
export function emergencyUnlock(view, lock) {
  return { view: { ...view, locked: false }, lock: { ...lock, override: true } };
}

// ---- live mode -------------------------------------------------------------------------------
export const NEW_LIVE = { on: false, seq: -1, stateJson: '', summaryJson: 'null', msg: null, at: 0, holdSummary: false };

// One GET /api/state answer in. Returns the new live record and the summary to show now (or null).
export function livePoll(live, r, nowMs) {
  if (r.seq === live.seq) return { live, summary: null };
  const first = live.seq < 0;
  let next = { ...live, seq: r.seq };
  let summary = null;
  const stateJson = JSON.stringify(r.state);
  const summaryJson = JSON.stringify(r.summary);
  if (stateJson !== live.stateJson) {
    next = { ...next, stateJson, msg: r.state, at: nowMs - r.age_s * 1000, holdSummary: false };
  }
  if (summaryJson !== live.summaryJson) {
    next = { ...next, summaryJson };
    // An old summary at app start is history, not news: show only the ones that arrive while we watch.
    if (r.summary && !first) {
      summary = r.summary;
      next = { ...next, holdSummary: r.state.s !== 'ready' };
    }
  }
  return { live: next, summary };
}

// The watch sends a countdown only every 30 to 60 s: count down locally between its messages.
export function liveMessage(live, nowMs) {
  if (!live.msg || live.holdSummary) return null;
  const m = { ...live.msg };
  if (m.left_s !== undefined) m.left_s = Math.max(0, m.left_s - Math.floor((nowMs - live.at) / 1000));
  return m;
}

// ---- watch simulator -------------------------------------------------------------------------
// Sends the same messages as the watch in demo mode. Short phases (30 s focus, 15 s break) so a demo
// fits in a minute; the factors 58 and 29 make the screen show realistic minutes.
const SIM = { FOCUS_S: 30, BREAK_S: 15, TARGET: 100, REST: 58, HOLD_S: 3, AUTO_MOVE_S: 4, MAX_HR: 124, MIN_HR: 64 };
export const NEW_SIM = { state: 'ready', left: 0, hr: 64, hold: 0, moving: false, wait: 0 };

export const simStart = (sim) => (sim.state === 'ready' ? { ...sim, state: 'focus', left: SIM.FOCUS_S } : sim);
export const simMove = (sim) => ({ ...sim, moving: true });

// One second of the simulator. Returns { sim, msgs } with the messages to apply in order.
export function simTick(sim, local) {
  const s = { ...sim };
  const msgs = [];
  if (s.state === 'focus') {
    s.left--;
    msgs.push({ t: 'state', s: 'focus', left_s: s.left * 58, planned_s: SIM.FOCUS_S * 58 });
    if (s.left <= 0) Object.assign(s, { state: 'earn', hold: 0, wait: 0, moving: false });
  } else if (s.state === 'earn') {
    if (++s.wait >= SIM.AUTO_MOVE_S) s.moving = true;   // the demo starts to move by itself
    s.hr = s.moving ? Math.min(SIM.MAX_HR, s.hr + 5) : Math.max(SIM.MIN_HR, s.hr - 2);
    s.hold = s.hr >= SIM.TARGET ? s.hold + 1 : 0;
    msgs.push({ t: 'state', s: 'earn', hr: s.hr, target: SIM.TARGET, rest: SIM.REST });
    if (s.hold >= SIM.HOLD_S) Object.assign(s, { state: 'break', left: SIM.BREAK_S });
  } else if (s.state === 'break') {
    s.left--;
    s.hr = Math.max(SIM.MIN_HR, s.hr - 3);
    msgs.push({ t: 'state', s: 'break', left_s: s.left * 29, planned_s: SIM.BREAK_S * 29 });
    if (s.left <= 0) {
      msgs.push({ t: 'summary', score: 82, min: local.next_min, place: 'Platform Calgary', streak: local.streak + 1, next_min: local.next_min });
      s.state = 'ready';
    }
  }
  return { sim: s, msgs };
}
