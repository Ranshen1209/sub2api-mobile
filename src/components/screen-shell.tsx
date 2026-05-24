import type { PropsWithChildren, ReactNode } from 'react';
import { SafeAreaView } from 'react-native-safe-area-context';
import type { Edge } from 'react-native-safe-area-context';
import { RefreshControl, ScrollView, Text, View } from 'react-native';

import { useColors } from '@/src/lib/colors';
import type { ColorPalette } from '@/src/lib/colors';
import { useTabBarInset } from '@/src/lib/use-tab-bar-inset';

type ScreenShellProps = PropsWithChildren<{
  title: string;
  subtitle: string;
  titleAside?: ReactNode;
  right?: ReactNode;
  variant?: 'card' | 'minimal';
  scroll?: boolean;
  withTabBar?: boolean;
  horizontalInsetClassName?: string;
  contentGapClassName?: string;
  refreshing?: boolean;
  onRefresh?: () => void | Promise<void>;
  safeAreaEdges?: Edge[];
}>;

interface ScreenHeaderProps extends Pick<ScreenShellProps, 'title' | 'subtitle' | 'titleAside' | 'right' | 'variant'> {
  colors: ColorPalette;
}

function ScreenHeader({ title, subtitle, titleAside, right, variant, colors }: ScreenHeaderProps) {
  if (variant === 'minimal') {
    return (
      <View className="mt-4 flex-row items-start justify-between gap-4 px-1 py-1">
        <View className="flex-1">
          <View className="flex-row items-center gap-2">
            <Text className="text-[20px] font-bold tracking-tight" style={{ color: colors.text }}>{title}</Text>
            {titleAside}
          </View>
          {subtitle ? (
            <Text numberOfLines={1} className="mt-1 text-[11px] leading-4" style={{ color: colors.mutedText }}>
              {subtitle}
            </Text>
          ) : null}
        </View>
        {right ? <View className="items-end justify-start">{right}</View> : null}
      </View>
    );
  }

  return (
    <View
      className="mt-4 rounded-[24px] border px-4 py-4"
      style={{ backgroundColor: colors.card, borderColor: colors.border }}
    >
      <View className="flex-row items-start justify-between gap-4">
        <View className="flex-1">
          <Text className="text-[24px] font-bold tracking-tight" style={{ color: colors.text }}>{title}</Text>
          <Text numberOfLines={1} className="mt-1 text-xs leading-4" style={{ color: colors.faintText }}>
            {subtitle}
          </Text>
        </View>
        {right}
      </View>
    </View>
  );
}

export function ScreenShell({
  title,
  subtitle,
  titleAside,
  right,
  children,
  variant = 'card',
  scroll = true,
  withTabBar = true,
  horizontalInsetClassName = 'px-5',
  contentGapClassName = 'mt-4 gap-4',
  refreshing = false,
  onRefresh,
  safeAreaEdges = ['top'],
}: ScreenShellProps) {
  const colors = useColors();
  const tabBarInset = useTabBarInset();
  const bottomPadding = withTabBar ? tabBarInset + 16 : 24;

  const header = (
    <ScreenHeader
      title={title}
      subtitle={subtitle}
      titleAside={titleAside}
      right={right}
      variant={variant}
      colors={colors}
    />
  );

  if (!scroll) {
    return (
      <SafeAreaView edges={safeAreaEdges} style={{ flex: 1, backgroundColor: colors.page }}>
        <View className={`flex-1 ${horizontalInsetClassName}`} style={{ paddingBottom: bottomPadding }}>
          {header}
          <View className={`flex-1 ${contentGapClassName}`}>{children}</View>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView edges={safeAreaEdges} style={{ flex: 1, backgroundColor: colors.page }}>
      <ScrollView
        className="flex-1"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: bottomPadding }}
        refreshControl={onRefresh ? <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} /> : undefined}
      >
        <View className={horizontalInsetClassName}>
          {header}
          <View className={contentGapClassName}>{children}</View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
