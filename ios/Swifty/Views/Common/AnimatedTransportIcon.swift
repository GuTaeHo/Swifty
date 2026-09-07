import SwiftUI

/// 현재 속도에 반응해 움직이는 이동수단 아이콘.
///
/// SF Symbol은 자동차 바퀴만 따로 돌릴 수 있는 레이어 구조가 아니라서,
/// 속도감은 아이콘 뒤로 흐르는 속도선과 이동수단별 고유 동작으로 표현한다.
struct AnimatedTransportIcon: View {

    /// 속도선의 세기. 이동수단의 속도 구간을 그대로 4단계로 옮긴 것이라
    /// 계기판에 표시되는 구간(걷기/달리기, 시내/고속도로 …)과 항상 일치한다.
    enum StreakLevel {
        case none      // 없음 — 멈춰 있음
        case short     // 조금
        case medium    // 중간
        case long      // 김

        var lineCount: Int {
            switch self {
            case .none: 0
            case .short: 1
            case .medium: 2
            case .long: 3
            }
        }

        /// 아이콘 크기 대비 선 길이.
        var lengthFactor: Double {
            switch self {
            case .none: 0
            case .short: 0.35
            case .medium: 0.62
            case .long: 0.95
            }
        }

        /// 선이 흐르는 속도 (초당 반복 횟수).
        var rate: Double {
            switch self {
            case .none: 0
            case .short: 1.2
            case .medium: 2.4
            case .long: 4.0
            }
        }

        var maxOpacity: Double {
            switch self {
            case .none: 0
            case .short: 0.30
            case .medium: 0.45
            case .long: 0.60
            }
        }

        /// 아이콘 흔들림의 세기.
        var intensity: Double {
            switch self {
            case .none: 0
            case .short: 0.35
            case .medium: 0.7
            case .long: 1.0
            }
        }
    }

    var mode: TransportMode
    /// 계기판 최대 눈금 대비 현재 속도 (0~1).
    var speedFraction: Double
    /// 선택된 항목만 움직인다.
    var isActive: Bool
    var size: CGFloat = 17

    /// 이동수단의 구간표를 4단계 속도선 세기로 옮긴다.
    private var level: StreakLevel {
        guard isActive else { return .none }
        // 사실상 멈춘 상태에서는 아무것도 움직이지 않는다.
        guard speedFraction > 0.01 else { return .none }

        switch mode.zone(forFraction: speedFraction).level {
        case .easy: return .short
        case .normal: return .medium
        case .fast, .limit: return .long
        }
    }

    private var isMoving: Bool { level != .none }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isMoving)) { context in
            let phase = isMoving
                ? (context.date.timeIntervalSinceReferenceDate * level.rate)
                    .truncatingRemainder(dividingBy: 1)
                : 0

            ZStack {
                speedLines(phase: phase)
                symbol(phase: phase)
            }
            .frame(width: size * 2.4, height: size * 1.5)
            .animation(.easeInOut(duration: 0.3), value: level)
        }
    }

    // MARK: - 아이콘

    private func symbol(phase: Double) -> some View {
        Image(systemName: symbolName(phase: phase))
            .font(.system(size: size, weight: .semibold))
            .offset(motionOffset(phase: phase))
            .rotationEffect(.degrees(motionRotation(phase: phase)))
    }

    /// 도보만 심볼을 번갈아 써서 다리 동작 자체를 만든다.
    /// 다른 이동수단은 형태가 바뀌면 어색해서 흔들림으로만 표현한다.
    private func symbolName(phase: Double) -> String {
        guard mode == .walking, isMoving else { return mode.symbol }

        // 달리는 구간에서는 달리는 자세로 바꾼다.
        // figure.run에는 짝이 되는 모션 변형이 없으므로 심볼을 바꾸지 않고
        // 아래의 상하 튐으로 리듬을 준다.
        if mode.zone(forFraction: speedFraction).level == .fast
            || mode.zone(forFraction: speedFraction).level == .limit {
            return "figure.run"
        }
        return phase < 0.5 ? "figure.walk" : "figure.walk.motion"
    }

    /// 이동수단마다 다른 흔들림.
    private func motionOffset(phase: Double) -> CGSize {
        guard isMoving else { return .zero }
        let wave = sin(phase * 2 * .pi)
        let intensity = level.intensity

        switch mode {
        case .walking:
            // 발을 디딜 때마다 위아래로 튄다. 한 주기에 두 걸음.
            return CGSize(width: 0, height: -abs(sin(phase * 2 * .pi)) * (0.8 + intensity))
        case .cycling:
            // 페달을 밟는 리듬으로 좌우로 살짝 흔들린다.
            return CGSize(width: wave * (0.6 + intensity * 0.8), height: 0)
        case .car:
            // 노면 진동. 빠를수록 잘게 떨린다.
            return CGSize(width: 0, height: sin(phase * 4 * .pi) * intensity * 0.9)
        case .subway, .train:
            // 레일 이음매를 지나는 규칙적인 흔들림.
            return CGSize(width: wave * intensity * 0.7, height: 0)
        case .airplane:
            // 상승 기류를 타듯 완만하게 위아래로.
            return CGSize(width: 0, height: wave * (0.5 + intensity))
        }
    }

    private func motionRotation(phase: Double) -> Double {
        guard isMoving else { return 0 }
        let intensity = level.intensity
        switch mode {
        case .cycling: return sin(phase * 2 * .pi) * intensity * 4
        case .airplane: return sin(phase * 2 * .pi) * intensity * 5
        case .subway, .train, .car: return sin(phase * 4 * .pi) * intensity * 1.5
        case .walking: return 0
        }
    }

    // MARK: - 속도선

    /// 아이콘 뒤로 흘러가는 선. 단계가 올라갈수록 개수가 늘고 길어진다.
    private func speedLines(phase: Double) -> some View {
        Canvas { context, canvasSize in
            let count = level.lineCount
            guard count > 0 else { return }

            let travel = canvasSize.width
            let lineLength = size * level.lengthFactor

            for index in 0..<count {
                // 선들을 균등한 간격으로 어긋나게 배치해 끊기지 않고 흐르게 한다.
                let offset = (phase + Double(index) / Double(count))
                    .truncatingRemainder(dividingBy: 1)
                let x = travel * (1 - offset)

                // 개수가 적을 때는 가운데에, 많아지면 위아래로 퍼뜨린다.
                let lane = count == 1 ? 0.5 : 0.3 + 0.4 * Double(index % 2)
                let y = canvasSize.height * lane

                // 양 끝에서 흐려지도록 투명도를 준다.
                let opacity = sin(offset * .pi) * level.maxOpacity

                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - lineLength, y: y))
                context.stroke(path,
                               with: .color(.primary.opacity(opacity)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
    }
}
