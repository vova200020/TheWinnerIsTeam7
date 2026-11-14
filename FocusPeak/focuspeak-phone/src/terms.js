// The shared terms of FocusPeak. The watch app has the same table in
// main_project/watch/source/core/Terms.mc: change the two together.
//
// Why: a concept must look the same on the wrist and on the phone, so the user recognizes it and
// never has to guess if "locked" on one screen means "focus" on the other. Each term has one
// word, one color and one shape (the Chip in ui.js), on both devices.
import { Platform } from 'react-native';

export const TERM_COLOR = {
  neutral: '#eef1f5',
  focus: '#4da3ff',
  earn: '#ffb020',
  rest: '#3ddc84',
};

export const TERMS = {
  READY: { text: 'Ready', color: TERM_COLOR.neutral },
  FOCUS: { text: 'Focus', color: TERM_COLOR.focus },
  EARN: { text: 'Move to unlock', color: TERM_COLOR.earn },
  BREAK: { text: 'Break', color: TERM_COLOR.rest },
  SCORE: { text: 'Focus score', color: TERM_COLOR.neutral },
  STREAK: { text: 'Streak', color: TERM_COLOR.earn },
  BLOCK: { text: 'Block', color: TERM_COLOR.focus },
};

// The watch draws its labels in a condensed sans font. Roboto Condensed is the closest font
// that every Android phone has, so the chips use it. iOS falls back to its condensed system face.
export const TERM_FONT = Platform.select({ android: 'sans-serif-condensed', ios: 'AvenirNextCondensed-DemiBold', default: undefined });
