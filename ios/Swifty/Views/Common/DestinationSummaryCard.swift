import SwiftUI

/// 목적지까지 남은 거리·시간·도착 예정 시각. 지도 모드와 계기판 모드가 함께 쓴다.
struct DestinationSummaryCard: View {

    var navigation: NavigationService
    var location: LocationService
    var unit: UnitSystem
    var transport: TransportMode
    @Binding var showsElevation: Bool
    var onConfirm: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil
    var clearAccessibilityLabel = "목적지 지우기"

    @Environment(\.palette) private var palette

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let estimate = navigation.estimate {
                    HStack(spacing: 8) {
                        MetricCell(label: "남은 거리",
                                   value: Fmt.distance(estimate.distance, unit: unit, transport: transport),
                                   systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                                   tint: palette.accent)
                        MetricCell(label: "남은 시간",
                                   value: Fmt.duration(estimate.time),
                                   systemImage: "clock.fill")
                        MetricCell(label: "도착 예정",
                                   value: Fmt.arrivalTime(after: estimate.time),
                                   systemImage: "flag.checkered")
                    }

                    if showsElevation {
                        elevationRow
                    }

                    HStack(spacing: 6) {
                        Image(systemName: iconName(for: estimate.source))
                            .font(.caption2)
                        Text(estimate.source.label)
                            .font(.caption2)
                        if navigation.isCalculatingRoute {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .foregroundStyle(estimate.source == .straightLine ? Theme.warning : Theme.secondaryText)
                } else {
                    Text("위치를 확인하는 중입니다…")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                if let message = navigation.routeErrorMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                }
            }
        }
    }

    /// 목적지를 정한 뒤의 고도 변화.
    ///
    /// iOS에는 임의 좌표의 지형 고도를 조회하는 공개 API가 없어 목적지 자체의
    /// 고도는 알 수 없다. 그래서 "목적지까지 남은 고도"가 아니라
    /// "출발 이후 실제로 오르내린 높이"를 보여준다.
    private var elevationRow: some View {
        HStack(spacing: 8) {
            MetricCell(label: "출발 대비",
                       value: Fmt.signedAltitude(navigation.elevationChange, unit: unit),
                       unit: unit.altitudeSymbol,
                       systemImage: "arrow.up.arrow.down",
                       tint: elevationTint)

            MetricCell(label: "누적 상승",
                       value: "\(Int(unit.altitude(fromMeters: location.elevationGain).rounded()))",
                       unit: unit.altitudeSymbol,
                       systemImage: "arrow.up.right",
                       tint: Theme.primaryText)

            MetricCell(label: "누적 하강",
                       value: "\(Int(unit.altitude(fromMeters: location.elevationLoss).rounded()))",
                       unit: unit.altitudeSymbol,
                       systemImage: "arrow.down.right",
                       tint: Theme.primaryText)
        }
    }

    private var elevationTint: Color {
        guard let change = navigation.elevationChange else { return Theme.secondaryText }
        if change > 5 { return Theme.warning }
        if change < -5 { return palette.accent }
        return Theme.primaryText
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(navigation.destination?.name ?? "목적지")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if let subtitle = navigation.destination?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            ElevationToggleButton(isOn: $showsElevation)
            if let onConfirm {
                Button(action: onConfirm) {
                    Image(systemName: "flag.checkered")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(palette.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("목적지 설정")
            }
            if let onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearAccessibilityLabel)
            }
        }
    }

    private func iconName(for source: NavigationService.EstimateSource) -> String {
        switch source {
        case .route: "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .cachedRoute: "arrow.down.circle.fill"
        case .straightLine: "ruler.fill"
        }
    }
}
