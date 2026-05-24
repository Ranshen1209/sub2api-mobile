import type { LucideIcon } from 'lucide-react-native';
import type { ReactNode } from 'react';
import { Text, View } from 'react-native';

import { useColors } from '@/src/lib/colors';

type BadgeTone = 'default' | 'success' | 'muted' | 'danger';

type ListCardProps = {
  title: string;
  meta?: string;
  badge?: string;
  badgeTone?: BadgeTone;
  children?: ReactNode;
  icon?: LucideIcon;
};

export function ListCard({ title, meta, badge, badgeTone = 'default', children, icon: Icon }: ListCardProps) {
  const colors = useColors();

  const badgeStyles: Record<BadgeTone, { bg: string; color: string }> = {
    default: { bg: colors.badgeDefault, color: colors.badgeDefaultText },
    success: { bg: colors.successBgSoft, color: colors.primary },
    muted: { bg: colors.badgeMuted, color: colors.mutedText },
    danger: { bg: colors.badgeDangerBg, color: colors.badgeDangerText },
  };
  const badgeStyle = badgeStyles[badgeTone];

  return (
    <View
      className="rounded-[16px] border p-3.5"
      style={{ backgroundColor: colors.card, borderColor: colors.borderSoft }}
    >
      <View className="flex-row items-start justify-between gap-3">
        <View className="flex-1">
          <View className="flex-row items-center gap-2">
            {Icon ? <Icon color={colors.mutedText} size={16} /> : null}
            <Text className="text-base font-semibold" style={{ color: colors.text }}>{title}</Text>
          </View>
          {meta ? (
            <Text numberOfLines={1} className="mt-1 text-xs" style={{ color: colors.mutedText }}>
              {meta}
            </Text>
          ) : null}
        </View>
        {badge ? (
          <View className="rounded-full px-2.5 py-1" style={{ backgroundColor: badgeStyle.bg }}>
            <Text className="text-[10px] font-semibold uppercase tracking-[1px]" style={{ color: badgeStyle.color }}>
              {badge}
            </Text>
          </View>
        ) : null}
      </View>
      {children ? <View className="mt-3">{children}</View> : null}
    </View>
  );
}
