import SwiftUI

/// 계기판 화면용 목적지 요약. 한 화면에 다 들어가도록 카드 대신 한 줄로 압축했다.
struct DestinationStrip: View {

    var navigation: NavigationService
    var location: LocationService
    var unit: UnitSystem
    var transport: TransportMode
    @Binding var showsElevation: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(palette.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(navigation.destination?.name ?? "목적지")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                    Text(navigation.estimate?.source.label ?? "계산 중")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)

                ElevationToggleButton(isOn: $showsElevation)

                if let estimate = navigation.estimate {
                    value(Fmt.distance(estimate.distance, unit: unit, transport: transport),
                          label: "남은 거리",
                          tint: palette.accent)
                    value(Fmt.duration(estimate.time), label: "남은 시간", tint: Theme.primaryText)
                    value(Fmt.arrivalTime(after: estimate.time),
                          label: "도착 예정",
                          tint: Theme.primaryText)
                }
            }

            // 고도 지표는 설정에서 켠 경우에만 한 줄 더 붙는다.
            if showsElevation {
                Divider().overlay(Theme.stroke)

                HStack(spacing: 10) {
                    value(Fmt.signedAltitude(navigation.elevationChange, unit: unit)
                            + " " + unit.altitudeSymbol,
                          label: "출발 대비",
                          tint: elevationTint)
                    Spacer(minLength: 0)
                    value("\(Int(unit.altitude(fromMeters: location.elevationGain).rounded())) \(unit.altitudeSymbol)",
                          label: "누적 상승",
                          tint: Theme.primaryText)
                    value("\(Int(unit.altitude(fromMeters: location.elevationLoss).rounded())) \(unit.altitudeSymbol)",
                          label: "누적 하강",
                          tint: Theme.primaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showsElevation)
    }

    private func value(_ text: String, label: String, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Text(text)
                .font(Theme.numeric(14))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var elevationTint: Color {
        guard let change = navigation.elevationChange else { return Theme.secondaryText }
        if change > 5 { return Theme.warning }
        if change < -5 { return palette.accent }
        return Theme.primaryText
    }
}

/// 목적지 요약에서 고도 지표를 펼치고 접는 전용 버튼.
struct ElevationToggleButton: View {

    @Binding var isOn: Bool

    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() }
        } label: {
            Image(systemName: "mountain.2.fill")
                .font(.caption)
                .foregroundStyle(isOn ? palette.accent : Theme.secondaryText)
                .frame(width: 30, height: 30)
                .background(isOn ? palette.accent.opacity(0.15) : Theme.primaryText.opacity(0.06),
                            in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "고도 지표 접기" : "고도 지표 펼치기")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
