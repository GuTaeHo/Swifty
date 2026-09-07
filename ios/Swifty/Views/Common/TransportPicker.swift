import SwiftUI

/// 이동수단을 아이콘으로 고르는 가로 선택기.
struct TransportPicker: View {

    @Binding var selection: TransportMode
    /// 선택된 이동수단 기준 현재 속도 비율 (0~1). 아이콘 애니메이션 속도를 결정한다.
    var speedFraction: Double

    @Environment(\.palette) private var palette
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TransportMode.allCases) { mode in
                item(mode)
            }
        }
        .padding(3)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("이동수단")
    }

    private func item(_ mode: TransportMode) -> some View {
        let isSelected = selection == mode
        return Button {
            Haptics.selection()
            withAnimation(.snappy(duration: 0.25)) { selection = mode }
        } label: {
            AnimatedTransportIcon(mode: mode,
                                  speedFraction: speedFraction,
                                  isActive: isSelected,
                                  size: 16)
                .foregroundStyle(isSelected ? palette.accent : Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(palette.accent.opacity(0.16))
                        .matchedGeometryEffect(id: "transport", in: highlight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
