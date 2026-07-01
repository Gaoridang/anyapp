# 릴리스 및 버전 관리

## 요약

| 항목 | 필드 | 관리 방식 | 원천 |
|---|---|---|---|
| 앱 버전 | `MARKETING_VERSION` | 수동 변경 | `anyapp.xcodeproj/project.pbxproj` |
| 빌드 번호 | `CURRENT_PROJECT_VERSION` | CI 자동 증가 | `fastlane/Fastfile` (`next_build_number`) |

소스 코드의 `CURRENT_PROJECT_VERSION` 값(현재 `1`)은 로컬 기본값일 뿐이며, TestFlight에 올라가는 실제 빌드 번호와 다를 수 있습니다.

## 앱 버전 (`MARKETING_VERSION`)

사용자에게 보이는 버전입니다. TestFlight와 App Store에 `1.0`, `1.1`처럼 표시됩니다.

**올리는 시점 예시**

- 사용자에게 의미 있는 기능 추가 (예: 오디오 메모 출시)
- UI/UX 대규모 변경
- App Store 정식 출시 준비

**변경 방법**

Xcode에서 Target → General → Version을 수정하거나, `anyapp.xcodeproj/project.pbxproj`의 `MARKETING_VERSION`을 변경합니다.

## 빌드 번호 (`CURRENT_PROJECT_VERSION`)

같은 앱 버전 안에서 빌드를 구분하는 번호입니다. TestFlight에서 `1.0 (9)`의 `(9)`에 해당합니다.

**자동 관리**

`main`에 push되면 GitHub Actions가 Fastlane `beta` lane을 실행하고, 빌드 번호를 아래 규칙으로 설정합니다.

```
max(GITHUB_RUN_NUMBER, TestFlight 최신 빌드 번호 + 1)
```

로직은 [`fastlane/Fastfile`](../fastlane/Fastfile)의 `next_build_number`에 있습니다.

**수동으로 올리지 않습니다.** `main` 머지마다 CI가 처리합니다.

## 현재 빌드 확인

1. **GitHub Actions** — `TestFlight` 워크플로우 실행 로그에서 `agvtool new-version -all N` 또는 `Latest upload ... is build: N` 확인
2. **TestFlight 앱** — Apple 처리 완료 후 표시되는 빌드 번호 확인

## 배포 흐름

```
main push → GitHub Actions (TestFlight workflow)
         → fastlane beta
         → 빌드 번호 자동 증가
         → 빌드 & TestFlight 업로드
         → Apple 빌드 처리 (수 분 소요)
         → TestFlight에서 설치 가능
```

## 관련 파일

- [`anyapp.xcodeproj/project.pbxproj`](../anyapp.xcodeproj/project.pbxproj) — `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
- [`fastlane/Fastfile`](../fastlane/Fastfile) — 빌드 번호 자동 증가 로직
- [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) — CI 트리거 (`main` push)
