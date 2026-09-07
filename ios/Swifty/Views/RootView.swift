import SwiftUI

/// 지도 · 계기판 · 기록 세 화면을 묶는 최상위 뷰.
struct RootView: View {

    @State private var appState = AppState()
    @State private var location = LocationService()
    @State private var network = NetworkMonitor()
    @State private var navigation = NavigationService()
    @State private var search = PlaceSearchService()
    @State private var recorder = TripRecorder()
    @State private var store = TripStore()

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $appState.mode) {
            NavigationStack {
                MapModeView(appState: appState,
                            location: location,
                            navigation: navigation,
                            search: search,
                            isOnline: network.isOnline)
            }
            .tabItem { Label(AppMode.map.title, systemImage: AppMode.map.symbol) }
            .tag(AppMode.map)

            NavigationStack {
                GaugeModeView(appState: appState,
                              location: location,
                              navigation: navigation,
                              recorder: recorder,
                              store: store,
                              isOnline: network.isOnline)
            }
            .tabItem { Label(AppMode.gauge.title, systemImage: AppMode.gauge.symbol) }
            .tag(AppMode.gauge)

            NavigationStack {
                HistoryListView(store: store, unit: appState.unitSystem)
            }
            .tabItem { Label(AppMode.history.title, systemImage: AppMode.history.symbol) }
            .tag(AppMode.history)
            .badge(recorder.isRecording ? "●" : nil)
        }
        .tint(appState.accent.color)
        .environment(\.palette, Palette(accent: appState.accent.color))
        .preferredColorScheme(appState.appearance.colorScheme)
        .task {
            navigation.transport = appState.transport
            location.start()
            search.updateRegion(center: location.location?.coordinate)
        }
        // GPS fix가 올 때마다 남은 거리·시간을 다시 계산하고 측정에도 반영한다.
        .onChange(of: location.lastFixDate) {
            refreshNavigation()
            if let fix = location.location {
                recorder.ingest(fix, smoothedSpeed: location.speedMetersPerSecond)
            }
        }
        // 1초 시계에 맞춰 도착 예정 시각 등을 최신으로 유지한다.
        .onChange(of: location.clock) { refreshNavigation() }
        // 속도 구간을 넘어설 때마다 손끝으로 알린다. 어느 탭에 있든 동작한다.
        .onChange(of: currentZoneLevel) { previous, current in
            Haptics.zoneChanged(from: previous, to: current)
        }
        .onChange(of: network.isOnline) { _, online in
            if online { refreshNavigation() }
        }
        // 이동수단이 바뀌면 경로 종류가 달라지므로 즉시 다시 계산한다.
        .onChange(of: appState.transport) { _, mode in
            navigation.transport = mode
            refreshNavigation()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                location.start()
            case .background:
                // 백그라운드 위치 권한을 쓰지 않으므로 배터리를 위해 멈춘다.
                location.stop()
            default:
                break
            }
        }
        .onChange(of: location.location?.coordinate.latitude) {
            search.updateRegion(center: location.location?.coordinate)
        }
    }

    /// 현재 속도가 속한 구간. 이동수단과 단위계가 바뀌면 함께 바뀐다.
    private var currentZoneLevel: SpeedZone.Level {
        let speed = appState.unitSystem.speed(fromMetersPerSecond: location.speedMetersPerSecond)
        let maximum = appState.transport.gaugeMaxSpeed(for: appState.unitSystem)
        let fraction = maximum > 0 ? min(speed / maximum, 1) : 0
        return appState.transport.zone(forFraction: fraction).level
    }

    private func refreshNavigation() {
        navigation.update(from: location.location,
                          speed: location.speedMetersPerSecond,
                          online: network.isOnline)
    }
}
