import SwiftUI

/// 화면 모드, 강조 색상, 단위계를 한곳에서 바꾼다.
struct SettingsSheet: View {

    @Bindable var appState: AppState

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 14)]

    var body: some View {
        NavigationStack {
            Form {
                Section("화면 모드") {
                    Picker("화면 모드", selection: $appState.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(AccentPalette.allCases) { option in
                            swatch(option)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("강조 색상")
                } footer: {
                    Text("속도 게이지, 나침반, 버튼 등 앱 전체의 강조 색이 바뀝니다.")
                }

                Section("단위계") {
                    Picker("단위계", selection: $appState.unitSystem) {
                        ForEach(UnitSystem.allCases) { system in
                            Text(system.title).tag(system)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle("화면 항상 켜기", isOn: $appState.keepScreenAwake)
                    Toggle("촉각 피드백", isOn: $appState.hapticsEnabled)
                } footer: {
                    Text("화면 항상 켜기는 주행 중 화면이 자동으로 꺼지지 않게 합니다. 촉각 피드백은 속도 구간을 넘어설 때와 버튼을 누를 때 진동으로 알립니다.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(palette.accent)
        .onChange(of: appState.appearance) { Haptics.selection() }
        .onChange(of: appState.unitSystem) { Haptics.selection() }
        .onChange(of: appState.keepScreenAwake) { Haptics.light() }

        .onChange(of: appState.hapticsEnabled) { _, on in if on { Haptics.light() } }
    }

    private func swatch(_ option: AccentPalette) -> some View {
        let isSelected = appState.accent == option
        return Button {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.18)) { appState.accent = option }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(option.color, lineWidth: 2)
                        .padding(-5)
                        .opacity(isSelected ? 1 : 0)
                )
                Text(option.title)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? option.color : Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
