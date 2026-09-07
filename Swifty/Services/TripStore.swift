import Foundation
import Observation

/// 기록을 디스크에 보관한다.
///
/// 기록 하나당 파일 하나로 저장해서, 새 기록을 추가하거나 하나만 지울 때
/// 전체를 다시 쓰지 않아도 되게 했다.
@MainActor
@Observable
final class TripStore {

    /// 최근 기록이 앞에 온다.
    private(set) var records: [TripRecord] = []
    private(set) var loadError: String?

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Trips", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    // MARK: - 읽기

    func load() {
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)

            records = files
                .filter { $0.pathExtension == "json" }
                .compactMap { url in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(TripRecord.self, from: data)
                }
                .sorted { $0.startedAt > $1.startedAt }
            loadError = nil
        } catch {
            records = []
            loadError = "기록을 불러오지 못했습니다."
        }
    }

    // MARK: - 쓰기

    func add(_ record: TripRecord) {
        records.insert(record, at: 0)
        write(record)
    }

    func delete(_ record: TripRecord) {
        records.removeAll { $0.id == record.id }
        try? FileManager.default.removeItem(at: url(for: record.id))
    }

    func delete(atOffsets offsets: IndexSet) {
        for index in offsets {
            guard records.indices.contains(index) else { continue }
            try? FileManager.default.removeItem(at: url(for: records[index].id))
        }
        records.remove(atOffsets: offsets)
    }

    private func write(_ record: TripRecord) {
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: url(for: record.id), options: .atomic)
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
