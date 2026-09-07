package com.gutaeho.swifty.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.Fmt
import com.gutaeho.swifty.domain.TripRecord
import com.gutaeho.swifty.ui.components.MetricCell
import com.gutaeho.swifty.ui.components.PanelCard
import com.gutaeho.swifty.ui.components.iconVector
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.Style
import kotlin.math.roundToInt

@Composable
fun HistoryScreen(viewModel: SwiftyViewModel, modifier: Modifier = Modifier) {
    val selected = viewModel.selectedRecord
    if (selected != null) {
        HistoryDetail(viewModel, selected, modifier)
    } else {
        HistoryList(viewModel, modifier)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HistoryList(viewModel: SwiftyViewModel, modifier: Modifier) {
    Column(modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("이동 기록") },
            actions = {
                if (viewModel.recorder.isRecording) {
                    AssistChip(
                        onClick = viewModel::toggleRecording,
                        label = { Text("측정 중") },
                        leadingIcon = {
                            Icon(
                                Icons.Filled.FiberManualRecord,
                                contentDescription = null,
                                Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.error,
                            )
                        },
                        modifier = Modifier.padding(end = 8.dp),
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
        )
        viewModel.store.loadError?.let {
            Text(
                it,
                Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (viewModel.store.records.isEmpty()) {
            EmptyHistory(Modifier.fillMaxSize())
        } else {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(viewModel.store.records, key = { it.id }) { record ->
                    RecordCard(viewModel, record)
                }
            }
        }
    }
}

@Composable
private fun EmptyHistory(modifier: Modifier) {
    Column(
        modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Surface(
            shape = MaterialTheme.shapes.extraLarge,
            color = MaterialTheme.colorScheme.surfaceContainerHigh,
            contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
        ) {
            Icon(Icons.Outlined.History, contentDescription = null, Modifier.padding(20.dp).size(40.dp))
        }
        Spacer(Modifier.height(20.dp))
        Text("아직 이동 기록이 없습니다", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        Text(
            "계기판에서 측정을 시작해 첫 기록을 남겨보세요.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordCard(viewModel: SwiftyViewModel, record: TripRecord) {
    Card(
        onClick = { viewModel.selectRecord(record) },
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        ListItem(
            colors = ListItemDefaults.colors(containerColor = Color.Transparent),
            leadingContent = {
                Surface(shape = CircleShape, color = MaterialTheme.colorScheme.secondaryContainer) {
                    Icon(
                        record.transport.iconVector,
                        contentDescription = record.transport.title,
                        Modifier.padding(10.dp).size(22.dp),
                        tint = MaterialTheme.colorScheme.onSecondaryContainer,
                    )
                }
            },
            headlineContent = { Text(record.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            supportingContent = { Text(Fmt.recordDate(record.startedAtMillis)) },
            trailingContent = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            Fmt.distance(record.distanceMeters, viewModel.unitSystem, record.transport),
                            style = MaterialTheme.typography.titleSmall,
                        )
                        Text(
                            Fmt.elapsed(record.durationSeconds),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HistoryDetail(viewModel: SwiftyViewModel, record: TripRecord, modifier: Modifier) {
    var confirmingDelete by remember { mutableStateOf(false) }
    if (confirmingDelete) {
        AlertDialog(
            onDismissRequest = { confirmingDelete = false },
            icon = { Icon(Icons.Filled.Delete, contentDescription = null) },
            title = { Text("기록 삭제") },
            text = { Text("이 이동 기록을 삭제할까요?") },
            confirmButton = {
                TextButton(onClick = { confirmingDelete = false; viewModel.deleteRecord(record) }) {
                    Text("삭제", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { confirmingDelete = false }) { Text("취소") } },
        )
    }

    Column(modifier.fillMaxSize()) {
        TopAppBar(
            title = {
                Column {
                    Text(record.title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(
                        Fmt.recordDate(record.startedAtMillis),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            },
            navigationIcon = {
                IconButton(onClick = { viewModel.selectRecord(null) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "기록 목록")
                }
            },
            actions = {
                IconButton(onClick = { confirmingDelete = true }) {
                    Icon(Icons.Filled.Delete, contentDescription = "기록 삭제", tint = MaterialTheme.colorScheme.error)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
        )
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TripRouteMap(record)
            PanelCard(Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        MetricCell(
                            "거리",
                            Fmt.distance(record.distanceMeters, viewModel.unitSystem, record.transport),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        MetricCell("시간", Fmt.elapsed(record.durationSeconds))
                        MetricCell("이동수단", record.transport.title)
                    }
                    HorizontalDivider()
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        MetricCell(
                            "평균 속도",
                            viewModel.unitSystem.speed(record.averageSpeedMetersPerSecond).roundToInt().toString(),
                            viewModel.unitSystem.speedSymbol,
                        )
                        MetricCell(
                            "최고 속도",
                            viewModel.unitSystem.speed(record.maxSpeedMetersPerSecond).roundToInt().toString(),
                            viewModel.unitSystem.speedSymbol,
                        )
                        MetricCell("경로 점", record.samples.size.toString())
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        MetricCell(
                            "누적 상승",
                            viewModel.unitSystem.altitude(record.elevationGainMeters).roundToInt().toString(),
                            viewModel.unitSystem.altitudeSymbol,
                        )
                        MetricCell(
                            "누적 하강",
                            viewModel.unitSystem.altitude(record.elevationLossMeters).roundToInt().toString(),
                            viewModel.unitSystem.altitudeSymbol,
                        )
                        val range = record.altitudeRange
                        MetricCell(
                            "고도 범위",
                            range?.let {
                                "${viewModel.unitSystem.altitude(it.start).roundToInt()}–" +
                                    "${viewModel.unitSystem.altitude(it.endInclusive).roundToInt()}"
                            } ?: "–",
                            viewModel.unitSystem.altitudeSymbol,
                        )
                    }
                }
            }
            DataChart(
                "속도 변화",
                record.samples.map { viewModel.unitSystem.speed(it.speedMetersPerSecond) },
                MaterialTheme.colorScheme.primary,
                viewModel.unitSystem.speedSymbol,
            )
            val altitudes = record.samples.mapNotNull { it.altitudeMeters?.let(viewModel.unitSystem::altitude) }
            if (altitudes.size >= 2) {
                DataChart("고도 변화", altitudes, MaterialTheme.colorScheme.tertiary, viewModel.unitSystem.altitudeSymbol)
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun TripRouteMap(record: TripRecord) {
    val mapView = rememberMapViewWithLifecycle()
    val routeColor = MaterialTheme.colorScheme.primary.toArgb()
    Surface(
        Modifier.fillMaxWidth().height(260.dp),
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        AndroidView(
            factory = { mapView },
            modifier = Modifier.fillMaxSize(),
            update = { view ->
                view.getMapAsync { map ->
                    val apply = {
                        map.clear()
                        map.uiSettings.isAttributionEnabled = true
                        map.uiSettings.isLogoEnabled = true
                        val points = record.samples.map { it.coordinate.toLatLng() }
                        if (points.isNotEmpty()) {
                            map.addMarker(MarkerOptions().position(points.first()).title("출발"))
                            map.addMarker(MarkerOptions().position(points.last()).title("도착"))
                        }
                        if (points.size >= 2) {
                            map.addPolyline(PolylineOptions().addAll(points).color(routeColor).width(7f))
                            val bounds = LatLngBounds.Builder().also { builder -> points.forEach(builder::include) }.build()
                            map.moveCamera(CameraUpdateFactory.newLatLngBounds(bounds, 80))
                        }
                    }
                    if (map.style == null) map.setStyle(Style.Builder().fromUri(MapStyleUrl)) { apply() } else apply()
                }
            },
        )
    }
}

@Composable
private fun DataChart(title: String, values: List<Double>, color: Color, unit: String) {
    if (values.size < 2) return
    val minimum = values.min()
    val maximum = values.max()
    val baselineColor = MaterialTheme.colorScheme.outlineVariant
    PanelCard(Modifier.fillMaxWidth()) {
        Column {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, style = MaterialTheme.typography.titleSmall)
                Text(
                    "${maximum.roundToInt()} $unit",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(12.dp))
            Canvas(Modifier.fillMaxWidth().height(120.dp)) {
                val range = (maximum - minimum).takeIf { it > 0 } ?: 1.0
                val path = Path()
                values.forEachIndexed { index, value ->
                    val x = size.width * index / (values.size - 1)
                    val y = size.height - size.height * ((value - minimum) / range).toFloat()
                    if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                drawLine(baselineColor, Offset(0f, size.height), Offset(size.width, size.height), 1f)
                drawPath(path, color, style = Stroke(4f, cap = StrokeCap.Round))
            }
        }
    }
}
