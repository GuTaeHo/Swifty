import Foundation
import Network
import Observation

/// 네트워크 연결 상태 감시.
///
/// MapKit은 공개 API로 오프라인 지도 다운로드를 지원하지 않기 때문에
/// (iOS 18의 오프라인 지도는 Apple 지도 앱 전용이다) 연결이 끊기면
/// 지도 모드를 비활성화하고 계기판 모드만 쓰도록 안내하는 데 쓴다.
@MainActor
@Observable
final class NetworkMonitor {

    private(set) var isOnline = true
    private(set) var isExpensive = false
    /// 저데이터 모드 등으로 사용자가 데이터 절약을 요청한 상태.
    private(set) var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gutaeho.Swifty.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // 콜백은 임의의 큐에서 오므로 값만 꺼내 메인 액터로 넘긴다.
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isOnline = online
                self.isExpensive = expensive
                self.isConstrained = constrained
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
