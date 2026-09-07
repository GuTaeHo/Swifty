package com.gutaeho.swifty.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val Default = Typography()

/**
 * The Material 3 type scale, with the display styles tightened up. They are used for
 * the large speed read-outs, where the stock tracking and line height are too airy.
 */
val SwiftyTypography = Default.copy(
    displayLarge = Default.displayLarge.copy(
        fontSize = 64.sp,
        lineHeight = 66.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = (-2).sp,
    ),
    displayMedium = Default.displayMedium.copy(
        fontSize = 48.sp,
        lineHeight = 50.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = (-1.5).sp,
    ),
    headlineLarge = Default.headlineLarge.copy(
        fontWeight = FontWeight.Medium,
        letterSpacing = (-0.5).sp,
    ),
)

/** Tabular-ish style for metric values so digits do not jitter as they change. */
val MetricValueStyle: TextStyle = Default.titleMedium.copy(fontWeight = FontWeight.SemiBold)
