import SwiftUI
import Observation

/// 화면 모드.
enum AppMode: String, CaseIterable, Identifiable {
    case map
    case gauge
    case history

    var id: String { rawValue }
    var title: String {
        switch self {
        case .map: "지도"
        case .gauge: "계기판"
        case .history: "기록"
        }
    }
    var symbol: String {
        switch self {
        case .map: "map.fill"
        case .gauge: "speedometer"
        case .history: "list.bullet.rectangle.fill"
        }
    }
}

/// 계기판 표시 방식.
enum GaugeStyle: String, CaseIterable, Identifiable {
    case digital
    case analog

    var id: String { rawValue }
    var title: String {
        switch self {
        case .digital: "디지털"
        case .analog: "아날로그"
        }
    }
    var symbol: String {
        switch self {
        case .digital: "textformat.123"
        case .analog: "gauge.with.needle"
        }
    }
}

/// 사용자 선택 상태. 앱을 다시 켜도 유지된다.
@MainActor
@Observable
final class AppState {

    var mode: AppMode {
        didSet { defaults.set(mode.rawValue, forKey: Keys.mode) }
    }
    var gaugeStyle: GaugeStyle {
        didSet { defaults.set(gaugeStyle.rawValue, forKey: Keys.gaugeStyle) }
    }
    var unitSystem: UnitSystem {
        didSet { defaults.set(unitSystem.rawValue, forKey: Keys.unitSystem) }
    }
    var transport: TransportMode {
        didSet { defaults.set(transport.rawValue, forKey: Keys.transport) }
    }
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var accent: AccentPalette {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }
    /// 목적지 요약에 고도 지표(출발 대비·누적 상승/하강)를 펼쳐 둘지.
    /// 목적지 영역의 전용 버튼으로 켜고 끄며, 마지막 상태를 기억한다.
    /// 남은 거리·시간·도착 예정은 이 값과 무관하게 항상 보인다.
    var showsElevationMetrics: Bool {
        didSet { defaults.set(showsElevationMetrics, forKey: Keys.elevationMetrics) }
    }
    /// 촉각 피드백 사용 여부.
    var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Keys.haptics)
            Haptics.isEnabled = hapticsEnabled
        }
    }
    /// 주행 중 화면이 꺼지지 않도록 한다.
    var keepScreenAwake: Bool {
        didSet {
            defaults.set(keepScreenAwake, forKey: Keys.keepAwake)
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
        }
    }

    private enum Keys {
        static let mode = "swifty.mode"
        static let gaugeStyle = "swifty.gaugeStyle"
        static let unitSystem = "swifty.unitSystem"
        static let transport = "swifty.transport"
        static let appearance = "swifty.appearance"
        static let accent = "swifty.accent"
        static let keepAwake = "swifty.keepAwake"
        static let haptics = "swifty.haptics"
        static let elevationMetrics = "swifty.elevationMetrics"
    }

    private let defaults = UserDefaults.standard

    init() {
        // 기본 단위계는 지역 설정을 따른다.
        let localeDefault: UnitSystem = Locale.current.measurementSystem == .metric ? .metric : .imperial

        mode = AppMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .gauge
        gaugeStyle = GaugeStyle(rawValue: defaults.string(forKey: Keys.gaugeStyle) ?? "") ?? .analog
        unitSystem = UnitSystem(rawValue: defaults.string(forKey: Keys.unitSystem) ?? "") ?? localeDefault
        transport = TransportMode(rawValue: defaults.string(forKey: Keys.transport) ?? "") ?? .car
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        accent = AccentPalette(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .green
        keepScreenAwake = defaults.object(forKey: Keys.keepAwake) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        showsElevationMetrics = defaults.object(forKey: Keys.elevationMetrics) as? Bool ?? false

        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
        Haptics.isEnabled = hapticsEnabled
        Haptics.prepare()
    }
}
