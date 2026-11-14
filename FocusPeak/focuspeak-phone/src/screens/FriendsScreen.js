// Friends tab: served by the backend. A place label only: never coordinates, never Home.
import { Pressable, Text, Vibration, View } from 'react-native';
import { T } from '../theme';
import { hmm, levelColor, nextRival } from '../logic';
import { Bars, Card, H2, Muted, ScoreBar, s as ui } from '../ui';

const FEED_ROWS = 8;
const TOUCH_MIN_PX = 48;        // smallest touch target (Material Design accessibility guidance)
const KUDOS_BUZZ_MS = 12;       // a short tick confirms the tap without a look at the screen

export default function FriendsScreen({ board, challenge, places, feed, onKudos }) {
  const rival = nextRival(board);
  const topMin = Math.max(1, ...board.map((r) => r.min));
  return (
    <View>
      <Card>
        <View style={ui.row}>
          <H2>{challenge.name}</H2>
          <Text style={ui.bold}>{hmm(challenge.total_min) + ' / ' + hmm(challenge.goal_min) + ' h'}</Text>
        </View>
        <ScoreBar percent={challenge.percent} color={T.good} />
        <Muted style={{ marginTop: 6 }}>{challenge.percent >= 100 ? 'Goal reached. Well done, team.' : hmm(Math.max(0, challenge.goal_min - challenge.total_min)) + ' h to the team goal. Every focus minute counts.'}</Muted>
      </Card>
      <Card>
        <H2>Leaderboard</H2>
        {board.map((r, i) => {
          const mine = r.user === 'You';
          return (
            <View key={r.user} style={[ui.item, i === 0 && ui.itemFirst, mine && { backgroundColor: 'rgba(77,163,255,0.10)', marginHorizontal: -10, paddingHorizontal: 10, borderRadius: 12, borderTopWidth: 0 }]}>
              <View style={ui.row}>
                <Text style={ui.fg}>
                  <Text style={{ color: T.muted }}>{(i + 1) + '   '}</Text>
                  <Text style={[ui.bold, mine && ui.me]}>{r.user}</Text>
                </Text>
                <Text style={ui.fg}>
                  {hmm(r.min) + ' h   '}
                  <Text style={[ui.bold, { color: levelColor(r.score) }]}>{r.score}</Text>
                </Text>
              </View>
              {/* Bar length = focus time against the leader: the ranking reads without the numbers. */}
              <ScoreBar percent={(100 * r.min) / topMin} color={mine ? T.calm : T.muted} />
            </View>
          );
        })}
        {rival && <Muted style={{ marginTop: 10 }}>{(rival.min >= 60 ? hmm(rival.min) + ' h' : rival.min + ' min') + ' more and you pass ' + rival.user + '.'}</Muted>}
      </Card>
      <Card>
        <H2>Good places to focus</H2>
        <Bars rows={places} nameOf={(r) => r.place} valueOf={(r) => r.score + ' · ' + r.users + (r.users === 1 ? ' person' : ' people')} />
        <Muted style={{ marginTop: 8 }}>Shared by label only. Home is never shared.</Muted>
      </Card>
      <Card>
        <H2>Friends feed</H2>
        {feed.slice(0, FEED_ROWS).map((f, i) => (
          <View key={String(f.id)} style={[ui.item, i === 0 && ui.itemFirst, ui.row]}>
            <View style={{ flex: 1 }}>
              <Text style={ui.fg}>
                <Text style={[ui.bold, f.user === 'You' && ui.me]}>{f.user}</Text>
                {' '}
                <Text style={[ui.bold, { color: levelColor(f.score) }]}>{f.score}</Text>
              </Text>
              <Muted>{(f.place || 'Private place') + ' · ' + f.min + ' min · ' + f.ago}</Muted>
            </View>
            <Pressable onPress={() => { Vibration.vibrate(KUDOS_BUZZ_MS); onKudos(f.id); }} accessibilityRole="button" accessibilityLabel={'Kudos for ' + f.user}
              style={({ pressed }) => [{
                backgroundColor: T.panel2, borderColor: T.line, borderWidth: 1, borderRadius: 999,
                paddingHorizontal: 14, minWidth: 72, minHeight: TOUCH_MIN_PX, alignItems: 'center', justifyContent: 'center',
              }, pressed && { transform: [{ scale: 0.96 }] }]}>
              <Text style={{ color: T.fg, fontSize: 15 }}>{'👏 ' + f.kudos}</Text>
            </Pressable>
          </View>
        ))}
      </Card>
    </View>
  );
}
