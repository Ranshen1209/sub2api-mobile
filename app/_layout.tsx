import '@/src/global.css';

import { QueryClientProvider } from '@tanstack/react-query';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useMemo } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { useColors } from '@/src/lib/colors';
import { queryClient } from '@/src/lib/query-client';
import { markPerformance } from '@/src/lib/performance';
import { adminConfigState, hydrateAdminConfig } from '@/src/store/admin-config';

const { useSnapshot } = require('valtio/react');

export const unstable_settings = {
  initialRouteName: 'index',
};

export default function RootLayout() {
  const config = useSnapshot(adminConfigState);
  const colors = useColors();

  useEffect(() => {
    hydrateAdminConfig()
      .then(() => markPerformance('config_hydrated'))
      .catch(() => undefined);
  }, []);

  const cardHeader = useMemo(
    () => ({
      animation: 'slide_from_right' as const,
      presentation: 'card' as const,
      headerShown: true,
      headerBackTitle: '返回',
      headerTintColor: colors.text,
      headerStyle: { backgroundColor: colors.page },
      headerShadowVisible: false,
    }),
    [colors.text, colors.page]
  );

  const isReady = config.hydrated;
  return (
    <SafeAreaProvider>
      <GestureHandlerRootView style={{ flex: 1, backgroundColor: colors.page }}>
        <StatusBar style="auto" />
        <QueryClientProvider client={queryClient}>
          {!isReady ? (
            <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.page }}>
              <ActivityIndicator color={colors.primary} />
            </View>
          ) : (
            <Stack initialRouteName="index" screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.page } }}>
              <Stack.Screen name="index" />
              <Stack.Screen name="(tabs)" />
              <Stack.Screen name="login" />
              <Stack.Screen name="users/[id]" options={{ ...cardHeader, title: '用户详情' }} />
              <Stack.Screen name="users/create-account" options={{ ...cardHeader, title: '添加账号' }} />
              <Stack.Screen name="users/create-user" options={{ ...cardHeader, title: '添加用户' }} />
              <Stack.Screen name="accounts/create" options={{ ...cardHeader, title: '添加账号' }} />
              <Stack.Screen name="accounts/overview" options={{ ...cardHeader, title: '账号清单' }} />
            </Stack>
          )}
        </QueryClientProvider>
      </GestureHandlerRootView>
    </SafeAreaProvider>
  );
}
