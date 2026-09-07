import SwiftUI

/// 숫자로만 정확한 값을 보여주는 계기판. 스크롤 없이 주어진 높이에 맞춘다.
struct DigitalGaugeView: View {

    var location: LocationService
    var recorder: TripRecorder
    var unit: UnitSystem
    var transport: TransportMode
    var now: Date
    var onStopRecording: () -> Void

    @Environment(\.palette) private var palette

    private var speed: Double { unit.speed(fromMetersPerSecond: location.speedMetersPerSecond) }
    private var speedFraction: Double { min(speed / transport.gaugeMaxSpeed(for: unit), 1) }
    private var zone: SpeedZone { transport.zone(forFraction: speedFraction) }

    var body: some View {
        VStack(spacing: 10) {
            speedBlock
                .frame(maxHeight: .infinity)
            middleRow
            bottomRow
        }
    }

    // MARK: - 속도

    private var speedBlock: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("현재 속도")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(zone.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(for: zone.level))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.color(for: zone.level).opacity(0.15), in: Capsule())
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(speed.rounded()))")
                        .font(Theme.numeric(88, weight: .bold))
                        .foregroundStyle(palette.color(for: zone.level))
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.25), value: Int(speed.rounded()))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(unit.speedSymbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)

                    Spacer()

                    // 도보에서는 속도보다 페이스가 익숙하므로 함께 보여준다.
                    if transport.usesPace {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("페이스")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(Fmt.pace(fromMetersPerSecond: location.speedMetersPerSecond,
                                              unit: unit))
                                    .font(Theme.numeric(30, weight: .bold))
                                    .foregroundStyle(Theme.primaryText)
                                    .contentTransition(.numericText())
                                Text(unit.paceSymbol)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        }
                    }
                }

                Spacer(minLength: 0)

                // 속도 막대: 숫자만으로는 변화가 잘 안 보여서 함께 둔다.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.primaryText.opacity(0.08))
                        Capsule()
                            .fill(palette.color(for: zone.level))
                            .frame(width: proxy.size.width * speedFraction)
                            .animation(.easeOut(duration: 0.3), value: speedFraction)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - 방향 · 고도

    private var middleRow: some View {
        HStack(spacing: 10) {
            // 너비만 고정하고 높이는 옆 카드에 맞춰 늘어나게 둔다.
            CompassCard(bearing: location.displayBearing)
                .frame(width: 126)
                .frame(maxHeight: .infinity)

            PanelCard {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        MetricCell(label: "고도",
                                   value: location.altitudeMeters.map {
                                       "\(Int(unit.altitude(fromMeters: $0).rounded()))"
                                   } ?? "–",
                                   unit: unit.altitudeSymbol,
                                   systemImage: "mountain.2.fill")
                        MetricCell(label: "누적 상승",
                                   value: "\(Int(unit.altitude(fromMeters: location.elevationGain).rounded()))",
                                   unit: unit.altitudeSymbol,
                                   systemImage: "arrow.up.right")
                        MetricCell(label: "누적 하강",
                                   value: "\(Int(unit.altitude(fromMeters: location.elevationLoss).rounded()))",
                                   unit: unit.altitudeSymbol,
                                   systemImage: "arrow.down.right")
                    }

                    // 속도는 도플러로 직접 재기 때문에 보통 위치 정확도보다 훨씬 좋다.
                    HStack(spacing: 8) {
                        MetricCell(label: "속도 정확도",
                                   value: location.speedAccuracy >= 0
                                       ? "±\(String(format: "%.1f", unit.speed(fromMetersPerSecond: location.speedAccuracy)))"
                                       : "–",
                                   unit: unit.speedSymbol,
                                   systemImage: "speedometer",
                                   tint: palette.accent)
                        MetricCell(label: "위치 정확도",
                                   value: location.horizontalAccuracy >= 0
                                       ? "±\(Int(location.horizontalAccuracy.rounded()))"
                                       : "–",
                                   unit: "m",
                                   systemImage: "scope",
                                   tint: location.horizontalAccuracy > 20 ? Theme.warning : Theme.primaryText)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 주행 기록

    private var bottomRow: some View {
        TripMetricsCard(location: location,
                        recorder: recorder,
                        unit: unit,
                        transport: transport,
                        now: now,
                        showsAltitude: false,
                        onStopRecording: onStopRecording)
    }
}
