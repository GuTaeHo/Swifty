import SwiftUI

/// 저장된 측정 기록 목록.
struct HistoryListView: View {

    var store: TripStore
    var unit: UnitSystem

    @Environment(\.palette) private var palette
    @State private var editMode: EditMode = .inactive

    var body: some View {
        Group {
            if store.records.isEmpty {
                ContentUnavailableView {
                    Label("기록이 없습니다", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("계기판 화면 오른쪽 위의 측정 버튼을 눌러 시작하면\n주행이 여기에 저장됩니다.")
                }
            } else {
                List {
                    ForEach(store.records) { record in
                        NavigationLink {
                            HistoryDetailView(record: record, unit: unit)
                        } label: {
                            row(record)
                        }
                    }
                    .onDelete {
                        Haptics.light()
                        store.delete(atOffsets: $0)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            if !store.records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.selection()
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode.isEditing ? "checkmark" : "pencil")
                            .font(.headline)
                    }
                    .tint(palette.accent)
                    .accessibilityLabel(editMode.isEditing ? "편집 완료" : "기록 편집")
                }
            }
        }
    }

    private func row(_ record: TripRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.transport.symbol)
                .font(.title3)
                .foregroundStyle(palette.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: 10) {
                    label("road.lanes", Fmt.distance(record.distance,
                                                      unit: unit,
                                                      transport: record.transport))
                    label("clock", Fmt.elapsed(record.duration))
                    label("speedometer",
                          "\(Int(unit.speed(fromMetersPerSecond: record.maxSpeed).rounded())) \(unit.speedSymbol)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func label(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(text)
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(Theme.secondaryText)
    }
}
