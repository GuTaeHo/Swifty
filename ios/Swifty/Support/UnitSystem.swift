import Foundation

/// 앱 전체에서 쓰는 단위계. 사용자가 설정에서 바꿀 수 있다.
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "미터법 (km/h)"
        case .imperial: "야드파운드법 (mph)"
        }
    }

    var speedSymbol: String {
        switch self {
        case .metric: "km/h"
        case .imperial: "mph"
        }
    }

    /// 페이스 단위. 미터법은 1 km당, 야드파운드법은 1 mi당 걸리는 시간이다.
    var paceSymbol: String {
        switch self {
        case .metric: "/km"
        case .imperial: "/mi"
        }
    }

    var altitudeSymbol: String {
        switch self {
        case .metric: "m"
        case .imperial: "ft"
        }
    }

    /// m/s -> 표시 속도
    func speed(fromMetersPerSecond value: Double) -> Double {
        switch self {
        case .metric: value * 3.6
        case .imperial: value * 2.236936
        }
    }

    /// m -> 표시 고도
    func altitude(fromMeters value: Double) -> Double {
        switch self {
        case .metric: value
        case .imperial: value * 3.280840
        }
    }
}
