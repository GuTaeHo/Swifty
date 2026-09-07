import SwiftUI

/// 계기판 오른쪽 아래의 지표 카드.
///
/// 측정 중에는 같은 자리가 통째로 붉게 바뀌고 내용도 측정값으로 갈린다.
/// 별도의 상태 줄을 띄우지 않아도 녹화 중임이 한눈에 보이고,
/// 모서리 버튼은 초기화 대신 측정 종료가 된다.
struct TripMetricsCard: View {

    var location: LocationService
    var recorder: TripRecorder
    var unit: UnitSystem
    var transport: TransportMode
    /// 경과 시간을 1초마다 다시 그리게 하는 시계.
    var now: Date
    /// 고도 칸을 넣을지. 디지털 화면은 위쪽에 이미 고도가 있어 뺀다.
    var showsAltitude: Bool = true
    var onStopRecording: () -> Void

    @Environment(\.palette) private var palette

    private var isRecording: Bool { recorder.isRecording }
    private var accent: Color { isRecording ? Theme.danger : palette.accent }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isRecording ? Theme.danger.opacity(0.55) : Theme.stroke,
                            lineWidth: isRecording ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                cornerButton
                    .offset(x: 14, y: -14)
            }
            .animation(.easeInOut(duration: 0.25), value: isRecording)
    }

    @ViewBuilder
    private var background: some View {
        if isRecording {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.danger.opacity(0.16))
                )
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.panel)
        }
    }

    // MARK: - 내용

    @ViewBuilder
    private var content: some View {
        if isRecording {
            recordingContent
        } else {
            idleContent
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricCell(label: "경과",
                           value: Fmt.elapsed(recorder.elapsed(now: now)),
                           systemImage: "record.circle",
                           tint: Theme.danger)
                MetricCell(label: "측정 거리",
                           value: Fmt.distance(recorder.distance,
                                               unit: unit,
                                               transport: recorder.transport),
                           systemImage: "road.lanes",
                           tint: Theme.danger)
            }
            HStack(spacing: 8) {
                MetricCell(label: "최고",
                           value: "\(Int(unit.speed(fromMetersPerSecond: recorder.maxSpeed).rounded()))",
                           unit: unit.speedSymbol,
                           systemImage: "arrow.up.right",
                           tint: Theme.warning)
                MetricCell(label: "평균",
                           value: "\(Int(unit.speed(fromMetersPerSecond: recorder.averageSpeed).rounded()))",
                           unit: unit.speedSymbol,
                           systemImage: "equal")
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var idleContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if showsAltitude {
                    MetricCell(label: "고도",
                               value: location.altitudeMeters.map {
                                   "\(Int(unit.altitude(fromMeters: $0).rounded()))"
                               } ?? "–",
                               unit: unit.altitudeSymbol,
                               systemImage: "mountain.2.fill")
                }
                MetricCell(label: "최고",
                           value: "\(Int(unit.speed(fromMetersPerSecond: location.maxSpeedMetersPerSecond).rounded()))",
                           unit: unit.speedSymbol,
                           systemImage: "arrow.up.right",
                           tint: Theme.warning)
                if !showsAltitude {
                    MetricCell(label: "평균",
                               value: "\(Int(unit.speed(fromMetersPerSecond: location.averageSpeedMetersPerSecond).rounded()))",
                               unit: unit.speedSymbol,
                               systemImage: "equal")
                }
            }
            HStack(spacing: 8) {
                if showsAltitude {
                    MetricCell(label: "평균",
                               value: "\(Int(unit.speed(fromMetersPerSecond: location.averageSpeedMetersPerSecond).rounded()))",
                               unit: unit.speedSymbol,
                               systemImage: "equal")
                }
                MetricCell(label: "주행 거리",
                           value: Fmt.distance(location.tripDistance,
                                               unit: unit,
                                               transport: transport),
                           systemImage: "road.lanes")
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 모서리 버튼

    private var cornerButton: some View {
        Button {
            Haptics.light()
            if isRecording {
                onStopRecording()
            } else {
                location.resetTrip()
            }
        } label: {
            Image(systemName: isRecording ? "stop.fill" : "arrow.counterclockwise")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                // 카드 경계선 위에 얹히므로 배경색으로 선을 끊어 준다.
                .background(Theme.background, in: Circle())
                .overlay(Circle().stroke(isRecording ? Theme.danger.opacity(0.55) : Theme.stroke,
                                         lineWidth: isRecording ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "측정 종료" : "주행 기록 초기화")
    }
}
