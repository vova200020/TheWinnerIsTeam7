// FocusPeak phone app: the shell, the four tabs and the link to the watch.
// Port of main_project/phone/index.html. The message contract is main_project/phone/LINK.md.
// Live mode: the laptop backend (main_project/backend/server.py) relays the watch, polled once per second.
// Offline mode: example data and a built-in watch simulator, so the demo never depends on the network.
import { useEffect, useRef, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import {
  AppState, BackHandler, Platform, Pressable, ScrollView, StatusBar as RNStatusBar, StyleSheet, Text, Vibration, View,
} from 'react-native';
import { T } from './src/theme';
import {
  EXAMPLE_SLEEP_H, NEW_AWAY, NEW_LIVE, NEW_LOCK, NEW_SIM, READY_VIEW, addLocalSummary, applyMessage, buildBoard, challengeOf,
  emergencyUnlock, liveMessage, livePoll, localMe, makeExampleData, simMove, simStart, simTick, weekMinutes,
} from './src/logic';
import { fetchAll, getJson, postJson, probeBackend } from './src/api';
import { TabIcon } from './src/ui';
import FocusScreen, { LockScreen } from './src/screens/FocusScreen';
import JournalScreen from './src/screens/JournalScreen';
import FriendsScreen from './src/screens/FriendsScreen';
import YouScreen from './src/screens/YouScreen';

const POLL_MS = 1000;            // the watch sends a state at most every 2 s: 1 s keeps the lock prompt
const REFRESH_MS = 5000;         // community data changes slowly
const RETRY_MS = 10000;          // offline: look for the backend again, so a late laptop start still goes live
const SIM_TICK_MS = 1000;
// Web pattern [120, 80, 120] is buzz, pause, buzz. Android reads the first value as a wait, so lead with 0.
const BREAK_VIBRATION_MS = Platform.OS === 'android' ? [0, 120, 80, 120] : [120, 80, 120];
// No safe-area library in this project: the status bar height is known, the bottom inset is a fixed
// margin that clears a 3-button Android navigation bar in edge-to-edge mode.
const TOP_INSET_PX = RNStatusBar.currentHeight || 0;
const BOTTOM_INSET_PX = Platform.OS === 'android' ? 48 : 34;

const TABS = [['focus', 'Focus'], ['journal', 'Journal'], ['friends', 'Friends'], ['you', 'You']];

export default function App() {
  // Timers and the poll loop read and write this store; a state bump redraws. One source of truth,
  // no stale closures in the intervals.
  const store = useRef(null);
  if (!store.current) {
    store.current = { view: READY_VIEW, lock: NEW_LOCK, data: makeExampleData(), live: NEW_LIVE, sim: NEW_SIM, away: { ...NEW_AWAY } };
  }
  const S = store.current;
  const [, setFrame] = useState(0);
  const redraw = () => setFrame((n) => n + 1);
  const [tab, setTab] = useState('focus');
  const scroll = useRef(null);

  const refresh = async () => {
    if (S.live.on) {
      try {
        S.data = { ...S.data, ...(await fetchAll()) };
      } catch (e) { /* the backend stopped: keep the last data */ }
    }
    redraw();
  };

  const handleMessage = (m) => {
    // A new block starts with a clean phone-use count.
    if (m.t === 'state' && m.s === 'focus' && !['focus', 'earn', 'break'].includes(S.lock.last)) S.away = { ...NEW_AWAY };
    const r = applyMessage(S.view, S.lock, m);
    S.view = r.view;
    S.lock = r.lock;
    if (r.vibrate) Vibration.vibrate(BREAK_VIBRATION_MS);
    if (r.isSummary) {
      if (!S.live.on) S.data = addLocalSummary(S.data, m, new Date().getHours(), Date.now());
      refresh();
    }
    redraw();
  };

  useEffect(() => {
    let alive = true;
    let polling = false;
    let probing = false;
    const timers = [];

    const pollState = async () => {
      if (polling) return;           // a slow answer must not stack a second request
      polling = true;
      try {
        const r = await getJson('/api/state');
        if (!alive) return;
        const p = livePoll(S.live, r, Date.now());
        S.live = p.live;
        if (p.summary) handleMessage(p.summary);
        const m = liveMessage(S.live, Date.now());
        if (m) handleMessage(m);
      } catch (e) {
        /* the backend stopped: keep the last screen */
      } finally {
        polling = false;
      }
    };

    const goLive = () => {
      S.live = { ...NEW_LIVE, on: true };
      // A native build reads this number from the health store of the phone. Here it is an example value.
      postJson('/api/sleep', { hours: EXAMPLE_SLEEP_H }).catch(() => {});
      timers.push(setInterval(pollState, POLL_MS), setInterval(refresh, REFRESH_MS));
      pollState();
      refresh();
    };

    const tryBackend = async () => {
      if (probing || S.live.on) return;
      probing = true;
      const ok = await probeBackend();
      probing = false;
      if (alive && ok && !S.live.on) goLive();
    };

    timers.push(setInterval(() => {
      if (S.live.on) return;
      const r = simTick(S.sim, S.data.local);
      S.sim = r.sim;
      r.msgs.forEach(handleMessage);
    }, SIM_TICK_MS));
    timers.push(setInterval(tryBackend, RETRY_MS));
    tryBackend();

    return () => {
      alive = false;
      timers.forEach(clearInterval);
    };
  }, []);

  const locked = S.view.locked;

  // Focus time means no phone time. Leaving this app while a block wants the phone locked is
  // counted, sent to the backend (the watch lowers the Focus score) and shown on return.
  useEffect(() => {
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'background' && S.view.wantLock && !S.away.leftAt) {
        S.away.leftAt = Date.now();
      } else if (next === 'active' && S.away.leftAt) {
        const seconds = Math.max(1, Math.round((Date.now() - S.away.leftAt) / 1000));
        S.away = { exits: S.away.exits + 1, sec: S.away.sec + seconds, leftAt: 0 };
        if (S.live.on) postJson('/api/away', { seconds }).catch(() => {});
        redraw();
      }
    });
    return () => sub.remove();
  }, []);

  // While locked, the Android back button must not leave the lock view.
  useEffect(() => {
    if (!locked) return undefined;
    const sub = BackHandler.addEventListener('hardwareBackPress', () => true);
    return () => sub.remove();
  }, [locked]);

  const onUnlock = () => {
    // The laptop pins this app during focus (backend --pin). The emergency hold must also end that pin.
    if (S.live.on) postJson('/api/unlock', {}).catch(() => {});
    const r = emergencyUnlock(S.view, S.lock);
    S.view = r.view;
    S.lock = r.lock;
    redraw();
  };

  const onKudos = (id) => {
    S.data = { ...S.data, feed: S.data.feed.map((f) => (f.id === id ? { ...f, kudos: f.kudos + 1 } : f)) };
    redraw();
    if (S.live.on) postJson('/api/kudos', { id }).catch(() => {});
  };

  const openTab = (name) => {
    setTab(name);
    scroll.current?.scrollTo({ y: 0, animated: false });
  };

  const me = S.data.me || localMe(S.data.local);
  const weekMin = weekMinutes(me);
  const board = buildBoard(S.data, me, S.live.on);

  return (
    <View style={st.root}>
      <StatusBar style="light" />
      <View style={st.header}>
        <Text style={st.h1}>Focus<Text style={{ color: T.good }}>Peak</Text></Text>
        {/* Left side, next to the name: the top right corner belongs to system and tool buttons. */}
        <View style={st.tag}>
          <View style={[st.dot, { backgroundColor: S.live.on ? T.good : T.warn }]} />
          <Text style={[st.tagText, { color: S.live.on ? T.good : T.warn }]}>{S.live.on ? 'LIVE' : 'DEMO DATA'}</Text>
        </View>
      </View>

      <ScrollView ref={scroll} style={{ flex: 1 }} contentContainerStyle={st.content}>
        {tab === 'focus' && <FocusScreen view={S.view} me={me} weekMin={weekMin} away={S.away} />}
        {tab === 'journal' && <JournalScreen me={me} />}
        {tab === 'friends' && (
          <FriendsScreen board={board} challenge={challengeOf(S.data, board)} places={S.data.places} feed={S.data.feed} onKudos={onKudos} />
        )}
        {tab === 'you' && <YouScreen me={me} />}
      </ScrollView>

      {!locked && (
        <View style={st.nav}>
          {!S.live.on && (
            <View style={st.sim}>
              <Text style={[st.muted, { flex: 1 }]}>Watch simulator</Text>
              <SimButton label="Start block" onPress={() => { S.sim = simStart(S.sim); }} />
              <SimButton label="Move" onPress={() => { S.sim = simMove(S.sim); }} />
            </View>
          )}
          <View style={st.tabs}>
            {TABS.map(([name, label]) => {
              const on = tab === name;
              return (
                <Pressable key={name} style={st.tabBtn} onPress={() => openTab(name)} accessibilityRole="tab"
                  accessibilityState={{ selected: on }}>
                  <View style={[st.tabPill, on && st.tabPillOn]}><TabIcon name={name} color={on ? T.good : T.muted} /></View>
                  <Text style={[st.tabLabel, on && st.tabLabelOn]}>{label}</Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      )}

      {locked && <LockScreen view={S.view} onUnlock={onUnlock} away={S.away} />}
    </View>
  );
}

const SimButton = ({ label, onPress }) => (
  <Pressable onPress={onPress} style={st.simBtn} accessibilityRole="button">
    <Text style={{ color: T.fg, fontSize: 13.5 }}>{label}</Text>
  </Pressable>
);

const st = StyleSheet.create({
  root: { flex: 1, backgroundColor: T.bg, paddingTop: TOP_INSET_PX },
  header: { flexDirection: 'row', justifyContent: 'flex-start', gap: 12, alignItems: 'center', paddingHorizontal: 16, paddingTop: 14, paddingBottom: 4 },
  h1: { color: T.fg, fontSize: 24, fontWeight: '800', letterSpacing: -0.3 },
  tag: { flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: T.panel, borderRadius: 999, paddingVertical: 5, paddingHorizontal: 11 },
  dot: { width: 8, height: 8, borderRadius: 4 },
  tagText: { fontSize: 11.5, fontWeight: '800', letterSpacing: 1 },
  content: { paddingHorizontal: 16, paddingBottom: 24 },
  muted: { color: T.muted, fontSize: 13.5 },
  nav: { backgroundColor: T.panel, borderTopLeftRadius: 22, borderTopRightRadius: 22, paddingBottom: BOTTOM_INSET_PX },
  sim: { flexDirection: 'row', gap: 8, alignItems: 'center', paddingVertical: 8, paddingHorizontal: 16, borderBottomWidth: 1, borderBottomColor: T.line },
  simBtn: { backgroundColor: T.panel2, borderColor: T.line, borderWidth: 1, borderRadius: 10, paddingVertical: 8, paddingHorizontal: 12 },
  tabs: { flexDirection: 'row' },
  tabBtn: { flex: 1, alignItems: 'center', paddingTop: 8, paddingBottom: 8, gap: 2 },
  tabPill: { paddingVertical: 5, paddingHorizontal: 18, borderRadius: 999 },
  tabPillOn: { backgroundColor: 'rgba(61,220,132,0.14)' },
  tabLabel: { color: T.muted, fontSize: 12 },
  tabLabelOn: { color: T.fg, fontWeight: '700' },
});
