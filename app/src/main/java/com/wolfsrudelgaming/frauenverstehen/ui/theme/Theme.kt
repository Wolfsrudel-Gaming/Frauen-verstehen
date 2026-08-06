package com.wolfsrudelgaming.frauenverstehen.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val LightColorScheme = lightColorScheme(
    primary = Rose40,
    onPrimary = Color.White,
    primaryContainer = RoseContainer,
    onPrimaryContainer = OnRoseContainer,
    secondary = Purple40,
    onSecondary = Color.White,
    secondaryContainer = Purple80,
    onSecondaryContainer = Color(0xFF21005D),
    background = WarmBackground,
    onBackground = Color(0xFF201A1E),
    surface = WarmSurface,
    onSurface = Color(0xFF201A1E),
    surfaceVariant = Color(0xFFF3DEE7),
    onSurfaceVariant = Color(0xFF4D3841),
)

private val DarkColorScheme = darkColorScheme(
    primary = Rose80,
    onPrimary = Rose20,
    primaryContainer = Color(0xFF8B004E),
    onPrimaryContainer = RoseContainer,
    secondary = Purple80,
    onSecondary = Color(0xFF3D006E),
    background = Color(0xFF1A1013),
    onBackground = Color(0xFFEDD7E2),
    surface = Color(0xFF1A1013),
    onSurface = Color(0xFFEDD7E2),
)

@Composable
fun FrauenVerstehenTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
