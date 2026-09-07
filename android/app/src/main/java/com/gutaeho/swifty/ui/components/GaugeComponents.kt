package com.gutaeho.swifty.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.Fmt
import com.gutaeho.swifty.ui.theme.rememberSpeedPalette
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun DigitalGauge(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    val speed = viewModel.unitSystem.speed(viewModel.location.speedMetersPerSecond)
    val maximum = viewModel.transport.gaugeMaxSpeed(viewModel.unitSystem)
    val fraction = (speed / maximum).coerceIn(0.0, 1.0)
    val zone = viewModel.transport.zone(fraction)
    val color = rememberSpeedPalette()[zone.level]

    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PanelCard(Modifier.fillMaxWidth().weight(1f)) {
            Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.SpaceBetween) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        "현재 속도",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    ZoneLabel(zone.label, color)
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        speed.roundToInt().toString(),
                        style = MaterialTheme.typography.displayLarge,
                        color = color,
                    )
                    Text(
                        viewModel.unitSystem.speedSymbol,
                        Modifier.padding(start = 8.dp, bottom = 12.dp),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.weight(1f))
                    if (viewModel.transport.usesPace) {
                        Column(horizontalAlignment = Alignment.End) {
                            Text(
                                "페이스",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                Fmt.pace(viewModel.location.speedMetersPerSecond, viewModel.unitSystem) +
                                    viewModel.unitSystem.paceSymbol,
                                style = MaterialTheme.typography.headlineSmall,
                            )
                        }
                    }
                }
                LinearProgressIndicator(
                    progress = { fraction.toFloat() },
                    modifier = Modifier.fillMaxWidth().height(8.dp),
                    color = color,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHighest,
                    strokeCap = StrokeCap.Round,
                )
            }
        }
        Row(Modifier.fillMaxWidth().height(150.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CompassCard(viewModel.location.displayBearing, Modifier.width(124.dp).fillMaxHeight())
            PanelCard(Modifier.weight(1f).fillMaxHeight()) {
                Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.SpaceEvenly) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        MetricCell(
                            "고도",
                            viewModel.location.location?.altitudeMeters
                                ?.let { viewModel.unitSystem.altitude(it).roundToInt().toString() } ?: "–",
                            viewModel.unitSystem.altitudeSymbol,
                        )
                        MetricCell(
                            "누적 상승",
                            viewModel.unitSystem.altitude(viewModel.location.elevationGainMeters).roundToInt().toString(),
                            viewModel.unitSystem.altitudeSymbol,
                        )
                        MetricCell(
                            "누적 하강",
                            viewModel.unitSystem.altitude(viewModel.location.elevationLossMeters).roundToInt().toString(),
                            viewModel.unitSystem.altitudeSymbol,
                        )
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        val fix = viewModel.location.location
                        MetricCell(
                            "속도 정확도",
                            fix?.speedAccuracy?.let { "±%.1f".format(viewModel.unitSystem.speed(it)) } ?: "–",
                            viewModel.unitSystem.speedSymbol,
                            MaterialTheme.colorScheme.primary,
                        )
                        MetricCell("위치 정확도", fix?.horizontalAccuracy?.roundToInt()?.let { "±$it" } ?: "–", "m")
                    }
                }
            }
        }
        TripMetrics(viewModel, Modifier.fillMaxWidth())
    }
}

@Composable
fun AnalogGauge(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SpeedometerDial(viewModel, Modifier.fillMaxWidth().weight(1f))
        Row(Modifier.fillMaxWidth().height(148.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CompassCard(viewModel.location.displayBearing, Modifier.width(124.dp).fillMaxHeight())
            TripMetrics(viewModel, Modifier.weight(1f).fillMaxHeight())
        }
    }
}

@Composable
fun SpeedometerDial(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    val speed = viewModel.unitSystem.speed(viewModel.location.speedMetersPerSecond)
    val peak = viewModel.unitSystem.speed(viewModel.location.maxSpeedMetersPerSecond)
    val maximum = viewModel.transport.gaugeMaxSpeed(viewModel.unitSystem)
    val majorStep = viewModel.transport.gaugeMajorStep(viewModel.unitSystem)
    val fraction = (speed / maximum).coerceIn(0.0, 1.0)
    val peakFraction = (peak / maximum).coerceIn(0.0, 1.0)
    val zone = viewModel.transport.zone(fraction)
    val palette = rememberSpeedPalette()
    val currentColor = palette[zone.level]
    val scheme = MaterialTheme.colorScheme
    val onSurface = scheme.onSurface
    val outline = scheme.outlineVariant
    val dialSurface = scheme.surfaceContainerHighest
    val needleColor = scheme.error
    val hubColor = scheme.onSurfaceVariant
    val peakColor = scheme.tertiary

    Box(modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(4.dp)) {
            val radius = size.minDimension / 2
            val center = Offset(size.width / 2, size.height / 2)
            drawCircle(dialSurface, radius, center)
            drawCircle(outline, radius, center, style = Stroke(2f))

            var lower = 0.0
            viewModel.transport.zones.forEach { item ->
                drawArc(
                    palette[item.level].copy(alpha = .28f),
                    startAngle = (135 + lower * 270).toFloat(),
                    sweepAngle = ((item.upperFraction - lower) * 270).toFloat(),
                    useCenter = false,
                    topLeft = Offset(radius * .07f, radius * .07f),
                    size = Size(radius * 1.86f, radius * 1.86f),
                    style = Stroke(radius * .055f, cap = StrokeCap.Butt),
                )
                lower = item.upperFraction
            }
            drawArc(
                currentColor,
                startAngle = 135f,
                sweepAngle = (fraction * 270).toFloat(),
                useCenter = false,
                topLeft = Offset(radius * .09f, radius * .09f),
                size = Size(radius * 1.82f, radius * 1.82f),
                style = Stroke(radius * .035f, cap = StrokeCap.Round),
            )

            val majorCount = (maximum / majorStep).roundToInt().coerceAtLeast(1)
            val tickCount = majorCount * 4
            repeat(tickCount + 1) { index ->
                val t = index.toDouble() / tickCount
                val angle = Math.toRadians(135 + 270 * t)
                val outer = radius * .91f
                val inner = radius * if (index % 4 == 0) .78f else .84f
                val start = Offset(center.x + cos(angle).toFloat() * inner, center.y + sin(angle).toFloat() * inner)
                val end = Offset(center.x + cos(angle).toFloat() * outer, center.y + sin(angle).toFloat() * outer)
                drawLine(
                    if (t >= viewModel.transport.redlineFraction) needleColor
                    else onSurface.copy(alpha = if (index % 4 == 0) .75f else .30f),
                    start,
                    end,
                    strokeWidth = if (index % 4 == 0) 5f else 2f,
                    cap = StrokeCap.Round,
                )
            }

            val needleAngle = Math.toRadians(135 + fraction * 270)
            val needleEnd = Offset(
                center.x + cos(needleAngle).toFloat() * radius * .58f,
                center.y + sin(needleAngle).toFloat() * radius * .58f,
            )
            drawLine(needleColor, center, needleEnd, radius * .032f, StrokeCap.Round)
            drawCircle(hubColor, radius * .075f, center)

            if (peak > 1) {
                val peakAngle = Math.toRadians(135 + peakFraction * 270)
                val p1 = Offset(center.x + cos(peakAngle).toFloat() * radius * .70f, center.y + sin(peakAngle).toFloat() * radius * .70f)
                val p2 = Offset(center.x + cos(peakAngle).toFloat() * radius * .76f, center.y + sin(peakAngle).toFloat() * radius * .76f)
                drawLine(peakColor, p1, p2, 7f, StrokeCap.Round)
            }
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
            modifier = Modifier.padding(top = 88.dp),
        ) {
            Text(speed.roundToInt().toString(), style = MaterialTheme.typography.displayLarge)
            Text(
                viewModel.unitSystem.speedSymbol,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (viewModel.transport.usesPace) {
                Text(
                    Fmt.pace(viewModel.location.speedMetersPerSecond, viewModel.unitSystem) +
                        viewModel.unitSystem.paceSymbol,
                    style = MaterialTheme.typography.labelMedium,
                )
            }
            Spacer(Modifier.height(4.dp))
            ZoneLabel(zone.label, currentColor)
        }
    }
}

@Composable
fun CompassCard(bearing: Double?, modifier: Modifier = Modifier) {
    PanelCard(modifier, contentPadding = PaddingValues(12.dp)) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.weight(1f).aspectRatio(1f), contentAlignment = Alignment.Center) {
                val onSurface = MaterialTheme.colorScheme.onSurface
                val accent = MaterialTheme.colorScheme.primary
                val dial = MaterialTheme.colorScheme.surfaceContainerHighest
                Canvas(Modifier.fillMaxSize()) {
                    val center = Offset(size.width / 2, size.height / 2)
                    val radius = size.minDimension / 2
                    drawCircle(dial, radius, center)
                    drawCircle(onSurface.copy(alpha = .18f), radius, center, style = Stroke(1.5f))
                    repeat(36) { step ->
                        val angle = Math.toRadians(step * 10.0 - 90 - (bearing ?: 0.0))
                        val cardinal = step % 9 == 0
                        val inner = radius * if (cardinal) .72f else .82f
                        val outer = radius * .91f
                        drawLine(
                            onSurface.copy(alpha = if (cardinal) .75f else .25f),
                            Offset(center.x + cos(angle).toFloat() * inner, center.y + sin(angle).toFloat() * inner),
                            Offset(center.x + cos(angle).toFloat() * outer, center.y + sin(angle).toFloat() * outer),
                            if (cardinal) 3f else 1.5f,
                        )
                    }
                    drawLine(
                        accent,
                        Offset(center.x, center.y - radius * .94f),
                        Offset(center.x, center.y - radius * .78f),
                        7f,
                        StrokeCap.Round,
                    )
                }
                Text(
                    "N",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(Fmt.cardinalName(bearing), style = MaterialTheme.typography.labelLarge)
                Text(
                    Fmt.degrees(bearing),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/** Material 3 tonal chip marking the current speed zone. */
@Composable
private fun ZoneLabel(label: String, color: Color) {
    Surface(
        shape = MaterialTheme.shapes.small,
        color = color.copy(alpha = .16f),
        contentColor = color,
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelMedium,
        )
    }
}
