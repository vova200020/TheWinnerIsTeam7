// Run: node src/logic.test.mjs   (plain Node, no test framework)
import assert from 'node:assert/strict';
import {
  levelColor, clock, dayPart, dayText, localMe, makeExampleData, applyMessage, emergencyUnlock,
  READY_VIEW, NEW_LOCK, NEW_LIVE, livePoll, liveMessage, NEW_SIM, simStart, simTick, buildBoard, challengeOf,
} from './logic.js';
import { T } from './theme.js';

let passed = 0;
const test = (name, fn) => { fn(); passed++; console.log('ok   ' + name); };

test('levelColor thresholds', () => {
  assert.equal(levelColor(100), T.good);
  assert.equal(levelColor(70), T.good);
  assert.equal(levelColor(69), T.warn);
  assert.equal(levelColor(40), T.warn);
  assert.equal(levelColor(39), T.bad);
  assert.equal(levelColor(0), T.bad);
});

test('clock', () => {
  assert.equal(clock(0), '0:00');
  assert.equal(clock(59), '0:59');
  assert.equal(clock(60), '1:00');
  assert.equal(clock(360), '6:00');
  assert.equal(clock(435), '7:15');
  assert.equal(clock(-5), '0:00');
  assert.equal(clock(61.9), '1:01');
});

test('dayPart boundaries', () => {
  assert.equal(dayPart(4), 3);
  assert.equal(dayPart(5), 0);
  assert.equal(dayPart(11), 0);
  assert.equal(dayPart(12), 1);
  assert.equal(dayPart(16), 1);
  assert.equal(dayPart(17), 2);
  assert.equal(dayPart(21), 2);
  assert.equal(dayPart(22), 3);
});

test('dayText', () => {
  const now = new Date(2026, 10, 14, 15, 0);
  assert.equal(dayText('2026-11-14', now), 'Today');
  assert.equal(dayText('2026-11-13', now), 'Yesterday');
  assert.equal(dayText('2026-11-12', now), 'Thu 12 Nov');
  assert.equal(dayText('3 days ago', now), '3 days ago');
});

const focus = { t: 'state', s: 'focus', left_s: 1440, planned_s: 1440 };
const earn = { t: 'state', s: 'earn', hr: 96, target: 104, rest: 58 };
const brk = { t: 'state', s: 'break', left_s: 360, planned_s: 360 };

test('lock rule: focus and earn lock, break and ready unlock', () => {
  let r = applyMessage(READY_VIEW, NEW_LOCK, focus);
  assert.equal(r.view.locked, true);
  assert.equal(r.view.big, '24');
  r = applyMessage(r.view, r.lock, earn);
  assert.equal(r.view.locked, true);
  assert.equal(r.view.ringColor, T.warn);
  r = applyMessage(r.view, r.lock, brk);
  assert.equal(r.view.locked, false);
  assert.equal(r.vibrate, true);
  assert.equal(r.view.big, '6:00');
  r = applyMessage(r.view, r.lock, brk);
  assert.equal(r.vibrate, false, 'vibrate once per break, not per message');
  r = applyMessage(r.view, r.lock, { t: 'state', s: 'ready' });
  assert.equal(r.view.locked, false);
});

test('lock rule: override holds within a phase and through earn, a new phase clears it', () => {
  let r = applyMessage(READY_VIEW, NEW_LOCK, focus);
  r = emergencyUnlock(r.view, r.lock);
  assert.equal(r.view.locked, false);
  r = applyMessage(r.view, r.lock, { ...focus, left_s: 1400 });
  assert.equal(r.view.locked, false, 'same phase keeps the override');
  r = applyMessage(r.view, r.lock, earn);
  assert.equal(r.view.locked, false, 'earn keeps the override');
  r = applyMessage(r.view, r.lock, brk);
  r = applyMessage(r.view, r.lock, focus);
  assert.equal(r.view.locked, true, 'the next focus block locks again');
});

test('summary view', () => {
  const r = applyMessage(READY_VIEW, NEW_LOCK, { t: 'summary', score: 82, min: 24, place: 'Library', streak: 1, next_min: 29 });
  assert.equal(r.isSummary, true);
  assert.equal(r.view.sub, 'streak 1 day');
  assert.equal(r.view.ringColor, T.good);
});

test('localMe known answers from the example data', () => {
  const me = localMe(makeExampleData().local, new Date(2026, 10, 14));
  assert.equal(me.total, 14);
  assert.deepEqual(me.parts[0], { name: 'Morning', score: 82, n: 6 });
  assert.deepEqual(me.places[0], { name: 'Library', score: 82, n: 6 });
  assert.equal(me.week.length, 7);
  assert.equal(me.week[6].day, 'Sat');
  assert.equal(me.week[5].min, 58);
  assert.equal(me.sessions[0].day, 'Yesterday');
});

test('offline board adds You, challenge sums the board', () => {
  const data = makeExampleData();
  const me = localMe(data.local, new Date(2026, 10, 14));
  const board = buildBoard(data, me, false);
  assert.equal(board.length, 4);
  assert.ok(board.some((r) => r.user === 'You'));
  const ch = challengeOf(data, board);
  assert.equal(ch.total_min, board.reduce((a, r) => a + r.min, 0));
});

test('live poll: first summary is history, later summary is shown, countdown runs locally', () => {
  let { live, summary } = livePoll(NEW_LIVE, { seq: 3, state: focus, age_s: 0, summary: { t: 'summary', score: 50 } }, 10000);
  assert.equal(summary, null);
  assert.equal(liveMessage(live, 70000).left_s, 1380);
  ({ live, summary } = livePoll(live, { seq: 4, state: { t: 'state', s: 'ready' }, age_s: 0, summary: { t: 'summary', score: 82 } }, 80000));
  assert.equal(summary.score, 82);
  assert.equal(live.holdSummary, false);
});

test('simulator runs focus, earn with auto move, break, summary', () => {
  let sim = simStart(NEW_SIM);
  const local = makeExampleData().local;
  const seen = [];
  for (let i = 0; i < 120 && !(seen.includes('summary') && sim.state === 'ready'); i++) {
    const r = simTick(sim, local);
    sim = r.sim;
    r.msgs.forEach((m) => { const k = m.t === 'summary' ? 'summary' : m.s; if (seen[seen.length - 1] !== k) seen.push(k); });
  }
  assert.deepEqual(seen, ['focus', 'earn', 'break', 'summary']);
});

console.log(passed + ' tests passed');

// ---- added: duration format and the next rival ----
{
  const { hmm, nextRival } = await import('./logic.js');
  const assert = (await import('node:assert')).default;
  assert.equal(hmm(193), '3:13');
  assert.equal(hmm(60), '1:00');
  assert.equal(hmm(29), '0:29');
  assert.equal(hmm(1200), '20:00');
  const board = [{ user: 'Maya', min: 310 }, { user: 'Arjun', min: 265 }, { user: 'You', min: 193 }, { user: 'Sam', min: 190 }];
  assert.deepEqual(nextRival(board), { user: 'Arjun', min: 73 });
  assert.equal(nextRival([{ user: 'You', min: 400 }, { user: 'Maya', min: 310 }]), null);
  console.log('ok   hmm() and nextRival()');
}

// ---- added: live recovery text in the break ----
{
  const { breakText } = await import('./logic.js');
  const assert = (await import('node:assert')).default;
  assert.equal(breakText({}), 'Enjoy the break. The phone locks again at the next block.');
  assert.equal(breakText({ hr: 98, steps: 40, ok: 0 }), 'Heart rate 98 bpm · 40 steps. Recovering. A short walk helps.');
  assert.equal(breakText({ hr: 72, steps: 0, ok: 1 }), 'Heart rate 72 bpm. Recovered: you are ready for the next block.');
  console.log('ok   breakText()');
}

// ---- added: phone use during focus ----
{
  const { phonePenalty, awayNote } = await import('./logic.js');
  const assert = (await import('node:assert')).default;
  assert.equal(phonePenalty(0, 0), 0);
  assert.equal(phonePenalty(1, 0), 5);
  assert.equal(phonePenalty(2, 35), 15);
  assert.equal(phonePenalty(3, 600), 30);
  assert.equal(awayNote({ exits: 0, sec: 0 }), '');
  assert.equal(awayNote({ exits: 2, sec: 35 }), 'You left the app 2 times (0:35 away). Focus score -15.');
  console.log('ok   phonePenalty() and awayNote()');
}
