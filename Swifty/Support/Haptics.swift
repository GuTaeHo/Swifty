import UIKit

/// 앱 전체의 촉각 피드백.
///
/// 제너레이터를 매번 새로 만들면 첫 진동이 수십 밀리초 늦게 울린다.
/// 하나씩 만들어 두고 재사용하며, 곧 쓸 것 같으면 미리 prepare()로 깨운다.
@MainActor
enum Haptics {

    /// 설정에서 끌 수 있다. 주행 중 진동을 원치 않는 경우가 있다.
    static var isEnabled = true

    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// 곧 진동이 필요할 화면에 들어갈 때 호출한다.
    static func prepare() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
        rigidGenerator.prepare()
    }

    /// 세그먼트·목록에서 선택이 바뀔 때.
    static func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// 가벼운 확인. 되돌릴 수 있는 사소한 동작에 쓴다.
    static func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    /// 분명한 동작. 측정 시작처럼 상태가 바뀔 때.
    static func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    /// 딱 끊기는 느낌. 구간을 넘어설 때처럼 경계를 알릴 때.
    static func rigid(intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        rigidGenerator.impactOccurred(intensity: intensity)
        rigidGenerator.prepare()
    }

    static func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    static func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    /// 속도 구간을 넘어설 때.
    ///
    /// 올라갈 때는 단계가 높을수록 세게, 내려올 때는 한 번 가볍게 쳐서
    /// 화면을 보지 않아도 방향을 구분할 수 있게 한다.
    static func zoneChanged(from previous: SpeedZone.Level, to current: SpeedZone.Level) {
        guard isEnabled, previous != current else { return }

        if current.rank > previous.rank {
            switch current {
            case .easy, .normal: rigid(intensity: 0.6)
            case .fast: rigid(intensity: 0.85)
            case .limit: warning()   // 한계 구간 진입은 확실히 구분되게
            }
        } else {
            light()
        }
    }
}

extension SpeedZone.Level {
    /// 구간의 높낮이. 넘어선 방향을 판단하는 데 쓴다.
    var rank: Int {
        switch self {
        case .easy: 0
        case .normal: 1
        case .fast: 2
        case .limit: 3
        }
    }
}
