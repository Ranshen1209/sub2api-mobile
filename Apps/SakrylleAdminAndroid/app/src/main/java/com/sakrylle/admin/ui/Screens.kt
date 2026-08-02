package com.sakrylle.admin.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.sakrylle.admin.AppViewModel
import com.sakrylle.admin.data.*
import kotlinx.coroutines.delay

@Composable
fun LoginScreen(vm: AppViewModel) {
    var baseUrl by rememberSaveable { mutableStateOf("") }
    var apiKey by rememberSaveable { mutableStateOf("") }
    var showKey by rememberSaveable { mutableStateOf(false) }
    var checking by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val connect: () -> Unit = {
        checking = true
        vm.connect(baseUrl, apiKey) { error -> message = error; checking = false }
        Unit
    }

    BoxWithConstraints(
        Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
    ) {
        val landscape = maxWidth > maxHeight
        if (landscape) {
            Row(
                Modifier.fillMaxSize().padding(horizontal = 32.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                LoginBrand(Modifier.weight(.85f))
                LazyColumn(
                    modifier = Modifier.weight(1.15f).fillMaxHeight(),
                    contentPadding = PaddingValues(vertical = 12.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    item {
                        LoginForm(
                            baseUrl = baseUrl,
                            onBaseUrlChange = { baseUrl = it },
                            apiKey = apiKey,
                            onApiKeyChange = { apiKey = it },
                            showKey = showKey,
                            onToggleKey = { showKey = !showKey },
                            checking = checking,
                            message = message,
                            onConnect = connect,
                            modifier = Modifier.widthIn(max = 480.dp).fillMaxWidth(),
                        )
                    }
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 24.dp, vertical = 32.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                item { LoginBrand(Modifier.widthIn(max = 420.dp).fillMaxWidth()) }
                item {
                    LoginForm(
                        baseUrl = baseUrl,
                        onBaseUrlChange = { baseUrl = it },
                        apiKey = apiKey,
                        onApiKeyChange = { apiKey = it },
                        showKey = showKey,
                        onToggleKey = { showKey = !showKey },
                        checking = checking,
                        message = message,
                        onConnect = connect,
                        modifier = Modifier.widthIn(max = 420.dp).fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun LoginBrand(modifier: Modifier = Modifier) {
    Column(
        modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.primaryContainer) {
            Icon(
                painterResource(com.sakrylle.admin.R.drawable.cherry_blossom),
                contentDescription = null,
                modifier = Modifier.padding(6.dp).size(52.dp),
                tint = Color.Unspecified,
            )
        }
        Text("Sakrylle Admin", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("连接管理接口，开始巡检。", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun LoginForm(
    baseUrl: String,
    onBaseUrlChange: (String) -> Unit,
    apiKey: String,
    onApiKeyChange: (String) -> Unit,
    showKey: Boolean,
    onToggleKey: () -> Unit,
    checking: Boolean,
    message: String?,
    onConnect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val fieldColors = TextFieldDefaults.colors(
        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
        focusedIndicatorColor = Color.Transparent,
        unfocusedIndicatorColor = Color.Transparent,
        disabledIndicatorColor = Color.Transparent,
        errorIndicatorColor = Color.Transparent,
    )
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("服务器连接", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            TextField(
                value = baseUrl,
                onValueChange = onBaseUrlChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("服务器地址") },
                leadingIcon = { Icon(Icons.Rounded.Link, null) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                colors = fieldColors,
            )
            TextField(
                value = apiKey,
                onValueChange = onApiKeyChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Admin Key") },
                leadingIcon = { Icon(Icons.Rounded.Key, null) },
                trailingIcon = {
                    IconButton(onClick = onToggleKey) {
                        Icon(if (showKey) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility, if (showKey) "隐藏" else "显示")
                    }
                },
                visualTransformation = if (showKey) VisualTransformation.None else PasswordVisualTransformation(),
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                colors = fieldColors,
            )
            ErrorMessage(message)
            Button(onClick = onConnect, modifier = Modifier.fillMaxWidth(), enabled = !checking) {
                if (checking) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                else Icon(Icons.Rounded.Bolt, null)
                Spacer(Modifier.width(8.dp))
                Text(if (checking) "正在验证..." else "连接服务器")
            }
        }
    }
}

@Composable
fun MonitorScreen(vm: AppViewModel) {
    var days by rememberSaveable { mutableLongStateOf(7) }
    LaunchedEffect(days, vm.activeProfile?.id) { vm.loadDashboard(days) }
    val stats = vm.dashboard.value
    Page("概览", "实时查看请求、Token、成本与服务负载。") {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(1L to "24H", 7L to "7D", 30L to "30D").forEach { (value, label) ->
                FilterChip(selected = days == value, onClick = { days = value }, label = { Text(label) })
            }
        }
        Loading(vm.dashboard.loading)
        ErrorMessage(vm.dashboard.error)
        SectionCard {
            Text("当前负载", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            MetricRow("RPM" to "${stats?.rpm ?: 0}", "TPM" to compact((stats?.tpm ?: 0).toLong()), "活跃用户" to "${stats?.activeUsers ?: 0}")
        }
        SectionCard {
            Text(if (days == 1L) "近 24 小时" else "近 $days 天", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            MetricRow("请求" to "${vm.trend.sumOf { it.requests }}", "Token" to compact(vm.trend.sumOf { it.totalTokens }), "成本" to money(vm.trend.sumOf { it.actualCost.takeIf { c -> c > 0 } ?: it.cost }))
            TrendChart(vm.trend.map { it.totalTokens.toDouble() })
        }
        SectionCard {
            Text("资源", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            MetricRow("用户" to "${stats?.totalUsers ?: 0}", "API Keys" to "${stats?.totalApiKeys ?: 0}", "账号" to "${stats?.totalAccounts ?: 0}")
            HorizontalDivider()
            MetricRow("正常账号" to "${stats?.normalAccounts ?: 0}", "异常账号" to "${stats?.errorAccounts ?: 0}", "累计请求" to compact((stats?.totalRequests ?: 0).toLong()))
        }
    }
}

@Composable
fun UsersScreen(vm: AppViewModel, openUser: (Int) -> Unit, createUser: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    var page by rememberSaveable { mutableIntStateOf(1) }
    LaunchedEffect(search, page, vm.activeProfile?.id) {
        delay(250)
        vm.loadUsers(search, page)
    }
    Page("用户", "搜索用户、查看 7 天用量并进入详情。") {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = search,
                onValueChange = { search = it; page = 1 },
                modifier = Modifier.weight(1f),
                label = { Text("搜索邮箱 / 用户名") },
                leadingIcon = { Icon(Icons.Rounded.Search, null) },
                singleLine = true,
            )
            FilledIconButton(onClick = createUser) { Icon(Icons.Rounded.Add, "创建用户") }
        }
        Loading(vm.users.loading)
        ErrorMessage(vm.users.error)
        val userItems = vm.users.value?.items.orEmpty()
        userItems.forEachIndexed { index, user ->
            Surface(
                onClick = { openUser(user.id) },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(4.dp),
                color = Color.Transparent,
            ) {
                Column(Modifier.padding(horizontal = 4.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(user.email, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Text("最近使用 ${displayDate(user.lastUsedAt)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        StatusBadge(user.status ?: "unknown", user.status == "active")
                    }
                    val usage = vm.usageByUser[user.id]
                    MetricRow("消费" to money(usage?.consumption, true), "Token" to compact(usage?.totalTokens ?: 0), "请求" to "${usage?.totalRequests ?: 0}")
                }
            }
            if (index < userItems.lastIndex) HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = .65f))
        }
        vm.users.value?.let { data ->
            if (data.pages > 1) Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                IconButton(onClick = { page-- }, enabled = page > 1) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "上一页") }
                Text("第 ${data.page} / ${data.pages} 页", style = MaterialTheme.typography.labelLarge)
                IconButton(onClick = { page++ }, enabled = page < data.pages) { Icon(Icons.Rounded.ArrowForward, "下一页") }
            }
        }
    }
}

@Composable
fun UserDetailScreen(vm: AppViewModel, id: Int, goBack: () -> Unit) {
    var days by rememberSaveable { mutableLongStateOf(7) }
    var search by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("10") }
    var notes by rememberSaveable { mutableStateOf("") }
    var operation by rememberSaveable { mutableStateOf("add") }
    var actionError by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(id, days) { vm.loadUser(id, days) }
    val context = LocalContext.current
    Page("用户详情", vm.userDetail.value?.email) {
        IconButton(onClick = goBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
        Loading(vm.userDetail.loading)
        ErrorMessage(vm.userDetail.error)
        vm.userDetail.value?.let { user ->
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(user.email, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Text(user.username ?: "未命名", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("余额 ${money(user.balance)} · 最近使用 ${displayDate(user.lastUsedAt)}", style = MaterialTheme.typography.bodySmall)
                    }
                    StatusBadge(user.status ?: "unknown", user.status == "active")
                }
                if (user.role?.lowercase() != "admin") {
                    OutlinedButton(onClick = { vm.updateUserStatus(id, if (user.status == "disabled") "active" else "disabled") { actionError = it } }) {
                        Text(if (user.status == "disabled") "启用用户" else "禁用用户")
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(1L to "24H", 7L to "7D", 30L to "30D").forEach { (value, label) ->
                FilterChip(selected = days == value, onClick = { days = value }, label = { Text(label) })
            }
        }
        SectionCard {
            Text("API Keys", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), label = { Text("搜索名称 / 分组") }, leadingIcon = { Icon(Icons.Rounded.Search, null) }, singleLine = true)
            vm.keys.filter { key -> search.isBlank() || listOf(key.name, key.group?.name).joinToString(" ").contains(search, true) }.forEach { key ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(key.name, fontWeight = FontWeight.Bold)
                        Text(key.group?.name ?: "未分组", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        val cost = vm.usageByKey[key.id]?.consumption ?: key.quotaUsed
                        Text("消费 ${money(cost, true)} · 最近 ${displayDate(key.lastUsedAt)}", style = MaterialTheme.typography.bodySmall)
                    }
                    IconButton(onClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("API Key", key.key))
                    }) { Icon(Icons.Rounded.ContentCopy, "复制") }
                }
                HorizontalDivider()
            }
        }
        SectionCard {
            Text("余额操作", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("add" to "充值", "subtract" to "扣减", "set" to "设为").forEach { (value, label) ->
                    FilterChip(selected = operation == value, onClick = { operation = value }, label = { Text(label) })
                }
            }
            OutlinedTextField(amount, { amount = it }, Modifier.fillMaxWidth(), label = { Text("金额") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true)
            OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("备注") }, maxLines = 3)
            ErrorMessage(actionError)
            Button(onClick = {
                val value = amount.toDoubleOrNull()
                if (value == null || value < 0) actionError = "请输入有效金额。"
                else vm.updateBalance(id, BalanceRequest(value, operation, notes.ifBlank { null })) { actionError = it }
            }, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Rounded.CheckCircle, null); Spacer(Modifier.width(8.dp)); Text("提交余额变更") }
        }
    }
}

@Composable
fun StatusScreen(vm: AppViewModel) {
    var period by rememberSaveable { mutableStateOf("24h") }
    LaunchedEffect(period) { vm.loadStatus(period) }
    Page("状态", "服务可用性监测。") {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("90m" to "近90分钟", "24h" to "近24小时", "7d" to "近7天", "30d" to "近30天").forEach { (value, label) ->
                FilterChip(selected = period == value, onClick = { period = value }, label = { Text(label) })
            }
        }
        Loading(vm.status.loading)
        ErrorMessage(vm.status.error)
        SectionCard {
            val groups = vm.status.value.orEmpty()
            MetricRow("正常" to "${groups.count { it.currentStatus == 1 }}", "异常" to "${groups.count { it.currentStatus == 0 }}", "总计" to "${groups.size}")
            groups.forEach { group ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(group.channelName ?: group.channel, fontWeight = FontWeight.Bold)
                        Text("${group.providerName ?: group.provider} · ${group.serviceName ?: group.service}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        group.layers.firstOrNull()?.let { layer -> Text("${layer.model} · ${layer.currentStatus?.latency ?: 0} ms", style = MaterialTheme.typography.labelSmall) }
                    }
                    StatusBadge(if (group.currentStatus == 1) "正常" else "异常", group.currentStatus == 1)
                }
                HorizontalDivider()
            }
        }
    }
}

@Composable
fun SettingsScreen(vm: AppViewModel, openAccounts: () -> Unit, openGroups: () -> Unit) {
    var addServer by rememberSaveable { mutableStateOf(false) }
    var baseUrl by rememberSaveable { mutableStateOf("") }
    var key by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    Page("服务器", "选择正在管理的服务器，或添加新的服务器。") {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = openAccounts) { Icon(Icons.Rounded.Dns, null); Spacer(Modifier.width(6.dp)); Text("账号清单") }
            OutlinedButton(onClick = openGroups) { Icon(Icons.Rounded.Layers, null); Spacer(Modifier.width(6.dp)); Text("分组") }
            FilledIconButton(onClick = { addServer = !addServer }) { Icon(Icons.Rounded.Add, "添加服务器") }
        }
        if (addServer) SectionCard {
            Text("添加服务器", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            OutlinedTextField(baseUrl, { baseUrl = it }, Modifier.fillMaxWidth(), label = { Text("服务器地址") }, singleLine = true)
            OutlinedTextField(key, { key = it }, Modifier.fillMaxWidth(), label = { Text("Admin Key") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            ErrorMessage(message)
            Button(onClick = {
                vm.connect(baseUrl, key) { error -> message = error; if (error == null) { addServer = false; baseUrl = ""; key = "" } }
            }) { Text("添加服务器") }
        }
        vm.profiles.forEach { profile ->
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(profile.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        Text(profile.baseUrl, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (profile.id == vm.activeProfile?.id) StatusBadge("使用中", true)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { vm.switchServer(profile.id) }, enabled = profile.id != vm.activeProfile?.id) { Text("切换") }
                    OutlinedButton(onClick = { vm.removeServer(profile.id) }) { Text("删除") }
                }
            }
        }
        if (vm.profiles.isEmpty()) SectionCard { Text("还没有服务器", fontWeight = FontWeight.Bold); Text("添加服务器后即可开始管理。", color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable
fun AccountsScreen(vm: AppViewModel, goBack: () -> Unit, createAccount: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(search, vm.activeProfile?.id) { delay(250); vm.loadAccounts(search) }
    Page("账号清单", "搜索、筛选、测试并暂停或恢复账号。") {
        IconButton(onClick = goBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(search, { search = it }, Modifier.weight(1f), label = { Text("搜索账号名称 / 平台") }, leadingIcon = { Icon(Icons.Rounded.Search, null) }, singleLine = true)
            FilledIconButton(onClick = createAccount) { Icon(Icons.Rounded.Add, "创建账号") }
        }
        Loading(vm.accounts.loading)
        ErrorMessage(vm.accounts.error)
        vm.accounts.value.orEmpty().forEach { account ->
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(account.name, fontWeight = FontWeight.Bold)
                        Text("${account.platform} · ${account.type}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    StatusBadge(account.status ?: "unknown", account.status == "active")
                }
                val stats = vm.statsByAccount[account.id]
                MetricRow("请求次数" to "${stats?.requests ?: 0}", "消费金额" to money(stats?.cost), "Token" to compact(stats?.tokens ?: 0))
                Text("优先级 ${account.priority ?: 0} · 倍率 ${"%.2f".format(account.rateMultiplier ?: 1.0)}x", style = MaterialTheme.typography.bodySmall)
                var feedback by remember(account.id) { mutableStateOf<String?>(null) }
                feedback?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { vm.testAccount(account.id) { feedback = it } }) { Text("测试") }
                    OutlinedButton(onClick = { vm.toggleAccount(account) { feedback = it } }) { Text(if (account.schedulable == false) "恢复" else "暂停") }
                }
            }
        }
    }
}

@Composable
fun GroupsScreen(vm: AppViewModel, goBack: () -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(search, vm.activeProfile?.id) { delay(250); vm.loadGroups(search) }
    Page("分组", "搜索分组并查看平台、倍率和账号数。") {
        IconButton(onClick = goBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
        OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth(), label = { Text("搜索分组名称") }, leadingIcon = { Icon(Icons.Rounded.Search, null) }, singleLine = true)
        Loading(vm.groups.loading)
        ErrorMessage(vm.groups.error)
        vm.groups.value.orEmpty().forEach { group ->
            SectionCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(group.name, fontWeight = FontWeight.Bold)
                        Text("${group.platform} · 倍率 ${"%.2f".format(group.rateMultiplier ?: 1.0)} · ${group.subscriptionType ?: "standard"}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("账号数 ${group.accountCount ?: 0} · ${if (group.isExclusive == true) "独占分组" else "共享分组"}", style = MaterialTheme.typography.bodySmall)
                    }
                    StatusBadge(group.status ?: "active", group.status != "disabled")
                }
            }
        }
    }
}

@Composable
fun CreateUserScreen(vm: AppViewModel, goBack: () -> Unit) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var username by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var role by rememberSaveable { mutableStateOf("user") }
    var status by rememberSaveable { mutableStateOf("active") }
    var balance by rememberSaveable { mutableStateOf("") }
    var concurrency by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    Page("创建用户") {
        IconButton(onClick = goBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
        SectionCard {
            OutlinedTextField(email, { email = it }, Modifier.fillMaxWidth(), label = { Text("邮箱") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), singleLine = true)
            OutlinedTextField(password, { password = it }, Modifier.fillMaxWidth(), label = { Text("密码") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            OutlinedTextField(username, { username = it }, Modifier.fillMaxWidth(), label = { Text("用户名") }, singleLine = true)
            OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("备注") }, maxLines = 3)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("user", "admin").forEach { FilterChip(selected = role == it, onClick = { role = it }, label = { Text(it) }) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("active", "disabled").forEach { FilterChip(selected = status == it, onClick = { status = it }, label = { Text(it) }) }
            }
            OutlinedTextField(balance, { balance = it }, Modifier.fillMaxWidth(), label = { Text("余额") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true)
            OutlinedTextField(concurrency, { concurrency = it }, Modifier.fillMaxWidth(), label = { Text("并发") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
            ErrorMessage(error)
            Button(onClick = {
                if (email.isBlank() || password.isBlank()) error = "邮箱和密码不能为空。"
                else vm.createUser(CreateUserRequest(email.trim(), password, username.ifBlank { null }, notes.ifBlank { null }, role, status, balance.toDoubleOrNull(), concurrency.toIntOrNull())) {
                    error = it
                    if (it == null) goBack()
                }
            }, modifier = Modifier.fillMaxWidth()) { Text("创建用户") }
        }
    }
}

@Composable
fun CreateAccountScreen(vm: AppViewModel, goBack: () -> Unit) {
    var name by rememberSaveable { mutableStateOf("") }
    var platform by rememberSaveable { mutableStateOf("anthropic") }
    var type by rememberSaveable { mutableStateOf("apikey") }
    var baseUrl by rememberSaveable { mutableStateOf("") }
    var apiKey by rememberSaveable { mutableStateOf("") }
    var accessToken by rememberSaveable { mutableStateOf("") }
    var refreshToken by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var concurrency by rememberSaveable { mutableStateOf("") }
    var priority by rememberSaveable { mutableStateOf("") }
    var multiplier by rememberSaveable { mutableStateOf("") }
    var groupIds by rememberSaveable { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    Page("创建账号") {
        IconButton(onClick = goBack) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, "返回") }
        SectionCard {
            OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("名称") }, singleLine = true)
            Text("平台", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("anthropic", "openai", "gemini").forEach { FilterChip(selected = platform == it, onClick = { platform = it }, label = { Text(it) }) }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("apikey", "oauth").forEach { FilterChip(selected = type == it, onClick = { type = it }, label = { Text(it) }) }
            }
            if (type == "apikey") {
                OutlinedTextField(baseUrl, { baseUrl = it }, Modifier.fillMaxWidth(), label = { Text("base_url") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri), singleLine = true)
                OutlinedTextField(apiKey, { apiKey = it }, Modifier.fillMaxWidth(), label = { Text("api_key") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
            } else {
                OutlinedTextField(accessToken, { accessToken = it }, Modifier.fillMaxWidth(), label = { Text("access_token") }, visualTransformation = PasswordVisualTransformation(), singleLine = true)
                OutlinedTextField(refreshToken, { refreshToken = it }, Modifier.fillMaxWidth(), label = { Text("refresh_token") }, singleLine = true)
            }
            OutlinedTextField(notes, { notes = it }, Modifier.fillMaxWidth(), label = { Text("备注") }, maxLines = 3)
            OutlinedTextField(concurrency, { concurrency = it }, Modifier.fillMaxWidth(), label = { Text("concurrency") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
            OutlinedTextField(priority, { priority = it }, Modifier.fillMaxWidth(), label = { Text("priority") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
            OutlinedTextField(multiplier, { multiplier = it }, Modifier.fillMaxWidth(), label = { Text("rate_multiplier") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true)
            OutlinedTextField(groupIds, { groupIds = it }, Modifier.fillMaxWidth(), label = { Text("group_ids 逗号分隔") }, singleLine = true)
            ErrorMessage(error)
            Button(onClick = {
                val credentials = if (type == "apikey") mapOf("base_url" to baseUrl.trim(), "api_key" to apiKey.trim()).filterValues { it.isNotBlank() }
                else mapOf("access_token" to accessToken.trim(), "refresh_token" to refreshToken.trim()).filterValues { it.isNotBlank() }
                if (name.isBlank() || credentials.isEmpty() || (type == "apikey" && credentials.size < 2)) error = "名称和凭据不能为空。"
                else vm.createAccount(CreateAccountRequest(
                    name.trim(), platform, type, credentials, notes.ifBlank { null }, concurrency.toIntOrNull(), priority.toIntOrNull(), multiplier.toDoubleOrNull(),
                    groupIds.split(',').mapNotNull { it.trim().toIntOrNull() }.takeIf { it.isNotEmpty() },
                )) { error = it; if (it == null) goBack() }
            }, modifier = Modifier.fillMaxWidth()) { Text("创建账号") }
        }
    }
}
