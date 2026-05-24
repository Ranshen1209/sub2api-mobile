import { Platform } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const NATIVE_TAB_BAR_HEIGHT = Platform.OS === 'ios' ? 49 : 56;

export function useTabBarInset(): number {
  const insets = useSafeAreaInsets();
  return NATIVE_TAB_BAR_HEIGHT + insets.bottom;
}
