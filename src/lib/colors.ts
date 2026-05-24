export const colors = {
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

export type ColorToken = keyof typeof colors;
