// Focus tab: the ring that follows the watch. In the locked state the same stage covers the whole phone.
import { useRef } from 'react';
import { Animated, Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { T, FILL } from '../theme';
import { awayNote, hmm } from '../logic';
import { Card, Chip, H2, Muted, Ring, s as ui } from '../ui';

const HOLD_MS = 3000;          // a 3 s hold, so the emergency unlock is never a reflex
const RING_MAX_PX = 290;
const HALO_ALPHA = '1f';        // 12 % of the ring color behind the number: the state is readable at arm's length

// idle: what the ring shows while no block runs (the next block length), instead of an empty value.
export function Stage({ view, idle, away }) {
  const { width } = useWindowDimensions();
  const size = Math.min(width * 0.74, RING_MAX_PX);
  const ready = view.state === 'READY' && idle != null;
  return (
    <View style={st.stage}>
      <View style={{ width: size, height: size, marginTop: 18, marginBottom: 16 }}>
        <View style={[st.halo, { backgroundColor: view.ringColor + HALO_ALPHA }]} />
        <Ring size={size} frac={view.ringFrac} color={view.ringColor} />
        <View style={st.mid} pointerEvents="none">
          <Chip term={view.term || 'READY'} />
          <Text style={st.big}>{ready ? idle : view.big}</Text>
          <Muted>{ready ? 'min block' : view.sub}</Muted>
        </View>
      </View>
      <Text style={st.title}>{view.title}</Text>
      <Muted style={st.text}>{view.text}</Muted>
      {!!awayNote(away) && view.state !== 'READY' && <Text style={st.away}>{awayNote(away)}</Text>}
    </View>
  );
}

function HoldToUnlock({ onUnlock }) {
  const fill = useRef(new Animated.Value(0)).current;
  const timer = useRef(null);
  const stop = () => {
    clearTimeout(timer.current);
    fill.stopAnimation();
    fill.setValue(0);
  };
  const start = () => {
    Animated.timing(fill, { toValue: 1, duration: HOLD_MS, useNativeDriver: false }).start();
    timer.current = setTimeout(() => { stop(); onUnlock(); }, HOLD_MS);
  };
  const width = fill.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] });
  return (
    <Pressable onPressIn={start} onPressOut={stop} style={st.unlock} accessibilityRole="button"
      accessibilityLabel="Emergency: hold 3 seconds to unlock">
      <Animated.View style={[st.unlockFill, { width }]} />
      <Text style={st.unlockText}>Emergency: hold 3 s to unlock</Text>
    </Pressable>
  );
}

// Full-screen lock view. The App hides the tab bar while this shows.
export function LockScreen({ view, onUnlock, away }) {
  return (
    <View style={st.lock}>
      <Stage view={view} away={away} />
      <HoldToUnlock onUnlock={onUnlock} />
    </View>
  );
}

export default function FocusScreen({ view, me, weekMin, away }) {
  return (
    <View>
      <Stage view={view} idle={me.next_min} away={away} />
      <View style={st.stats}>
        <Stat value={me.streak} unit={me.streak === 1 ? 'day' : 'days'} term="STREAK" color={T.warn} />
        <Stat value={hmm(weekMin)} unit="h this week" color={T.good} />
        <Stat value={me.next_min} unit="min" term="BLOCK" color={T.calm} />
      </View>
      <Card>
        <View style={ui.row}>
          <View style={{ flex: 1 }}>
            <H2>Last night</H2>
            <Muted>From the health store of this phone. One number goes to the watch.</Muted>
          </View>
          <Text style={[ui.score, { color: T.fg }]}>{(me.sleep_hours != null ? me.sleep_hours : 6.4) + ' h'}</Text>
        </View>
      </Card>
    </View>
  );
}

// A tile: the shared term in its box when there is one, then the value with its unit.
const Stat = ({ value, unit, term, color }) => (
  <View style={st.stat}>
    <View style={st.statHead}>{term ? <Chip term={term} size={11} /> : <Muted>Focus time</Muted>}</View>
    <Text style={[st.statValue, { color }]}>{value}</Text>
    <Muted style={{ textAlign: 'center' }}>{unit}</Muted>
  </View>
);

const st = StyleSheet.create({
  stage: { alignItems: 'center', paddingTop: 8 },
  mid: { ...FILL, alignItems: 'center', justifyContent: 'center', gap: 4 },
  halo: { ...FILL, borderRadius: 999, margin: 18 },
  state: { fontSize: 13, fontWeight: '800', letterSpacing: 2.2 },
  big: { color: T.fg, fontSize: 76, fontWeight: '800', lineHeight: 82, fontVariant: ['tabular-nums'] },
  title: { color: T.fg, fontWeight: '800', fontSize: 22, marginTop: 4, textAlign: 'center' },
  text: { maxWidth: 300, marginTop: 6, marginBottom: 14, textAlign: 'center', fontSize: 15, lineHeight: 21 },
  away: { color: T.warn, fontSize: 14.5, fontWeight: '700', textAlign: 'center', maxWidth: 310, marginBottom: 12 },
  lock: { ...FILL, zIndex: 20, elevation: 20, backgroundColor: T.bg, justifyContent: 'center', alignItems: 'center', padding: 24 },
  unlock: { marginTop: 36, borderWidth: 1, borderColor: T.line, borderRadius: 999, paddingVertical: 14, paddingHorizontal: 22, overflow: 'hidden' },
  unlockFill: { position: 'absolute', left: 0, top: 0, bottom: 0, backgroundColor: T.unlockFill },
  unlockText: { color: T.muted, fontSize: 13 },
  stats: { flexDirection: 'row', gap: 10, marginVertical: 6 },
  stat: { flex: 1, alignItems: 'center', backgroundColor: T.panel, borderRadius: 18, paddingVertical: 14, paddingHorizontal: 6 },
  statValue: { fontSize: 30, fontWeight: '800', fontVariant: ['tabular-nums'] },
  statHead: { height: 26, justifyContent: 'center', marginBottom: 2 },
});
