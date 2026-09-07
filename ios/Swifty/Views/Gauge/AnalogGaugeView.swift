import SwiftUI

/// 자동차 계기판을 본뜬 아날로그 화면. 스크롤 없이 주어진 높이에 맞춘다.
struct AnalogGaugeView: View {

    var location: LocationService
    var recorder: TripRecorder
    var unit: UnitSystem
    var transport: TransportMode
    var now: Date
    var onStopRecording: () -> Void

    @Environment(\.palette) private var palette

    private var speed: Double { unit.speed(fromMetersPerSecond: location.speedMetersPerSecond) }

    /// 도보에서만 단위 라벨 옆에 페이스를 덧붙인다.
    private var paceReadout: String? {
        guard transport.usesPace else { return nil }
        let pace = Fmt.pace(fromMetersPerSecond: location.speedMetersPerSecond, unit: unit)
        // 멈춰 있을 때는 "–/km"처럼 적히면 어색해서 기호만 남긴다.
        return pace == "–" ? pace : "\(pace)\(unit.paceSymbol)"
    }

    var body: some View {
        VStack(spacing: 10) {
            SpeedometerDial(speed: speed,
                            maxSpeed: transport.gaugeMaxSpeed(for: unit),
                            majorStep: transport.gaugeMajorStep(for: unit),
                            unitLabel: unit.speedSymbol,
                            peakSpeed: unit.speed(fromMetersPerSecond: location.maxSpeedMetersPerSecond),
                            transport: transport,
                            paceReadout: paceReadout)
                .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                // 너비만 고정하고 높이는 옆 카드에 맞춰 늘어나게 둔다.
                CompassCard(bearing: location.displayBearing)
                    .frame(width: 112)
                    .frame(maxHeight: .infinity)

                TripMetricsCard(location: location,
                                recorder: recorder,
                                unit: unit,
                                transport: transport,
                                now: now,
                                onStopRecording: onStopRecording)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            // 버튼이 카드 밖으로 나가므로 오른쪽에 자리를 비워 둔다.
            .padding(.trailing, 8)
        }
    }
}
