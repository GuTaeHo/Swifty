package com.gutaeho.swifty.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.gutaeho.swifty.domain.AccentPalette
import com.gutaeho.swifty.domain.SpeedLevel
import kotlin.math.abs

/**
 * Approximation of a Material 3 tonal palette: a fixed hue whose chroma fades toward
 * the light and dark ends of the tonal range. Every colour role in the scheme is read
 * from one of these palettes, so the result behaves like a generated M3 scheme.
 */
@Immutable
internal class TonalPalette(private val hue: Float, private val chroma: Float) {
    fun tone(value: Int): Color {
        val lightness = (value / 100f).coerceIn(0f, 1f)
        val falloff = 1f - abs(lightness - 0.5f) * 2f
        return Color.hsl(hue, (chroma * (0.30f + 0.70f * falloff)).coerceIn(0f, 1f), lightness)
    }
}

private class Palettes(hue: Float, chroma: Float) {
    val primary = TonalPalette(hue, chroma)
    val secondary = TonalPalette(hue, chroma * 0.34f)
    val tertiary = TonalPalette((hue + 60f) % 360f, chroma * 0.55f)
    val neutral = TonalPalette(hue, 0.05f)
    val neutralVariant = TonalPalette(hue, 0.11f)
    val error = TonalPalette(25f, 0.85f)
}

private val AccentPalette.palettes: Palettes
    get() = when (this) {
        AccentPalette.GREEN -> Palettes(148f, 0.62f)
        AccentPalette.BLUE -> Palettes(214f, 0.78f)
        AccentPalette.TEAL -> Palettes(184f, 0.64f)
        AccentPalette.PURPLE -> Palettes(264f, 0.70f)
        AccentPalette.PINK -> Palettes(332f, 0.70f)
        AccentPalette.ORANGE -> Palettes(26f, 0.80f)
        AccentPalette.AMBER -> Palettes(43f, 0.84f)
    }

internal fun lightColorSchemeFor(accent: AccentPalette): ColorScheme {
    val p = accent.palettes
    return lightColorScheme(
        primary = p.primary.tone(40),
        onPrimary = p.primary.tone(100),
        primaryContainer = p.primary.tone(90),
        onPrimaryContainer = p.primary.tone(10),
        inversePrimary = p.primary.tone(80),
        secondary = p.secondary.tone(40),
        onSecondary = p.secondary.tone(100),
        secondaryContainer = p.secondary.tone(90),
        onSecondaryContainer = p.secondary.tone(10),
        tertiary = p.tertiary.tone(40),
        onTertiary = p.tertiary.tone(100),
        tertiaryContainer = p.tertiary.tone(90),
        onTertiaryContainer = p.tertiary.tone(10),
        error = p.error.tone(40),
        onError = p.error.tone(100),
        errorContainer = p.error.tone(90),
        onErrorContainer = p.error.tone(10),
        background = p.neutral.tone(98),
        onBackground = p.neutral.tone(10),
        surface = p.neutral.tone(98),
        onSurface = p.neutral.tone(10),
        surfaceVariant = p.neutralVariant.tone(90),
        onSurfaceVariant = p.neutralVariant.tone(30),
        surfaceTint = p.primary.tone(40),
        inverseSurface = p.neutral.tone(20),
        inverseOnSurface = p.neutral.tone(95),
        outline = p.neutralVariant.tone(50),
        outlineVariant = p.neutralVariant.tone(80),
        scrim = Color.Black,
        surfaceBright = p.neutral.tone(98),
        surfaceDim = p.neutral.tone(87),
        surfaceContainerLowest = p.neutral.tone(100),
        surfaceContainerLow = p.neutral.tone(96),
        surfaceContainer = p.neutral.tone(94),
        surfaceContainerHigh = p.neutral.tone(92),
        surfaceContainerHighest = p.neutral.tone(90),
    )
}

internal fun darkColorSchemeFor(accent: AccentPalette): ColorScheme {
    val p = accent.palettes
    return darkColorScheme(
        primary = p.primary.tone(80),
        onPrimary = p.primary.tone(20),
        primaryContainer = p.primary.tone(30),
        onPrimaryContainer = p.primary.tone(90),
        inversePrimary = p.primary.tone(40),
        secondary = p.secondary.tone(80),
        onSecondary = p.secondary.tone(20),
        secondaryContainer = p.secondary.tone(30),
        onSecondaryContainer = p.secondary.tone(90),
        tertiary = p.tertiary.tone(80),
        onTertiary = p.tertiary.tone(20),
        tertiaryContainer = p.tertiary.tone(30),
        onTertiaryContainer = p.tertiary.tone(90),
        error = p.error.tone(80),
        onError = p.error.tone(20),
        errorContainer = p.error.tone(30),
        onErrorContainer = p.error.tone(90),
        background = p.neutral.tone(6),
        onBackground = p.neutral.tone(90),
        surface = p.neutral.tone(6),
        onSurface = p.neutral.tone(90),
        surfaceVariant = p.neutralVariant.tone(30),
        onSurfaceVariant = p.neutralVariant.tone(80),
        surfaceTint = p.primary.tone(80),
        inverseSurface = p.neutral.tone(90),
        inverseOnSurface = p.neutral.tone(20),
        outline = p.neutralVariant.tone(60),
        outlineVariant = p.neutralVariant.tone(30),
        scrim = Color.Black,
        surfaceBright = p.neutral.tone(24),
        surfaceDim = p.neutral.tone(6),
        surfaceContainerLowest = p.neutral.tone(4),
        surfaceContainerLow = p.neutral.tone(10),
        surfaceContainer = p.neutral.tone(12),
        surfaceContainerHigh = p.neutral.tone(17),
        surfaceContainerHighest = p.neutral.tone(22),
    )
}

/** Swatch shown in the settings sheet, taken from the same tonal palette as the scheme. */
fun accentSwatch(accent: AccentPalette, dark: Boolean): Color =
    accent.palettes.primary.tone(if (dark) 70 else 45)

/** Speed-zone colours resolved against the active scheme so they read in both themes. */
@Immutable
class SpeedPalette internal constructor(
    private val easy: Color,
    private val normal: Color,
    private val fast: Color,
    private val limit: Color,
) {
    operator fun get(level: SpeedLevel): Color = when (level) {
        SpeedLevel.EASY -> easy
        SpeedLevel.NORMAL -> normal
        SpeedLevel.FAST -> fast
        SpeedLevel.LIMIT -> limit
    }
}

@Composable
fun rememberSpeedPalette(): SpeedPalette {
    val scheme = MaterialTheme.colorScheme
    val dark = isDarkScheme()
    return remember(scheme, dark) {
        SpeedPalette(
            easy = scheme.secondary,
            normal = scheme.primary,
            fast = if (dark) Color(0xFFFFB868) else Color(0xFFB25E00),
            limit = scheme.error,
        )
    }
}

/** True when the active scheme is a dark one, regardless of the system setting. */
@Composable
@ReadOnlyComposable
fun isDarkScheme(): Boolean = MaterialTheme.colorScheme.surface.luminance() < 0.5f
