package com.gutaeho.swifty.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.Geo
import com.gutaeho.swifty.domain.LocationFix
import kotlin.math.abs
import kotlin.math.max

enum class LocationPermissionStatus { NOT_DETERMINED, GRANTED, DENIED }

class LocationTracker(
    private val context: Context,
    private val onFix: (LocationFix) -> Unit,
) : LocationListener, SensorEventListener {
    private val locationManager = context.getSystemService(LocationManager::class.java)
    private val sensorManager = context.getSystemService(SensorManager::class.java)
    private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val handler = Handler(Looper.getMainLooper())

    var permissionStatus by mutableStateOf(permissionStatus())
        private set
    var location by mutableStateOf<LocationFix?>(null)
        private set
    var speedMetersPerSecond by mutableDoubleStateOf(0.0)
        private set
    var maxSpeedMetersPerSecond by mutableDoubleStateOf(0.0)
        private set
    var tripDistanceMeters by mutableDoubleStateOf(0.0)
        private set
    var elevationGainMeters by mutableDoubleStateOf(0.0)
        private set
    var elevationLossMeters by mutableDoubleStateOf(0.0)
        private set
    var headingDegrees by mutableStateOf<Double?>(null)
        private set
    var tripStartedAtMillis by mutableLongStateOf(System.currentTimeMillis())
        private set
    var clockMillis by mutableLongStateOf(System.currentTimeMillis())
        private set
    var isRunning by mutableStateOf(false)
        private set

    private var distanceAnchor: LocationFix? = null
    private var altitudeAnchor: Double? = null
    private var lastFixAtMillis: Long? = null

    val needsAuthorization: Boolean get() = permissionStatus != LocationPermissionStatus.GRANTED
    val isSignalStale: Boolean get() = lastFixAtMillis?.let { clockMillis - it > 5_000 } ?: true
    val averageSpeedMetersPerSecond: Double
        get() {
            val elapsed = (clockMillis - tripStartedAtMillis) / 1000.0
            return if (elapsed > 10 && tripDistanceMeters > 0) tripDistanceMeters / elapsed else 0.0
        }
    val displayBearing: Double?
        get() = if (speedMetersPerSecond > .5) location?.course ?: headingDegrees else headingDegrees ?: location?.course

    private val clockTick = object : Runnable {
        override fun run() {
            clockMillis = System.currentTimeMillis()
            handler.postDelayed(this, 1_000)
        }
    }

    init {
        handler.post(clockTick)
    }

    fun refreshPermission() {
        permissionStatus = permissionStatus()
    }

    fun start() {
        refreshPermission()
        if (isRunning || permissionStatus != LocationPermissionStatus.GRANTED) return
        isRunning = true
        runCatching {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED &&
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            ) {
                locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 500L, 0f, this, Looper.getMainLooper())
            }
            if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 1_500L, 0f, this, Looper.getMainLooper())
            }
        }.onFailure { isRunning = false }
        rotationSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    fun stop() {
        if (!isRunning) return
        runCatching { locationManager.removeUpdates(this) }
        sensorManager.unregisterListener(this)
        isRunning = false
    }

    fun close() {
        stop()
        handler.removeCallbacks(clockTick)
    }

    fun resetTrip() {
        maxSpeedMetersPerSecond = 0.0
        tripDistanceMeters = 0.0
        elevationGainMeters = 0.0
        elevationLossMeters = 0.0
        tripStartedAtMillis = System.currentTimeMillis()
        distanceAnchor = location
        altitudeAnchor = null
    }

    override fun onLocationChanged(value: Location) {
        if (!value.hasAccuracy() || value.accuracy < 0 || value.accuracy >= 100) return
        val rawSpeed = if (value.hasSpeed() && value.speed >= 0) value.speed.toDouble() else 0.0
        val targetSpeed = if (rawSpeed < .5) 0.0 else rawSpeed
        val course = if (value.hasBearing() && targetSpeed > .5) value.bearing.toDouble() else null
        val verticalAccuracy = if (value.hasVerticalAccuracy()) value.verticalAccuracyMeters.toDouble() else null
        val altitude = if (value.hasAltitude() && verticalAccuracy != null && verticalAccuracy <= 15) value.altitude else null
        val fix = LocationFix(
            coordinate = Coordinate(value.latitude, value.longitude),
            timestampMillis = value.time.takeIf { it > 0 } ?: System.currentTimeMillis(),
            speedMetersPerSecond = rawSpeed,
            course = course,
            altitudeMeters = altitude,
            horizontalAccuracy = value.accuracy.toDouble(),
            verticalAccuracy = verticalAccuracy,
            speedAccuracy = if (value.hasSpeedAccuracy()) value.speedAccuracyMetersPerSecond.toDouble() else null,
        )

        accumulateDistance(fix)
        accumulateElevation(fix)
        speedMetersPerSecond += (targetSpeed - speedMetersPerSecond) * .35
        if (speedMetersPerSecond < .05) speedMetersPerSecond = 0.0
        maxSpeedMetersPerSecond = max(maxSpeedMetersPerSecond, targetSpeed)
        location = fix.copy(speedMetersPerSecond = speedMetersPerSecond)
        lastFixAtMillis = fix.timestampMillis
        clockMillis = System.currentTimeMillis()
        onFix(location!!)
    }

    private fun accumulateDistance(fix: LocationFix) {
        val anchor = distanceAnchor
        if (anchor == null) {
            distanceAnchor = fix
            return
        }
        val delta = Geo.distance(anchor.coordinate, fix.coordinate)
        val elapsed = (fix.timestampMillis - anchor.timestampMillis) / 1000.0
        if (elapsed > 0 && delta / elapsed > 111) {
            distanceAnchor = fix
            return
        }
        val noise = max((anchor.horizontalAccuracy + fix.horizontalAccuracy) / 2, 2.0)
        if (delta > noise) {
            tripDistanceMeters += delta
            distanceAnchor = fix
        }
    }

    private fun accumulateElevation(fix: LocationFix) {
        val altitude = fix.altitudeMeters ?: return
        val accuracy = fix.verticalAccuracy ?: return
        val anchor = altitudeAnchor
        if (anchor == null) {
            altitudeAnchor = altitude
            return
        }
        val delta = altitude - anchor
        if (abs(delta) <= max(accuracy, 3.0)) return
        if (delta > 0) elevationGainMeters += delta else elevationLossMeters -= delta
        altitudeAnchor = altitude
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) return
        val rotationMatrix = FloatArray(9)
        val orientation = FloatArray(3)
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        SensorManager.getOrientation(rotationMatrix, orientation)
        headingDegrees = ((Math.toDegrees(orientation[0].toDouble()) + 360) % 360)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun permissionStatus(): LocationPermissionStatus {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        return if (fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED) {
            LocationPermissionStatus.GRANTED
        } else {
            LocationPermissionStatus.NOT_DETERMINED
        }
    }
}
