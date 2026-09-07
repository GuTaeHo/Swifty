package com.gutaeho.swifty.ui.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.EstimateSource
import com.gutaeho.swifty.domain.Fmt
import com.gutaeho.swifty.domain.TransportMode
import com.gutaeho.swifty.location.LocationPermissionStatus
import com.gutaeho.swifty.navigation.NavigationService
import com.gutaeho.swifty.ui.theme.MetricValueStyle
import kotlin.math.roundToInt

/** Material 3 surface container card used for every panel in the app. */
@Composable
fun PanelCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable () -> Unit,
) {
    Card(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            contentColor = MaterialTheme.colorScheme.onSurface,
        ),
    ) {
        Box(Modifier.padding(contentPadding)) { content() }
    }
}

@Composable
fun MetricCell(
    label: String,
    value: String,
    unit: String? = null,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(value, style = MetricValueStyle, color = tint)
            if (unit != null) {
                Text(
                    unit,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * Floating status message. Uses the Material 3 error / secondary container roles so the
 * banner stays legible on top of the map without translucent surface hacks.
 */
@Composable
fun StatusBanner(
    text: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    container: Color = MaterialTheme.colorScheme.secondaryContainer,
    onContainer: Color = MaterialTheme.colorScheme.onSecondaryContainer,
) {
    Surface(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        color = container,
        contentColor = onContainer,
        shadowElevation = 3.dp,
    ) {
        Row(
            Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(icon, contentDescription = null, Modifier.size(18.dp))
            Text(text, style = MaterialTheme.typography.labelLarge)
        }
    }
}

@Composable
fun TransportPicker(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    Row(
        modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        TransportMode.entries.forEach { mode ->
            val selected = viewModel.transport == mode
            FilterChip(
                selected = selected,
                onClick = { viewModel.chooseTransport(mode) },
                label = { Text(mode.title) },
                leadingIcon = {
                    Icon(mode.iconVector, contentDescription = null, Modifier.size(FilterChipDefaults.IconSize))
                },
            )
        }
    }
}

@Composable
fun LocationGate(
    status: LocationPermissionStatus,
    denied: Boolean,
    onRequest: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val blocked = denied || status == LocationPermissionStatus.DENIED
    Column(
        modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = MaterialTheme.colorScheme.secondaryContainer,
            contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
        ) {
            Icon(
                if (blocked) Icons.Filled.LocationOff else Icons.Filled.LocationOn,
                contentDescription = null,
                Modifier.padding(20.dp).size(40.dp),
            )
        }
        Spacer(Modifier.height(20.dp))
        Text(
            if (blocked) "위치 권한이 필요합니다" else "현재 위치를 사용합니다",
            style = MaterialTheme.typography.headlineSmall,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "현재 속도와 이동 거리, 방향 및 경로를 계산하려면 위치 사용을 허용해 주세요.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        if (blocked) {
            Button(onClick = onOpenSettings) { Text("설정 열기") }
        } else {
            Button(onClick = onRequest) { Text("위치 사용 허용") }
        }
    }
}

@Composable
fun DestinationSummary(
    viewModel: SwiftyViewModel,
    modifier: Modifier = Modifier,
    navigation: NavigationService = viewModel.navigation,
    compact: Boolean = false,
    onConfirm: (() -> Unit)? = null,
    onClear: (() -> Unit)? = null,
) {
    val destination = navigation.destination ?: return
    val estimate = navigation.estimate
    PanelCard(modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        destination.name,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    destination.subtitle?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                IconButton(onClick = { viewModel.setShowsElevation(!viewModel.showsElevationMetrics) }) {
                    Icon(
                        if (viewModel.showsElevationMetrics) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                        contentDescription = if (viewModel.showsElevationMetrics) "고도 접기" else "고도 펼치기",
                    )
                }
                if (onClear != null) {
                    IconButton(onClick = onClear) {
                        Icon(Icons.Filled.Close, contentDescription = if (onConfirm != null) "닫기" else "목적지 지우기")
                    }
                }
            }
            if (estimate == null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    LinearProgressIndicator(Modifier.width(72.dp))
                    Text("위치를 확인하는 중입니다…", style = MaterialTheme.typography.bodySmall)
                }
            } else {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    MetricCell(
                        "남은 거리",
                        Fmt.distance(estimate.distanceMeters, viewModel.unitSystem, viewModel.transport),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    MetricCell("남은 시간", Fmt.duration(estimate.timeSeconds))
                    MetricCell("도착 예정", Fmt.arrivalTime(estimate.timeSeconds))
                }
                if (viewModel.showsElevationMetrics) {
                    HorizontalDivider()
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        MetricCell(
                            "출발 대비",
                            Fmt.signedAltitude(navigation.elevationChange, viewModel.unitSystem),
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
                }
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    val straightLine = estimate.source == EstimateSource.STRAIGHT_LINE
                    val chipColor = if (straightLine) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
                    AssistChip(
                        onClick = {},
                        enabled = false,
                        label = { Text(estimate.source.label) },
                        leadingIcon = {
                            Icon(
                                estimate.source.iconVector,
                                contentDescription = null,
                                Modifier.size(AssistChipDefaults.IconSize),
                            )
                        },
                        colors = AssistChipDefaults.assistChipColors(
                            disabledLabelColor = chipColor,
                            disabledLeadingIconContentColor = chipColor,
                        ),
                    )
                    if (navigation.isCalculatingRoute) {
                        Text(
                            "경로 계산 중",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    if (onConfirm != null) {
                        Button(onClick = onConfirm, contentPadding = PaddingValues(horizontal = 16.dp)) {
                            Icon(Icons.Filled.Flag, contentDescription = null, Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("확정")
                        }
                    }
                }
            }
            if (!compact) {
                navigation.routeErrorMessage?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}

@Composable
fun TripMetrics(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    val recorder = viewModel.recorder
    val unit = viewModel.unitSystem
    PanelCard(modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (recorder.isRecording) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    MetricCell(
                        "경과",
                        Fmt.elapsed(recorder.elapsedSeconds(viewModel.location.clockMillis)),
                        tint = MaterialTheme.colorScheme.error,
                    )
                    MetricCell(
                        "측정 거리",
                        Fmt.distance(recorder.distanceMeters, unit, recorder.transport),
                        tint = MaterialTheme.colorScheme.error,
                    )
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    MetricCell("최고", unit.speed(recorder.maxSpeedMetersPerSecond).roundToInt().toString(), unit.speedSymbol)
                    MetricCell("평균", unit.speed(recorder.averageSpeedMetersPerSecond).roundToInt().toString(), unit.speedSymbol)
                    IconButton(onClick = viewModel::toggleRecording) {
                        Icon(Icons.Filled.Stop, contentDescription = "측정 종료", tint = MaterialTheme.colorScheme.error)
                    }
                }
            } else {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    MetricCell("최고", unit.speed(viewModel.location.maxSpeedMetersPerSecond).roundToInt().toString(), unit.speedSymbol)
                    MetricCell("평균", unit.speed(viewModel.location.averageSpeedMetersPerSecond).roundToInt().toString(), unit.speedSymbol)
                    MetricCell("주행 거리", Fmt.distance(viewModel.location.tripDistanceMeters, unit, viewModel.transport))
                    IconButton(onClick = viewModel.location::resetTrip) {
                        Icon(Icons.Filled.Refresh, contentDescription = "주행 기록 초기화")
                    }
                }
            }
        }
    }
}
