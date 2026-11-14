// Journal tab: the week chart and the own sessions.
import { Text, View } from 'react-native';
import Svg, { Rect, Text as SvgText } from 'react-native-svg';
import { T } from '../theme';
import { dayText, hmm, levelColor, mean } from '../logic';
import { Card, Chip, H2, Muted, s as ui } from '../ui';

// Chart geometry in viewBox units, same as the web page: 7 bars of 28 in a 300 x 120 box.
const W = 300;
const H = 120;
const BAR_W = 28;
const GAP = (W - 7 * BAR_W) / 6;
const BASE_Y = 96;          // bottom of the bars, room below for the day labels
const MAX_BAR_H = 80;
const MIN_SCALE_MIN = 30;   // a light week still shows short bars, not full-height ones

function WeekChart({ week }) {
  const max = Math.max(MIN_SCALE_MIN, ...week.map((d) => d.min));
  return (
    <View style={{ marginTop: 8 }}>
      <Svg width="100%" style={{ aspectRatio: W / H }} viewBox={`0 0 ${W} ${H}`}
        accessibilityLabel="Focus minutes per day, color by score">
        {week.map((d, i) => {
          const h = Math.round((MAX_BAR_H * d.min) / max);
          const x = i * (BAR_W + GAP);
          return [
            <Rect key={'r' + i} x={x} y={BASE_Y - h} width={BAR_W} height={Math.max(h, 2)} rx="6"
              fill={d.min ? levelColor(d.score) : T.line} />,
            d.min ? (
              <SvgText key={'m' + i} x={x + BAR_W / 2} y={90 - h} textAnchor="middle" fontSize="10" fill={T.muted}>{String(d.min)}</SvgText>
            ) : null,
            <SvgText key={'d' + i} x={x + BAR_W / 2} y="113" textAnchor="middle" fontSize="11" fontWeight={i === week.length - 1 ? '700' : '400'}
              fill={i === week.length - 1 ? T.fg : T.muted}>{i === week.length - 1 ? 'Today' : d.day}</SvgText>,
          ];
        })}
      </Svg>
      <Muted>Minutes per day. Color shows the Focus Score.</Muted>
    </View>
  );
}

// The answer first, the chart second: three numbers that sum up the week.
const Fact = ({ value, label, color }) => (
  <View style={{ flex: 1 }}>
    <Text style={{ color, fontSize: 26, fontWeight: '800', fontVariant: ['tabular-nums'] }}>{value}</Text>
    <Muted>{label}</Muted>
  </View>
);

export default function JournalScreen({ me }) {
  const days = me.week.filter((d) => d.min > 0);
  const weekMin = me.week.reduce((a, d) => a + d.min, 0);
  return (
    <View>
      <Card>
        <H2>This week</H2>
        <View style={{ flexDirection: 'row', marginTop: 4 }}>
          <Fact value={hmm(weekMin)} label="hours focused" color={T.good} />
          <Fact value={mean(days.map((d) => d.score))} label="mean score" color={levelColor(mean(days.map((d) => d.score)))} />
          <Fact value={days.length + ' / 7'} label="active days" color={T.calm} />
        </View>
        <WeekChart week={me.week} />
      </Card>
      <Card>
        <View style={[ui.row, { marginBottom: 2 }]}><H2>Sessions</H2><Chip term="SCORE" size={11} /></View>
        {me.sessions.map((s, i) => (
          <View key={i} style={[ui.item, i === 0 && ui.itemFirst, ui.row]}>
            <View style={{ flex: 1 }}>
              <Text style={ui.bold}>{s.place || 'No place'}</Text>
              <Muted>{dayText(s.day) + ' · ' + s.part + ' · ' + s.min + ' min' + (s.exits ? ' · phone ' + s.exits + 'x' : '')}</Muted>
            </View>
            <Text style={[ui.score, { color: levelColor(s.score) }]}>{s.score}</Text>
          </View>
        ))}
      </Card>
    </View>
  );
}
