package com.sakrylle.admin

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.sakrylle.admin.data.*
import kotlinx.coroutines.async
import kotlinx.coroutines.launch

data class Loadable<T>(val value: T? = null, val loading: Boolean = false, val error: String? = null)

class AppViewModel(application: Application) : AndroidViewModel(application) {
    val repository = AdminRepository(application)

    var dashboard by mutableStateOf(Loadable<DashboardStats>())
    var trend by mutableStateOf<List<TrendPoint>>(emptyList())
    var users by mutableStateOf(Loadable<PageData<User>>())
    var usageByUser by mutableStateOf<Map<Int, UsageStats>>(emptyMap())
    var userDetail by mutableStateOf(Loadable<User>())
    var keys by mutableStateOf<List<ApiKey>>(emptyList())
    var usageByKey by mutableStateOf<Map<Int, UsageStats>>(emptyMap())
    var status by mutableStateOf(Loadable<List<StatusGroup>>())
    var groups by mutableStateOf(Loadable<List<Group>>())
    var accounts by mutableStateOf(Loadable<List<Account>>())
    var statsByAccount by mutableStateOf<Map<Int, AccountTodayStats>>(emptyMap())
    var profiles by mutableStateOf(repository.profiles())
    var activeProfile by mutableStateOf(repository.activeProfile)

    fun connect(baseUrl: String, key: String, onResult: (String?) -> Unit) = viewModelScope.launch {
        if (baseUrl.isBlank() || key.isBlank()) {
            onResult("请填写服务器地址和 Admin Key。")
            return@launch
        }
        repository.saveServer(baseUrl, key)
        runCatching { repository.verify() }
            .onSuccess {
                syncProfiles()
                onResult(null)
            }
            .onFailure { onResult(it.message ?: "连接失败") }
    }

    fun loadDashboard(days: Long = 7) = viewModelScope.launch {
        dashboard = dashboard.copy(loading = true, error = null)
        runCatching {
            val stats = async { repository.dashboardStats() }
            val points = async { repository.dashboardTrend(days).trend }
            stats.await() to points.await()
        }.onSuccess { (stats, points) ->
            dashboard = Loadable(stats)
            trend = points
        }.onFailure { dashboard = Loadable(error = it.message) }
    }

    fun loadUsers(search: String = "", page: Int = 1) = viewModelScope.launch {
        users = users.copy(loading = true, error = null)
        runCatching {
            val pageData = repository.users(search, page)
            pageData to repository.userUsage(pageData.items)
        }.onSuccess { (pageData, usage) ->
            users = Loadable(pageData)
            usageByUser = usage
        }.onFailure { users = Loadable(error = it.message) }
    }

    fun loadUser(id: Int, days: Long = 7) = viewModelScope.launch {
        userDetail = userDetail.copy(loading = true, error = null)
        runCatching {
            val user = async { repository.user(id) }
            val keyPage = async { repository.keys(id) }
            val nextUser = user.await()
            val nextKeys = keyPage.await().items
            Triple(nextUser, nextKeys, repository.keyUsage(nextKeys, days))
        }.onSuccess { (user, nextKeys, usage) ->
            userDetail = Loadable(user)
            keys = nextKeys
            usageByKey = usage
        }.onFailure { userDetail = Loadable(error = it.message) }
    }

    fun createUser(body: CreateUserRequest, onResult: (String?) -> Unit) = viewModelScope.launch {
        runCatching { repository.createUser(body) }
            .onSuccess { onResult(null) }
            .onFailure { onResult(it.message ?: "创建失败") }
    }

    fun updateBalance(id: Int, body: BalanceRequest, onResult: (String?) -> Unit) = viewModelScope.launch {
        runCatching { repository.updateBalance(id, body) }
            .onSuccess { userDetail = Loadable(it); onResult(null) }
            .onFailure { onResult(it.message ?: "余额变更失败") }
    }

    fun updateUserStatus(id: Int, status: String, onResult: (String?) -> Unit) = viewModelScope.launch {
        runCatching { repository.updateUserStatus(id, status) }
            .onSuccess { userDetail = Loadable(it); onResult(null) }
            .onFailure { onResult(it.message ?: "状态变更失败") }
    }

    fun loadStatus(period: String = "24h") = viewModelScope.launch {
        status = status.copy(loading = true, error = null)
        runCatching { repository.status(period) }
            .onSuccess { status = Loadable(it) }
            .onFailure { status = Loadable(error = it.message) }
    }

    fun loadGroups(search: String = "") = viewModelScope.launch {
        groups = groups.copy(loading = true, error = null)
        runCatching { repository.groups(search).items }
            .onSuccess { groups = Loadable(it) }
            .onFailure { groups = Loadable(error = it.message) }
    }

    fun loadAccounts(search: String = "") = viewModelScope.launch {
        accounts = accounts.copy(loading = true, error = null)
        runCatching {
            val items = repository.accounts(search).items
            items to repository.accountStats(items)
        }.onSuccess { (items, stats) ->
            accounts = Loadable(items)
            statsByAccount = stats
        }.onFailure { accounts = Loadable(error = it.message) }
    }

    fun createAccount(body: CreateAccountRequest, onResult: (String?) -> Unit) = viewModelScope.launch {
        runCatching { repository.createAccount(body) }
            .onSuccess { onResult(null) }
            .onFailure { onResult(it.message ?: "创建失败") }
    }

    fun testAccount(id: Int, onResult: (String) -> Unit) = viewModelScope.launch {
        runCatching { repository.testAccount(id) }
            .onSuccess { onResult("测试完成") }
            .onFailure { onResult(it.message ?: "测试失败") }
    }

    fun toggleAccount(account: Account, onResult: (String?) -> Unit) = viewModelScope.launch {
        runCatching { repository.setAccountSchedulable(account.id, account.schedulable == false) }
            .onSuccess { loadAccounts(); onResult(null) }
            .onFailure { onResult(it.message ?: "操作失败") }
    }

    fun switchServer(id: String) {
        repository.switchServer(id)
        syncProfiles()
        loadDashboard()
    }

    fun removeServer(id: String) {
        repository.removeServer(id)
        syncProfiles()
    }

    private fun syncProfiles() {
        profiles = repository.profiles()
        activeProfile = repository.activeProfile
    }
}
