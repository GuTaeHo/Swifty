import Foundation
import CoreLocation
import MapKit
import Observation

/// 목적지까지 남은 거리·시간을 계산한다.
///
/// 온라인이면 MKDirections로 실제 도로 경로를 받아 쓰고, 그 경로는 메모리에 남는다.
/// 따라서 경로를 한 번 받아둔 뒤 연결이 끊겨도 폴리라인 위 투영으로 남은 거리를
/// 계속 정확하게 갱신할 수 있다. 경로가 아예 없으면 직선 거리로 대체한다.
@MainActor
@Observable
final class NavigationService {

    /// 남은 거리·시간을 무엇으로 계산했는지. UI에서 신뢰도를 표시하는 데 쓴다.
    enum EstimateSource {
        case route          // 실제 도로 경로
        case cachedRoute    // 오프라인이지만 이전에 받아둔 경로를 따라가는 중
        case straightLine   // 경로 없음: 직선 거리 기반 근사

        var label: String {
            switch self {
            case .route: "도로 경로"
            case .cachedRoute: "저장된 경로"
            case .straightLine: "직선 거리"
            }
        }
    }

    struct Estimate {
        var distance: CLLocationDistance
        var time: TimeInterval
        var source: EstimateSource
    }

    // MARK: - 상태

    private(set) var destination: Destination? {
        didSet {
            if persistsDestination {
                destination?.persist()
            }
        }
    }
    private(set) var route: MKRoute?
    private(set) var isCalculatingRoute = false
    private(set) var routeErrorMessage: String?
    private(set) var estimate: Estimate?

    /// 지도에서 확정 전 경로를 계산하는 인스턴스는 목적지를 저장하지 않는다.
    private let persistsDestination: Bool

    /// 목적지를 정한 시점(정확히는 그 뒤 첫 유효 fix)의 고도 (m).
    /// iOS에는 임의 좌표의 지형 고도를 조회하는 공개 API가 없어서
    /// 목적지 고도를 직접 알 수는 없다. 대신 이 구간을 시작한 높이를 기준으로
    /// 지금까지의 고도 변화를 보여준다.
    private(set) var legStartAltitude: Double?
    /// 출발 대비 현재 고도차 (m). 위로 올라왔으면 양수.
    private(set) var elevationChange: Double?

    /// 현재 이동수단. 경로 종류와 순항 속도, 이탈 판정 기준을 결정한다.
    var transport: TransportMode = .car {
        didSet {
            guard transport != oldValue else { return }
            // 이동수단이 바뀌면 이전 경로는 더 이상 맞지 않는다.
            cancelRouteRequest()
            clearRoute()
            routeErrorMessage = nil
        }
    }

    var hasDestination: Bool { destination != nil }

    // MARK: - 내부

    /// 경로 폴리라인의 좌표와, 각 점에서 목적지까지 남은 거리의 누적표.
    private var routePoints: [CLLocationCoordinate2D] = []
    private var remainingFromIndex: [CLLocationDistance] = []
    private var routeTotalDistance: CLLocationDistance = 0
    private var routeTotalTime: TimeInterval = 0

    private var lastRouteOrigin: CLLocation?
    private var lastRouteDate: Date?
    private var routeTask: Task<Void, Never>?
    private var activeRouteRequestID: UUID?

    /// 경로를 다시 계산할 조건.
    private let recalculateAfter: TimeInterval = 25
    private let recalculateWhenMoved: CLLocationDistance = 300
    /// 경로가 아예 성립하지 않는 이동수단(비행기)인지.
    private var routingUnavailable: Bool { transport.directionsTransportType == nil }

    init(restoresPersistedDestination: Bool = true) {
        persistsDestination = restoresPersistedDestination
        destination = restoresPersistedDestination ? Destination.loadPersisted() : nil
    }

    // MARK: - 목적지 조작

    func setDestination(_ new: Destination, from origin: CLLocation?, online: Bool) {
        cancelRouteRequest()
        destination = new
        legStartAltitude = nil
        elevationChange = nil
        clearRoute()
        routeErrorMessage = nil
        update(from: origin, speed: 0, online: online)
        if online, !routingUnavailable, let origin {
            requestRoute(from: origin, force: true)
        }
    }

    func clearDestination() {
        cancelRouteRequest()
        destination = nil
        estimate = nil
        legStartAltitude = nil
        elevationChange = nil
        routeErrorMessage = nil
        clearRoute()
        if persistsDestination {
            Destination.clearPersisted()
        }
    }

    private func cancelRouteRequest() {
        routeTask?.cancel()
        routeTask = nil
        activeRouteRequestID = nil
        isCalculatingRoute = false
    }

    private func clearRoute() {
        route = nil
        routePoints = []
        remainingFromIndex = []
        routeTotalDistance = 0
        routeTotalTime = 0
        lastRouteOrigin = nil
        lastRouteDate = nil
    }

    // MARK: - 주기적 갱신

    /// 위치가 갱신될 때마다 호출한다. 남은 거리·시간을 다시 계산하고,
    /// 필요하면 백그라운드로 경로를 새로 요청한다.
    func update(from origin: CLLocation?, speed: Double, online: Bool) {
        guard let destination, let origin else {
            estimate = nil
            return
        }

        updateElevation(from: origin)

        if routePoints.count >= 2 {
            let (remaining, deviation) = remainingAlongRoute(from: origin.coordinate)
            let fraction = routeTotalDistance > 0 ? remaining / routeTotalDistance : 0
            let time = timeEstimate(distance: remaining,
                                    routeTime: routeTotalTime * fraction,
                                    speed: speed)
            estimate = Estimate(distance: remaining,
                                time: time,
                                source: online ? .route : .cachedRoute)

            if online, deviation > transport.offRouteThreshold {
                requestRoute(from: origin, force: true)
                return
            }
        } else {
            let straight = origin.distance(from: destination.clLocation)
            estimate = Estimate(distance: straight,
                                time: timeEstimate(distance: straight, routeTime: nil, speed: speed),
                                source: .straightLine)
        }

        if online, !routingUnavailable {
            requestRoute(from: origin, force: false)
        }
    }

    /// 이 구간의 기준 고도를 잡고, 그 뒤로는 현재 고도와의 차이를 갱신한다.
    private func updateElevation(from origin: CLLocation) {
        // 수직 정확도가 나쁜 fix로 기준을 잡으면 구간 내내 값이 틀어진다.
        guard origin.verticalAccuracy >= 0, origin.verticalAccuracy <= 15 else { return }

        guard let start = legStartAltitude else {
            legStartAltitude = origin.altitude
            elevationChange = 0
            return
        }
        elevationChange = origin.altitude - start
    }

    /// 도로 경로의 남은 시간이 있으면 그것을 쓰되, 실제 주행 속도가 있으면 섞어서 보정한다.
    private func timeEstimate(distance: CLLocationDistance,
                              routeTime: TimeInterval?,
                              speed: Double) -> TimeInterval {
        if let routeTime, routeTime > 0 {
            guard speed > 1 else { return routeTime }
            let bySpeed = distance / speed
            // 경로 예상치와 현재 속도 기반 추정을 7:3으로 섞는다.
            return routeTime * 0.7 + bySpeed * 0.3
        }
        let effective = speed > 1 ? speed : transport.cruiseSpeedMetersPerSecond
        return distance / effective
    }

    // MARK: - 경로 계산

    private func shouldRecalculate(from origin: CLLocation, force: Bool) -> Bool {
        if force { return true }
        guard route != nil else { return lastRouteDate == nil || Date().timeIntervalSince(lastRouteDate!) > 10 }
        guard let lastOrigin = lastRouteOrigin, let lastDate = lastRouteDate else { return true }
        if Date().timeIntervalSince(lastDate) < 8 { return false }
        return origin.distance(from: lastOrigin) > recalculateWhenMoved
            || Date().timeIntervalSince(lastDate) > recalculateAfter
    }

    private func requestRoute(from origin: CLLocation, force: Bool) {
        guard let destination, let transportType = transport.directionsTransportType else { return }
        guard shouldRecalculate(from: origin, force: force) else { return }
        guard routeTask == nil else { return }

        lastRouteOrigin = origin
        lastRouteDate = Date()
        isCalculatingRoute = true
        let requestID = UUID()
        activeRouteRequestID = requestID

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = transportType
        request.requestsAlternateRoutes = false

        routeTask = Task { [weak self] in
            defer {
                Task { @MainActor in
                    guard self?.activeRouteRequestID == requestID else { return }
                    self?.isCalculatingRoute = false
                    self?.routeTask = nil
                    self?.activeRouteRequestID = nil
                }
            }
            do {
                let response = try await MKDirections(request: request).calculate()
                guard let best = response.routes.first else { return }
                await MainActor.run {
                    guard self?.activeRouteRequestID == requestID,
                          self?.destination?.id == destination.id else { return }
                    self?.apply(route: best)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard self?.activeRouteRequestID == requestID,
                          self?.destination?.id == destination.id else { return }
                    // 이미 경로가 있으면 그걸 계속 쓰고, 없을 때만 사용자에게 알린다.
                    if self?.route == nil {
                        let mode = self?.transport.title ?? ""
                        self?.routeErrorMessage = "\(mode) 경로를 계산할 수 없습니다. 직선 거리로 표시합니다."
                    }
                }
            }
        }
    }

    private func apply(route newRoute: MKRoute) {
        route = newRoute
        routeErrorMessage = nil
        routeTotalDistance = newRoute.distance
        routeTotalTime = newRoute.expectedTravelTime

        let polyline = newRoute.polyline
        var coordinates = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        routePoints = coordinates

        // 각 점에서 목적지까지 남은 거리를 뒤에서부터 누적한다.
        var remaining = [CLLocationDistance](repeating: 0, count: coordinates.count)
        for index in stride(from: coordinates.count - 2, through: 0, by: -1) {
            let a = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            let b = CLLocation(latitude: coordinates[index + 1].latitude, longitude: coordinates[index + 1].longitude)
            remaining[index] = remaining[index + 1] + a.distance(from: b)
        }
        remainingFromIndex = remaining
    }

    // MARK: - 폴리라인 투영

    /// 현재 위치를 경로에 투영해 (남은 거리, 경로에서 벗어난 거리)를 구한다.
    private func remainingAlongRoute(from coordinate: CLLocationCoordinate2D)
        -> (remaining: CLLocationDistance, deviation: CLLocationDistance) {

        let here = MKMapPoint(coordinate)
        var bestDeviation = CLLocationDistance.greatestFiniteMagnitude
        var bestIndex = 0
        var bestFraction = 0.0

        for index in 0..<(routePoints.count - 1) {
            let a = MKMapPoint(routePoints[index])
            let b = MKMapPoint(routePoints[index + 1])
            let (fraction, squared) = projection(of: here, onSegmentFrom: a, to: b)
            if squared < bestDeviation {
                bestDeviation = squared
                bestIndex = index
                bestFraction = fraction
            }
        }

        // 투영점부터 구간 끝까지 + 구간 끝부터 목적지까지.
        let start = CLLocation(latitude: routePoints[bestIndex].latitude,
                               longitude: routePoints[bestIndex].longitude)
        let end = CLLocation(latitude: routePoints[bestIndex + 1].latitude,
                             longitude: routePoints[bestIndex + 1].longitude)
        let segmentLength = start.distance(from: end)
        let remaining = remainingFromIndex[bestIndex + 1] + segmentLength * (1 - bestFraction)

        // MKMapPoint 거리는 축척이 있으므로 미터로 환산한다.
        let deviationMeters = sqrt(bestDeviation) * MKMetersPerMapPointAtLatitude(coordinate.latitude)
        return (max(0, remaining), deviationMeters)
    }

    /// 점 p를 선분 a-b에 투영한 위치 비율(0~1)과 제곱거리(맵포인트 단위)를 돌려준다.
    private func projection(of p: MKMapPoint, onSegmentFrom a: MKMapPoint, to b: MKMapPoint)
        -> (fraction: Double, squaredDistance: Double) {

        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            let ex = p.x - a.x, ey = p.y - a.y
            return (0, ex * ex + ey * ey)
        }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared
        t = min(max(t, 0), 1)
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        let ex = p.x - projX, ey = p.y - projY
        return (t, ex * ex + ey * ey)
    }
}
