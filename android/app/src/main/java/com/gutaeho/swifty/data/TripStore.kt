package com.gutaeho.swifty.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.gutaeho.swifty.domain.Coordinate
import com.gutaeho.swifty.domain.TransportMode
import com.gutaeho.swifty.domain.TripRecord
import com.gutaeho.swifty.domain.TripSample
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class TripStore(context: Context) {
    private val directory = File(context.filesDir, "Trips")

    var records by mutableStateOf<List<TripRecord>>(emptyList())
        private set
    var loadError by mutableStateOf<String?>(null)
        private set

    init {
        load()
    }

    fun load() {
        runCatching {
            directory.mkdirs()
            records = directory.listFiles { file -> file.extension == "json" }
                .orEmpty()
                .mapNotNull { file -> runCatching { decode(file.readText()) }.getOrNull() }
                .sortedByDescending { it.startedAtMillis }
            loadError = null
        }.onFailure {
            records = emptyList()
            loadError = "기록을 불러오지 못했습니다."
        }
    }

    fun add(record: TripRecord) {
        records = listOf(record) + records
        runCatching {
            directory.mkdirs()
            File(directory, "${record.id}.json").writeText(encode(record).toString())
        }
    }

    fun delete(record: TripRecord) {
        records = records.filterNot { it.id == record.id }
        runCatching { File(directory, "${record.id}.json").delete() }
    }

    private fun encode(record: TripRecord): JSONObject = JSONObject()
        .put("id", record.id)
        .put("startedAt", record.startedAtMillis)
        .put("endedAt", record.endedAtMillis)
        .put("transport", record.transport.name)
        .put("distance", record.distanceMeters)
        .put("maxSpeed", record.maxSpeedMetersPerSecond)
        .put("elevationGain", record.elevationGainMeters)
        .put("elevationLoss", record.elevationLossMeters)
        .put("destinationName", record.destinationName.orEmpty())
        .put("samples", JSONArray().apply {
            record.samples.forEach { sample ->
                put(
                    JSONObject()
                        .put("t", sample.elapsedSeconds)
                        .put("lat", sample.coordinate.latitude)
                        .put("lon", sample.coordinate.longitude)
                        .put("speed", sample.speedMetersPerSecond)
                        .put("altitude", sample.altitudeMeters ?: JSONObject.NULL),
                )
            }
        })

    private fun decode(encoded: String): TripRecord {
        val json = JSONObject(encoded)
        val samplesJson = json.getJSONArray("samples")
        val samples = buildList {
            repeat(samplesJson.length()) { index ->
                val item = samplesJson.getJSONObject(index)
                add(
                    TripSample(
                        elapsedSeconds = item.getDouble("t"),
                        coordinate = Coordinate(item.getDouble("lat"), item.getDouble("lon")),
                        speedMetersPerSecond = item.getDouble("speed"),
                        altitudeMeters = if (item.isNull("altitude")) null else item.getDouble("altitude"),
                    ),
                )
            }
        }
        return TripRecord(
            id = json.getString("id"),
            startedAtMillis = json.getLong("startedAt"),
            endedAtMillis = json.getLong("endedAt"),
            transport = runCatching { TransportMode.valueOf(json.getString("transport")) }.getOrDefault(TransportMode.CAR),
            distanceMeters = json.getDouble("distance"),
            maxSpeedMetersPerSecond = json.getDouble("maxSpeed"),
            elevationGainMeters = json.optDouble("elevationGain", 0.0),
            elevationLossMeters = json.optDouble("elevationLoss", 0.0),
            destinationName = json.optString("destinationName").takeIf { it.isNotBlank() },
            samples = samples,
        )
    }
}
