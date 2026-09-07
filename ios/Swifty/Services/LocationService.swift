import Foundation
import CoreLocation
import Observation

/// GPS 기반의 위치·속도·방향·고도 소스. 지도 모드와 계기판 모드가 공유한다.
/// 인터넷 없이도 동작하는 유일한 데이터 소스이므로 오프라인에서도 그대로 살아 있다.
@MainActor
@Observable
final class LocationService: NSObject {

    // MARK: - 게시되는 상태

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var location: CLLocation?

    /// 평활화된 현재 속도 (m/s). 유효하지 않으면 0.
    private(set) var speedMetersPerSecond: Double = 0
    /// 이번 주행에서 관측된 최고 속도 (m/s).
    private(set) var maxSpeedMetersPerSecond: Double = 0
    /// 이번 주행의 누적 이동 거리 (m).
    private(set) var tripDistance: CLLocationDistance = 0
    /// 이번 주행의 누적 상승 고도 (m).
    private(set) var elevationGain: Double = 0
    /// 이번 주행의 누적 하강 고도 (m).
    private(set) var elevationLoss: Double = 0
    /// 주행 시작 시각. 통계 리셋 시 갱신된다.
    private(set) var tripStartedAt: Date = .now

    /// 진행 방향 (도, 0~360). GPS course. 유효하지 않으면 nil.
    private(set) var course: Double?
    /// 나침반 방위 (도, 0~360). 자기계 기반. 정지 상태에서도 유효하다.
    private(set) var heading: Double?

    private(set) var altitudeMeters: Double?
    private(set) var horizontalAccuracy: CLLocationAccuracy = -1
    private(set) var verticalAccuracy: CLLocationAccuracy = -1
    /// 속도 측정 오차 (m/s). 도플러 기반이라 보통 위치 정확도보다 훨씬 좋다.
    private(set) var speedAccuracy: CLLocationSpeedAccuracy = -1

    /// 마지막 위치 갱신 시각. 신호 끊김 판정에 쓴다.
    private(set) var lastFixDate: Date?

    /// 1초마다 갱신되는 시계.
    /// 경과 시간에서 파생되는 값(평균 속도, 신호 끊김 여부)이 관측 대상이 되도록,
    /// 그 값들은 Date()가 아니라 이 프로퍼티를 읽는다.
    private(set) var clock: Date = .now

    var isRunning: Bool { updating }

    /// 권한이 아직 없거나 거부되어 위치를 쓸 수 없는 상태.
    var needsAuthorization: Bool {
        authorizationStatus == .notDetermined
            || authorizationStatus == .denied
            || authorizationStatus == .restricted
    }

    /// GPS 신호가 5초 넘게 끊긴 상태.
    var isSignalStale: Bool {
        guard let lastFixDate else { return true }
        return clock.timeIntervalSince(lastFixDate) > 5
    }

    // MARK: - 내부

    private let manager = CLLocationManager()
    private var updating = false
    private var clockTask: Task<Void, Never>?
    /// 주행 거리를 마지막으로 확정한 지점.
    private var distanceAnchor: CLLocation?
    /// 고도 변화를 마지막으로 확정한 높이 (m).
    private var altitudeAnchor: Double?
    /// 이 값보다 수직 정확도가 나쁜 fix는 고도 누적에 쓰지 않는다.
    private let usableVerticalAccuracy: CLLocationAccuracy = 15
    /// 노이즈가 큰 GPS 속도를 다듬기 위한 지수이동평균 계수.
    private let smoothing = 0.35
    /// 이 값 아래는 정지로 간주한다 (약 1.8 km/h).
    private let stationaryThreshold = 0.5
    /// 이보다 빠른 이동은 GPS 튐으로 보고 거리 집계에서 제외한다 (약 400 km/h).
    private let maxPlausibleSpeed: Double = 111

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.headingFilter = 2
        authorizationStatus = manager.authorizationStatus
        startClock()
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            // self를 약하게 잡고 있으므로 서비스가 해제되면 루프가 스스로 끝난다.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await MainActor.run { self.clock = .now }
            }
        }
    }

    // MARK: - 제어

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        guard !updating else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return
        case .denied, .restricted:
            return
        default:
            break
        }
        updating = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        guard updating else { return }
        updating = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// 최고 속도·주행 거리·경과 시간을 초기화한다.
    func resetTrip() {
        maxSpeedMetersPerSecond = 0
        tripDistance = 0
        elevationGain = 0
        elevationLoss = 0
        tripStartedAt = .now
        distanceAnchor = location
        altitudeAnchor = nil
    }

    /// 주행 거리를 누적한다.
    ///
    /// 매 fix마다 직전 위치와의 차이를 더하면 GPS 잡음이 그대로 쌓이고,
    /// 반대로 잡음보다 큰 이동만 세면 도보처럼 느린 이동은 영영 집계되지 않는다.
    /// 그래서 마지막으로 거리를 확정한 지점(앵커)을 두고, 거기서 잡음 수준을
    /// 넘어설 만큼 멀어졌을 때 한 번에 더한 뒤 앵커를 옮긴다.
    private func accumulateDistance(to newLocation: CLLocation) {
        guard let anchor = distanceAnchor else {
            distanceAnchor = newLocation
            return
        }

        let delta = newLocation.distance(from: anchor)
        let elapsed = newLocation.timestamp.timeIntervalSince(anchor.timestamp)

        // 물리적으로 불가능한 순간 이동(터널 재포착 등)은 버리고 앵커만 옮긴다.
        if elapsed > 0, delta / elapsed > maxPlausibleSpeed {
            distanceAnchor = newLocation
            return
        }

        // 두 지점의 정확도를 합친 값이 잡음의 크기다. 그보다 멀어져야 실제 이동으로 본다.
        let noise = max((anchor.horizontalAccuracy + newLocation.horizontalAccuracy) / 2, 2)
        guard delta > noise else { return }

        tripDistance += delta
        distanceAnchor = newLocation
    }

    /// 누적 상승·하강 고도를 모은다.
    ///
    /// GPS 고도는 수평 위치보다 훨씬 부정확해서(보통 수평의 2~3배 오차)
    /// 매 fix의 차이를 그대로 더하면 가만히 있어도 수백 미터가 쌓인다.
    /// 거리와 같은 앵커 방식을 쓰되, 문턱값을 수직 정확도에 맞춰 더 크게 잡는다.
    private func accumulateElevation(from newLocation: CLLocation) {
        // 수직 정확도가 없거나 나쁘면 아예 쓰지 않는다.
        guard newLocation.verticalAccuracy >= 0,
              newLocation.verticalAccuracy <= usableVerticalAccuracy else { return }

        let altitude = newLocation.altitude
        guard let anchor = altitudeAnchor else {
            altitudeAnchor = altitude
            return
        }

        let delta = altitude - anchor
        let noise = max(newLocation.verticalAccuracy, 3)
        guard abs(delta) > noise else { return }

        if delta > 0 {
            elevationGain += delta
        } else {
            elevationLoss -= delta
        }
        altitudeAnchor = altitude
    }

    // MARK: - 파생 값

    /// 주행 평균 속도 (m/s). 이동 거리 / 경과 시간.
    var averageSpeedMetersPerSecond: Double {
        let elapsed = clock.timeIntervalSince(tripStartedAt)
        // 주행 초반에는 표본이 적어 값이 크게 튀므로 잠시 0으로 둔다.
        guard elapsed > 10, tripDistance > 0 else { return 0 }
        return tripDistance / elapsed
    }

    /// 화면에 표시할 방향. 이동 중이면 진행 방향, 정지 중이면 나침반 방위.
    var displayBearing: Double? {
        if speedMetersPerSecond > stationaryThreshold, let course { return course }
        return heading ?? course
    }

    // MARK: - 갱신 처리

    private func ingest(_ newLocation: CLLocation) {
        // 정확도가 없거나 터무니없이 나쁜 fix는 버린다.
        guard newLocation.horizontalAccuracy >= 0,
              newLocation.horizontalAccuracy < 100 else { return }

        accumulateDistance(to: newLocation)
        accumulateElevation(from: newLocation)

        location = newLocation
        lastFixDate = newLocation.timestamp
        horizontalAccuracy = newLocation.horizontalAccuracy
        verticalAccuracy = newLocation.verticalAccuracy
        speedAccuracy = newLocation.speedAccuracy
        altitudeMeters = newLocation.verticalAccuracy >= 0 ? newLocation.altitude : nil

        // 속도: 음수는 무효값이다.
        let raw = newLocation.speed >= 0 ? newLocation.speed : 0
        let target = raw < stationaryThreshold ? 0 : raw
        speedMetersPerSecond += (target - speedMetersPerSecond) * smoothing
        if speedMetersPerSecond < 0.05 { speedMetersPerSecond = 0 }
        maxSpeedMetersPerSecond = max(maxSpeedMetersPerSecond, target)

        // 진행 방향: 정지 상태의 course는 신뢰할 수 없다.
        // courseAccuracy를 채우지 않는 환경도 있으므로, 값이 있으면 그때만 검사한다.
        let courseIsUsable = newLocation.course >= 0
            && (newLocation.courseAccuracy < 0 || newLocation.courseAccuracy < 45)
        if courseIsUsable, target > stationaryThreshold {
            course = newLocation.course
        } else if target <= stationaryThreshold {
            course = nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.updating = false   // start()의 중복 가드를 풀고 다시 시작한다.
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.ingest(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading은 위치 fix가 있어야 유효하다. 없으면 자북을 쓴다.
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard value >= 0 else { return }
        Task { @MainActor in self.heading = value }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown은 일시적이므로 무시하고 다음 fix를 기다린다.
    }
}
