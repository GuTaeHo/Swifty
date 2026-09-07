import SwiftUI
import MapKit

/// 목적지 검색 시트. 입력 중에는 자동완성, 검색 실행 시에는 지점 목록을 보여준다.
struct DestinationSearchSheet: View {

    @Bindable var search: PlaceSearchService
    var unit: UnitSystem
    var transport: TransportMode
    /// 거리 표시용 현재 위치.
    var origin: CLLocation?
    var onSelect: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            List {
                if let message = search.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .listRowBackground(Color.clear)
                }

                if !search.results.isEmpty {
                    Section("검색 결과") {
                        ForEach(search.results, id: \.self) { item in
                            Button {
                                choose(Destination(mapItem: item))
                            } label: {
                                resultRow(name: item.name ?? "이름 없는 지점",
                                          subtitle: item.placemark.title,
                                          coordinate: item.placemark.coordinate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !search.suggestions.isEmpty {
                    Section("추천") {
                        ForEach(search.suggestions, id: \.self) { suggestion in
                            Button {
                                resolve(suggestion)
                            } label: {
                                resultRow(name: suggestion.title,
                                          subtitle: suggestion.subtitle.isEmpty ? nil : suggestion.subtitle,
                                          coordinate: nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if search.suggestions.isEmpty && search.results.isEmpty && search.errorMessage == nil {
                    ContentUnavailableView("목적지 검색",
                                           systemImage: "magnifyingglass",
                                           description: Text("장소 이름이나 주소를 입력하세요.\n지도를 길게 눌러 직접 찍을 수도 있습니다."))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("목적지 검색")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "장소, 주소")
            .onSubmit(of: .search) { search.searchCurrentQuery() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
            .overlay {
                if isResolving || search.isSearching {
                    ProgressView().controlSize(.large)
                }
            }
        }
        .tint(palette.accent)
    }

    private func resultRow(name: String, subtitle: String?, coordinate: CLLocationCoordinate2D?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let coordinate, let origin {
                let meters = origin.distance(from: CLLocation(latitude: coordinate.latitude,
                                                              longitude: coordinate.longitude))
                Text(Fmt.distance(meters, unit: unit, transport: transport))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .contentShape(Rectangle())
    }

    private func choose(_ destination: Destination) {
        onSelect(destination)
        dismiss()
    }

    private func resolve(_ suggestion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            let destination = await search.resolve(suggestion)
            isResolving = false
            if let destination { choose(destination) }
        }
    }
}
