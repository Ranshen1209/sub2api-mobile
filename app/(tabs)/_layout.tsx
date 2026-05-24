import { createNativeBottomTabNavigator } from '@bottom-tabs/react-navigation';
import type {
  NativeBottomTabNavigationEventMap,
  NativeBottomTabNavigationOptions,
} from '@bottom-tabs/react-navigation';
import type { ParamListBase, TabNavigationState } from '@react-navigation/native';
import { Redirect, withLayoutContext } from 'expo-router';

import { useColors } from '@/src/lib/colors';
import { adminConfigState, hasAuthenticatedAdminSession } from '@/src/store/admin-config';

const { useSnapshot } = require('valtio/react');

const { Navigator } = createNativeBottomTabNavigator();

const Tabs = withLayoutContext<
  NativeBottomTabNavigationOptions,
  typeof Navigator,
  TabNavigationState<ParamListBase>,
  NativeBottomTabNavigationEventMap
>(Navigator);

export default function TabsLayout() {
  const config = useSnapshot(adminConfigState);
  const colors = useColors();
  const hasAccount = hasAuthenticatedAdminSession(config);

  if (!hasAccount) {
    return <Redirect href="/login" />;
  }

  return (
    <Tabs
      initialRouteName="monitor"
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
      }}
    >
      <Tabs.Screen
        name="monitor"
        options={{
          title: '概览',
          tabBarIcon: () => ({ sfSymbol: 'chart.line.uptrend.xyaxis' }),
        }}
      />
      <Tabs.Screen
        name="users"
        options={{
          title: '用户',
          tabBarIcon: () => ({ sfSymbol: 'person.2.fill' }),
        }}
      />
      <Tabs.Screen
        name="settings"
        options={{
          title: '服务器',
          tabBarIcon: () => ({ sfSymbol: 'server.rack' }),
        }}
      />
      <Tabs.Screen name="groups" options={{ tabBarItemHidden: true }} />
      <Tabs.Screen name="accounts" options={{ tabBarItemHidden: true }} />
    </Tabs>
  );
}
