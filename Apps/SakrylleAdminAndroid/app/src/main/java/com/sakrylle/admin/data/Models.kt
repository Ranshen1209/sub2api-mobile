package com.sakrylle.admin.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ApiEnvelope<T>(
    val code: Int = 0,
    val message: String = "",
    val reason: String? = null,
    val data: T? = null,
)

@Serializable
data class PageData<T>(
    val items: List<T> = emptyList(),
    val total: Int = 0,
    val page: Int = 1,
    @SerialName("page_size") val pageSize: Int = 20,
    val pages: Int = 1,
)

@Serializable
data class DashboardStats(
    @SerialName("total_users") val totalUsers: Int = 0,
    @SerialName("active_users") val activeUsers: Int = 0,
    @SerialName("total_api_keys") val totalApiKeys: Int = 0,
    @SerialName("total_accounts") val totalAccounts: Int = 0,
    @SerialName("normal_accounts") val normalAccounts: Int = 0,
    @SerialName("error_accounts") val errorAccounts: Int = 0,
    @SerialName("total_requests") val totalRequests: Int = 0,
    @SerialName("total_cost") val totalCost: Double = 0.0,
    @SerialName("total_tokens") val totalTokens: Long = 0,
    @SerialName("today_requests") val todayRequests: Int = 0,
    @SerialName("today_cost") val todayCost: Double = 0.0,
    @SerialName("today_tokens") val todayTokens: Long = 0,
    val rpm: Int = 0,
    val tpm: Int = 0,
)

@Serializable
data class TrendPoint(
    val date: String,
    val requests: Int = 0,
    @SerialName("total_tokens") val totalTokens: Long = 0,
    val cost: Double = 0.0,
    @SerialName("actual_cost") val actualCost: Double = 0.0,
)

@Serializable
data class TrendResponse(val trend: List<TrendPoint> = emptyList())

@Serializable
data class User(
    val id: Int,
    val email: String,
    val username: String? = null,
    val balance: Double? = null,
    val status: String? = null,
    val role: String? = null,
    val notes: String? = null,
    @SerialName("last_used_at") val lastUsedAt: String? = null,
)

@Serializable
data class UsageStats(
    @SerialName("total_requests") val totalRequests: Int = 0,
    @SerialName("total_tokens") val totalTokens: Long = 0,
    @SerialName("total_input_tokens") val totalInputTokens: Long = 0,
    @SerialName("total_output_tokens") val totalOutputTokens: Long = 0,
    @SerialName("total_cost") val totalCost: Double? = null,
    @SerialName("total_actual_cost") val totalActualCost: Double? = null,
    @SerialName("total_account_cost") val totalAccountCost: Double? = null,
) {
    val consumption: Double get() = totalActualCost ?: totalCost ?: 0.0
}

@Serializable
data class Group(
    val id: Int,
    val name: String,
    val platform: String = "",
    val status: String? = null,
    val description: String? = null,
    @SerialName("rate_multiplier") val rateMultiplier: Double? = null,
    @SerialName("is_exclusive") val isExclusive: Boolean? = null,
    @SerialName("subscription_type") val subscriptionType: String? = null,
    @SerialName("account_count") val accountCount: Int? = null,
)

@Serializable
data class ApiKey(
    val id: Int,
    @SerialName("user_id") val userId: Int,
    val key: String,
    val name: String,
    val status: String,
    val quota: Double = 0.0,
    @SerialName("quota_used") val quotaUsed: Double = 0.0,
    @SerialName("last_used_at") val lastUsedAt: String? = null,
    val group: Group? = null,
)

@Serializable
data class Account(
    val id: Int,
    val name: String,
    val platform: String,
    val type: String,
    val status: String? = null,
    val schedulable: Boolean? = null,
    val priority: Int? = null,
    @SerialName("rate_multiplier") val rateMultiplier: Double? = null,
    @SerialName("error_message") val errorMessage: String? = null,
    @SerialName("last_used_at") val lastUsedAt: String? = null,
    val groups: List<Group>? = null,
)

@Serializable
data class AccountTodayStats(
    val requests: Int = 0,
    val tokens: Long = 0,
    val cost: Double = 0.0,
)

@Serializable
data class StatusResponse(val groups: List<StatusGroup> = emptyList())

@Serializable
data class StatusGroup(
    val provider: String,
    @SerialName("provider_name") val providerName: String? = null,
    val service: String,
    @SerialName("service_name") val serviceName: String? = null,
    val channel: String,
    @SerialName("channel_name") val channelName: String? = null,
    @SerialName("current_status") val currentStatus: Int? = null,
    val layers: List<StatusLayer> = emptyList(),
)

@Serializable
data class StatusLayer(
    val model: String,
    @SerialName("current_status") val currentStatus: CurrentStatus? = null,
    val timeline: List<StatusPoint> = emptyList(),
)

@Serializable
data class CurrentStatus(val status: Int = -1, val latency: Int = 0)

@Serializable
data class StatusPoint(
    val timestamp: Long,
    val status: Int,
    val latency: Int = 0,
    val availability: Double = 0.0,
)

@Serializable
data class ServerProfile(
    val id: String,
    val label: String,
    val baseUrl: String,
    val adminApiKey: String,
    val updatedAt: Long,
)

@Serializable
data class CreateUserRequest(
    val email: String,
    val password: String,
    val username: String? = null,
    val notes: String? = null,
    val role: String = "user",
    val status: String = "active",
    val balance: Double? = null,
    val concurrency: Int? = null,
)

@Serializable
data class BalanceRequest(val balance: Double, val operation: String, val notes: String? = null)

@Serializable
data class UserStatusRequest(val status: String)

@Serializable
data class SchedulableRequest(val schedulable: Boolean)

@Serializable
data class CreateAccountRequest(
    val name: String,
    val platform: String,
    val type: String,
    val credentials: Map<String, String>,
    val notes: String? = null,
    val concurrency: Int? = null,
    val priority: Int? = null,
    @SerialName("rate_multiplier") val rateMultiplier: Double? = null,
    @SerialName("group_ids") val groupIds: List<Int>? = null,
)
