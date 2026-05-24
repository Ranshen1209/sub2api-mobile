import type { LucideIcon } from 'lucide-react-native';
import { TrendingDown, TrendingUp } from 'lucide-react-native';
import { Text, View } from 'react-native';

import { useColors } from '@/src/lib/colors';

type StatCardProps = {
  label: string;
  value: string;
  tone?: 'light' | 'dark';
  trend?: 'up' | 'down';
  icon?: LucideIcon;
};

export function StatCard({ label, value, tone = 'light', trend, icon: Icon }: StatCardProps) {
  const colors = useColors();
  const dark = tone === 'dark';
  const TrendIcon = trend === 'up' ? TrendingUp : trend === 'down' ? TrendingDown : null;
  const accentColor = dark ? colors.primarySoft : colors.mutedText;

  return (
    <View
      className="rounded-[24px] p-4"
      style={{ backgroundColor: dark ? colors.primary : colors.card }}
    >
      <View className="flex-row items-center justify-between gap-3">
        <Text className="text-xs uppercase tracking-[1.5px]" style={{ color: accentColor }}>
          {label}
        </Text>
        <View className="flex-row items-center gap-2">
          {TrendIcon ? <TrendIcon color={accentColor} size={14} /> : null}
          {Icon ? <Icon color={accentColor} size={14} /> : null}
        </View>
      </View>
      <Text className="mt-3 text-3xl font-bold" style={{ color: dark ? '#ffffff' : colors.text }}>
        {value}
      </Text>
    </View>
  );
}
