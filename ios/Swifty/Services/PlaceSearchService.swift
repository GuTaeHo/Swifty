import Foundation
import MapKit
import Observation

/// 목적지 검색. 입력 중에는 MKLocalSearchCompleter로 자동완성을 보여주고,
/// 항목을 고르면 MKLocalSearch로 실제 좌표를 가져온다. 둘 다 네트워크가 필요하다.
@MainActor
@Observable
final class PlaceSearchService: NSObject {

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var results: [MKMapItem] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                suggestions = []
                results = []
                errorMessage = nil
                completer.cancel()
            } else {
                completer.queryFragment = trimmed
            }
        }
    }

    private let completer = MKLocalSearchCompleter()
    private var searchTask: Task<Void, Never>?
    /// 검색 결과를 현재 위치 주변으로 편향시키기 위한 영역.
    private var region: MKCoordinateRegion?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address, .query]
    }

    /// 현재 위치가 정해지면 검색 영역을 갱신한다.
    func updateRegion(center: CLLocationCoordinate2D?) {
        guard let center else { return }
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: 50_000,
                                        longitudinalMeters: 50_000)
        self.region = region
        completer.region = region
    }

    func reset() {
        query = ""
        suggestions = []
        results = []
        errorMessage = nil
        isSearching = false
        searchTask?.cancel()
        searchTask = nil
        completer.cancel()
    }

    /// 자동완성 항목을 실제 지점으로 해석한다.
    func resolve(_ completion: MKLocalSearchCompletion) async -> Destination? {
        let request = MKLocalSearch.Request(completion: completion)
        if let region { request.region = region }
        return await runSearch(request)
    }

    /// 검색어를 그대로 검색해 여러 결과를 채운다.
    func searchCurrentQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        searchTask?.cancel()
        isSearching = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        if let region { request.region = region }

        searchTask = Task { [weak self] in
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.results = response.mapItems
                    self?.isSearching = false
                    if response.mapItems.isEmpty {
                        self?.errorMessage = "검색 결과가 없습니다."
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    self?.isSearching = false
                    self?.errorMessage = "검색에 실패했습니다. 네트워크 연결을 확인하세요."
                }
            }
            await MainActor.run { self?.searchTask = nil }
        }
    }

    private func runSearch(_ request: MKLocalSearch.Request) async -> Destination? {
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else {
                errorMessage = "검색 결과가 없습니다."
                return nil
            }
            return Destination(mapItem: item)
        } catch {
            errorMessage = "검색에 실패했습니다. 네트워크 연결을 확인하세요."
            return nil
        }
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension PlaceSearchService: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
            self.errorMessage = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            // 입력 중 취소로 인한 실패는 사용자에게 보여줄 필요가 없다.
            self.suggestions = []
        }
    }
}
