package com.gutaeho.swifty.domain

import java.text.NumberFormat
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

enum class AppMode(val title: String) {
    MAP("지도"),
    GAUGE("계기판"),
    HISTORY("기록"),
}

enum class GaugeStyle(val title: String) {
    DIGITAL("디지털"),
    ANALOG("아날로그"),
}

enum class UnitSystem(
    val title: String,
    val speedSymbol: String,
    val paceSymbol: String,
    val altitudeSymbol: String,
) {
    METRIC("미터법 (km/h)", "km/h", "/km", "m"),
    IMPERIAL("야드파운드법 (mph)", "mph", "/mi", "ft");

    fun speed(metersPerSecond: Double): Double = when (this) {
        METRIC -> metersPerSecond * 3.6
        IMPERIAL -> metersPerSecond * 2.236936
    }

    fun altitude(meters: Double): Double = when (this) {
        METRIC -> meters
        IMPERIAL -> meters * 3.280840
    }
}

enum class AppearanceMode(val title: String) {
    SYSTEM("시스템"),
    LIGHT("라이트"),
    DARK("다크"),
}

enum class AccentPalette(val title: String) {
    GREEN("그린"),
    BLUE("블루"),
    TEAL("틸"),
    PURPLE("퍼플"),
    PINK("핑크"),
    ORANGE("오렌지"),
    AMBER("앰버"),
}

enum class SpeedLevel { EASY, NORMAL, FAST, LIMIT }

data class SpeedZone(
    val upperFraction: Double,
    val level: SpeedLevel,
    val label: String,
)

enum class TransportMode(
    val title: String,
    val cruiseSpeedMetersPerSecond: Double,
    val offRouteThreshold: Double,
) {
    WALKING("도보", 1.4, 40.0),
    CYCLING("자전거", 4.7, 40.0),
    CAR("자동차", 11.1, 80.0),
    SUBWAY("지하철", 16.7, 200.0),
    TRAIN("기차", 33.3, 200.0),
    AIRPLANE("비행기", 222.0, Double.MAX_VALUE);

    fun gaugeMaxSpeed(unit: UnitSystem): Double = when (this to unit) {
        WALKING to UnitSystem.METRIC -> 30.0
        WALKING to UnitSystem.IMPERIAL -> 20.0
        CYCLING to UnitSystem.METRIC -> 80.0
        CYCLING to UnitSystem.IMPERIAL -> 50.0
        CAR to UnitSystem.METRIC -> 240.0
        CAR to UnitSystem.IMPERIAL -> 160.0
        SUBWAY to UnitSystem.METRIC -> 120.0
        SUBWAY to UnitSystem.IMPERIAL -> 80.0
        TRAIN to UnitSystem.METRIC -> 360.0
        TRAIN to UnitSystem.IMPERIAL -> 220.0
        AIRPLANE to UnitSystem.METRIC -> 1000.0
        AIRPLANE to UnitSystem.IMPERIAL -> 600.0
        else -> 240.0
    }

    fun gaugeMajorStep(unit: UnitSystem): Double = when (this to unit) {
        WALKING to UnitSystem.METRIC, WALKING to UnitSystem.IMPERIAL -> 5.0
        CYCLING to UnitSystem.METRIC, CYCLING to UnitSystem.IMPERIAL -> 10.0
        CAR to UnitSystem.METRIC, CAR to UnitSystem.IMPERIAL -> 20.0
        SUBWAY to UnitSystem.METRIC -> 20.0
        SUBWAY to UnitSystem.IMPERIAL -> 10.0
        TRAIN to UnitSystem.METRIC -> 40.0
        TRAIN to UnitSystem.IMPERIAL -> 20.0
        AIRPLANE to UnitSystem.METRIC, AIRPLANE to UnitSystem.IMPERIAL -> 100.0
        else -> 20.0
    }

    val zones: List<SpeedZone>
        get() = when (this) {
            WALKING -> listOf(
                SpeedZone(.20, SpeedLevel.EASY, "걷기"),
                SpeedZone(.40, SpeedLevel.NORMAL, "조깅"),
                SpeedZone(.70, SpeedLevel.FAST, "달리기"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "질주"),
            )
            CYCLING -> listOf(
                SpeedZone(.19, SpeedLevel.EASY, "서행"),
                SpeedZone(.38, SpeedLevel.NORMAL, "순항"),
                SpeedZone(.63, SpeedLevel.FAST, "고속"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "질주"),
            )
            CAR -> listOf(
                SpeedZone(.25, SpeedLevel.EASY, "서행"),
                SpeedZone(.42, SpeedLevel.NORMAL, "정속"),
                SpeedZone(.67, SpeedLevel.FAST, "고속"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "초고속"),
            )
            SUBWAY -> listOf(
                SpeedZone(.25, SpeedLevel.EASY, "서행"),
                SpeedZone(.50, SpeedLevel.NORMAL, "정속"),
                SpeedZone(.75, SpeedLevel.FAST, "고속"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "최고"),
            )
            TRAIN -> listOf(
                SpeedZone(.22, SpeedLevel.EASY, "저속"),
                SpeedZone(.44, SpeedLevel.NORMAL, "중속"),
                SpeedZone(.72, SpeedLevel.FAST, "순항"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "고속"),
            )
            AIRPLANE -> listOf(
                SpeedZone(.10, SpeedLevel.EASY, "지상"),
                SpeedZone(.30, SpeedLevel.NORMAL, "이착륙"),
                SpeedZone(.70, SpeedLevel.FAST, "상승"),
                SpeedZone(1.0, SpeedLevel.LIMIT, "순항"),
            )
        }

    fun zone(fraction: Double): SpeedZone {
        val value = fraction.coerceIn(0.0, 1.0)
        return zones.firstOrNull { value <= it.upperFraction } ?: zones.last()
    }

    val redlineFraction: Double get() = zones[zones.lastIndex - 1].upperFraction
    val usesPace: Boolean get() = this == WALKING
    val supportsRoadRoute: Boolean get() = this == WALKING || this == CYCLING || this == CAR

    fun fineUnitLimit(unit: UnitSystem): Double = when (this to unit) {
        WALKING to UnitSystem.METRIC -> 3000.0
        WALKING to UnitSystem.IMPERIAL -> 1609.0
        CYCLING to UnitSystem.METRIC -> 2000.0
        CYCLING to UnitSystem.IMPERIAL -> 1609.0
        AIRPLANE to UnitSystem.METRIC, AIRPLANE to UnitSystem.IMPERIAL -> 0.0
        else -> 1000.0
    }

    fun coarseDecimals(value: Double): Int = when (this) {
        AIRPLANE -> 0
        else -> if (value < 100) 1 else 0
    }
}

data class Coordinate(val latitude: Double, val longitude: Double)

data class LocationFix(
    val coordinate: Coordinate,
    val timestampMillis: Long,
    val speedMetersPerSecond: Double,
    val course: Double?,
    val altitudeMeters: Double?,
    val horizontalAccuracy: Double,
    val verticalAccuracy: Double?,
    val speedAccuracy: Double?,
)

data class Destination(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val subtitle: String? = null,
    val coordinate: Coordinate,
)

enum class EstimateSource(val label: String) {
    ROUTE("도로 경로"),
    CACHED_ROUTE("저장된 경로"),
    STRAIGHT_LINE("직선 거리"),
}

data class NavigationEstimate(
    val distanceMeters: Double,
    val timeSeconds: Double,
    val source: EstimateSource,
)

data class TripSample(
    val elapsedSeconds: Double,
    val coordinate: Coordinate,
    val speedMetersPerSecond: Double,
    val altitudeMeters: Double?,
)

data class TripRecord(
    val id: String = UUID.randomUUID().toString(),
    val startedAtMillis: Long,
    val endedAtMillis: Long,
    val transport: TransportMode,
    val distanceMeters: Double,
    val maxSpeedMetersPerSecond: Double,
    val elevationGainMeters: Double,
    val elevationLossMeters: Double,
    val destinationName: String?,
    val samples: List<TripSample>,
) {
    val durationSeconds: Double get() = (endedAtMillis - startedAtMillis).coerceAtLeast(0) / 1000.0
    val averageSpeedMetersPerSecond: Double
        get() = if (durationSeconds > 1 && distanceMeters > 0) distanceMeters / durationSeconds else 0.0
    val title: String get() = destinationName?.takeIf { it.isNotBlank() } ?: "${transport.title} 기록"
    val altitudeRange: ClosedFloatingPointRange<Double>?
        get() {
            val values = samples.mapNotNull { it.altitudeMeters }
            return if (values.isEmpty()) null else values.min()..values.max()
        }
}

object Geo {
    private const val EarthRadiusMeters = 6_371_000.0

    fun distance(a: Coordinate, b: Coordinate): Double {
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val dLat = lat2 - lat1
        val dLon = Math.toRadians(b.longitude - a.longitude)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * EarthRadiusMeters * atan2(sqrt(h), sqrt(1 - h))
    }

    fun remainingAlongRoute(
        current: Coordinate,
        points: List<Coordinate>,
    ): Pair<Double, Double>? {
        if (points.size < 2) return null
        val remaining = DoubleArray(points.size)
        for (index in points.lastIndex - 1 downTo 0) {
            remaining[index] = remaining[index + 1] + distance(points[index], points[index + 1])
        }

        val latitudeScale = 111_320.0
        val longitudeScale = latitudeScale * cos(Math.toRadians(current.latitude))
        var bestDeviation = Double.MAX_VALUE
        var bestRemaining = remaining.first()

        for (index in 0 until points.lastIndex) {
            val a = points[index]
            val b = points[index + 1]
            val ax = (a.longitude - current.longitude) * longitudeScale
            val ay = (a.latitude - current.latitude) * latitudeScale
            val bx = (b.longitude - current.longitude) * longitudeScale
            val by = (b.latitude - current.latitude) * latitudeScale
            val dx = bx - ax
            val dy = by - ay
            val lengthSquared = dx * dx + dy * dy
            val fraction = if (lengthSquared > 0) (-(ax * dx + ay * dy) / lengthSquared).coerceIn(0.0, 1.0) else 0.0
            val px = ax + fraction * dx
            val py = ay + fraction * dy
            val deviation = sqrt(px * px + py * py)
            if (deviation < bestDeviation) {
                bestDeviation = deviation
                bestRemaining = remaining[index + 1] + distance(a, b) * (1 - fraction)
            }
        }
        return max(0.0, bestRemaining) to bestDeviation
    }
}

object Fmt {
    private val integerFormat = NumberFormat.getIntegerInstance(Locale.KOREA)
    private val timeFormat = DateTimeFormatter.ofPattern("a h:mm", Locale.KOREAN)
    private val dateFormat = DateTimeFormatter.ofPattern("yyyy. M. d. a h:mm", Locale.KOREAN)

    fun distance(meters: Double, unit: UnitSystem, transport: TransportMode): String {
        if (!meters.isFinite() || meters < 0) return "–"
        val fineLimit = transport.fineUnitLimit(unit)
        return when (unit) {
            UnitSystem.METRIC -> if (meters < fineLimit) {
                "${integerFormat.format(meters.roundToInt())} m"
            } else {
                decimalDistance(meters / 1000, transport.coarseDecimals(meters / 1000), "km")
            }
            UnitSystem.IMPERIAL -> if (meters < fineLimit) {
                "${integerFormat.format((meters * 3.280840).roundToInt())} ft"
            } else {
                val miles = meters / 1609.344
                decimalDistance(miles, transport.coarseDecimals(miles), "mi")
            }
        }
    }

    private fun decimalDistance(value: Double, decimals: Int, symbol: String): String =
        if (decimals > 0) String.format(Locale.US, "%.${decimals}f %s", value, symbol)
        else "${integerFormat.format(value.roundToInt())} $symbol"

    fun signedAltitude(meters: Double?, unit: UnitSystem): String {
        if (meters == null || !meters.isFinite()) return "–"
        val value = unit.altitude(meters).roundToInt()
        return when {
            value > 0 -> "+$value"
            value < 0 -> "−${abs(value)}"
            else -> "0"
        }
    }

    fun pace(speedMetersPerSecond: Double, unit: UnitSystem): String {
        if (speedMetersPerSecond <= .3) return "–"
        val metersPerUnit = if (unit == UnitSystem.METRIC) 1000.0 else 1609.344
        val secondsPerUnit = metersPerUnit / speedMetersPerSecond
        if (!secondsPerUnit.isFinite() || secondsPerUnit >= 3600) return "–"
        val total = secondsPerUnit.roundToInt()
        return String.format(Locale.US, "%d'%02d\"", total / 60, total % 60)
    }

    fun elapsed(seconds: Double): String {
        val total = max(0, seconds.toInt())
        val hours = total / 3600
        val minutes = total % 3600 / 60
        val secs = total % 60
        return if (hours > 0) String.format(Locale.US, "%d:%02d:%02d", hours, minutes, secs)
        else String.format(Locale.US, "%d:%02d", minutes, secs)
    }

    fun duration(seconds: Double): String {
        if (!seconds.isFinite() || seconds <= 0) return "–"
        val total = seconds.roundToInt()
        val hours = total / 3600
        val minutes = total % 3600 / 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}시간 ${minutes}분"
            hours > 0 -> "${hours}시간"
            minutes > 0 -> "${minutes}분"
            else -> "1분 미만"
        }
    }

    fun arrivalTime(seconds: Double): String {
        if (!seconds.isFinite() || seconds <= 0) return "–"
        return timeFormat.format(Instant.now().plusMillis((seconds * 1000).toLong()).atZone(ZoneId.systemDefault()))
    }

    fun recordDate(epochMillis: Long): String =
        dateFormat.format(Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault()))

    fun cardinal(degrees: Double?): String {
        if (degrees == null || !degrees.isFinite() || degrees < 0) return "–"
        val names = listOf("북", "북동", "동", "남동", "남", "남서", "서", "북서")
        val normalized = ((degrees % 360) + 360) % 360
        return names[(normalized / 45).roundToInt() % 8]
    }

    fun cardinalName(degrees: Double?): String = if (degrees == null) "–" else "${cardinal(degrees)}쪽"
    fun degrees(value: Double?): String = value?.takeIf { it.isFinite() && it >= 0 }?.let { "${it.roundToInt()}°" } ?: "–"
    fun coordinate(value: Coordinate): String = String.format(
        Locale.US,
        "%.4f°%s, %.4f°%s",
        abs(value.latitude), if (value.latitude >= 0) "N" else "S",
        abs(value.longitude), if (value.longitude >= 0) "E" else "W",
    )
}
