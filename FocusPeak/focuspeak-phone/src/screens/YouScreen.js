// You tab: the personal baseline, the recipe and the evidence behind it.
import { Linking, Text, View } from 'react-native';
import { T } from '../theme';
import { breakMinutes } from '../logic';
import { Bars, Card, Chip, H2, Muted, s as ui } from '../ui';

const WHY = [
  { head: 'Fixed breaks beat self-chosen breaks.', body: ' Less fatigue, more concentration, same work done. ', link: 'Biwer 2023', url: 'https://pubmed.ncbi.nlm.nih.gov/36859717/' },
  { head: 'Move before the break.', body: ' One bout of exercise gives a small to medium gain in attention. ', link: 'Meta-review 2025', url: 'https://pubmed.ncbi.nlm.nih.gov/39883421/' },
  { head: 'Longer breaks after hard work.', body: ' Short breaks raise energy, and hard tasks can need more than 10 min. ', link: 'Albulescu 2022', url: 'https://doi.org/10.1371/journal.pone.0272460' },
  { head: 'Phone out of reach.', body: ' Attention is lower with a phone on the desk. ', link: 'Skowronek 2023', url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC10249922' },
];

const KV = ({ k, term, v }) => (
  <View style={[ui.row, { marginTop: 8 }]}>
    {term ? <Chip term={term} size={12} /> : <Text style={ui.fg}>{k}</Text>}
    <Text style={ui.bold}>{v}</Text>
  </View>
);

export default function YouScreen({ me }) {
  return (
    <View>
      {me.parts.length > 0 && (
        <Card style={{ backgroundColor: 'rgba(61,220,132,0.10)' }}>
          <Muted>What your data says</Muted>
          <Text style={{ color: T.fg, fontSize: 21, fontWeight: '800', lineHeight: 28, marginTop: 4 }}>
            {'You focus best in the ' + me.parts[0].name.toLowerCase() + '.' + (me.places.length ? ' Best place: ' + me.places[0].name + '.' : '')}
          </Text>
          <Muted style={{ marginTop: 6 }}>{'Learned from ' + me.total + ' blocks. Next block: ' + me.next_min + ' min, then a ' + breakMinutes(me.next_min) + ' min break.'}</Muted>
        </Card>
      )}
      <Card><H2>Your best time</H2><Bars rows={me.parts} nameOf={(r) => r.name} valueOf={(r) => r.score} /></Card>
      <Card>
        <H2>Your best places</H2>
        <Bars rows={me.places} nameOf={(r) => r.name + (r.name === 'Home' ? ' (private)' : '')} valueOf={(r) => r.score} />
        <Muted style={{ marginTop: 8 }}>Your own view. Other people never see Home.</Muted>
      </Card>
      <Card>
        <H2>Your recipe</H2>
        <KV term="BLOCK" v={me.next_min + ' min'} />
        <KV term="BREAK" v={breakMinutes(me.next_min) + ' min'} />
        <KV k="Learned from" v={me.total + ' blocks'} />
        <Muted style={{ marginTop: 8 }}>Starts at 24 + 6 min. Three good blocks in a row add 5 min, up to 90 + 15 min.</Muted>
      </Card>
      <Card>
        <H2>Why it works</H2>
        {WHY.map((w, i) => (
          <View key={w.url} style={[ui.item, i === 0 && ui.itemFirst]}>
            <Muted>
              <Text style={{ color: T.fg, fontWeight: '700' }}>{w.head}</Text>
              {w.body}
              <Text style={{ color: T.calm, textDecorationLine: 'underline' }} accessibilityRole="link"
                onPress={() => Linking.openURL(w.url).catch(() => {})}>{w.link}</Text>
            </Muted>
          </View>
        ))}
        <View style={ui.item}>
          <Muted>The Focus Score is a proxy: time on task, wrist stillness and a calm heart rate.</Muted>
        </View>
      </Card>
      <Card>
        <H2>Privacy</H2>
        <Muted>Your sessions live on your watch and this phone. Friends see a score, minutes and a place label that you chose. No coordinates leave the watch.</Muted>
      </Card>
    </View>
  );
}
