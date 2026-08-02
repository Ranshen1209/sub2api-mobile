package com.sakrylle.admin.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.text.DecimalFormat
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

@Composable
fun Page(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.primaryContainer) {
                Icon(painterResource(com.sakrylle.admin.R.drawable.cherry_blossom), null, Modifier.padding(4.dp).size(40.dp), tint = androidx.compose.ui.graphics.Color.Unspecified)
            }
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                subtitle?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
        }
        content()
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
fun SectionCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

@Composable
fun MetricRow(vararg metrics: Pair<String, String>) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        metrics.forEach { (title, value) ->
            Column(Modifier.weight(1f).padding(vertical = 6.dp)) {
                Text(title, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, maxLines = 1)
            }
        }
    }
}

@Composable
fun StatusBadge(text: String, healthy: Boolean) {
    val color = if (healthy) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.error
    Surface(shape = RoundedCornerShape(8.dp), color = color.copy(alpha = .12f)) {
        Text(text, Modifier.padding(horizontal = 8.dp, vertical = 4.dp), color = color, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun ErrorMessage(message: String?) {
    if (!message.isNullOrBlank()) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Rounded.ErrorOutline, null, tint = MaterialTheme.colorScheme.error)
            Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun Loading(visible: Boolean) {
    if (visible) LinearProgressIndicator(Modifier.fillMaxWidth())
}

@Composable
fun TrendChart(values: List<Double>, modifier: Modifier = Modifier) {
    if (values.size < 2) return
    val primary = MaterialTheme.colorScheme.primary
    val surface = MaterialTheme.colorScheme.surfaceContainerLowest
    val grid = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier.fillMaxWidth().height(128.dp)) {
        val min = values.minOrNull() ?: 0.0
        val max = values.maxOrNull() ?: 0.0
        val range = (max - min).takeIf { it > 0 } ?: 1.0
        val horizontalInset = 10.dp.toPx()
        val verticalInset = 12.dp.toPx()
        val plotWidth = size.width - horizontalInset * 2
        val plotHeight = size.height - verticalInset * 2
        val points = values.mapIndexed { index, value ->
            Offset(
                x = horizontalInset + plotWidth * index / (values.size - 1),
                y = verticalInset + plotHeight - ((value - min) / range * plotHeight).toFloat(),
            )
        }
        repeat(4) { index ->
            val y = verticalInset + plotHeight * index / 3f
            drawLine(grid.copy(alpha = .45f), Offset(horizontalInset, y), Offset(size.width - horizontalInset, y), 1.dp.toPx())
        }

        fun Path.addSmoothSegments() {
            points.zipWithNext().forEachIndexed { index, (current, next) ->
                val previous = points.getOrElse(index - 1) { current }
                val following = points.getOrElse(index + 2) { next }
                cubicTo(
                    current.x + (next.x - previous.x) / 6f,
                    current.y + (next.y - previous.y) / 6f,
                    next.x - (following.x - current.x) / 6f,
                    next.y - (following.y - current.y) / 6f,
                    next.x,
                    next.y,
                )
            }
        }

        val line = Path().apply { moveTo(points.first().x, points.first().y); addSmoothSegments() }
        val area = Path().apply {
            moveTo(points.first().x, size.height - verticalInset)
            lineTo(points.first().x, points.first().y)
            addSmoothSegments()
            lineTo(points.last().x, size.height - verticalInset)
            close()
        }
        drawPath(
            path = area,
            brush = Brush.verticalGradient(
                colors = listOf(primary.copy(alpha = .22f), Color.Transparent),
                startY = verticalInset,
                endY = size.height - verticalInset,
            ),
        )
        drawPath(line, primary, style = Stroke(2.6.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        val markerCount = minOf(points.size, 7)
        val markerIndices = if (markerCount < 2) listOf(0) else {
            (0 until markerCount).map { index ->
                (index * (points.lastIndex.toFloat() / (markerCount - 1))).toInt()
            }.distinct()
        }
        markerIndices.forEach { index ->
            drawCircle(surface, 4.dp.toPx(), points[index])
            drawCircle(primary, 4.dp.toPx(), points[index], style = Stroke(2.dp.toPx()))
        }
    }
}

fun money(value: Double?, precise: Boolean = false): String =
    "￥" + DecimalFormat(if (precise) "0.0000" else "0.00").format(value ?: 0.0)

fun compact(value: Long): String = when {
    value >= 1_000_000_000 -> DecimalFormat("0.#B").format(value / 1_000_000_000.0)
    value >= 1_000_000 -> DecimalFormat("0.#M").format(value / 1_000_000.0)
    value >= 1_000 -> DecimalFormat("0.#K").format(value / 1_000.0)
    else -> value.toString()
}

fun displayDate(value: String?): String = runCatching {
    OffsetDateTime.parse(value).format(DateTimeFormatter.ofPattern("MM-dd HH:mm"))
}.getOrDefault(value?.take(16)?.replace('T', ' ') ?: "--")
