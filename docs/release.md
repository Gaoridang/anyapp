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

GitHub Actions에서 **TestFlight** 워크플로를 수동 실행하면 Fastlane `beta` lane이 빌드 번호를 아래 규칙으로 설정합니다.

```
TARGET_BUILD_NUMBER(입력 시) 또는 max(GITHUB_RUN_NUMBER, TestFlight 최신 빌드 번호 + 1)
```

워크플로 실행 시 `build_number` 입력란에 `40`처럼 지정하면 해당 번호로 업로드합니다. 비워 두면 자동 증가합니다.

로직은 [`fastlane/Fastfile`](../fastlane/Fastfile)의 `next_build_number`에 있습니다.

**수동으로 올리지 않습니다.** TestFlight 워크플로 실행 시 CI가 처리합니다. `main` push만으로는 TestFlight에 배포되지 않습니다.

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
폰에서 확인할 때
         → main 머지 (필요 시)
         → ./scripts/trigger_testflight.sh   ← 권장 (CLI/에이전트)
         또는 GitHub Actions → TestFlight → Run workflow
         → fastlane beta
         → 빌드 번호 자동 증가
         → 빌드 & TestFlight 업로드
         → CI 완료 (GitHub Actions 성공)
         → Apple 빌드 처리 (1~5분, TestFlight 앱에서 확인)
         → TestFlight에서 설치 가능
```

`main`에 코드를 push/merge해도 TestFlight 워크플로는 자동으로 실행되지 않습니다.

## TestFlight 트리거 (CLI / Cloud Agent)

**권장:** [`scripts/trigger_testflight.sh`](../scripts/trigger_testflight.sh) — `repository_dispatch`로 워크플로를 실행합니다.

```bash
# 빌드 번호 자동 증가
./scripts/trigger_testflight.sh

# 특정 빌드 번호 지정 (예: 40)
./scripts/trigger_testflight.sh 40

# 실행 상태 확인
gh run list --workflow=testflight.yml --limit 3
```

**`gh workflow run`은 사용하지 않습니다.** Cloud Agent 등 일부 GitHub 토큰은 `workflow_dispatch` 권한이 없어 `HTTP 403`이 납니다. `repository_dispatch`는 위 스크립트로 안정적으로 동작합니다.

GitHub Actions UI에서 **Run workflow**를 누르는 방식(`workflow_dispatch`)은 사람이 수동으로 실행할 때 그대로 사용 가능합니다.

## Cloud Agent 배포 런북

사용자가 **머지 + TestFlight 배포**를 요청했을 때:

1. **PR을 draft로 만들지 않습니다.** draft PR은 머지할 수 없습니다. 이미 draft이면 `gh pr ready <번호>` 후 진행합니다.
2. PR을 `main`에 머지합니다.
3. `main`을 pull한 뒤 `./scripts/trigger_testflight.sh`로 배포를 트리거합니다. (`gh workflow run` 사용 금지)
4. `gh run list --workflow=testflight.yml --limit 1`로 run ID를 확인하고, `gh run view <id> --json conclusion,status`로 완료 여부를 확인합니다.
5. CI success 후 TestFlight 앱 반영까지 **1~5분** 추가 대기가 필요할 수 있음을 사용자에게 안내합니다.

## CI 최적화

TestFlight 워크플로우는 아래 최적화가 적용되어 있습니다.

- **Apple 처리 대기 스킵** — CI는 업로드 직후 완료
- **DerivedData 캐시** — 2회차 이후 빌드 시간 단축
- **수동 배포** — `workflow_dispatch` 또는 `repository_dispatch`로 실행 (`main` push와 분리)
- **CI 빌드 플래그** — `ENABLE_PREVIEWS=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`
- **90382 사전 검사** — 24시간 내 업로드가 많으면 빌드 전에 CI 실패 (runner 시간 절약)
- **90382 처리** — 업로드 단계에서 Apple 한도(90382)에 걸리면 CI를 **실패**로 표시

## TestFlight 업로드 한도 (90382)

Apple은 앱당 하루 업로드 횟수에 제한이 있습니다. 짧은 시간에 TestFlight 워크플로를 여러 번 실행하면 `Upload limit reached (90382)` 오류가 날 수 있습니다.

**Apple 90382 한도는 우회할 수 없습니다.** 한도가 풀릴 때까지(보통 ~24시간) 기다린 뒤 워크플로를 다시 실행해야 합니다.

| 상황 | CI 결과 | 조치 |
|---|---|---|
| 24시간 내 업로드 과다 (사전 검사) | **실패** (빌드 생략) | ~24시간 후 워크플로 재실행 |
| 90382 (Apple 일일 한도) | **실패** (업로드 실패) | ~24시간 후 워크플로 재실행 |

환경 변수 (Fastfile):

- `TARGET_BUILD_NUMBER` — 워크플로 `build_number` 입력값 (예: `40`)
- `TESTFLIGHT_MAX_UPLOADS_PER_24H` — 사전 검사 임계값 (기본 `10`)

## 관련 파일

- [`anyapp.xcodeproj/project.pbxproj`](../anyapp.xcodeproj/project.pbxproj) — `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
- [`fastlane/Fastfile`](../fastlane/Fastfile) — 빌드 번호 자동 증가 로직
- [`scripts/trigger_testflight.sh`](../scripts/trigger_testflight.sh) — TestFlight 트리거 (`repository_dispatch`, CLI/에이전트 권장)
- [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml) — TestFlight 수동 배포 (`workflow_dispatch`, UI용)
- [`.github/workflows/ci-verify.yml`](../.github/workflows/ci-verify.yml) — CI 설정 검증
