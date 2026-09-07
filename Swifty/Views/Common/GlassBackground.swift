import SwiftUI

/// 지도 위에 떠 있는 원형 버튼의 바탕.
///
/// iOS 26에서는 시스템 유리 재질을 그대로 쓰고, 그 이전 버전에서는
/// 같은 역할을 하는 머티리얼로 대체한다.
struct GlassCircle: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
    }
}

extension View {
    /// 원형 유리 바탕을 입힌다.
    func glassCircle() -> some View {
        modifier(GlassCircle())
    }
}
