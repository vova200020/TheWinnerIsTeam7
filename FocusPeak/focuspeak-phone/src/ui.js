// Small shared building blocks for the screens.
import { StyleSheet, Text, View } from 'react-native';
import Svg, { Circle, G, Path } from 'react-native-svg';
import { T, card } from './theme';
import { levelColor } from './logic';
import { TERMS, TERM_FONT } from './terms';

export const Card = ({ children, style }) => <View style={[card, style]}>{children}</View>;
export const H2 = ({ children }) => <Text style={s.h2}>{children}</Text>;
export const Muted = ({ children, style }) => <Text style={[s.muted, style]}>{children}</Text>;

// A shared term in its box: the same word, color and pill shape as on the watch (see terms.js).
const CHIP_FILL_ALPHA = '26';      // 15 % of the term color inside the box
const CHIP_EDGE_ALPHA = '99';      // 60 % for the outline
export function Chip({ term, size = 13 }) {
  const t = TERMS[term];
  if (!t) return null;
  return (
    <View style={{ alignSelf: 'center', backgroundColor: t.color + CHIP_FILL_ALPHA, borderColor: t.color + CHIP_EDGE_ALPHA,
      borderWidth: 1.2, borderRadius: 999, paddingVertical: size * 0.28, paddingHorizontal: size * 0.85 }}>
      <Text style={{ color: t.color, fontFamily: TERM_FONT, fontSize: size, fontWeight: '700', letterSpacing: size * 0.03 }}
        accessibilityRole="text">{t.text}</Text>
    </View>
  );
}

// A score bar from 0 to 100, colored like the web page.
export function ScoreBar({ percent, color }) {
  return (
    <View style={s.bar}>
      <View style={[s.barFill, { width: Math.min(100, Math.max(0, percent)) + '%', backgroundColor: color }]} />
    </View>
  );
}

// A list of named rows, each with a score bar.
export function Bars({ rows, nameOf, valueOf }) {
  return rows.map((r, i) => (
    <View key={nameOf(r) + i} style={[s.item, i === 0 && s.itemFirst]}>
      <View style={s.row}>
        <Text style={s.fg}>{nameOf(r)}</Text>
        <Text style={s.bold}>{valueOf(r)}</Text>
      </View>
      <ScoreBar percent={r.score} color={levelColor(r.score)} />
    </View>
  ));
}

const RING_R = 45;
const RING_LEN = 2 * Math.PI * RING_R;

// Circular progress ring. The rotation makes 0 % start at the top, like a watch hand.
export function Ring({ size, frac, color }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <G rotation={-90} origin="50, 50">
        <Circle cx="50" cy="50" r={RING_R} fill="none" stroke={T.panel2} strokeWidth="6" />
        <Circle cx="50" cy="50" r={RING_R} fill="none" stroke={color} strokeWidth="6" strokeLinecap="round"
          strokeDasharray={`${RING_LEN} ${RING_LEN}`} strokeDashoffset={RING_LEN * (1 - frac)} />
      </G>
    </Svg>
  );
}

// The tab icons of the web page, same paths.
const ICONS = {
  focus: (c) => [<Circle key="a" cx="12" cy="12" r="8.5" stroke={c} />, <Circle key="b" cx="12" cy="12" r="2.5" stroke={c} />],
  journal: (c) => [<Path key="a" d="M5 20V11M12 20V4M19 20v-7" stroke={c} />],
  friends: (c) => [<Circle key="a" cx="8.5" cy="9" r="3" stroke={c} />, <Circle key="b" cx="16.5" cy="10" r="2.5" stroke={c} />,
    <Path key="c" d="M3 19c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5M15 14.6c2.6-.4 5 .9 6 4.4" stroke={c} />],
  you: (c) => [<Circle key="a" cx="12" cy="8" r="3.5" stroke={c} />, <Path key="b" d="M5 20c.8-3.8 3.6-5.5 7-5.5s6.2 1.7 7 5.5" stroke={c} />],
};

export function TabIcon({ name, color }) {
  return (
    <Svg width={22} height={22} viewBox="0 0 24 24" fill="none" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
      {ICONS[name](color)}
    </Svg>
  );
}

export const s = StyleSheet.create({
  h2: { color: T.fg, fontSize: 17, fontWeight: '800', marginBottom: 6 },
  muted: { color: T.muted, fontSize: 14, lineHeight: 20 },
  fg: { color: T.fg, fontSize: 16 },
  bold: { color: T.fg, fontSize: 16, fontWeight: '700' },
  row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 12 },
  item: { paddingVertical: 12, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: T.line },
  itemFirst: { borderTopWidth: 0 },
  bar: { height: 10, borderRadius: 5, backgroundColor: T.panel2, overflow: 'hidden', marginTop: 6 },
  barFill: { height: '100%', borderRadius: 5 },
  score: { fontSize: 27, fontWeight: '700', fontVariant: ['tabular-nums'] },
  me: { color: T.calm },
});
