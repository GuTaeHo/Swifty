package com.gutaeho.swifty.navigation

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.gutaeho.swifty.data.AppPreferences
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.Destination
import com.gutaeho.swifty.domain.EstimateSource
import com.gutaeho.swifty.domain.Geo
import com.gutaeho.swifty.domain.LocationFix
import com.gutaeho.swifty.domain.NavigationEstimate
import com.gutaeho.swifty.domain.TransportMode
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class NavigationService(
    private val preferences: AppPreferences,
    private val scope: CoroutineScope,
    private val restoresPersistedDestination: Boolean = true,
) {
    var destination by mutableStateOf(if (restoresPersistedDestination) preferences.destination else null)
        private set
    var routePoints by mutableStateOf<List<Coordinate>>(emptyList())
        private set
    var estimate by mutableStateOf<NavigationEstimate?>(null)
        private set
    var isCalculatingRoute by mutableStateOf(false)
        private set
    var routeErrorMessage by mutableStateOf<String?>(null)
        private set
    var legStartAltitude by mutableStateOf<Double?>(null)
        private set
    var elevationChange by mutableStateOf<Double?>(null)
        private set
    var transport by mutableStateOf(TransportMode.CAR)
        private set

    private var routeTotalDistance = 0.0
    private var routeTotalTime = 0.0
    private var lastRouteOrigin: Coordinate? = null
    private var lastRouteAtMillis: Long? = null
    private var routeJob: Job? = null
    private var routeRequestGeneration = 0L

    val hasDestination: Boolean get() = destination != null

    fun updateTransport(value: TransportMode, origin: LocationFix?, online: Boolean) {
        if (transport == value) return
        transport = value
        clearRoute()
        routeErrorMessage = null
        update(origin, 0.0, online)
    }

    fun applyDestination(value: Destination, origin: LocationFix?, online: Boolean) {
        clearRoute()
        destination = value
        if (restoresPersistedDestination) preferences.destination = value
        legStartAltitude = null
        elevationChange = null
        routeErrorMessage = null
        update(origin, 0.0, online)
        if (online && transport.supportsRoadRoute && origin != null) requestRoute(origin, true)
    }

    fun clearDestination() {
        clearRoute()
        destination = null
        if (restoresPersistedDestination) preferences.destination = null
        estimate = null
        legStartAltitude = null
        elevationChange = null
        routeErrorMessage = null
    }

    fun update(origin: LocationFix?, speedMetersPerSecond: Double, online: Boolean) {
        val target = destination
        if (target == null || origin == null) {
            estimate = null
            return
        }
        updateElevation(origin)

        val alongRoute = Geo.remainingAlongRoute(origin.coordinate, routePoints)
        if (alongRoute != null) {
            val (remaining, deviation) = alongRoute
            val fraction = if (routeTotalDistance > 0) remaining / routeTotalDistance else 0.0
            estimate = NavigationEstimate(
                remaining,
                timeEstimate(remaining, routeTotalTime * fraction, speedMetersPerSecond),
                if (online) EstimateSource.ROUTE else EstimateSource.CACHED_ROUTE,
            )
            if (online && deviation > transport.offRouteThreshold) {
                requestRoute(origin, true)
                return
            }
        } else {
            val straight = Geo.distance(origin.coordinate, target.coordinate)
            estimate = NavigationEstimate(
                straight,
                timeEstimate(straight, null, speedMetersPerSecond),
                EstimateSource.STRAIGHT_LINE,
            )
        }

        if (online && transport.supportsRoadRoute) requestRoute(origin, false)
    }

    private fun updateElevation(origin: LocationFix) {
        val altitude = origin.altitudeMeters ?: return
        if ((origin.verticalAccuracy ?: Double.MAX_VALUE) > 15) return
        val start = legStartAltitude
        if (start == null) {
            legStartAltitude = altitude
            elevationChange = 0.0
        } else {
            elevationChange = altitude - start
        }
    }

    private fun timeEstimate(distance: Double, routeTime: Double?, speed: Double): Double {
        if (routeTime != null && routeTime > 0) {
            if (speed <= 1) return routeTime
            return routeTime * .7 + distance / speed * .3
        }
        return distance / if (speed > 1) speed else transport.cruiseSpeedMetersPerSecond
    }

    private fun requestRoute(origin: LocationFix, force: Boolean) {
        val target = destination ?: return
        if (!transport.supportsRoadRoute || routeJob != null || !shouldRecalculate(origin.coordinate, force)) return
        lastRouteOrigin = origin.coordinate
        lastRouteAtMillis = System.currentTimeMillis()
        isCalculatingRoute = true
        val requestId = ++routeRequestGeneration
        val targetId = target.id
        routeJob = scope.launch {
            try {
                val result = withContext(Dispatchers.IO) { fetchRoute(origin.coordinate, target.coordinate) }
                if (requestId != routeRequestGeneration || destination?.id != targetId) return@launch
                routePoints = result.points
                routeTotalDistance = result.distance
                routeTotalTime = result.duration
                routeErrorMessage = null
                update(origin, origin.speedMetersPerSecond, true)
            } catch (_: CancellationException) {
                return@launch
            } catch (_: Exception) {
                if (requestId == routeRequestGeneration && destination?.id == targetId && routePoints.isEmpty()) {
                    routeErrorMessage = "${transport.title} 경로를 계산할 수 없습니다. 직선 거리로 표시합니다."
                }
            } finally {
                if (requestId == routeRequestGeneration) {
                    isCalculatingRoute = false
                    routeJob = null
                }
            }
        }
    }

    private fun shouldRecalculate(origin: Coordinate, force: Boolean): Boolean {
        if (force) return true
        val lastTime = lastRouteAtMillis ?: return true
        val elapsed = System.currentTimeMillis() - lastTime
        if (routePoints.isEmpty()) return elapsed > 10_000
        if (elapsed < 8_000) return false
        val lastOrigin = lastRouteOrigin ?: return true
        return Geo.distance(lastOrigin, origin) > 300 || elapsed > 25_000
    }

    private data class RouteResult(val points: List<Coordinate>, val distance: Double, val duration: Double)

    private fun fetchRoute(origin: Coordinate, target: Coordinate): RouteResult {
        val address = "https://router.project-osrm.org/route/v1/driving/" +
            "${origin.longitude},${origin.latitude};${target.longitude},${target.latitude}" +
            "?overview=full&geometries=geojson&alternatives=false&steps=false"
        val connection = URL(address).openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = 8_000
            connection.readTimeout = 10_000
            connection.setRequestProperty("User-Agent", "Swifty-Android/1.0")
            if (connection.responseCode !in 200..299) error("Routing HTTP ${connection.responseCode}")
            val root = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
            if (root.optString("code") != "Ok") error("No route")
            val route = root.getJSONArray("routes").getJSONObject(0)
            val coordinates = route.getJSONObject("geometry").getJSONArray("coordinates")
            val points = buildList {
                repeat(coordinates.length()) { index ->
                    val item = coordinates.getJSONArray(index)
                    add(Coordinate(item.getDouble(1), item.getDouble(0)))
                }
            }
            RouteResult(points, route.getDouble("distance"), route.getDouble("duration"))
        } finally {
            connection.disconnect()
        }
    }

    private fun clearRoute() {
        routeRequestGeneration += 1
        routeJob?.cancel()
        routeJob = null
        routePoints = emptyList()
        routeTotalDistance = 0.0
        routeTotalTime = 0.0
        lastRouteOrigin = null
        lastRouteAtMillis = null
        isCalculatingRoute = false
    }
}
