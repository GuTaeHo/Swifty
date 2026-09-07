import SwiftUI
import MapKit

/// 기록 하나의 상세. 경로 지도, 요약 통계, 속도·고도 그래프를 보여준다.
struct HistoryDetailView: View {

    var record: TripRecord
    var unit: UnitSystem

    @Environment(\.palette) private var palette

    private var coordinates: [CLLocationCoordinate2D] {
        record.samples.map(\.coordinate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                routeMap
                summary
                speedProfile
                if record.samples.contains(where: { $0.altitude != nil }) {
                    altitudeProfile
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 경로

    /// 저장된 좌표만으로 그리므로 지도 타일이 없는 오프라인에서도
    /// 아래 통계와 그래프는 그대로 볼 수 있다.
    private var routeMap: some View {
        Map(initialPosition: .rect(boundingRect)) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(palette.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            if let start = coordinates.first {
                Annotation("출발", coordinate: start) {
                    endpoint(color: palette.accent, symbol: "figure.stand")
                }
                .annotationTitles(.hidden)
            }
            if let end = coordinates.last {
                Annotation("도착", coordinate: end) {
                    endpoint(color: Theme.danger, symbol: "flag.checkered")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private func endpoint(color: Color, symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    /// 경로 전체가 보이도록 여유를 준 사각형.
    private var boundingRect: MKMapRect {
        guard !coordinates.isEmpty else {
            return MKMapRect.world
        }
        let rect = coordinates.reduce(MKMapRect.null) { partial, coordinate in
            let point = MKMapPoint(coordinate)
            return partial.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        // 점 하나뿐이면 넓이가 0이라 카메라가 잡히지 않는다.
        let padded = rect.width < 200 || rect.height < 200
            ? rect.insetBy(dx: -400, dy: -400)
            : rect.insetBy(dx: -rect.width * 0.2, dy: -rect.height * 0.2)
        return padded
    }

    // MARK: - 요약

    private var summary: some View {
        VStack(spacing: 12) {
            PanelCard {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: record.transport.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Text(record.transport.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Spacer()
                        Text("\(record.startedAt.formatted(date: .omitted, time: .shortened)) – \(record.endedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack(spacing: 8) {
                        MetricCell(label: "거리",
                                   value: Fmt.distance(record.distance,
                                                       unit: unit,
                                                       transport: record.transport),
                                   systemImage: "road.lanes",
                                   tint: palette.accent)
                        MetricCell(label: "소요 시간",
                                   value: Fmt.elapsed(record.duration),
                                   systemImage: "clock.fill")
                    }

                    HStack(spacing: 8) {
                        MetricCell(label: "최고 속도",
                                   value: "\(Int(unit.speed(fromMetersPerSecond: record.maxSpeed).rounded()))",
                                   unit: unit.speedSymbol,
                                   systemImage: "arrow.up.right",
                                   tint: Theme.warning)
                        MetricCell(label: "평균 속도",
                                   value: "\(Int(unit.speed(fromMetersPerSecond: record.averageSpeed).rounded()))",
                                   unit: unit.speedSymbol,
                                   systemImage: "equal")
                    }

                    HStack(spacing: 8) {
                        MetricCell(label: "누적 상승",
                                   value: "\(Int(unit.altitude(fromMeters: record.elevationGain).rounded()))",
                                   unit: unit.altitudeSymbol,
                                   systemImage: "arrow.up.right")
                        MetricCell(label: "누적 하강",
                                   value: "\(Int(unit.altitude(fromMeters: record.elevationLoss).rounded()))",
                                   unit: unit.altitudeSymbol,
                                   systemImage: "arrow.down.right")
                    }
                }
            }
        }
    }

    // MARK: - 그래프

    private var speedProfile: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("속도")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("최고 \(Int(unit.speed(fromMetersPerSecond: record.maxSpeed).rounded())) \(unit.speedSymbol)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
                ProfileChart(values: record.samples.map {
                                 unit.speed(fromMetersPerSecond: $0.speed)
                             },
                             fill: palette.accent)
                    .frame(height: 90)
            }
        }
    }

    private var altitudeProfile: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("고도")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    if let range = record.altitudeRange {
                        Text("\(Int(unit.altitude(fromMeters: range.min).rounded())) – \(Int(unit.altitude(fromMeters: range.max).rounded())) \(unit.altitudeSymbol)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                // 고도가 빠진 구간은 직전 값으로 이어 그린다.
                ProfileChart(values: filledAltitudes, fill: Theme.warning)
                    .frame(height: 90)
            }
        }
    }

    private var filledAltitudes: [Double] {
        var last: Double?
        return record.samples.compactMap { sample in
            if let altitude = sample.altitude {
                last = altitude
                return unit.altitude(fromMeters: altitude)
            }
            return last.map { unit.altitude(fromMeters: $0) }
        }
    }
}

/// 값의 흐름을 면 그래프로 그린다. 축 없이 형태만 보여주는 용도다.
struct ProfileChart: View {

    var values: [Double]
    var fill: Color

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }

            let lowest = values.min() ?? 0
            let highest = values.max() ?? 1
            // 값이 거의 일정하면 0으로 나누게 되므로 최소 범위를 준다.
            let span = max(highest - lowest, 0.001)

            func point(_ index: Int) -> CGPoint {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let normalized = (values[index] - lowest) / span
                // 위아래로 약간 여백을 두어 선이 잘리지 않게 한다.
                let y = size.height * (1 - CGFloat(normalized) * 0.88) - size.height * 0.06
                return CGPoint(x: x, y: y)
            }

            var line = Path()
            line.move(to: point(0))
            for index in 1..<values.count {
                line.addLine(to: point(index))
            }

            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()

            context.fill(area, with: .linearGradient(
                Gradient(colors: [fill.opacity(0.35), fill.opacity(0.02)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)))

            context.stroke(line, with: .color(fill),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
