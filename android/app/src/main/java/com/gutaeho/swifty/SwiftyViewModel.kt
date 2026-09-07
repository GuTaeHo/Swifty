package com.gutaeho.swifty

import android.app.Application
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.gutaeho.swifty.data.AppPreferences
import com.gutaeho.swifty.data.TripRecorder
import com.gutaeho.swifty.data.TripStore
import com.gutaeho.swifty.domain.AccentPalette
import com.gutaeho.swifty.domain.AppMode
import com.gutaeho.swifty.domain.AppearanceMode
import com.gutaeho.swifty.domain.Destination
import com.gutaeho.swifty.domain.GaugeStyle
import com.gutaeho.swifty.domain.LocationFix
import com.gutaeho.swifty.domain.SpeedLevel
import com.gutaeho.swifty.domain.TransportMode
import com.gutaeho.swifty.domain.TripRecord
import com.gutaeho.swifty.domain.UnitSystem
import com.gutaeho.swifty.location.LocationTracker
import com.gutaeho.swifty.location.NetworkMonitor
import com.gutaeho.swifty.navigation.NavigationService
import com.gutaeho.swifty.navigation.PlaceSearchService
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class SwiftyViewModel(application: Application) : AndroidViewModel(application) {
    private val preferences = AppPreferences(application)
    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        application.getSystemService(VibratorManager::class.java).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        application.getSystemService(Vibrator::class.java)
    }

    val recorder = TripRecorder()
    val store = TripStore(application)
    val network = NetworkMonitor(application)
    val navigation = NavigationService(preferences, viewModelScope)
    val previewNavigation = NavigationService(preferences, viewModelScope, restoresPersistedDestination = false)
    val search = PlaceSearchService(application, viewModelScope)
    val location = LocationTracker(application, ::handleLocationFix)

    var mode by mutableStateOf(preferences.mode)
        private set
    var gaugeStyle by mutableStateOf(preferences.gaugeStyle)
        private set
    var unitSystem by mutableStateOf(preferences.unitSystem)
        private set
    var transport by mutableStateOf(preferences.transport)
        private set
    var appearance by mutableStateOf(preferences.appearance)
        private set
    var accent by mutableStateOf(preferences.accent)
        private set
    var dynamicColor by mutableStateOf(preferences.dynamicColor)
        private set
    var showsElevationMetrics by mutableStateOf(preferences.showsElevationMetrics)
        private set
    var hapticsEnabled by mutableStateOf(preferences.hapticsEnabled)
        private set
    var keepScreenAwake by mutableStateOf(preferences.keepScreenAwake)
        private set
    var locationPermissionDenied by mutableStateOf(false)
        private set
    var selectedRecord by mutableStateOf<TripRecord?>(null)
        private set
    var savedRecordNotice by mutableStateOf<String?>(null)
        private set

    private var currentSpeedLevel = SpeedLevel.EASY

    init {
        navigation.updateTransport(transport, location.location, network.isOnline)
        previewNavigation.updateTransport(transport, location.location, network.isOnline)
    }

    private fun handleLocationFix(fix: LocationFix) {
        recorder.ingest(fix, fix.speedMetersPerSecond)
        navigation.update(fix, fix.speedMetersPerSecond, network.isOnline)
        previewNavigation.update(fix, fix.speedMetersPerSecond, network.isOnline)
        updateSpeedZone()
    }

    fun chooseMode(value: AppMode) {
        if (mode == AppMode.MAP && value != AppMode.MAP) previewNavigation.clearDestination()
        mode = value
        preferences.mode = value
        selectionHaptic()
    }

    fun chooseGaugeStyle(value: GaugeStyle) {
        gaugeStyle = value
        preferences.gaugeStyle = value
        selectionHaptic()
    }

    fun chooseUnitSystem(value: UnitSystem) {
        unitSystem = value
        preferences.unitSystem = value
        updateSpeedZone()
    }

    fun chooseTransport(value: TransportMode) {
        transport = value
        preferences.transport = value
        navigation.updateTransport(value, location.location, network.isOnline)
        previewNavigation.updateTransport(value, location.location, network.isOnline)
        updateSpeedZone()
        selectionHaptic()
    }

    fun chooseAppearance(value: AppearanceMode) {
        appearance = value
        preferences.appearance = value
    }

    fun chooseAccent(value: AccentPalette) {
        accent = value
        preferences.accent = value
        selectionHaptic()
    }

    fun updateDynamicColor(value: Boolean) {
        dynamicColor = value
        preferences.dynamicColor = value
        selectionHaptic()
    }

    fun setShowsElevation(value: Boolean) {
        showsElevationMetrics = value
        preferences.showsElevationMetrics = value
        lightHaptic()
    }

    fun updateHapticsEnabled(value: Boolean) {
        hapticsEnabled = value
        preferences.hapticsEnabled = value
        if (value) lightHaptic()
    }

    fun updateKeepScreenAwake(value: Boolean) {
        keepScreenAwake = value
        preferences.keepScreenAwake = value
    }

    fun onPermissionResult(granted: Boolean) {
        locationPermissionDenied = !granted
        location.refreshPermission()
        if (granted) location.start()
    }

    fun onResume() {
        location.refreshPermission()
        if (!location.needsAuthorization) {
            locationPermissionDenied = false
            location.start()
        }
    }

    fun onPause() = location.stop()

    fun refreshNavigation() {
        navigation.update(location.location, location.speedMetersPerSecond, network.isOnline)
        previewNavigation.update(location.location, location.speedMetersPerSecond, network.isOnline)
    }

    fun previewDestination(value: Destination) {
        previewNavigation.applyDestination(value, location.location, network.isOnline)
        lightHaptic()
    }

    fun confirmPreview() {
        val value = previewNavigation.destination ?: return
        navigation.applyDestination(value, location.location, network.isOnline)
        previewNavigation.clearDestination()
        successHaptic()
    }

    fun cancelPreview() {
        if (!previewNavigation.hasDestination) return
        previewNavigation.clearDestination()
        lightHaptic()
    }

    fun clearDestination() {
        navigation.clearDestination()
        lightHaptic()
    }

    fun toggleRecording() {
        if (recorder.isRecording) {
            val saved = recorder.stop(navigation.destination?.name)
            if (saved != null) {
                store.add(saved)
                successHaptic()
                showNotice("기록을 저장했습니다 · ${com.gutaeho.swifty.domain.Fmt.elapsed(saved.durationSeconds)}")
            } else {
                warningHaptic()
                showNotice("움직인 거리가 없어 저장하지 않았습니다.")
            }
        } else {
            mediumHaptic()
            recorder.start(transport, location.location)
        }
    }

    fun selectRecord(record: TripRecord?) {
        selectedRecord = record
    }

    fun deleteRecord(record: TripRecord) {
        store.delete(record)
        if (selectedRecord?.id == record.id) selectedRecord = null
        lightHaptic()
    }

    fun lightHaptic() = vibrate(18, 90)
    private fun selectionHaptic() = vibrate(12, 55)
    private fun mediumHaptic() = vibrate(35, 150)
    private fun successHaptic() = vibrate(45, 180)
    private fun warningHaptic() = vibrate(80, 230)

    private fun updateSpeedZone() {
        val speed = unitSystem.speed(location.speedMetersPerSecond)
        val maximum = transport.gaugeMaxSpeed(unitSystem)
        val level = transport.zone(if (maximum > 0) speed / maximum else 0.0).level
        if (level != currentSpeedLevel) {
            val intensity = if (level.ordinal > currentSpeedLevel.ordinal) 160 + level.ordinal * 25 else 80
            vibrate(22, intensity)
            currentSpeedLevel = level
        }
    }

    private fun showNotice(text: String) {
        savedRecordNotice = text
        viewModelScope.launch {
            delay(3_000)
            if (savedRecordNotice == text) savedRecordNotice = null
        }
    }

    private fun vibrate(durationMillis: Long, amplitude: Int) {
        if (!hapticsEnabled || !vibrator.hasVibrator()) return
        vibrator.vibrate(VibrationEffect.createOneShot(durationMillis, amplitude.coerceIn(1, 255)))
    }

    override fun onCleared() {
        location.close()
        network.close()
        super.onCleared()
    }
}
