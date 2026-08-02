package com.sakrylle.admin.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF9A405F),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFD9E2),
    onPrimaryContainer = Color(0xFF3F001C),
    secondary = Color(0xFF74565E),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFFFD9E1),
    onSecondaryContainer = Color(0xFF2B151B),
    tertiary = Color(0xFF7D5635),
    tertiaryContainer = Color(0xFFFFDCC1),
    background = Color(0xFFFFF8F8),
    surface = Color(0xFFFFF8F8),
    surfaceVariant = Color(0xFFF2DDE1),
    outline = Color(0xFF837377),
    error = Color(0xFFBA1A1A),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFFFB1C4),
    onPrimary = Color(0xFF5F1131),
    primaryContainer = Color(0xFF7C2948),
    onPrimaryContainer = Color(0xFFFFD9E2),
    secondary = Color(0xFFE3BDC5),
    onSecondary = Color(0xFF422930),
    secondaryContainer = Color(0xFF5B3F47),
    onSecondaryContainer = Color(0xFFFFD9E1),
    tertiary = Color(0xFFEFB98F),
    tertiaryContainer = Color(0xFF633F20),
    background = Color(0xFF201A1B),
    surface = Color(0xFF201A1B),
    surfaceVariant = Color(0xFF514347),
    outline = Color(0xFF9E8C90),
)

private fun androidx.compose.material3.ColorScheme.withSakrylleAccent(darkTheme: Boolean) = if (darkTheme) {
    copy(
        primary = Color(0xFFFFB1C4),
        onPrimary = Color(0xFF5F1131),
        primaryContainer = Color(0xFF7C2948),
        onPrimaryContainer = Color(0xFFFFD9E2),
    )
} else {
    copy(
        primary = Color(0xFFA33B60),
        onPrimary = Color.White,
        primaryContainer = Color(0xFFFFD9E2),
        onPrimaryContainer = Color(0xFF3F001C),
    )
}

@Composable
fun SakrylleTheme(content: @Composable () -> Unit) {
    val darkTheme = isSystemInDarkTheme()
    val context = LocalContext.current
    val colors = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && darkTheme -> dynamicDarkColorScheme(context).withSakrylleAccent(true)
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> dynamicLightColorScheme(context).withSakrylleAccent(false)
        darkTheme -> DarkColors
        else -> LightColors
    }
    MaterialTheme(
        colorScheme = colors,
        typography = MaterialTheme.typography,
        content = content,
    )
}
