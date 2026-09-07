import Foundation
import CoreLocation

enum Fmt {
    /// 거리를 단위계와 이동수단에 맞춰 사람이 읽는 문자열로.
    ///
    /// 같은 1,240 m라도 도보에서는 "1,240 m", 자동차에서는 "1.2 km"가 자연스럽다.
    /// 작은 단위로 적을 기준은 이동수단이 정한다.
    static func distance(_ meters: CLLocationDistance,
                         unit: UnitSystem,
                         transport: TransportMode) -> String {
        guard meters.isFinite, meters >= 0 else { return "–" }

        let fineLimit = transport.fineUnitLimit(for: unit)

        switch unit {
        case .metric:
            if meters < fineLimit {
                return "\(Int(meters.rounded()).formatted()) m"
            }
            let km = meters / 1000
            let decimals = transport.coarseDecimals(forDisplayValue: km)
            return decimals > 0
                ? String(format: "%.\(decimals)f km", km)
                : "\(Int(km.rounded()).formatted()) km"
        case .imperial:
            if meters < fineLimit {
                let feet = meters * 3.280840
                return "\(Int(feet.rounded()).formatted()) ft"
            }
            let miles = meters / 1609.344
            let decimals = transport.coarseDecimals(forDisplayValue: miles)
            return decimals > 0
                ? String(format: "%.\(decimals)f mi", miles)
                : "\(Int(miles.rounded()).formatted()) mi"
        }
    }

    /// 고도차처럼 부호가 의미 있는 값. (예: "+128 m", "−34 m")
    static func signedAltitude(_ meters: Double?, unit: UnitSystem) -> String {
        guard let meters, meters.isFinite else { return "–" }
        let value = unit.altitude(fromMeters: meters)
        let rounded = Int(value.rounded())
        if rounded == 0 { return "0" }
        return rounded > 0 ? "+\(rounded)" : "−\(abs(rounded))"
    }

    /// 단위 거리당 걸리는 시간. 도보·러닝에서는 속도보다 페이스가 익숙하다.
    /// (예: 5'30" — 1 km를 5분 30초에 간다)
    static func pace(fromMetersPerSecond speed: Double, unit: UnitSystem) -> String {
        // 거의 멈춘 상태에서는 페이스가 무한대로 치솟아 의미가 없다.
        guard speed > 0.3 else { return "–" }

        let metersPerUnit: Double = unit == .metric ? 1000 : 1609.344
        let secondsPerUnit = metersPerUnit / speed
        // 1단위에 한 시간 넘게 걸리면 표기하지 않는다.
        guard secondsPerUnit.isFinite, secondsPerUnit < 3600 else { return "–" }

        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit.rounded()) % 60
        return String(format: "%d'%02d\"", minutes, seconds)
    }

    /// 경과 시간을 시:분:초로. (예: "1:04:12", "12:35")
    static func elapsed(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// 남은 시간. (예: "12분", "1시간 24분")
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "–" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)시간 \(minutes)분" : "\(hours)시간"
        }
        if minutes > 0 { return "\(minutes)분" }
        return "1분 미만"
    }

    /// 도착 예정 시각.
    static func arrivalTime(after seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "–" }
        let date = Date().addingTimeInterval(seconds)
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// 방위각을 "남서쪽"처럼 읽는 이름으로. (예: 200° -> "남서쪽")
    static func cardinalName(_ degrees: Double?) -> String {
        guard let degrees, degrees.isFinite, degrees >= 0 else { return "–" }
        return cardinal(degrees) + "쪽"
    }

    /// 방위각을 8방위 한글 약어로. (예: 20° -> "북")
    static func cardinal(_ degrees: Double) -> String {
        guard degrees.isFinite, degrees >= 0 else { return "–" }
        let names = ["북", "북동", "동", "남동", "남", "남서", "서", "북서"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) / 45).rounded()) % 8
        return names[index]
    }

    static func degrees(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "–" }
        return "\(Int(value.rounded()))°"
    }

    /// 좌표 표기. (예: "37.5665°N, 126.9780°E")
    static func coordinate(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.4f°%@, %.4f°%@",
               abs(c.latitude), c.latitude >= 0 ? "N" : "S",
               abs(c.longitude), c.longitude >= 0 ? "E" : "W")
    }
}
