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

`main`에 앱/배포 관련 변경이 push되면 GitHub Actions가 Fastlane `beta` lane을 실행하고, 빌드 번호를 아래 규칙으로 설정합니다.

```
max(GITHUB_RUN_NUMBER, TestFlight 최신 빌드 번호 + 1)
```

로직은 [`fastlane/Fastfile`](../fastlane/Fastfile)의 `next_build_number`에 있습니다.

**수동으로 올리지 않습니다.** CI가 처리합니다. 문서만 변경된 push는 TestFlight 워크플로우를 트리거하지 않습니다.

## CI 완료 vs TestFlight 설치 가능

이 두 시점은 다릅니다.

| 시점 | 의미 | 예상 소요 |
|---|---|---|
| **CI 완료** | GitHub Actions가 빌드·업로드까지 성공 | 약 3~6분 (runner 큐 대기 포함) |
| **TestFlight 설치 가능** | Apple 서버 처리 완료 후 TestFlight 앱에 표시 | CI 완료 후 추가 1~5분 |

CI는 업로드 직후 완료됩니다 (`skip_waiting_for_build_processing: true`). TestFlight 앱에서 빌드가 보이고 설치 가능해지기까지는 Apple 측 처리 시간이 추가로 필요합니다.

## 현재 빌드 확인

1. **GitHub Actions** — `TestFlight` 워크플로우 실행 로그에서 `agvtool new-version -all N` 또는 `Latest upload ... is build: N` 확인
2. **TestFlight 앱** — Apple 처리 완료 후 표시되는 빌드 번호 확인

## 배포 흐름

```
main push (앱/배포 경로 변경 시)
         → GitHub Actions (TestFlight workflow)
         → fastlane beta
         → 빌드 번호 자동 증가
         → 빌드 & TestFlight 업로드
         → CI 완료 (GitHub Actions 성공)
         → Apple 빌드 처리 (1~5분, TestFlight 앱에서 확인)
         → TestFlight에서 설치 가능
```

## CI 최적화

TestFlight 워크플로우는 아래 최적화가 적용되어 있습니다.

- **Apple 처리 대기 스킵** — CI는 업로드 직후 완료
- **DerivedData 캐시** — 2회차 이후 빌드 시간 단축
- **경로 필터** — `anyapp/`, `fastlane/` 등 배포 관련 변경 시에만 실행
- **CI 빌드 플래그** — `ENABLE_PREVIEWS=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`
- **업로드 스로틀** — 24시간 내 업로드 횟수·최소 간격을 초과하면 빌드/업로드를 건너뜀 (Apple 90382 한도 방지)
- **90382 처리** — Apple 일일 업로드 한도에 걸리면 CI를 실패로 표시하지 않고 안내 메시지와 함께 종료

## TestFlight 업로드 한도 (90382)

Apple은 앱당 하루 업로드 횟수에 제한이 있습니다. 짧은 시간에 여러 번 merge하면 `Upload limit reached (90382)` 오류가 날 수 있습니다.

| 상황 | CI 결과 | 조치 |
|---|---|---|
| 스로틀에 걸림 (최근 업로드 많음) | 성공 (업로드 생략) | 한도가 풀린 뒤 Actions에서 **TestFlight** 워크플로 → **Run workflow** → `force_upload` 체크 |
| 90382 (Apple 일일 한도) | 성공 (업로드 생략) | 24시간 후 `force_upload`로 재시도 |

환경 변수 (Fastfile 기본값):

- `TESTFLIGHT_MAX_UPLOADS_PER_24H` — 기본 `8`
- `TESTFLIGHT_MIN_UPLOAD_INTERVAL_MINUTES` — 기본 `20`
- `FORCE_TESTFLIGHT_UPLOAD=true` — 스로틀 무시 (수동 재배포용)

## 관련 파일

- [`anyapp.xcodeproj/project.pbxproj`](../anyapp.xcodeproj/project.pbxproj) — `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
- [`fastlane/Fastfile`](../fastlane/Fastfile) — 빌드 번호 자동 증가 로직
- [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) — CI 트리거 (경로 필터 + `workflow_dispatch`)
- [`.github/workflows/ci-verify.yml`](../.github/workflows/ci-verify.yml) — CI 설정 검증
