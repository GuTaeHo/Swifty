import SwiftUI

/// 계기판 모드. 디지털/아날로그 두 표시 방식을 전환한다.
///
/// 주행 중에는 화면을 넘길 수 없으므로 스크롤 없이 한 화면에 다 담는다.
/// 표시 방식 전환과 측정 버튼은 툴바로 올려 본문 세로 공간을 비웠다.
/// 네트워크가 전혀 필요 없어서 오프라인에서도 그대로 동작한다.
struct GaugeModeView: View {

    @Bindable var appState: AppState
    var location: LocationService
    var navigation: NavigationService
    var recorder: TripRecorder
    var store: TripStore
    var isOnline: Bool

    @Environment(\.palette) private var palette
    @State private var showingSettings = false
    @State private var savedRecordNotice: String?
    /// GPS가 끊긴 직후 잠깐만 띄우는 표시.
    @State private var showsSignalWarning = false
    /// 표시를 끄기로 예약한 작업들 중 마지막 것만 유효하게 만드는 번호표.
    @State private var signalWarningToken = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if location.needsAuthorization {
                LocationGateView(status: location.authorizationStatus) {
                    location.requestAuthorization()
                }
            } else {
                content
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .tint(palette.accent)
            }
            ToolbarItem(placement: .principal) {
                styleSwitcher
            }
            ToolbarItem(placement: .topBarTrailing) {
                recordButton
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(appState: appState)
        }
        .onChange(of: appState.gaugeStyle) { Haptics.selection() }
        .onChange(of: location.isSignalStale) { _, isStale in
            isStale ? flashSignalWarning() : hideSignalWarning()
        }
        .task {
            Haptics.prepare()
            // 첫 fix가 오기 전에도 끊긴 상태이므로 같은 표시를 쓴다.
            if location.isSignalStale { flashSignalWarning() }
        }
    }

    // MARK: - 본문

    private var content: some View {
        VStack(spacing: 10) {
            TransportPicker(selection: $appState.transport,
                            speedFraction: speedFraction)

            if let savedRecordNotice {
                StatusBanner(text: savedRecordNotice,
                             systemImage: "checkmark.circle.fill",
                             tint: palette.accent)
            }

            // 남은 세로 공간은 계기판이 전부 가져간다.
            Group {
                switch appState.gaugeStyle {
                case .digital:
                    DigitalGaugeView(location: location,
                                     recorder: recorder,
                                     unit: appState.unitSystem,
                                     transport: appState.transport,
                                     now: location.clock,
                                     onStopRecording: toggleRecording)
                case .analog:
                    AnalogGaugeView(location: location,
                                    recorder: recorder,
                                    unit: appState.unitSystem,
                                    transport: appState.transport,
                                    now: location.clock,
                                    onStopRecording: toggleRecording)
                }
            }
            .frame(maxHeight: .infinity)
            // 이동수단 선택기 바로 아래 왼쪽에 겹쳐 둔다.
            .overlay(alignment: .topLeading) { signalWarningBadge }

            if navigation.hasDestination {
                DestinationStrip(navigation: navigation,
                                 location: location,
                                 unit: appState.unitSystem,
                                 transport: appState.transport,
                                 showsElevation: $appState.showsElevationMetrics)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: appState.gaugeStyle)
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
    }

    /// GPS 끊김 표시.
    ///
    /// 배너로 띄우면 계기판이 아래로 밀려서 주행 중에 더 방해가 된다.
    /// 자리를 차지하지 않게 겹쳐 두고, 알아차릴 만큼만 보였다가 사라진다.
    @ViewBuilder
    private var signalWarningBadge: some View {
        if showsSignalWarning {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.warning)
                .frame(width: 30, height: 30)
                .background(Theme.panel, in: Circle())
                .overlay(Circle().stroke(Theme.warning.opacity(0.45), lineWidth: 1))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel("GPS 신호 끊김")
        }
    }

    /// 신호가 끊기면 잠깐 띄우고 스스로 사라진다. 다시 끊기면 다시 뜬다.
    private func flashSignalWarning() {
        signalWarningToken += 1
        let token = signalWarningToken
        withAnimation(.easeInOut(duration: 0.2)) { showsSignalWarning = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard signalWarningToken == token else { return }
            withAnimation(.easeInOut(duration: 0.2)) { showsSignalWarning = false }
        }
    }

    /// 신호가 돌아오면 남은 표시를 바로 접는다.
    private func hideSignalWarning() {
        signalWarningToken += 1
        withAnimation(.easeInOut(duration: 0.2)) { showsSignalWarning = false }
    }

    // MARK: - 툴바 요소

    private var styleSwitcher: some View {
        Picker("표시 방식", selection: $appState.gaugeStyle) {
            ForEach(GaugeStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }

    private var recordButton: some View {
        Button {
            toggleRecording()
        } label: {
            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                .font(.title2)
                // 녹화는 어떤 강조색을 골라도 빨간색이어야 바로 알아본다.
                .foregroundStyle(Theme.danger)
        }
        .accessibilityLabel(recorder.isRecording ? "측정 종료" : "측정 시작")
    }

    private func toggleRecording() {
        if recorder.isRecording {
            let saved = recorder.stop(destinationName: navigation.destination?.name)
            if let saved {
                store.add(saved)
                Haptics.success()
                showNotice("기록을 저장했습니다 · \(Fmt.elapsed(saved.duration))")
            } else {
                Haptics.warning()
                showNotice("움직인 거리가 없어 저장하지 않았습니다.")
            }
        } else {
            Haptics.medium()
            recorder.start(transport: appState.transport, from: location.location)
        }
    }

    /// 저장 결과를 잠깐 알리고 스스로 사라진다.
    private func showNotice(_ text: String) {
        savedRecordNotice = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if savedRecordNotice == text { savedRecordNotice = nil }
        }
    }

    /// 선택된 이동수단의 최대 눈금 대비 현재 속도.
    private var speedFraction: Double {
        let speed = appState.unitSystem.speed(fromMetersPerSecond: location.speedMetersPerSecond)
        let maximum = appState.transport.gaugeMaxSpeed(for: appState.unitSystem)
        return maximum > 0 ? min(speed / maximum, 1) : 0
    }
}
