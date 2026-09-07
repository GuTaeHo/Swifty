import SwiftUI

/// 방위를 보여주는 작은 나침반. 방위 링이 돌고 위쪽 삼각형이 진행 방향을 가리킨다.
struct CompassRose: View {

    /// 진행 방향 또는 나침반 방위 (도). nil이면 방향을 알 수 없는 상태.
    var bearing: Double?

    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Theme.primaryText.opacity(0.05))
                    .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))

                dialRing(size: size)
                    // 링을 방위의 반대로 돌리면 위쪽이 항상 진행 방향이 된다.
                    .rotationEffect(.degrees(-(bearing ?? 0)))
                    .animation(.easeOut(duration: 0.3), value: bearing ?? 0)
                    .opacity(bearing == nil ? 0.3 : 1)

                // 고정된 기준 표식
                Triangle()
                    .fill(palette.accent)
                    .frame(width: size * 0.11, height: size * 0.10)
                    .offset(y: -size * 0.40)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("방향")
        .accessibilityValue(bearing.map { "\(Fmt.cardinalName($0)) \(Fmt.degrees($0))" } ?? "알 수 없음")
    }

    private func dialRing(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = size / 2
            let letters = ["N", "E", "S", "W"]

            for step in 0..<36 {
                let degrees = Double(step) * 10
                // 화면 좌표계는 0°가 3시 방향이므로 90°를 빼서 북쪽을 위로 맞춘다.
                let angle = Angle(degrees: degrees - 90)
                let isCardinal = step % 9 == 0
                let inner = radius * (isCardinal ? 0.76 : 0.84)

                var path = Path()
                path.move(to: point(center: center, radius: inner, angle: angle))
                path.addLine(to: point(center: center, radius: radius * 0.92, angle: angle))
                context.stroke(path,
                               with: .color(Theme.primaryText.opacity(isCardinal ? 0.8 : 0.25)),
                               style: StrokeStyle(lineWidth: isCardinal ? 2 : 1, lineCap: .round))

                guard isCardinal else { continue }
                let letter = letters[step / 9]
                let text = Text(letter)
                    .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                    .foregroundStyle(letter == "N" ? Theme.danger : Theme.primaryText.opacity(0.7))
                context.draw(context.resolve(text),
                             at: point(center: center, radius: radius * 0.62, angle: angle),
                             anchor: .center)
            }
        }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle.radians),
                y: center.y + radius * sin(angle.radians))
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 나침반과 방위 이름을 함께 보여주는 카드.
/// 이름은 눈금과 겹치지 않도록 원 바깥 좌측 하단에 둔다.
struct CompassCard: View {

    var bearing: Double?

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 6) {
                CompassRose(bearing: bearing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 방향 이름은 좌측 하단, 방위각은 우측 하단.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.cardinalName(bearing))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer(minLength: 2)
                    Text(bearing.map { Fmt.degrees($0) } ?? "–")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
