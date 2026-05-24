import { useColorScheme } from 'react-native';

const lightColors = {
  primary: '#9181bd',
  primaryDark: '#7a6aac',
  primarySoft: '#c8bee0',

  page: '#f5f1fa',
  card: '#faf7fd',
  mutedCard: '#efe9f7',

  text: '#16181a',
  textStrong: '#3a3548',
  subtext: '#6f6982',
  mutedText: '#7a7388',
  faintText: '#8c8499',
  placeholder: '#9b94ad',

  accentBg: '#e9defb',
  accentText: '#5c3da3',
  inactiveBadge: '#cfc5b7',

  border: '#ddd2ed',
  borderSoft: '#e6dfee',
  barTrack: '#e3dbef',

  badgeDefault: '#ece6f5',
  badgeDefaultText: '#5d5774',
  badgeMuted: '#e9e3f3',
  badgeDangerBg: '#f7e1d6',
  badgeDangerText: '#a4512b',
  successText: '#3d6ea4',
  successBgSoft: '#e6e1f2',
  inactiveBgSoft: '#e9e3f3',
  disabledButton: '#b1a8c8',
  loadingButton: '#beb3d8',
  dangerButton: '#8b3f1f',
  dangerButtonText: '#7a3d31',
  darkButton: '#1b1d1f',

  danger: '#c25d35',
  dangerBg: '#fbf1eb',
  warning: '#c79a45',

  tabInactive: '#8a82a0',
} as const;

const darkColors = {
  primary: '#a896c8',
  primaryDark: '#8a78b6',
  primarySoft: '#3f3553',

  page: '#14101c',
  card: '#1d1828',
  mutedCard: '#2a2336',

  text: '#f0ecf8',
  textStrong: '#e6e0f3',
  subtext: '#b1aac4',
  mutedText: '#8c869b',
  faintText: '#6e687f',
  placeholder: '#6e687f',

  accentBg: '#322746',
  accentText: '#c8b4f0',
  inactiveBadge: '#3a3548',

  border: '#2e2840',
  borderSoft: '#251f33',
  barTrack: '#2e2840',

  badgeDefault: '#2a2336',
  badgeDefaultText: '#b1aac4',
  badgeMuted: '#251f33',
  badgeDangerBg: '#3a2418',
  badgeDangerText: '#e09870',
  successText: '#7fa8d8',
  successBgSoft: '#2c2640',
  inactiveBgSoft: '#251f33',
  disabledButton: '#3a3548',
  loadingButton: '#4a4258',
  dangerButton: '#7a3d20',
  dangerButtonText: '#e09870',
  darkButton: '#0c0a14',

  danger: '#d97a52',
  dangerBg: '#3a2418',
  warning: '#d4a85a',

  tabInactive: '#6e687f',
} as const;

export type ColorPalette = { [K in keyof typeof lightColors]: string };
export type ColorToken = keyof ColorPalette;

const darkPalette: ColorPalette = darkColors;
const lightPalette: ColorPalette = lightColors;

export const colors: ColorPalette = lightPalette;

export function useColors(): ColorPalette {
  const scheme = useColorScheme();
  return scheme === 'dark' ? darkPalette : lightPalette;
}
