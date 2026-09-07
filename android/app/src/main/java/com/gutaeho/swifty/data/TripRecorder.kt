package com.gutaeho.swifty.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.gutaeho.swifty.domain.Geo
import com.gutaeho.swifty.domain.LocationFix
import com.gutaeho.swifty.domain.TransportMode
import com.gutaeho.swifty.domain.TripRecord
import com.gutaeho.swifty.domain.TripSample
import kotlin.math.abs
import kotlin.math.max

class TripRecorder {
    var isRecording by mutableStateOf(false)
        private set
    var startedAtMillis by mutableStateOf<Long?>(null)
        private set
    var distanceMeters by mutableDoubleStateOf(0.0)
        private set
    var maxSpeedMetersPerSecond by mutableDoubleStateOf(0.0)
        private set
    var elevationGainMeters by mutableDoubleStateOf(0.0)
        private set
    var elevationLossMeters by mutableDoubleStateOf(0.0)
        private set
    var sampleCount by mutableIntStateOf(0)
        private set
    var transport by mutableStateOf(TransportMode.CAR)
        private set

    private var samples = mutableListOf<TripSample>()
    private var distanceAnchor: LocationFix? = null
    private var altitudeAnchor: Double? = null
    private var lastSampleAtMillis: Long? = null
    private var lastSampleLocation: LocationFix? = null

    val averageSpeedMetersPerSecond: Double
        get() {
            val duration = elapsedSeconds(System.currentTimeMillis())
            return if (duration > 1 && distanceMeters > 0) distanceMeters / duration else 0.0
        }

    fun elapsedSeconds(nowMillis: Long): Double = startedAtMillis?.let { (nowMillis - it).coerceAtLeast(0) / 1000.0 } ?: 0.0

    fun start(transport: TransportMode, location: LocationFix?) {
        if (isRecording) return
        isRecording = true
        startedAtMillis = System.currentTimeMillis()
        this.transport = transport
        distanceMeters = 0.0
        maxSpeedMetersPerSecond = 0.0
        elevationGainMeters = 0.0
        elevationLossMeters = 0.0
        samples.clear()
        sampleCount = 0
        distanceAnchor = location
        altitudeAnchor = null
        lastSampleAtMillis = null
        lastSampleLocation = null
        location?.let { append(it, true, it.speedMetersPerSecond) }
    }

    fun stop(destinationName: String?): TripRecord? {
        val started = startedAtMillis ?: return null
        if (!isRecording) return null
        isRecording = false
        startedAtMillis = null
        val completedSamples = samples.toList()
        samples.clear()
        if (completedSamples.size < 2) return null
        return TripRecord(
            startedAtMillis = started,
            endedAtMillis = System.currentTimeMillis(),
            transport = transport,
            distanceMeters = distanceMeters,
            maxSpeedMetersPerSecond = maxSpeedMetersPerSecond,
            elevationGainMeters = elevationGainMeters,
            elevationLossMeters = elevationLossMeters,
            destinationName = destinationName,
            samples = completedSamples,
        )
    }

    fun cancel() {
        isRecording = false
        startedAtMillis = null
        samples.clear()
        sampleCount = 0
    }

    fun ingest(location: LocationFix, smoothedSpeed: Double) {
        if (!isRecording) return
        accumulateDistance(location)
        accumulateElevation(location)
        maxSpeedMetersPerSecond = max(maxSpeedMetersPerSecond, max(location.speedMetersPerSecond, 0.0))
        append(location, false, smoothedSpeed)
    }

    private fun append(location: LocationFix, force: Boolean, speed: Double) {
        val started = startedAtMillis ?: return
        if (!force) {
            val farEnough = lastSampleLocation?.let { Geo.distance(it.coordinate, location.coordinate) >= 5 } ?: true
            val longEnough = lastSampleAtMillis?.let { location.timestampMillis - it >= 2_000 } ?: true
            if (!farEnough && !longEnough) return
        }
        samples += TripSample(
            elapsedSeconds = (location.timestampMillis - started) / 1000.0,
            coordinate = location.coordinate,
            speedMetersPerSecond = speed,
            altitudeMeters = location.altitudeMeters,
        )
        sampleCount = samples.size
        lastSampleAtMillis = location.timestampMillis
        lastSampleLocation = location
    }

    private fun accumulateDistance(location: LocationFix) {
        val anchor = distanceAnchor
        if (anchor == null) {
            distanceAnchor = location
            return
        }
        val delta = Geo.distance(anchor.coordinate, location.coordinate)
        val elapsed = (location.timestampMillis - anchor.timestampMillis) / 1000.0
        if (elapsed > 0 && delta / elapsed > 111) {
            distanceAnchor = location
            return
        }
        val noise = max((anchor.horizontalAccuracy + location.horizontalAccuracy) / 2, 2.0)
        if (delta > noise) {
            distanceMeters += delta
            distanceAnchor = location
        }
    }

    private fun accumulateElevation(location: LocationFix) {
        val altitude = location.altitudeMeters ?: return
        val accuracy = location.verticalAccuracy ?: return
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
}
