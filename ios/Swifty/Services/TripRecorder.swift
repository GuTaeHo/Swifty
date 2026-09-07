import Foundation
import CoreLocation
import Observation

/// 측정 시작부터 종료까지 경로와 통계를 모은다.
///
/// LocationService의 누적값을 빼서 쓰지 않고 직접 모으는 이유는,
/// 사용자가 측정 도중에 주행 기록을 초기화해도 측정이 깨지지 않게 하기 위해서다.
@MainActor
@Observable
final class TripRecorder {

    private(set) var isRecording = false
    private(set) var startedAt: Date?
    private(set) var distance: CLLocationDistance = 0
    private(set) var maxSpeed: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var elevationLoss: Double = 0
    private(set) var sampleCount = 0

    /// 측정을 시작한 이동수단. 도중에 바꿔도 기록에는 시작 시점 값을 남긴다.
    private(set) var transport: TransportMode = .car

    private var samples: [TripSample] = []
    private var distanceAnchor: CLLocation?
    private var altitudeAnchor: Double?
    private var lastSampleAt: Date?
    private var lastSampleLocation: CLLocation?

    /// 경로를 너무 촘촘히 남기면 파일만 커진다. 이 두 조건 중 하나는 넘겨야 한 점을 남긴다.
    private let minSampleInterval: TimeInterval = 2
    private let minSampleDistance: CLLocationDistance = 5
    private let usableVerticalAccuracy: CLLocationAccuracy = 15

    /// 측정 중 경과 시간. 화면 갱신은 LocationService의 1초 시계가 이끈다.
    func elapsed(now: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        return now.timeIntervalSince(startedAt)
    }

    var averageSpeed: Double {
        guard let startedAt else { return 0 }
        let duration = Date().timeIntervalSince(startedAt)
        guard duration > 1, distance > 0 else { return 0 }
        return distance / duration
    }

    // MARK: - 제어

    func start(transport: TransportMode, from location: CLLocation?) {
        guard !isRecording else { return }
        isRecording = true
        startedAt = .now
        self.transport = transport

        distance = 0
        maxSpeed = 0
        elevationGain = 0
        elevationLoss = 0
        sampleCount = 0
        samples = []
        distanceAnchor = location
        altitudeAnchor = nil
        lastSampleAt = nil
        lastSampleLocation = nil

        if let location { append(location, force: true) }
    }

    /// 측정을 끝내고 기록을 만든다. 점이 거의 없으면 저장할 게 없으므로 nil.
    func stop(destinationName: String?) -> TripRecord? {
        guard isRecording, let startedAt else { return nil }
        isRecording = false
        self.startedAt = nil

        defer { samples = [] }
        guard samples.count >= 2 else { return nil }

        return TripRecord(id: UUID(),
                          startedAt: startedAt,
                          endedAt: .now,
                          transport: transport,
                          distance: distance,
                          maxSpeed: maxSpeed,
                          elevationGain: elevationGain,
                          elevationLoss: elevationLoss,
                          destinationName: destinationName,
                          samples: samples)
    }

    func cancel() {
        isRecording = false
        startedAt = nil
        samples = []
    }

    // MARK: - 수집

    /// 새 위치가 들어올 때마다 호출한다.
    func ingest(_ location: CLLocation, smoothedSpeed: Double) {
        guard isRecording else { return }

        accumulateDistance(to: location)
        accumulateElevation(from: location)
        maxSpeed = max(maxSpeed, max(location.speed, 0))
        append(location, force: false, speed: smoothedSpeed)
    }

    private func append(_ location: CLLocation, force: Bool, speed: Double? = nil) {
        guard let startedAt else { return }

        if !force {
            let farEnough = lastSampleLocation.map {
                location.distance(from: $0) >= minSampleDistance
            } ?? true
            let longEnough = lastSampleAt.map {
                location.timestamp.timeIntervalSince($0) >= minSampleInterval
            } ?? true
            guard farEnough || longEnough else { return }
        }

        let altitude = (location.verticalAccuracy >= 0
                        && location.verticalAccuracy <= usableVerticalAccuracy)
            ? location.altitude : nil

        samples.append(TripSample(t: location.timestamp.timeIntervalSince(startedAt),
                                  lat: location.coordinate.latitude,
                                  lon: location.coordinate.longitude,
                                  speed: speed ?? max(location.speed, 0),
                                  altitude: altitude))
        sampleCount = samples.count
        lastSampleAt = location.timestamp
        lastSampleLocation = location
    }

    /// 앵커 방식. 잡음 수준을 넘어설 만큼 멀어졌을 때만 거리를 확정한다.
    private func accumulateDistance(to location: CLLocation) {
        guard let anchor = distanceAnchor else {
            distanceAnchor = location
            return
        }
        let delta = location.distance(from: anchor)
        let elapsed = location.timestamp.timeIntervalSince(anchor.timestamp)
        // 물리적으로 불가능한 순간 이동은 버리고 앵커만 옮긴다.
        if elapsed > 0, delta / elapsed > 111 {
            distanceAnchor = location
            return
        }
        let noise = max((anchor.horizontalAccuracy + location.horizontalAccuracy) / 2, 2)
        guard delta > noise else { return }
        distance += delta
        distanceAnchor = location
    }

    private func accumulateElevation(from location: CLLocation) {
        guard location.verticalAccuracy >= 0,
              location.verticalAccuracy <= usableVerticalAccuracy else { return }
        let altitude = location.altitude
        guard let anchor = altitudeAnchor else {
            altitudeAnchor = altitude
            return
        }
        let delta = altitude - anchor
        guard abs(delta) > max(location.verticalAccuracy, 3) else { return }
        if delta > 0 { elevationGain += delta } else { elevationLoss -= delta }
        altitudeAnchor = altitude
    }
}
