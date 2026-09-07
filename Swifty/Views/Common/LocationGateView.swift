import SwiftUI
import CoreLocation

/// 위치 권한이 없을 때 대신 보여주는 안내 화면.
struct LocationGateView: View {

    var status: CLAuthorizationStatus
    var onRequest: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.warning)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if status == .notDetermined {
                Button(action: onRequest) {
                    Text("위치 사용 허용")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: url) {
                    Text("설정 열기")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var title: String {
        status == .notDetermined ? "위치 권한이 필요합니다" : "위치 접근이 꺼져 있습니다"
    }

    private var message: String {
        switch status {
        case .notDetermined:
            "속도, 방향, 고도, 남은 거리를 계산하려면 위치 정보가 필요합니다. 위치는 기기 안에서만 쓰이고 어디에도 전송되지 않습니다."
        case .denied:
            "설정 > 개인정보 보호 및 보안 > 위치 서비스에서 Swifty의 위치 접근을 허용해 주세요."
        case .restricted:
            "기기 제한 설정 때문에 위치를 사용할 수 없습니다."
        default:
            ""
        }
    }
}

/// 오프라인 등으로 GPS 신호가 약할 때 화면 위에 띄우는 알림 배너.
struct StatusBanner: View {

    var text: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        // 지도 위에 겹쳐도 읽히도록 불투명한 바탕을 먼저 깐다.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
