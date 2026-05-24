import { Text, View } from 'react-native';

import { useColors } from '@/src/lib/colors';

type DetailRowProps = {
  label: string;
  value: string;
};

export function DetailRow({ label, value }: DetailRowProps) {
  const colors = useColors();
  return (
    <View
      className="flex-row items-start justify-between gap-4 border-b py-3 last:border-b-0"
      style={{ borderBottomColor: colors.borderSoft }}
    >
      <Text className="text-sm" style={{ color: colors.mutedText }}>{label}</Text>
      <Text className="max-w-[62%] text-right text-sm font-medium" style={{ color: colors.text }}>{value}</Text>
    </View>
  );
}
