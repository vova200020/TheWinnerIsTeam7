// Same palette as main_project/phone/index.html, so the phone app and the web prototype look alike.
export const T = {
  bg: '#080b10',
  panel: '#131a23',
  panel2: '#1e2733',
  fg: '#eef1f5',
  muted: '#93a0b2',
  line: '#263140',
  good: '#3ddc84',
  warn: '#ffb020',
  bad: '#ff6b5e',
  calm: '#4da3ff',
  navBg: 'rgba(20,26,34,0.96)',
  unlockFill: 'rgba(255,107,94,0.25)',
};

export const card = {
  backgroundColor: T.panel,
  borderRadius: 20,
  padding: 18,
  marginVertical: 7,
};

// Covers the parent. React Native 0.88 has no StyleSheet.absoluteFillObject.
export const FILL = { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 };
