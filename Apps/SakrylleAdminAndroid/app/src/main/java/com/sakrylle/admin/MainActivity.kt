package com.sakrylle.admin

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.sakrylle.admin.ui.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { SakrylleTheme { SakrylleApp() } }
    }
}

private enum class MainTab(val route: String, val label: String) {
    Monitor("monitor", "概览"), Users("users", "用户"), Status("status", "状态"), Settings("settings", "服务器")
}

@Composable
fun SakrylleApp(vm: AppViewModel = viewModel()) {
    if (vm.activeProfile == null) {
        LoginScreen(vm)
        return
    }
    val navController = rememberNavController()
    val tabs = MainTab.entries
    Scaffold(
        bottomBar = {
            NavigationBar {
                val current by navController.currentBackStackEntryFlow.collectAsStateWithLifecycle(null)
                val currentRoute = current?.destination?.route
                tabs.forEach { tab ->
                    NavigationBarItem(
                        selected = currentRoute == tab.route,
                        onClick = { navController.navigate(tab.route) { popUpTo("monitor") { saveState = true }; launchSingleTop = true; restoreState = true } },
                        icon = {
                            Icon(
                                when (tab) {
                                    MainTab.Monitor -> Icons.Rounded.ShowChart
                                    MainTab.Users -> Icons.Rounded.People
                                    MainTab.Status -> Icons.Rounded.MonitorHeart
                                    MainTab.Settings -> Icons.Rounded.Dns
                                },
                                contentDescription = tab.label,
                            )
                        },
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { padding ->
        NavHost(navController, startDestination = MainTab.Monitor.route, modifier = Modifier.padding(padding)) {
            composable(MainTab.Monitor.route) { MonitorScreen(vm) }
            composable(MainTab.Users.route) { UsersScreen(vm, openUser = { navController.navigate("user/$it") }, createUser = { navController.navigate("create-user") }) }
            composable(MainTab.Status.route) { StatusScreen(vm) }
            composable(MainTab.Settings.route) {
                SettingsScreen(vm, openAccounts = { navController.navigate("accounts") }, openGroups = { navController.navigate("groups") })
            }
            composable("user/{id}", arguments = listOf(navArgument("id") { type = NavType.IntType })) {
                UserDetailScreen(vm, it.arguments?.getInt("id") ?: 0) { navController.popBackStack() }
            }
            composable("accounts") { AccountsScreen(vm, goBack = { navController.popBackStack() }, createAccount = { navController.navigate("create-account") }) }
            composable("groups") { GroupsScreen(vm) { navController.popBackStack() } }
            composable("create-user") { CreateUserScreen(vm) { navController.popBackStack() } }
            composable("create-account") { CreateAccountScreen(vm) { navController.popBackStack() } }
        }
    }
}
