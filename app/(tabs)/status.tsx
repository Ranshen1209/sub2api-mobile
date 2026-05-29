import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AvailabilityBar } from '@/src/components/availability-bar';
import { useColors } from '@/src/lib/colors';
import { useTabBarInset } from '@/src/lib/use-tab-bar-inset';
import { getServiceStatus } from '@/src/services/status';
import type { StatusGroup, StatusLayer, StatusPeriod } from '@/src/types/status';

type ProviderGroup = {
  provider: string;
  providerName: string;
  channels: StatusGroup[];
  upCount: number;
  degradedCount: number;
  downCount: number;
};

const PERIOD_OPTIONS: Array<{ key: StatusPeriod; label: string }> = [
  { key: '90m', label: '90M' },
  { key: '24h', label: '24H' },
  { key: '7d', label: '7D' },
  { key: '30d', label: '30D' },
];

function getStatusColor(status: number | undefined, colors: ReturnType<typeof useColors>) {
  switch (status) {
    case 1:
      return colors.primary;
    case 2:
      return colors.warning;
    case 0:
      return colors.danger;
    default:
      return colors.barTrack;
  }
}

function getStatusLabel(status: number | undefined) {
  switch (status) {
    case 1:
      return '正常';
    case 2:
      return '波动';
    case 0:
      return '异常';
    default:
      return '未知';
  }
}

function computeOverallStatus(channels: StatusGroup[]): number {
  let hasDown = false;
  let hasDegraded = false;

  for (const ch of channels) {
    if (ch.current_status === 0) hasDown = true;
    else if (ch.current_status === 2) hasDegraded = true;
  }

  if (hasDown) return 0;
  if (hasDegraded) return 2;
  return 1;
}

function groupByProvider(groups: StatusGroup[]): ProviderGroup[] {
  const map = new Map<string, ProviderGroup>();

  for (const g of groups) {
    const key = g.provider;
    let group = map.get(key);

    if (!group) {
      group = {
        provider: g.provider,
        providerName: g.provider_name || g.provider,
        channels: [],
        upCount: 0,
        degradedCount: 0,
        downCount: 0,
      };
      map.set(key, group);
    }

    group.channels.push(g);
    if (g.current_status === 1) group.upCount++;
    else if (g.current_status === 2) group.degradedCount++;
    else if (g.current_status === 0) group.downCount++;
  }

  return Array.from(map.values());
}

function computeAvailability(timeline: StatusLayer['timeline']): string {
  const valid = timeline.filter((p) => p.availability >= 0);
  if (valid.length === 0) return '--';
  const avg = valid.reduce((sum, p) => sum + p.availability, 0) / valid.length;
  return `${avg.toFixed(1)}%`;
}

export default function StatusScreen() {
  const colors = useColors();
  const tabBarInset = useTabBarInset();
  const [period, setPeriod] = useState<StatusPeriod>('24h');

  const statusQuery = useQuery({
    queryKey: ['service-status', period],
    queryFn: () => getServiceStatus(period),
    staleTime: 30_000,
    placeholderData: (prev) => prev,
  });

  const channels = statusQuery.data ?? [];
  const groups = useMemo(() => groupByProvider(channels), [channels]);
  const totalUp = channels.filter((c) => c.current_status === 1).length;
  const totalDegraded = channels.filter((c) => c.current_status === 2).length;
  const totalDown = channels.filter((c) => c.current_status === 0).length;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.page }}>
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingHorizontal: 16, paddingTop: 16, paddingBottom: tabBarInset + 16 }}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={statusQuery.isRefetching}
            onRefresh={() => void statusQuery.refetch()}
            tintColor={colors.primary}
          />
        }
      >
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
          <View style={{ flex: 1 }}>
            <Text style={{ fontSize: 28, fontWeight: '700', color: colors.text }}>服务状态</Text>
            <Text style={{ marginTop: 6, fontSize: 13, color: colors.faintText }}>
              上游 API 中转服务实时可用性。
            </Text>
          </View>
          <View style={{ flexDirection: 'row', gap: 8 }}>
            {PERIOD_OPTIONS.map((opt) => {
              const active = opt.key === period;
              return (
                <Pressable
                  key={opt.key}
                  style={{ backgroundColor: active ? colors.primary : colors.border, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 8 }}
                  onPress={() => setPeriod(opt.key)}
                >
                  <Text style={{ color: active ? '#ffffff' : colors.textStrong, fontSize: 12, fontWeight: '700' }}>{opt.label}</Text>
                </Pressable>
              );
            })}
          </View>
        </View>

        {statusQuery.isLoading ? (
          <View style={{ backgroundColor: colors.card, borderRadius: 18, padding: 16 }}>
            <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>正在加载</Text>
            <Text style={{ marginTop: 8, fontSize: 14, color: colors.subtext }}>正在获取服务状态数据…</Text>
          </View>
        ) : statusQuery.error ? (
          <View style={{ backgroundColor: colors.card, borderRadius: 18, padding: 16 }}>
            <Text style={{ fontSize: 18, fontWeight: '700', color: colors.text }}>加载失败</Text>
            <View style={{ marginTop: 12, borderRadius: 14, backgroundColor: colors.dangerBg, paddingHorizontal: 14, paddingVertical: 12 }}>
              <Text style={{ color: colors.danger, fontSize: 14 }}>无法连接到状态监测服务，请检查网络。</Text>
            </View>
            <Pressable
              style={{ marginTop: 14, alignSelf: 'flex-start', backgroundColor: colors.primary, borderRadius: 14, paddingHorizontal: 16, paddingVertical: 12 }}
              onPress={() => void statusQuery.refetch()}
            >
              <Text style={{ color: '#ffffff', fontSize: 13, fontWeight: '700' }}>重试</Text>
            </Pressable>
          </View>
        ) : (
          <View style={{ gap: 12 }}>
            <SummaryRow total={channels.length} up={totalUp} degraded={totalDegraded} down={totalDown} />
            {groups.map((group) => (
              <ProviderCard key={group.provider} group={group} />
            ))}
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

function SummaryRow({ total, up, degraded, down }: { total: number; up: number; degraded: number; down: number }) {
  const colors = useColors();
  return (
    <View style={{ flexDirection: 'row', gap: 8 }}>
      <View style={{ flex: 1, backgroundColor: colors.card, borderRadius: 14, padding: 12 }}>
        <Text style={{ fontSize: 11, color: colors.faintText }}>监测项</Text>
        <Text style={{ marginTop: 6, fontSize: 18, fontWeight: '700', color: colors.text }}>{total}</Text>
      </View>
      <View style={{ flex: 1, backgroundColor: colors.card, borderRadius: 14, padding: 12 }}>
        <Text style={{ fontSize: 11, color: colors.primary }}>正常</Text>
        <Text style={{ marginTop: 6, fontSize: 18, fontWeight: '700', color: colors.primary }}>{up}</Text>
      </View>
      <View style={{ flex: 1, backgroundColor: colors.card, borderRadius: 14, padding: 12 }}>
        <Text style={{ fontSize: 11, color: colors.warning }}>波动</Text>
        <Text style={{ marginTop: 6, fontSize: 18, fontWeight: '700', color: colors.warning }}>{degraded}</Text>
      </View>
      <View style={{ flex: 1, backgroundColor: colors.dangerBg, borderRadius: 14, padding: 12 }}>
        <Text style={{ fontSize: 11, color: colors.danger }}>异常</Text>
        <Text style={{ marginTop: 6, fontSize: 18, fontWeight: '700', color: colors.danger }}>{down}</Text>
      </View>
    </View>
  );
}

function ProviderCard({ group }: { group: ProviderGroup }) {
  const colors = useColors();
  const overallStatus = computeOverallStatus(group.channels);
  const statusColor = getStatusColor(overallStatus, colors);

  return (
    <View style={{ backgroundColor: colors.card, borderRadius: 18, padding: 16 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
        <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: statusColor }} />
        <Text style={{ fontSize: 16, fontWeight: '700', color: colors.text, flex: 1 }}>{group.providerName}</Text>
        <Text style={{ fontSize: 12, color: colors.subtext }}>
          {group.upCount}/{group.channels.length} 正常
        </Text>
      </View>
      <View style={{ marginTop: 12, gap: 10 }}>
        {group.channels.map((ch) => (
          <ChannelRow key={`${ch.provider}-${ch.service}-${ch.channel}`} channel={ch} />
        ))}
      </View>
    </View>
  );
}

function ChannelRow({ channel }: { channel: StatusGroup }) {
  const colors = useColors();
  const statusColor = getStatusColor(channel.current_status, colors);
  const displayName = channel.channel_name || channel.channel || channel.service_name || channel.service;
  const layer = channel.layers[0];
  const latency = layer?.current_status?.latency;
  const timeline = layer?.timeline ?? [];
  const availability = computeAvailability(timeline);

  return (
    <View style={{ backgroundColor: colors.mutedCard, borderRadius: 12, padding: 12 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
        <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: statusColor }} />
        <Text style={{ fontSize: 13, fontWeight: '600', color: colors.text, flex: 1 }} numberOfLines={1}>
          {displayName}
        </Text>
        <Text style={{ fontSize: 11, color: colors.subtext }}>
          {getStatusLabel(channel.current_status)}
        </Text>
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 8 }}>
        <Text style={{ fontSize: 11, color: colors.faintText }}>
          {typeof latency === 'number' ? `${latency}ms` : '--'}
        </Text>
        <Text style={{ fontSize: 11, color: colors.faintText }}>{availability}</Text>
        <View style={{ flex: 1 }}>
          <AvailabilityBar timeline={timeline} height={3} />
        </View>
      </View>
    </View>
  );
}
