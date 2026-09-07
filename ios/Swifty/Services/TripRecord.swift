import Foundation
import CoreLocation

/// 기록 중 남긴 한 점.
///
/// 파일 크기를 줄이려고 키를 짧게 두고, 시각은 시작 시점부터의 초로 저장한다.
struct TripSample: Codable, Identifiable {
    var t: TimeInterval
    var lat: CLLocationDegrees
    var lon: CLLocationDegrees
    /// m/s
    var speed: Double
    /// m. 수직 정확도가 나쁜 fix에서는 nil.
    var altitude: Double?

    var id: TimeInterval { t }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// 측정 시작부터 종료까지의 한 구간.
struct TripRecord: Codable, Identifiable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var transport: TransportMode
    /// m
    var distance: CLLocationDistance
    /// m/s
    var maxSpeed: Double
    /// m
    var elevationGain: Double
    var elevationLoss: Double
    /// 측정 당시 설정돼 있던 목적지 이름.
    var destinationName: String?
    var samples: [TripSample]

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    /// 이동 거리 ÷ 소요 시간 (m/s).
    var averageSpeed: Double {
        guard duration > 1, distance > 0 else { return 0 }
        return distance / duration
    }

    /// 기록에 남은 최고 고도와 최저 고도.
    var altitudeRange: (min: Double, max: Double)? {
        let altitudes = samples.compactMap(\.altitude)
        guard let low = altitudes.min(), let high = altitudes.max() else { return nil }
        return (low, high)
    }

    /// 목록에 보여줄 제목. 목적지가 있었으면 그 이름을, 없으면 이동수단을 쓴다.
    /// 시각은 부제로 따로 보여주므로 제목에 넣지 않는다.
    var title: String {
        if let destinationName, !destinationName.isEmpty { return destinationName }
        return "\(transport.title) 기록"
    }
}
