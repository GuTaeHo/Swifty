package com.gutaeho.swifty.data

import android.content.Context
import androidx.core.content.edit
import com.gutaeho.swifty.domain.AccentPalette
import com.gutaeho.swifty.domain.AppMode
import com.gutaeho.swifty.domain.AppearanceMode
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.Destination
import com.gutaeho.swifty.domain.GaugeStyle
import com.gutaeho.swifty.domain.TransportMode
import com.gutaeho.swifty.domain.UnitSystem
import org.json.JSONObject
import java.util.Locale

class AppPreferences(context: Context) {
    private val store = context.getSharedPreferences("swifty.settings", Context.MODE_PRIVATE)

    var mode: AppMode
        get() = enumValue("mode", AppMode.GAUGE)
        set(value) = put("mode", value.name)

    var gaugeStyle: GaugeStyle
        get() = enumValue("gaugeStyle", GaugeStyle.ANALOG)
        set(value) = put("gaugeStyle", value.name)

    var unitSystem: UnitSystem
        get() = if (store.contains("unitSystem")) enumValue("unitSystem", UnitSystem.METRIC)
        else if (Locale.getDefault().country in setOf("US", "LR", "MM")) UnitSystem.IMPERIAL else UnitSystem.METRIC
        set(value) = put("unitSystem", value.name)

    var transport: TransportMode
        get() = enumValue("transport", TransportMode.CAR)
        set(value) = put("transport", value.name)

    var appearance: AppearanceMode
        get() = enumValue("appearance", AppearanceMode.SYSTEM)
        set(value) = put("appearance", value.name)

    var accent: AccentPalette
        get() = enumValue("accent", AccentPalette.GREEN)
        set(value) = put("accent", value.name)

    var dynamicColor: Boolean
        get() = store.getBoolean("dynamicColor", false)
        set(value) = put("dynamicColor", value)

    var showsElevationMetrics: Boolean
        get() = store.getBoolean("elevationMetrics", false)
        set(value) = put("elevationMetrics", value)

    var hapticsEnabled: Boolean
        get() = store.getBoolean("haptics", true)
        set(value) = put("haptics", value)

    var keepScreenAwake: Boolean
        get() = store.getBoolean("keepAwake", true)
        set(value) = put("keepAwake", value)

    var destination: Destination?
        get() = store.getString("destination", null)?.let { encoded ->
            runCatching {
                val json = JSONObject(encoded)
                Destination(
                    id = json.getString("id"),
                    name = json.getString("name"),
                    subtitle = json.optString("subtitle").takeIf { it.isNotBlank() },
                    coordinate = Coordinate(json.getDouble("lat"), json.getDouble("lon")),
                )
            }.getOrNull()
        }
        set(value) {
            if (value == null) {
                store.edit { remove("destination") }
            } else {
                val json = JSONObject()
                    .put("id", value.id)
                    .put("name", value.name)
                    .put("subtitle", value.subtitle.orEmpty())
                    .put("lat", value.coordinate.latitude)
                    .put("lon", value.coordinate.longitude)
                put("destination", json.toString())
            }
        }

    private inline fun <reified T : Enum<T>> enumValue(key: String, fallback: T): T =
        store.getString(key, null)?.let { runCatching { enumValueOf<T>(it) }.getOrNull() } ?: fallback

    private fun put(key: String, value: String) = store.edit { putString(key, value) }
    private fun put(key: String, value: Boolean) = store.edit { putBoolean(key, value) }
}
