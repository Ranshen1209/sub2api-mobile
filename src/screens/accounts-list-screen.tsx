import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query';
import { KeyRound, Search, ShieldCheck, ShieldOff } from 'lucide-react-native';
import { useCallback, useMemo, useState } from 'react';
import { FlatList, Pressable, RefreshControl, Text, TextInput, View } from 'react-native';
import type { Edge } from 'react-native-safe-area-context';

import { ListCard } from '@/src/components/list-card';
import { ScreenShell } from '@/src/components/screen-shell';
import { useDebouncedValue } from '@/src/hooks/use-debounced-value';
import { useColors } from '@/src/lib/colors';
import { formatTokenValue } from '@/src/lib/formatters';
import { getAccountTodayStats, listAccounts, setAccountSchedulable, testAccount } from '@/src/services/admin';
import type { AdminAccount } from '@/src/types/admin';

type AccountStatusFilter = 'all' | 'active' | 'paused' | 'error';
type UsageSort = 'usage-desc' | 'usage-asc';
type AccountVisualStatus = {
  filterKey: AccountStatusFilter;
  label: '正常' | '暂停' | '异常';
  badgeTone: 'success' | 'muted' | 'danger';
};

type AccountTodaySummary = {
  requests: number;
  tokens: number;
  cost: number;
};

function formatTime(value?: string | null) {
  if (!value) return '--';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '--';
  return `${date.getFullYear()}/${String(date.getMonth() + 1).padStart(2, '0')}/${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function getAccountError(account: AdminAccount) {
  return Boolean(account.status === 'error' || account.error_message);
}

function getAccountVisualStatus(account: AdminAccount): AccountVisualStatus {
  const normalizedStatus = `${account.status ?? ''}`.toLowerCase();
  const isPausedStatus = ['inactive', 'disabled', 'paused', 'stop', 'stopped'].includes(normalizedStatus);

  if (getAccountError(account)) {
    return { filterKey: 'error', label: '异常', badgeTone: 'danger' };
  }
  if (isPausedStatus || account.schedulable === false) {
    return { filterKey: 'paused', label: '暂停', badgeTone: 'muted' };
  }
  return { filterKey: 'active', label: '正常', badgeTone: 'success' };
}

type AccountsListScreenProps = {
  safeAreaEdges?: Edge[];
  withTabBar?: boolean;
};

export function AccountsListScreen({ safeAreaEdges, withTabBar = true }: AccountsListScreenProps) {
  const colors = useColors();
  const [searchText, setSearchText] = useState('');
  const [filter, setFilter] = useState<AccountStatusFilter>('all');
  const [usageSort, setUsageSort] = useState<UsageSort>('usage-desc');
  const [testingAccountId, setTestingAccountId] = useState<number | null>(null);
  const [testFeedbackByAccountId, setTestFeedbackByAccountId] = useState<Record<number, string>>({});
  const [togglingAccountId, setTogglingAccountId] = useState<number | null>(null);
  const keyword = useDebouncedValue(searchText.trim(), 300);
  const queryClient = useQueryClient();

  const accountsQuery = useQuery({
    queryKey: ['accounts', keyword],
    queryFn: () => listAccounts(keyword),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ accountId, schedulable }: { accountId: number; schedulable: boolean }) =>
      setAccountSchedulable(accountId, schedulable),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['accounts'] }),
  });

  const testMutation = useMutation({
    mutationFn: (accountId: number) => testAccount(accountId),
  });

  const items = accountsQuery.data?.items ?? [];
  const accountCostQueries = useQueries({
    queries: items.map((account) => ({
      queryKey: ['account-today-stats', account.id],
      queryFn: () => getAccountTodayStats(account.id),
      staleTime: 60_000,
    })),
  });

  const todayByAccountId = useMemo(() => {
    const next = new Map<number, AccountTodaySummary>();
    items.forEach((account, index) => {
      const result = accountCostQueries[index]?.data;
      const fromStatsCost = typeof result?.cost === 'number' && Number.isFinite(result.cost) ? result.cost : undefined;
      const fromExtra = typeof account.extra?.today_cost === 'number' ? account.extra.today_cost : undefined;
      const cost = fromStatsCost ?? fromExtra ?? 0;
      const requests = typeof result?.requests === 'number' && Number.isFinite(result.requests) ? result.requests : 0;
      const tokens = typeof result?.tokens === 'number' && Number.isFinite(result.tokens) ? result.tokens : 0;
      next.set(account.id, { requests, tokens, cost });
    });
    return next;
  }, [accountCostQueries, items]);

  const filteredItems = useMemo(() => {
    const statusMatched = items.filter((account) => {
      const visualStatus = getAccountVisualStatus(account);
      if (filter === 'all') return true;
      if (filter === 'active') return visualStatus.filterKey === 'active';
      if (filter === 'paused') return visualStatus.filterKey === 'paused';
      if (filter === 'error') return visualStatus.filterKey === 'error';
      return true;
    });

    const sorted = [...statusMatched].sort((left, right) => {
      const requestsLeft = todayByAccountId.get(left.id)?.requests ?? 0;
      const requestsRight = todayByAccountId.get(right.id)?.requests ?? 0;
      if (requestsLeft === requestsRight) {
        const tokensLeft = todayByAccountId.get(left.id)?.tokens ?? 0;
        const tokensRight = todayByAccountId.get(right.id)?.tokens ?? 0;
        return tokensLeft - tokensRight;
      }
      if (usageSort === 'usage-asc') return requestsLeft - requestsRight;
      return requestsRight - requestsLeft;
    });

    return sorted;
  }, [filter, items, todayByAccountId, usageSort]);
  const errorMessage = accountsQuery.error instanceof Error ? accountsQuery.error.message : '';

  const summary = useMemo(() => {
    const total = items.length;
    const errors = items.filter((item) => getAccountVisualStatus(item).filterKey === 'error').length;
    const paused = items.filter((item) => getAccountVisualStatus(item).filterKey === 'paused').length;
    const active = items.filter((item) => getAccountVisualStatus(item).filterKey === 'active').length;
    return { total, active, paused, errors };
  }, [items]);

  const listHeader = useMemo(
    () => (
      <View className="pb-2">
        <View className="rounded-[24px] p-2.5" style={{ backgroundColor: colors.card }}>
          <View className="flex-row items-center rounded-[18px] px-4 py-3" style={{ backgroundColor: colors.mutedCard }}>
            <Search color={colors.mutedText} size={18} />
            <TextInput
              defaultValue=""
              onChangeText={setSearchText}
              placeholder="搜索账号名称 / 平台"
              placeholderTextColor={colors.placeholder}
              className="ml-3 flex-1 text-base"
              style={{ color: colors.text }}
            />
          </View>

          <View className="mt-3 flex-row gap-2">
            {([
              ['all', `全部 ${summary.total}`],
              ['active', `正常 ${summary.active}`],
              ['paused', `暂停 ${summary.paused}`],
              ['error', `异常 ${summary.errors}`],
            ] as const).map(([key, label]) => {
              const active = filter === key;
              return (
                <Pressable
                  key={key}
                  onPress={() => setFilter(key)}
                  className="rounded-full px-3 py-2"
                  style={{ backgroundColor: active ? colors.primary : colors.borderSoft }}
                >
                  <Text
                    className="text-xs font-semibold"
                    style={{ color: active ? '#ffffff' : colors.textStrong }}
                  >
                    {label}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          <View className="mt-3 flex-row gap-2">
            {([
              ['usage-desc', '请求高→低'],
              ['usage-asc', '请求低→高'],
            ] as const).map(([key, label]) => {
              const active = usageSort === key;
              return (
                <Pressable
                  key={key}
                  onPress={() => setUsageSort(key)}
                  className="rounded-full px-3 py-3"
                  style={{ backgroundColor: active ? colors.primaryDark : colors.borderSoft }}
                >
                  <Text
                    className="text-xs font-semibold"
                    style={{ color: active ? '#ffffff' : colors.textStrong }}
                  >
                    {label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      </View>
    ),
    [filter, summary.active, summary.errors, summary.paused, summary.total, usageSort]
  );

  const renderItem = useCallback(
    ({ item: account }: { item: (typeof filteredItems)[number] }) => {
      const isError = getAccountError(account);
      const visualStatus = getAccountVisualStatus(account);
      const statusText = visualStatus.label;
      const groupsText = account.groups?.map((group) => group.name).filter(Boolean).slice(0, 3).join(' · ');
      const todayStats = todayByAccountId.get(account.id) ?? { requests: 0, tokens: 0, cost: 0 };
      const nextSchedulable = visualStatus.filterKey === 'paused';
      const toggleLabel = nextSchedulable ? '恢复' : '暂停';
      const testFeedback = testFeedbackByAccountId[account.id];
      const isTogglingCurrent = togglingAccountId === account.id && toggleMutation.isPending;
      const isTestingCurrent = testingAccountId === account.id && testMutation.isPending;

      return (
        <View>
          <ListCard
            title={account.name}
            meta={`${account.platform} · ${account.type}`}
            badge={statusText}
            badgeTone={visualStatus.badgeTone}
            icon={KeyRound}
          >
            <View className="gap-3">
              <View className="flex-row items-center justify-between">
                <View className="flex-row items-center gap-2">
                  {account.schedulable && !isError ? (
                    <ShieldCheck color={colors.mutedText} size={14} />
                  ) : (
                    <ShieldOff color={colors.mutedText} size={14} />
                  )}
                  <Text className="text-sm" style={{ color: colors.mutedText }}>状态：{statusText}</Text>
                </View>
                <Text className="text-xs" style={{ color: colors.mutedText }}>
                  最近使用 {formatTime(account.last_used_at || account.updated_at)}
                </Text>
              </View>

              <View className="flex-row gap-2">
                <View className="flex-1 rounded-[14px] px-3 py-3" style={{ backgroundColor: colors.mutedCard }}>
                  <Text className="text-[11px]" style={{ color: colors.mutedText }}>请求次数</Text>
                  <Text className="mt-1 text-sm font-bold" style={{ color: colors.text }}>{todayStats.requests}</Text>
                </View>
                <View className="flex-1 rounded-[14px] px-3 py-3" style={{ backgroundColor: colors.mutedCard }}>
                  <Text className="text-[11px]" style={{ color: colors.mutedText }}>消费金额</Text>
                  <Text className="mt-1 text-sm font-bold" style={{ color: colors.text }}>￥{todayStats.cost.toFixed(2)}</Text>
                </View>
                <View className="flex-1 rounded-[14px] px-3 py-3" style={{ backgroundColor: colors.mutedCard }}>
                  <Text className="text-[11px]" style={{ color: colors.mutedText }}>token消耗</Text>
                  <Text className="mt-1 text-sm font-bold" style={{ color: colors.text }}>{formatTokenValue(todayStats.tokens)}</Text>
                </View>
              </View>

              <Text className="text-xs" style={{ color: colors.mutedText }}>
                优先级 {account.priority ?? 0} · 倍率 {(account.rate_multiplier ?? 1).toFixed(2)}x
              </Text>

              {groupsText ? (
                <Text className="text-xs" style={{ color: colors.mutedText }}>分组 {groupsText}</Text>
              ) : null}
              {account.error_message ? (
                <Text className="text-xs" style={{ color: colors.badgeDangerText }}>异常信息：{account.error_message}</Text>
              ) : null}

              <View className="flex-row gap-2">
                <Pressable
                  className="rounded-full px-4 py-2"
                  style={{ backgroundColor: colors.primary }}
                  disabled={isTestingCurrent}
                  onPress={(event) => {
                    event.stopPropagation();
                    setTestingAccountId(account.id);
                    testMutation.mutate(account.id, {
                      onSuccess: () => {
                        setTestFeedbackByAccountId((current) => ({ ...current, [account.id]: '测试成功' }));
                      },
                      onError: (error) => {
                        const message = error instanceof Error && error.message ? error.message : '测试失败';
                        setTestFeedbackByAccountId((current) => ({ ...current, [account.id]: message }));
                      },
                      onSettled: () => {
                        setTestingAccountId((current) => (current === account.id ? null : current));
                      },
                    });
                  }}
                >
                  <Text className="text-xs font-semibold uppercase tracking-[1.2px]" style={{ color: '#ffffff' }}>
                    {isTestingCurrent ? '测试中...' : '测试'}
                  </Text>
                </Pressable>
                <Pressable
                  className="rounded-full px-4 py-2"
                  style={{ backgroundColor: colors.borderSoft }}
                  disabled={isTogglingCurrent}
                  onPress={(event) => {
                    event.stopPropagation();
                    setTogglingAccountId(account.id);
                    toggleMutation.mutate({
                      accountId: account.id,
                      schedulable: nextSchedulable,
                    }, {
                      onSettled: () => {
                        setTogglingAccountId((current) => (current === account.id ? null : current));
                      },
                    });
                  }}
                >
                  <Text className="text-xs font-semibold uppercase tracking-[1.2px]" style={{ color: colors.textStrong }}>
                    {isTogglingCurrent ? '处理中...' : toggleLabel}
                  </Text>
                </Pressable>
              </View>

              {testFeedback ? (
                <Text className="text-xs" style={{ color: colors.primary }}>测试结果：{testFeedback}</Text>
              ) : null}
            </View>
          </ListCard>
        </View>
      );
    },
    [testFeedbackByAccountId, testMutation, testingAccountId, todayByAccountId, toggleMutation, togglingAccountId]
  );

  const emptyState = useMemo(
    () => <ListCard title="暂无账号" meta={errorMessage || '连上后这里会展示账号列表。'} icon={KeyRound} />,
    [errorMessage]
  );

  return (
    <ScreenShell
      title="账号清单"
      subtitle="查看名称、平台&类型、请求次数、消费金额、token消耗，并支持筛选与排序。"
      titleAside={(
        <Text className="text-[11px]" style={{ color: colors.mutedText }}>更接近网页后台的账号视图。</Text>
      )}
      variant="minimal"
      scroll={false}
      safeAreaEdges={safeAreaEdges}
      withTabBar={withTabBar}
      contentGapClassName="mt-2 gap-2"
    >
      <FlatList
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 12, flexGrow: 1 }}
        data={filteredItems}
        renderItem={renderItem}
        keyExtractor={(item) => `${item.id}`}
        showsVerticalScrollIndicator={false}
        refreshControl={<RefreshControl refreshing={accountsQuery.isRefetching} onRefresh={() => void accountsQuery.refetch()} tintColor={colors.primary} />}
        ListHeaderComponent={listHeader}
        ListEmptyComponent={emptyState}
        ItemSeparatorComponent={() => <View className="h-4" />}
        keyboardShouldPersistTaps="handled"
        initialNumToRender={8}
        maxToRenderPerBatch={8}
        windowSize={5}
      />
    </ScreenShell>
  );
}
