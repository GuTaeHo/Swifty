import SwiftUI

/// 라이트 / 다크 / 시스템 설정.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }

    var symbol: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// nil이면 기기 설정을 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// 사용자가 고를 수 있는 강조 색상.
///
/// 라이트 모드에서는 밝은 배경 위에서 대비가 떨어지는 색이 있어
/// 모드별로 채도와 명도를 따로 잡았다.
enum AccentPalette: String, CaseIterable, Identifiable {
    case green
    case blue
    case teal
    case purple
    case pink
    case orange
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: "그린"
        case .blue: "블루"
        case .teal: "틸"
        case .purple: "퍼플"
        case .pink: "핑크"
        case .orange: "오렌지"
        case .amber: "앰버"
        }
    }

    /// 다크 모드용 색. 어두운 배경 위에서 밝게 빛나도록 명도를 높게 잡았다.
    private var darkColor: Color {
        switch self {
        case .green: Color(red: 0.16, green: 0.86, blue: 0.42)
        case .blue: Color(red: 0.25, green: 0.62, blue: 1.00)
        case .teal: Color(red: 0.16, green: 0.82, blue: 0.82)
        case .purple: Color(red: 0.68, green: 0.51, blue: 1.00)
        case .pink: Color(red: 1.00, green: 0.40, blue: 0.66)
        case .orange: Color(red: 1.00, green: 0.55, blue: 0.22)
        case .amber: Color(red: 1.00, green: 0.79, blue: 0.20)
        }
    }

    /// 라이트 모드용 색. 흰 배경 위 대비를 위해 한 단계 어둡게.
    private var lightColor: Color {
        switch self {
        case .green: Color(red: 0.05, green: 0.60, blue: 0.28)
        case .blue: Color(red: 0.05, green: 0.42, blue: 0.90)
        case .teal: Color(red: 0.00, green: 0.53, blue: 0.56)
        case .purple: Color(red: 0.44, green: 0.28, blue: 0.85)
        case .pink: Color(red: 0.85, green: 0.16, blue: 0.45)
        case .orange: Color(red: 0.85, green: 0.36, blue: 0.05)
        case .amber: Color(red: 0.72, green: 0.50, blue: 0.00)
        }
    }

    /// 현재 화면 모드에 맞춰 자동으로 바뀌는 색.
    var color: Color {
        Color.dynamic(light: lightColor, dark: darkColor)
    }
}

extension Color {
    /// 라이트/다크에 따라 다른 값을 쓰는 색.
    /// SwiftUI가 현재 colorScheme으로 해석하므로 preferredColorScheme 설정도 그대로 따른다.
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
