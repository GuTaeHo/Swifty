import SwiftUI
import MapKit

/// 지도 모드. 현위치, 목적지 선택(지도 탭 / 검색), 경로, 속도, 남은 거리·시간을 보여준다.
///
/// MapKit은 공개 API로 지도 타일을 미리 받아둘 수 없으므로 오프라인에서는
/// 지도를 쓸 수 없다. 연결이 끊기면 화면을 덮고 계기판 모드로 안내한다.
struct MapModeView: View {

    @Bindable var appState: AppState
    var location: LocationService
    var navigation: NavigationService
    var search: PlaceSearchService
    var isOnline: Bool

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showingSearch = false
    @State private var showingSettings = false
    /// 한 번의 누름에서 핀이 두 번 찍히지 않게 막는다.
    @State private var didDropPin = false

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if location.needsAuthorization {
                LocationGateView(status: location.authorizationStatus) {
                    location.requestAuthorization()
                }
            } else {
                mapLayer
                    // 상단 바 뒤로도 지도가 이어지도록 위아래 안전 영역을 넘어간다.
                    .ignoresSafeArea(edges: [.top, .bottom])
                    .overlay(alignment: .top) { topOverlay }
                    .overlay(alignment: .bottomTrailing) { mapControls }
                    .overlay(alignment: .bottom) { bottomOverlay }

                if !isOnline {
                    offlineCover
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // 지도 위에서는 바탕을 지우고, 버튼만 떠 있게 한다.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(!isOnline)
                .tint(palette.accent)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .tint(palette.accent)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(appState: appState)
        }
        .sheet(isPresented: $showingSearch) {
            DestinationSearchSheet(search: search,
                                   unit: appState.unitSystem,
                                   transport: appState.transport,
                                   origin: location.location) { destination in
                apply(destination)
            }
        }
        .onChange(of: location.location?.coordinate.latitude) {
            search.updateRegion(center: location.location?.coordinate)
        }
    }

    // MARK: - 지도

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: .all) {
                UserAnnotation()

                if let route = navigation.route {
                    MapPolyline(route.polyline)
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 6,
                                                                 lineCap: .round,
                                                                 lineJoin: .round))
                }

                if let destination = navigation.destination {
                    Annotation(destination.name, coordinate: destination.coordinate) {
                        DestinationPin()
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            // Apple 지도와 같은 방식으로, 길게 눌러 목적지 핀을 찍는다.
            // 짧은 탭은 지도의 기본 동작(POI 선택)에 그대로 남겨둔다.
            //
            // 길게 눌러 목적지를 찍는다. 손을 떼는 순간이 아니라
            // 누르고 있는 상태에서 0.45초가 지나는 순간 바로 찍힌다.
            //
            // 길게 누르기와 드래그를 동시에 인식시켜, 길게 누르기가 성립한 시점에
            // 드래그가 들고 있는 시작 좌표를 그대로 쓴다. simultaneousGesture라서
            // 지도의 이동·확대는 그대로 동작하고, 손가락이 움직이면
            // 길게 누르기가 실패해 핀이 찍히지 않는다.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .simultaneously(with: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged { value in
                        guard value.first == true, let drag = value.second else { return }
                        dropPin(at: drag.startLocation, proxy: proxy)
                    }
                    .onEnded { _ in didDropPin = false }
            )
        }
    }

    // MARK: - 오버레이

    private var topOverlay: some View {
        VStack(spacing: 8) {
            if location.isSignalStale {
                StatusBanner(text: "GPS 신호를 기다리는 중입니다.",
                             systemImage: "antenna.radiowaves.left.and.right.slash",
                             tint: Theme.warning)
            }
            if !navigation.hasDestination {
                StatusBanner(text: "지도를 길게 누르거나 검색해서 목적지를 정하세요.",
                             systemImage: "hand.tap.fill",
                             tint: Theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var bottomOverlay: some View {
        VStack(spacing: 10) {
            if navigation.hasDestination {
                DestinationSummaryCard(navigation: navigation,
                                       location: location,
                                       unit: appState.unitSystem,
                                       transport: appState.transport,
                                       showsElevation: $appState.showsElevationMetrics) {
                    Haptics.light()
                    navigation.clearDestination()
                }
            }
            SpeedPill(speed: appState.unitSystem.speed(fromMetersPerSecond: location.speedMetersPerSecond),
                      unit: appState.unitSystem,
                      transport: appState.transport,
                      bearing: location.displayBearing)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.light()
                withAnimation { camera = .userLocation(fallback: .automatic) }
            } label: {
                Image(systemName: "location.fill")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현위치로 이동")

            if navigation.hasDestination {
                Button {
                    Haptics.light()
                    frameRoute()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.headline)
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("전체 경로 보기")
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, navigation.hasDestination ? 230 : 120)
    }

    /// 오프라인일 때 지도 위를 덮는 안내.
    private var offlineCover: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.warning)

                Text("오프라인에서는 지도를 쓸 수 없습니다")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Text("MapKit은 앱이 지도 타일을 미리 내려받는 방법을 제공하지 않습니다. 대신 계기판 모드는 GPS만 쓰므로 인터넷 없이도 속도·방향·고도를 정확히 보여줍니다.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                if navigation.hasDestination {
                    Text("설정된 목적지까지의 거리는 계기판 모드에서 계속 계산됩니다.")
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Button {
                    appState.mode = .gauge
                } label: {
                    Label("계기판 모드로 전환", systemImage: "speedometer")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
            .padding()
        }
    }

    // MARK: - 동작

    /// 한 번의 누름당 한 번만 찍는다.
    private func dropPin(at point: CGPoint, proxy: MapProxy) {
        guard !didDropPin,
              let coordinate = proxy.convert(point, from: .local) else { return }
        didDropPin = true
        apply(.droppedPin(at: coordinate))
    }

    private func apply(_ destination: Destination) {
        Haptics.success()
        navigation.setDestination(destination,
                                  from: location.location,
                                  online: isOnline)
        frameRoute()
    }

    /// 현위치와 목적지가 모두 보이도록 카메라를 맞춘다.
    private func frameRoute() {
        if let route = navigation.route {
            let rect = route.polyline.boundingMapRect
            withAnimation {
                camera = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.25))
            }
        } else if let here = location.location?.coordinate,
                  let there = navigation.destination?.coordinate {
            let center = CLLocationCoordinate2D(latitude: (here.latitude + there.latitude) / 2,
                                                longitude: (here.longitude + there.longitude) / 2)
            let span = MKCoordinateSpan(
                latitudeDelta: max(abs(here.latitude - there.latitude) * 1.6, 0.01),
                longitudeDelta: max(abs(here.longitude - there.longitude) * 1.6, 0.01))
            withAnimation {
                camera = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }
}

/// 목적지 핀.
private struct DestinationPin: View {

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.accent)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            Image(systemName: "flag.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.black)
        }
    }
}

/// 지도 위에 떠 있는 속도 표시.
private struct SpeedPill: View {

    var speed: Double
    var unit: UnitSystem
    var transport: TransportMode
    var bearing: Double?

    private var fraction: Double {
        let maximum = transport.gaugeMaxSpeed(for: unit)
        return maximum > 0 ? min(speed / maximum, 1) : 0
    }

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(speed.rounded()))")
                    .font(Theme.numeric(38, weight: .bold))
                    .foregroundStyle(palette.speedColor(fraction: fraction, transport: transport))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.25), value: Int(speed.rounded()))
                Text(unit.speedSymbol)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Divider().frame(height: 30).overlay(Theme.stroke)

            HStack(spacing: 6) {
                Image(systemName: transport.symbol)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)

                Divider().frame(height: 22).overlay(Theme.stroke)

                Image(systemName: "location.north.fill")
                    .font(.footnote)
                    .foregroundStyle(palette.accent)
                    .rotationEffect(.degrees(bearing ?? 0))
                    .animation(.easeOut(duration: 0.3), value: bearing ?? 0)
                VStack(alignment: .leading, spacing: 0) {
                    Text(bearing.map { Fmt.cardinal($0) } ?? "–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(bearing.map { Fmt.degrees($0) } ?? "–")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }
}
