import SwiftUI

/// 강조 색상과 거기서 파생되는 색들. 환경을 통해 화면 전체로 내려간다.
struct Palette: Equatable {
    var accent: Color

    /// 속도 구간에 대응하는 색.
    func color(for level: SpeedZone.Level) -> Color {
        switch level {
        case .easy, .normal: accent
        case .fast: Theme.warning
        case .limit: Theme.danger
        }
    }

    /// 구간 띠를 그릴 때 쓰는 색. 단계가 올라갈수록 진해진다.
    func bandColor(for level: SpeedZone.Level) -> Color {
        switch level {
        case .easy: accent.opacity(0.22)
        case .normal: accent.opacity(0.45)
        case .fast: Theme.warning.opacity(0.45)
        case .limit: Theme.danger.opacity(0.50)
        }
    }

    /// 이동수단의 구간표에 따라 현재 속도에 맞는 색을 고른다.
    func speedColor(fraction: Double, transport: TransportMode) -> Color {
        color(for: transport.zone(forFraction: fraction).level)
    }
}

extension EnvironmentValues {
    @Entry var palette = Palette(accent: AccentPalette.green.color)
}

/// 강조색과 무관한 공용 색과 서체.
/// 모든 값이 라이트/다크에 따라 자동으로 바뀐다.
enum Theme {
    static let background = Color.dynamic(
        light: Color(red: 0.95, green: 0.96, blue: 0.97),
        dark: Color(red: 0.04, green: 0.05, blue: 0.07))

    static let panel = Color.dynamic(
        light: .white,
        dark: Color(red: 0.09, green: 0.10, blue: 0.13))

    static let stroke = Color.dynamic(
        light: Color.black.opacity(0.08),
        dark: Color.white.opacity(0.10))

    /// 계기판 다이얼 안쪽 면.
    static let dialFace = Color.dynamic(
        light: Color(red: 0.99, green: 0.99, blue: 1.00),
        dark: Color(red: 0.07, green: 0.08, blue: 0.10))

    /// 바늘 축.
    static let dialHub = Color.dynamic(
        light: Color(white: 0.82),
        dark: Color(white: 0.16))

    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    static let warning = Color.dynamic(
        light: Color(red: 0.80, green: 0.52, blue: 0.00),
        dark: Color(red: 1.00, green: 0.72, blue: 0.20))

    static let danger = Color.dynamic(
        light: Color(red: 0.83, green: 0.15, blue: 0.13),
        dark: Color(red: 1.00, green: 0.30, blue: 0.28))

    /// 숫자 표시에 쓰는 고정폭 폰트. 자릿수가 바뀌어도 흔들리지 않는다.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

/// 정보 블록을 감싸는 카드.
struct PanelCard<Content: View>: View {
    var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

/// 라벨 + 값 한 쌍을 보여주는 작은 셀.
struct MetricCell: View {
    var label: String
    var value: String
    var unit: String?
    var systemImage: String?
    var tint: Color = Theme.primaryText

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(Theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.numeric(24))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
