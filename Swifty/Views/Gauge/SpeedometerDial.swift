import SwiftUI

/// 자동차 계기판 모양의 속도계.
///
/// 눈금과 숫자는 Canvas로 한 번에 그리고, 움직이는 바늘과 진행 호는 별도 뷰로 두어
/// SwiftUI가 각도/트림 값을 직접 보간하게 했다. Canvas 안에서는 애니메이션이 되지 않는다.
struct SpeedometerDial: View {

    /// 표시할 속도 (이미 단위계로 변환된 값).
    var speed: Double
    var maxSpeed: Double
    var majorStep: Double
    var unitLabel: String
    /// 이번 주행 최고 속도. 다이얼 위에 작은 표식으로 남는다.
    var peakSpeed: Double
    /// 구간 분할과 레드존 위치를 결정한다.
    var transport: TransportMode
    /// 단위 라벨 오른쪽 아래에 작게 얹는 보조 표시. 도보의 페이스처럼 필요할 때만 넘긴다.
    var paceReadout: String?

    @Environment(\.palette) private var palette

    /// 다이얼이 도는 각도 범위. 6시 방향 왼쪽에서 시작해 시계방향으로 270°.
    private let startAngle: Double = 135
    private let sweep: Double = 270
    /// 큰 눈금 하나를 몇 등분할지.
    private let minorPerMajor = 4

    private var fraction: Double {
        guard maxSpeed > 0 else { return 0 }
        return min(max(speed / maxSpeed, 0), 1)
    }

    private var peakFraction: Double {
        guard maxSpeed > 0 else { return 0 }
        return min(max(peakSpeed / maxSpeed, 0), 1)
    }

    private var redlineFraction: Double { transport.redlineFraction }

    private var currentZone: SpeedZone { transport.zone(forFraction: fraction) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                dialFace(size: size)
                zoneBands(size: size)
                progressArc(size: size)
                peakMarker(size: size)
                needle(size: size)
                centerReadout(size: size)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("속도계")
        .accessibilityValue("\(Int(speed.rounded())) \(unitLabel)")
    }

    // MARK: - 정적인 다이얼 면

    private func dialFace(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = size / 2

            // 베젤
            let bezel = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
            context.fill(bezel, with: .radialGradient(
                Gradient(colors: [Theme.dialFace, Theme.primaryText.opacity(0.10)]),
                center: center, startRadius: radius * 0.1, endRadius: radius))
            context.stroke(bezel, with: .color(Theme.stroke), lineWidth: 1)

            // 눈금이 놓이는 기준 반지름
            let outer = radius * 0.94
            let majorInner = radius * 0.80
            let minorInner = radius * 0.87
            let labelRadius = radius * 0.68

            let majorCount = max(Int((maxSpeed / majorStep).rounded()), 1)
            let totalTicks = majorCount * minorPerMajor

            for tick in 0...totalTicks {
                let t = Double(tick) / Double(totalTicks)
                let angle = Angle(degrees: startAngle + sweep * t)
                let isMajor = tick % minorPerMajor == 0

                let inner = isMajor ? majorInner : minorInner
                let color: Color = t >= redlineFraction
                    ? Theme.danger.opacity(isMajor ? 0.95 : 0.6)
                    : Theme.primaryText.opacity(isMajor ? 0.85 : 0.35)

                var path = Path()
                path.move(to: point(center: center, radius: inner, angle: angle))
                path.addLine(to: point(center: center, radius: outer, angle: angle))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: isMajor ? 3 : 1.5, lineCap: .round))

                guard isMajor else { continue }

                let value = maxSpeed * t
                let text = Text("\(Int(value.rounded()))")
                    .font(.system(size: size * 0.062, weight: .semibold, design: .rounded))
                    .foregroundStyle(t >= redlineFraction ? Theme.danger : Theme.primaryText.opacity(0.75))
                context.draw(context.resolve(text),
                             at: point(center: center, radius: labelRadius, angle: angle),
                             anchor: .center)
            }
        }
    }

    // MARK: - 움직이는 요소

    /// 이동수단별 속도 구간을 색 띠로 나눠 그린다.
    private func zoneBands(size: CGFloat) -> some View {
        ZStack {
            ForEach(Array(transport.zones.enumerated()), id: \.element.id) { index, zone in
                let lower = index == 0 ? 0 : transport.zones[index - 1].upperFraction
                Circle()
                    .trim(from: (sweep / 360) * lower,
                          to: (sweep / 360) * zone.upperFraction)
                    .stroke(palette.bandColor(for: zone.level),
                            style: StrokeStyle(lineWidth: size * 0.030, lineCap: .butt))
                    .rotationEffect(.degrees(startAngle))
                    .padding(size * 0.033)
            }
        }
    }

    /// 현재 속도까지 차오르는 호.
    private func progressArc(size: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: (sweep / 360) * fraction)
            .stroke(palette.color(for: currentZone.level),
                    style: StrokeStyle(lineWidth: size * 0.026, lineCap: .round))
            .rotationEffect(.degrees(startAngle))
            .padding(size * 0.035)
            .shadow(color: palette.color(for: currentZone.level).opacity(0.6), radius: 8)
            .animation(.easeOut(duration: 0.35), value: fraction)
    }

    /// 최고 속도 표식.
    private func peakMarker(size: CGFloat) -> some View {
        Capsule()
            .fill(Theme.warning)
            .frame(width: size * 0.02, height: size * 0.06)
            .offset(y: -size * 0.435)
            .rotationEffect(.degrees(startAngle + 90 + sweep * peakFraction))
            .opacity(peakSpeed > 1 ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: peakFraction)
    }

    /// 바늘. 회전 각도를 SwiftUI가 보간하므로 부드럽게 움직인다.
    private func needle(size: CGFloat) -> some View {
        ZStack {
            NeedleShape()
                .fill(
                    LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.055, height: size * 0.46)
                .offset(y: -size * 0.19)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

            // 허브
            Circle()
                .fill(Theme.dialHub)
                .frame(width: size * 0.14, height: size * 0.14)
                .overlay(Circle().stroke(Theme.primaryText.opacity(0.18), lineWidth: 1))
        }
        .rotationEffect(.degrees(startAngle + 90 + sweep * fraction))
        .animation(.interpolatingSpring(stiffness: 90, damping: 14), value: fraction)
    }

    // MARK: - 중앙 표시

    private func centerReadout(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text("\(Int(speed.rounded()))")
                .font(.system(size: size * 0.20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: Int(speed.rounded()))
            Text(unitLabel)
                .font(.system(size: size * 0.055, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, -size * 0.01)
                // 세로 배치에 끼어들면 중앙 숫자가 위로 밀려 보기 나쁘다.
                // 그래서 자리를 차지하지 않게 단위 라벨 오른쪽 아래에 겹쳐 둔다.
                .overlay(alignment: .bottomTrailing) {
                    if let paceReadout {
                        Text(paceReadout)
                            .font(.system(size: size * 0.042, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondaryText)
                            .contentTransition(.numericText())
                            .fixedSize()
                            // 아래 구간 이름표와 겹치지 않도록 오른쪽으로 충분히 빼 둔다.
                            .offset(x: size * 0.23, y: size * 0.022)
                    }
                }

            // 지금 어느 구간을 달리는지 이름으로 알려준다.
            Text(currentZone.label)
                .font(.system(size: size * 0.048, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.color(for: currentZone.level))
                .padding(.horizontal, size * 0.045)
                .padding(.vertical, size * 0.016)
                .background(palette.color(for: currentZone.level).opacity(0.15),
                            in: Capsule())
                .padding(.top, size * 0.020)
                .animation(.easeOut(duration: 0.25), value: currentZone.label)

            Spacer()
                .frame(height: size * 0.04)
        }
        .frame(width: size, height: size)
    }

    // MARK: - 도우미

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle.radians),
                y: center.y + radius * sin(angle.radians))
    }
}

/// 뿌리가 넓고 끝이 뾰족한 계기판 바늘.
private struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.width / 2))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - rect.width / 2),
                          control: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
