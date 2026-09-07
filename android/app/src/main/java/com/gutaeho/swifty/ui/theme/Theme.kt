package com.gutaeho.swifty.ui.theme

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.gutaeho.swifty.domain.AccentPalette
import com.gutaeho.swifty.domain.AppearanceMode

/** Dynamic colour is a Material You feature and only exists from Android 12. */
val supportsDynamicColor: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

@Composable
fun SwiftyTheme(
    appearance: AppearanceMode = AppearanceMode.SYSTEM,
    accent: AccentPalette = AccentPalette.GREEN,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val darkTheme = when (appearance) {
        AppearanceMode.SYSTEM -> isSystemInDarkTheme()
        AppearanceMode.LIGHT -> false
        AppearanceMode.DARK -> true
    }
    val context = LocalContext.current
    val useDynamic = dynamicColor && supportsDynamicColor
    val colorScheme = remember(accent, darkTheme, useDynamic, context) {
        when {
            useDynamic && darkTheme -> dynamicDarkColorScheme(context)
            useDynamic -> dynamicLightColorScheme(context)
            darkTheme -> darkColorSchemeFor(accent)
            else -> lightColorSchemeFor(accent)
        }
    }

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = view.context.findActivity()?.window ?: return@SideEffect
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !darkTheme
                isAppearanceLightNavigationBars = !darkTheme
            }
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = SwiftyTypography,
        content = content,
    )
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
