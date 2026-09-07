package com.gutaeho.swifty.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GpsOff
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.ZoomOutMap
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.gutaeho.swifty.SwiftyViewModel
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.Destination
import com.gutaeho.swifty.domain.Fmt
import com.gutaeho.swifty.domain.Geo
import com.gutaeho.swifty.navigation.NavigationService
import com.gutaeho.swifty.ui.components.DestinationSummary
import com.gutaeho.swifty.ui.components.LocationGate
import com.gutaeho.swifty.ui.components.SettingsSheet
import com.gutaeho.swifty.ui.components.StatusBanner
import com.gutaeho.swifty.ui.components.iconVector
import org.maplibre.android.annotations.MarkerOptions
import org.maplibre.android.annotations.PolylineOptions
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style

internal const val MapStyleUrl = "https://tiles.openfreemap.org/styles/liberty"

@Composable
fun MapScreen(
    viewModel: SwiftyViewModel,
    onRequestPermission: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var showingSettings by remember { mutableStateOf(false) }
    var showingSearch by remember { mutableStateOf(false) }
    if (showingSettings) SettingsSheet(viewModel) { showingSettings = false }
    if (showingSearch) DestinationSearchSheet(viewModel) { showingSearch = false }

    if (viewModel.location.needsAuthorization) {
        LocationGate(
            viewModel.location.permissionStatus,
            viewModel.locationPermissionDenied,
            onRequestPermission,
            onOpenSettings,
            modifier.fillMaxSize(),
        )
        return
    }

    val mapView = rememberMapViewWithLifecycle()
    var didCenter by remember { mutableStateOf(false) }
    val routeColor = MaterialTheme.colorScheme.primary.toArgb()
    val displayedNavigation = if (viewModel.previewNavigation.hasDestination) {
        viewModel.previewNavigation
    } else {
        viewModel.navigation
    }
    val previewPoint: (LatLng) -> Unit = remember(viewModel) {
        { point -> viewModel.previewDestination(destinationAt(point)) }
    }
    val clickListener = remember(viewModel) {
        MapLibreMap.OnMapClickListener { point ->
            previewPoint(point)
            true
        }
    }
    val longClickListener = remember(viewModel) {
        MapLibreMap.OnMapLongClickListener { point ->
            previewPoint(point)
            true
        }
    }

    LaunchedEffect(displayedNavigation.destination?.id) {
        if (displayedNavigation.hasDestination) frameRoute(mapView, viewModel, displayedNavigation)
    }

    Box(modifier.fillMaxSize()) {
        AndroidView(
            factory = { mapView },
            modifier = Modifier.fillMaxSize(),
            update = { view ->
                view.getMapAsync { map ->
                    val applyContent = {
                        map.clear()
                        map.uiSettings.isCompassEnabled = true
                        map.uiSettings.isAttributionEnabled = true
                        map.uiSettings.isLogoEnabled = true
                        val here = viewModel.location.location?.coordinate
                        if (here != null) {
                            map.addMarker(MarkerOptions().position(here.toLatLng()).title("현재 위치"))
                            if (!didCenter) {
                                map.animateCamera(CameraUpdateFactory.newLatLngZoom(here.toLatLng(), 15.0))
                                didCenter = true
                            }
                        }
                        displayedNavigation.destination?.let { target ->
                            map.addMarker(
                                MarkerOptions().position(target.coordinate.toLatLng())
                                    .title(target.name)
                                    .snippet(target.subtitle),
                            )
                        }
                        if (displayedNavigation.routePoints.size >= 2) {
                            map.addPolyline(
                                PolylineOptions()
                                    .addAll(displayedNavigation.routePoints.map(Coordinate::toLatLng))
                                    .color(routeColor)
                                    .width(7f),
                            )
                        }
                        map.removeOnMapClickListener(clickListener)
                        map.addOnMapClickListener(clickListener)
                        map.removeOnMapLongClickListener(longClickListener)
                        map.addOnMapLongClickListener(longClickListener)
                    }
                    if (map.style == null) map.setStyle(Style.Builder().fromUri(MapStyleUrl)) { applyContent() }
                    else applyContent()
                }
            },
        )

        Column(
            Modifier.align(Alignment.TopCenter).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            MapSearchBar(
                enabled = viewModel.network.isOnline,
                onSettings = { showingSettings = true },
                onSearch = { showingSearch = true },
            )
            if (viewModel.location.isSignalStale) {
                StatusBanner(
                    "GPS 신호를 기다리는 중입니다.",
                    Icons.Filled.GpsOff,
                    container = MaterialTheme.colorScheme.errorContainer,
                    onContainer = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
            if (!viewModel.network.isOnline) {
                StatusBanner(
                    "오프라인 · 저장된 지도와 경로를 사용합니다.",
                    Icons.Filled.WifiOff,
                    container = MaterialTheme.colorScheme.errorContainer,
                    onContainer = MaterialTheme.colorScheme.onErrorContainer,
                )
            }
            if (!displayedNavigation.hasDestination) {
                StatusBanner("지도를 눌러 경로를 확인한 뒤 목적지를 확정하세요.", Icons.Filled.TouchApp)
            }
        }

        Column(
            Modifier.align(Alignment.CenterEnd).padding(end = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SmallFloatingActionButton(
                onClick = {
                    viewModel.location.location?.coordinate?.let { coordinate ->
                        mapView.getMapAsync { map ->
                            map.animateCamera(CameraUpdateFactory.newLatLngZoom(coordinate.toLatLng(), 15.0))
                        }
                    }
                },
                containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                contentColor = MaterialTheme.colorScheme.primary,
            ) {
                Icon(Icons.Filled.MyLocation, contentDescription = "현재 위치로 이동")
            }
            if (displayedNavigation.hasDestination) {
                SmallFloatingActionButton(
                    onClick = { frameRoute(mapView, viewModel, displayedNavigation) },
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                    contentColor = MaterialTheme.colorScheme.primary,
                ) {
                    Icon(Icons.Filled.ZoomOutMap, contentDescription = "경로 전체 보기")
                }
            }
        }

        Column(
            Modifier.align(Alignment.BottomCenter).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Surface(
                shape = MaterialTheme.shapes.small,
                color = MaterialTheme.colorScheme.surfaceContainer,
                contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
            ) {
                Text(
                    "© OpenStreetMap contributors",
                    Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            if (displayedNavigation.hasDestination) {
                val isPreviewing = viewModel.previewNavigation.hasDestination
                DestinationSummary(
                    viewModel = viewModel,
                    modifier = Modifier.fillMaxWidth(),
                    navigation = displayedNavigation,
                    onConfirm = if (isPreviewing) viewModel::confirmPreview else null,
                    onClear = if (isPreviewing) viewModel::cancelPreview else viewModel::clearDestination,
                )
            }
            SpeedPill(viewModel)
        }
    }
}

/** Docked search bar in the Material 3 style, holding the settings and search entry points. */
@Composable
private fun MapSearchBar(enabled: Boolean, onSettings: () -> Unit, onSearch: () -> Unit) {
    Surface(
        Modifier.fillMaxWidth(),
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        shadowElevation = 3.dp,
    ) {
        Row(
            Modifier.padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onSettings) {
                Icon(Icons.Filled.Settings, contentDescription = "설정")
            }
            Text(
                if (enabled) "목적지 검색" else "오프라인 · 검색 불가",
                Modifier
                    .weight(1f)
                    .clickable(enabled = enabled, onClick = onSearch)
                    .padding(vertical = 14.dp),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            FilledIconButton(
                onClick = onSearch,
                enabled = enabled,
                modifier = Modifier.padding(4.dp),
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
            ) {
                Icon(Icons.Filled.Search, contentDescription = "목적지 검색")
            }
        }
    }
}

@Composable
private fun SpeedPill(viewModel: SwiftyViewModel) {
    Surface(
        Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.large,
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        contentColor = MaterialTheme.colorScheme.onSurface,
        shadowElevation = 3.dp,
    ) {
        Row(
            Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                viewModel.unitSystem.speed(viewModel.location.speedMetersPerSecond).toInt().toString(),
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                viewModel.unitSystem.speedSymbol,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.weight(1f))
            Icon(
                viewModel.transport.iconVector,
                contentDescription = viewModel.transport.title,
                Modifier.size(22.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Icon(
                Icons.Filled.Navigation,
                contentDescription = null,
                Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Column {
                Text(Fmt.cardinal(viewModel.location.displayBearing), style = MaterialTheme.typography.titleSmall)
                Text(
                    Fmt.degrees(viewModel.location.displayBearing),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DestinationSearchSheet(viewModel: SwiftyViewModel, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = { viewModel.search.reset(); onDismiss() }) {
        Column(Modifier.fillMaxWidth().height(540.dp)) {
            Text(
                "목적지 검색",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(horizontal = 24.dp),
            )
            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = viewModel.search.query,
                onValueChange = { viewModel.search.query = it },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                label = { Text("장소, 주소") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                trailingIcon = {
                    if (viewModel.search.query.isNotEmpty()) {
                        IconButton(onClick = { viewModel.search.query = "" }) {
                            Icon(Icons.Filled.Close, contentDescription = "검색어 지우기")
                        }
                    }
                },
                shape = CircleShape,
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { viewModel.search.search() }),
            )
            Spacer(Modifier.height(8.dp))
            if (viewModel.search.isSearching) {
                Box(Modifier.fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            viewModel.search.errorMessage?.let {
                Text(
                    it,
                    Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            if (viewModel.search.results.isEmpty() && !viewModel.search.isSearching && viewModel.search.errorMessage == null) {
                Text(
                    "장소 이름이나 주소를 검색하세요.\n지도를 눌러 직접 선택할 수도 있습니다.",
                    Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 32.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                items(viewModel.search.results, key = { it.id }) { result ->
                    ListItem(
                        modifier = Modifier.clickable {
                            viewModel.previewDestination(result)
                            viewModel.search.reset()
                            onDismiss()
                        },
                        leadingContent = {
                            Icon(
                                Icons.Filled.Place,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        },
                        headlineContent = { Text(result.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        supportingContent = result.subtitle?.let {
                            { Text(it, maxLines = 1, overflow = TextOverflow.Ellipsis) }
                        },
                        trailingContent = viewModel.location.location?.let { here ->
                            {
                                Text(
                                    Fmt.distance(
                                        Geo.distance(here.coordinate, result.coordinate),
                                        viewModel.unitSystem,
                                        viewModel.transport,
                                    ),
                                    style = MaterialTheme.typography.labelLarge,
                                )
                            }
                        },
                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
internal fun rememberMapViewWithLifecycle(): MapView {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val mapView = remember { MapView(context).apply { onCreate(null) } }
    DisposableEffect(lifecycle, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                Lifecycle.Event.ON_DESTROY -> mapView.onDestroy()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }
    return mapView
}

internal fun Coordinate.toLatLng() = LatLng(latitude, longitude)

private fun destinationAt(point: LatLng) = Destination(
    name = "목적지",
    subtitle = Fmt.coordinate(Coordinate(point.latitude, point.longitude)),
    coordinate = Coordinate(point.latitude, point.longitude),
)

private fun frameRoute(mapView: MapView, viewModel: SwiftyViewModel, navigation: NavigationService) {
    val points = navigation.routePoints.ifEmpty {
        listOfNotNull(viewModel.location.location?.coordinate, navigation.destination?.coordinate)
    }
    if (points.size < 2) return
    mapView.getMapAsync { map ->
        val builder = LatLngBounds.Builder()
        points.forEach { builder.include(it.toLatLng()) }
        map.animateCamera(CameraUpdateFactory.newLatLngBounds(builder.build(), 100))
    }
}
