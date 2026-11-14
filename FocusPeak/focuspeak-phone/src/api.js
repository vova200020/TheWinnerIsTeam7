// HTTP helpers for main_project/backend/server.py.
// 127.0.0.1 on the phone reaches the laptop through `adb reverse tcp:8787 tcp:8787`.
export const BACKEND_URL = 'http://127.0.0.1:8787';
export const PROBE_TIMEOUT_MS = 2000;   // long enough for USB, short enough that offline start feels instant
const REQUEST_TIMEOUT_MS = 3000;        // a poll must not pile up behind a dead connection

async function request(path, options = {}, timeoutMs = REQUEST_TIMEOUT_MS) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(BACKEND_URL + path, { ...options, signal: ctrl.signal });
    if (!r.ok) throw new Error('HTTP ' + r.status + ' for ' + path);
    return await r.json();
  } finally {
    clearTimeout(timer);
  }
}

export const getJson = (path, timeoutMs) => request(path, {}, timeoutMs);

export const postJson = (path, body) =>
  request(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

export async function probeBackend() {
  try {
    await getJson('/api/state', PROBE_TIMEOUT_MS);
    return true;
  } catch (e) {
    return false;
  }
}

// The five community and journal views, fetched together so the screen never mixes old and new data.
export async function fetchAll() {
  const [me, board, places, feed, challenge] = await Promise.all(
    ['me', 'leaderboard', 'places', 'feed', 'challenge'].map((n) => getJson('/api/' + n)));
  return { me, board, places, feed, challenge };
}
