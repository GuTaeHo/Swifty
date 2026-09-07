# Swifty

Swifty는 GPS를 이용해 현재 속도와 이동 정보를 보여주고, 목적지 안내와 이동 기록을 제공하는 iOS·Android 네이티브 앱입니다.

## 주요 기능

현재 iOS와 Android 네이티브 앱에는 다음 기능이 구현되어 있습니다.

- 현재 속도, 방향, 고도 및 페이스 표시
- 디지털·아날로그 계기판
- 도보, 자전거, 자동차, 지하철, 기차, 비행기 이동 모드
- 지도와 장소 검색, 목적지까지의 거리·예상 시간 안내
- 오프라인 상태에서 저장된 경로 또는 직선거리 기반 안내
- 이동 기록 저장과 기록별 거리·속도·고도 확인
- 미터법·야드파운드법, 라이트·다크 모드, 강조 색상 설정
- Android 12 이상에서 배경화면 기반 Material You 동적 색상 사용 (Android)
- 속도 구간 촉각 피드백과 화면 자동 잠금 방지

Android 앱은 Kotlin과 Jetpack Compose로 같은 기능 흐름을 구현하며, 화면 전체가 Material 3 디자인 시스템을 따릅니다. 강조 색상마다 Material 3 색상 역할 전체를 생성해 사용하고, Android 12 이상에서는 시스템 배경화면에서 뽑아낸 동적 색상으로 전환할 수 있습니다. Android 지도는 MapLibre와 OpenFreeMap을 사용하고, 장소 검색은 기기의 Android Geocoder, 도로 경로는 OSRM을 사용합니다. 지도 검색과 새 경로 계산에는 인터넷 연결이 필요하지만 GPS 계기판, 이동 기록, 저장된 목적지와 경로 기반 안내는 오프라인에서도 계속 동작합니다.

> Android의 기본 OSRM 공개 서버 설정은 개발·시험용입니다. 배포 규모가 커지면 자체 OSRM 서버 또는 운영 계약을 맺은 경로 제공자로 교체해야 합니다.

## 프로젝트 구성

```text
Swifty/
├── ios/       # SwiftUI 기반 iOS 앱과 Xcode 프로젝트
├── android/   # Kotlin 및 Jetpack Compose 기반 Android 앱
├── AGENTS.md  # Codex와 Claude의 공통 작업 규칙
├── CLAUDE.md  # AGENTS.md와 동기화되는 공통 작업 규칙
└── README.md
```

두 앱은 플랫폼별 네이티브 소스를 독립적으로 관리합니다.

## 실행 방법

### iOS

요구 사항:

- macOS
- Xcode
- iOS 18 이상 기기 또는 시뮬레이터

`ios/Swifty.xcodeproj`를 Xcode에서 열고 `Swifty` 스킴을 실행합니다.

### Android

요구 사항:

- JDK 17 이상
- Android SDK API 36
- USB 디버깅이 활성화된 Android 기기 또는 에뮬레이터

별도의 지도 API 키는 필요하지 않습니다.

Debug APK 빌드:

```bash
cd android
./gradlew :app:assembleDebug
```

연결된 기기에 빌드하고 설치:

```bash
cd android
adb devices
./gradlew :app:installDebug
```

빌드된 APK는 `android/app/build/outputs/apk/debug/`에서 확인할 수 있습니다.

## 커밋 규칙

커밋 메시지는 아래 형식을 사용합니다.

```text
Type: 한글 요약
```

사용 가능한 타입은 `Fix`, `Feat`, `Chore`, `Refactor`, `Docs`입니다.

예시:

```text
Fix: 도보 페이스 수치 튐 수정
```
