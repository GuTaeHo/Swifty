import Foundation
import SwiftUI
import MapKit

/// 계기판을 나누는 속도 구간.
struct SpeedZone: Identifiable {
    enum Level {
        case easy      // 여유
        case normal    // 일상적인 순항
        case fast      // 빠름
        case limit     // 사실상 한계
    }

    /// 계기판 최대 눈금 대비 구간의 끝 (0~1).
    var upperFraction: Double
    var level: Level
    var label: String

    var id: String { label }
}

/// 이동수단. 계기판 눈금 범위와 구간, 경로 계산 방식을 함께 결정한다.
enum TransportMode: String, CaseIterable, Identifiable, Codable {
    case walking
    case cycling
    case car
    case subway
    case train
    case airplane

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walking: "도보"
        case .cycling: "자전거"
        case .car: "자동차"
        case .subway: "지하철"
        case .train: "기차"
        case .airplane: "비행기"
        }
    }

    var symbol: String {
        switch self {
        case .walking: "figure.walk"
        case .cycling: "bicycle"
        case .car: "car.fill"
        case .subway: "tram.fill.tunnel"
        case .train: "tram.fill"
        case .airplane: "airplane"
        }
    }

    /// 계기판 최대 눈금.
    ///
    /// 이동수단이 현실적으로 도달할 수 있는 상한에 맞춘다.
    /// 도보는 일반인이 전력으로 달릴 때까지를 담아 30을 상한으로 두었고,
    /// 나머지도 같은 기준으로 잡아 바늘이 다이얼 전체를 쓰도록 했다.
    func gaugeMaxSpeed(for unit: UnitSystem) -> Double {
        switch (self, unit) {
        case (.walking, .metric): 30
        case (.walking, .imperial): 20
        case (.cycling, .metric): 80
        case (.cycling, .imperial): 50
        case (.car, .metric): 240
        case (.car, .imperial): 160
        case (.subway, .metric): 120
        case (.subway, .imperial): 80
        case (.train, .metric): 360
        case (.train, .imperial): 220
        case (.airplane, .metric): 1000
        case (.airplane, .imperial): 600
        }
    }

    /// 숫자가 붙는 큰 눈금 간격.
    func gaugeMajorStep(for unit: UnitSystem) -> Double {
        switch (self, unit) {
        case (.walking, .metric): 5
        case (.walking, .imperial): 5
        case (.cycling, .metric): 10
        case (.cycling, .imperial): 10
        case (.car, _): 20
        case (.subway, .metric): 20
        case (.subway, .imperial): 10
        case (.train, .metric): 40
        case (.train, .imperial): 20
        case (.airplane, _): 100
        }
    }

    /// 계기판 구간. 최대 눈금에 대한 비율로 두어 단위계가 바뀌어도 그대로 쓰인다.
    var zones: [SpeedZone] {
        switch self {
        case .walking:
            // 30 km/h 기준: 걷기 6 · 조깅 12 · 달리기 21 · 질주 30
            [.init(upperFraction: 0.20, level: .easy, label: "걷기"),
             .init(upperFraction: 0.40, level: .normal, label: "조깅"),
             .init(upperFraction: 0.70, level: .fast, label: "달리기"),
             .init(upperFraction: 1.00, level: .limit, label: "질주")]
        case .cycling:
            // 80 km/h 기준: 서행 15 · 순항 30 · 고속 50 · 질주 80
            [.init(upperFraction: 0.19, level: .easy, label: "서행"),
             .init(upperFraction: 0.38, level: .normal, label: "순항"),
             .init(upperFraction: 0.63, level: .fast, label: "고속"),
             .init(upperFraction: 1.00, level: .limit, label: "질주")]
        case .car:
            // 240 km/h 기준: 서행 60 · 정속 100 · 고속 160 · 초고속 240
            [.init(upperFraction: 0.25, level: .easy, label: "서행"),
             .init(upperFraction: 0.42, level: .normal, label: "정속"),
             .init(upperFraction: 0.67, level: .fast, label: "고속"),
             .init(upperFraction: 1.00, level: .limit, label: "초고속")]
        case .subway:
            // 120 km/h 기준: 서행 30 · 정속 60 · 고속 90 · 최고 120
            [.init(upperFraction: 0.25, level: .easy, label: "서행"),
             .init(upperFraction: 0.50, level: .normal, label: "정속"),
             .init(upperFraction: 0.75, level: .fast, label: "고속"),
             .init(upperFraction: 1.00, level: .limit, label: "최고")]
        case .train:
            // 360 km/h 기준: 저속 80 · 중속 160 · 순항 260 · 고속 360
            [.init(upperFraction: 0.22, level: .easy, label: "저속"),
             .init(upperFraction: 0.44, level: .normal, label: "중속"),
             .init(upperFraction: 0.72, level: .fast, label: "순항"),
             .init(upperFraction: 1.00, level: .limit, label: "고속")]
        case .airplane:
            // 1000 km/h 기준: 100 · 300 · 700 · 1000
            [.init(upperFraction: 0.10, level: .easy, label: "지상"),
             .init(upperFraction: 0.30, level: .normal, label: "이착륙"),
             .init(upperFraction: 0.70, level: .fast, label: "상승"),
             .init(upperFraction: 1.00, level: .limit, label: "순항")]
        }
    }

    /// 현재 속도 비율이 속한 구간.
    func zone(forFraction fraction: Double) -> SpeedZone {
        let f = min(max(fraction, 0), 1)
        return zones.first { f <= $0.upperFraction } ?? zones[zones.count - 1]
    }

    /// 마지막 구간이 시작되는 지점. 다이얼의 레드존 시작점이다.
    var redlineFraction: Double {
        zones.count >= 2 ? zones[zones.count - 2].upperFraction : 0.8
    }

    /// 속도 대신 페이스(단위 거리당 시간)가 더 익숙한 이동수단인지.
    /// 걷기·달리기에서는 "12 km/h"보다 "5'00\"/km"가 직관적이다.
    var usesPace: Bool {
        self == .walking
    }

    /// 이 거리 미만은 m·ft 같은 작은 단위로 표기한다.
    ///
    /// 도보에서 "1.2 km"는 정보를 잃는다. 1,240 m처럼 미터 단위로 보는 편이
    /// 유용하고, 반대로 비행기는 미터 단위가 의미 없어 항상 km·mi로 적는다.
    func fineUnitLimit(for unit: UnitSystem) -> CLLocationDistance {
        switch (self, unit) {
        case (.walking, .metric): 3000
        case (.walking, .imperial): 1609      // 1마일
        case (.cycling, .metric): 2000
        case (.cycling, .imperial): 1609
        case (.car, _): 1000
        case (.subway, _): 1000
        case (.train, _): 1000
        case (.airplane, _): 0                // 항상 큰 단위
        }
    }

    /// 큰 단위로 적을 때 소수점 자리 수.
    func coarseDecimals(forDisplayValue value: Double) -> Int {
        switch self {
        case .airplane: 0                     // 800 km에 소수점은 무의미하다
        case .train: value < 100 ? 1 : 0
        default: value < 100 ? 1 : 0
        }
    }

    /// MKDirections에 넘길 이동수단.
    /// 자전거 전용 경로 API는 없어서 도보 경로로 대신한다.
    /// 비행기는 도로망 경로가 의미 없으므로 nil을 돌려 직선 거리로 계산하게 한다.
    var directionsTransportType: MKDirectionsTransportType? {
        switch self {
        case .walking, .cycling: .walking
        case .car: .automobile
        case .subway, .train: .transit
        case .airplane: nil
        }
    }

    /// 경로를 못 구했을 때 남은 시간을 어림하는 데 쓰는 순항 속도 (m/s).
    var cruiseSpeedMetersPerSecond: Double {
        switch self {
        case .walking: 1.4      // 약 5 km/h
        case .cycling: 4.7      // 약 17 km/h
        case .car: 11.1         // 약 40 km/h
        case .subway: 16.7      // 약 60 km/h — 역 정차를 포함한 표정속도
        case .train: 33.3       // 약 120 km/h
        case .airplane: 222.0   // 약 800 km/h
        }
    }

    /// 경로에서 이만큼 벗어나면 이탈로 보고 다시 계산한다.
    /// 도보는 골목 단위로 움직이므로 기준을 좁게 잡는다.
    var offRouteThreshold: CLLocationDistance {
        switch self {
        case .walking, .cycling: 40
        case .car: 80
        case .subway, .train: 200
        case .airplane: .greatestFiniteMagnitude
        }
    }
}
