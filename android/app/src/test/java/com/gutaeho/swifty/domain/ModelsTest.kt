package com.gutaeho.swifty.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelsTest {
    @Test
    fun distanceMatchesKnownLatitudeDifference() {
        val distance = Geo.distance(Coordinate(37.0, 127.0), Coordinate(37.001, 127.0))
        assertEquals(111.2, distance, 1.0)
    }

    @Test
    fun remainingRouteProjectsCurrentPositionOntoSegment() {
        val route = listOf(
            Coordinate(37.0, 127.0),
            Coordinate(37.001, 127.0),
            Coordinate(37.002, 127.0),
        )
        val result = Geo.remainingAlongRoute(Coordinate(37.0005, 127.0001), route)
        requireNotNull(result)
        assertEquals(166.8, result.first, 2.0)
        assertTrue(result.second in 7.0..11.0)
    }

    @Test
    fun transportZonesAndUnitConversionsMatchIosRules() {
        assertEquals(240.0, TransportMode.CAR.gaugeMaxSpeed(UnitSystem.METRIC), 0.0)
        assertEquals(160.0, TransportMode.CAR.gaugeMaxSpeed(UnitSystem.IMPERIAL), 0.0)
        assertEquals(SpeedLevel.LIMIT, TransportMode.WALKING.zone(.9).level)
        assertEquals(36.0, UnitSystem.METRIC.speed(10.0), .0001)
        assertEquals(22.36936, UnitSystem.IMPERIAL.speed(10.0), .0001)
    }

    @Test
    fun formattingHandlesPaceDurationAndDistance() {
        assertEquals("5'00\"", Fmt.pace(1000.0 / 300.0, UnitSystem.METRIC))
        assertEquals("1:01:01", Fmt.elapsed(3661.0))
        assertEquals("1시간 1분", Fmt.duration(3661.0))
        assertEquals("1.2 km", Fmt.distance(1240.0, UnitSystem.METRIC, TransportMode.CAR))
        assertEquals("1,240 m", Fmt.distance(1240.0, UnitSystem.METRIC, TransportMode.WALKING))
    }
}
