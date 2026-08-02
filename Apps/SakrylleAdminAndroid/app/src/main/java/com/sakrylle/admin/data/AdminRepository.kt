package com.sakrylle.admin.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

class AdminRepository(context: Context) {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()
    private val preferences = EncryptedSharedPreferences.create(
        context,
        "sakrylle_admin_servers",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    var activeProfile: ServerProfile? = null
        private set

    init {
        val profiles = profiles()
        val activeId = preferences.getString("active_id", null)
        activeProfile = profiles.firstOrNull { it.id == activeId } ?: profiles.firstOrNull()
    }

    fun profiles(): List<ServerProfile> = runCatching {
        json.decodeFromString<List<ServerProfile>>(preferences.getString("profiles", "[]") ?: "[]")
    }.getOrDefault(emptyList())
        .map { it.copy(label = serverLabel(it.baseUrl)) }
        .sortedByDescending { it.updatedAt }

    fun saveServer(baseUrl: String, key: String): ServerProfile {
        val normalized = normalizeBaseUrl(baseUrl)
        val all = profiles().toMutableList()
        val index = all.indexOfFirst { it.baseUrl == normalized && it.adminApiKey == key.trim() }
        val profile = ServerProfile(
            id = if (index >= 0) all[index].id else UUID.randomUUID().toString(),
            label = serverLabel(normalized),
            baseUrl = normalized,
            adminApiKey = key.trim(),
            updatedAt = System.currentTimeMillis(),
        )
        if (index >= 0) all[index] = profile else all += profile
        persist(all, profile.id)
        activeProfile = profile
        return profile
    }

    fun switchServer(id: String) {
        activeProfile = profiles().firstOrNull { it.id == id } ?: return
        preferences.edit().putString("active_id", id).apply()
    }

    fun removeServer(id: String) {
        val next = profiles().filterNot { it.id == id }
        val active = if (activeProfile?.id == id) next.firstOrNull() else activeProfile
        persist(next, active?.id)
        activeProfile = active
    }

    suspend fun verify() = get<DashboardStats>("/api/v1/admin/dashboard/stats")

    suspend fun dashboardStats() = get<DashboardStats>("/api/v1/admin/dashboard/stats")

    suspend fun dashboardTrend(days: Long): TrendResponse {
        val end = LocalDate.now()
        return get("/api/v1/admin/dashboard/trend", mapOf(
            "start_date" to end.minusDays(days - 1).toString(),
            "end_date" to end.toString(),
            "granularity" to if (days == 1L) "hour" else "day",
        ))
    }

    suspend fun users(search: String, page: Int = 1): PageData<User> = get(
        "/api/v1/admin/users",
        mapOf("search" to search, "page" to page.toString(), "page_size" to "20", "sort_by" to "last_used_at", "sort_order" to "desc"),
    )

    suspend fun user(id: Int): User = get("/api/v1/admin/users/$id")

    suspend fun createUser(body: CreateUserRequest): User = post("/api/v1/admin/users", body)

    suspend fun updateBalance(id: Int, body: BalanceRequest): User = post("/api/v1/admin/users/$id/balance", body)

    suspend fun updateUserStatus(id: Int, status: String): User = put("/api/v1/admin/users/$id", UserStatusRequest(status))

    suspend fun keys(id: Int): PageData<ApiKey> = get("/api/v1/admin/users/$id/api-keys", mapOf("page" to "1", "page_size" to "100"))

    suspend fun usage(userId: Int? = null, keyId: Int? = null, days: Long = 7): UsageStats {
        val end = LocalDate.now()
        val query = mutableMapOf(
            "start_date" to end.minusDays(days - 1).toString(),
            "end_date" to end.toString(),
            "timezone" to ZoneId.systemDefault().id,
        )
        userId?.let { query["user_id"] = it.toString() }
        keyId?.let { query["api_key_id"] = it.toString(); query["nocache"] = "1" }
        return get("/api/v1/admin/usage/stats", query)
    }

    suspend fun userUsage(users: List<User>): Map<Int, UsageStats> = coroutineScope {
        users.map { user -> async { user.id to usage(userId = user.id) } }.awaitAll().toMap()
    }

    suspend fun keyUsage(keys: List<ApiKey>, days: Long): Map<Int, UsageStats> = coroutineScope {
        keys.map { key -> async { runCatching { key.id to usage(keyId = key.id, days = days) }.getOrNull() } }
            .awaitAll()
            .filterNotNull()
            .toMap()
    }

    suspend fun groups(search: String): PageData<Group> = get(
        "/api/v1/admin/groups",
        mapOf("page" to "1", "page_size" to "20", "search" to search),
    )

    suspend fun accounts(search: String): PageData<Account> = get(
        "/api/v1/admin/accounts",
        mapOf("page" to "1", "page_size" to "20", "search" to search),
    )

    suspend fun accountToday(id: Int): AccountTodayStats = get("/api/v1/admin/accounts/$id/today-stats")

    suspend fun createAccount(body: CreateAccountRequest): Account = post("/api/v1/admin/accounts", body)

    suspend fun testAccount(id: Int): JsonElement = post("/api/v1/admin/accounts/$id/test", emptyMap<String, String>())

    suspend fun setAccountSchedulable(id: Int, enabled: Boolean): Account =
        post("/api/v1/admin/accounts/$id/schedulable", SchedulableRequest(enabled))

    suspend fun accountStats(accounts: List<Account>): Map<Int, AccountTodayStats> = coroutineScope {
        accounts.map { account -> async { account.id to accountToday(account.id) } }.awaitAll().toMap()
    }

    suspend fun status(period: String): List<StatusGroup> = withContext(Dispatchers.IO) {
        val url = "https://status.sakrylle.com/api/status?period=${encode(period)}&board=hot"
        val connection = URI(url).toURL().openConnection() as HttpURLConnection
        connection.setRequestProperty("Accept", "application/json")
        try {
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            json.decodeFromString<StatusResponse>(body).groups
        } finally {
            connection.disconnect()
        }
    }

    private suspend inline fun <reified T> get(path: String, query: Map<String, String> = emptyMap()): T =
        request(path, query, "GET", null)

    private suspend inline fun <reified T, reified B> post(path: String, body: B): T =
        request(path, emptyMap(), "POST", json.encodeToString(body))

    private suspend inline fun <reified T, reified B> put(path: String, body: B): T =
        request(path, emptyMap(), "PUT", json.encodeToString(body))

    private suspend inline fun <reified T> request(path: String, query: Map<String, String>, method: String, body: String?): T = withContext(Dispatchers.IO) {
        val profile = activeProfile ?: error("请先添加服务器")
        val suffix = query.filterValues { it.isNotBlank() }.entries.joinToString("&") { "${encode(it.key)}=${encode(it.value)}" }
        val url = profile.baseUrl + path + if (suffix.isEmpty()) "" else "?$suffix"
        val connection = URI(url).toURL().openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.requestMethod = method
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("x-api-key", profile.adminApiKey)
        if (body != null) {
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.bufferedWriter().use { it.write(body) }
        }
        try {
            val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            val envelope = json.decodeFromString<ApiEnvelope<T>>(body)
            if (connection.responseCode !in 200..299 || envelope.code != 0) {
                error(envelope.reason ?: envelope.message.ifBlank { "HTTP ${connection.responseCode}" })
            }
            envelope.data ?: error("响应缺少 data")
        } finally {
            connection.disconnect()
        }
    }

    private fun persist(profiles: List<ServerProfile>, activeId: String?) {
        preferences.edit()
            .putString("profiles", json.encodeToString(profiles))
            .putString("active_id", activeId)
            .apply()
    }

    companion object {
        fun normalizeBaseUrl(value: String): String {
            var text = value.trim().trimEnd('/')
            if (text.isNotBlank() && !text.startsWith("http://") && !text.startsWith("https://")) text = "https://$text"
            return text
        }

        fun serverLabel(value: String): String {
            val normalized = normalizeBaseUrl(value)
            val host = runCatching { URI(normalized).host }.getOrNull()?.trim('.').orEmpty()
            if (host.isBlank()) return normalized
            if (host == "localhost" || host.contains(':') || host.all { it.isDigit() || it == '.' }) return host
            val labels = host.split('.').filter { it.isNotBlank() }
            return labels.getOrElse(labels.lastIndex - 1) { labels.firstOrNull() ?: normalized }
        }

        private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())
    }
}
