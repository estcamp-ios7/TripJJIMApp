# TripJJIMApp 에이전트 작업 지침

이 지침은 저장소 전체에 적용합니다. 팀 Git 협업 규칙도 이 파일에서 관리합니다.

## 프로젝트 개요

여행과 방문 일정을 만들고, 지도에서 장소를 선택하며, 방문 알림을 설정하는 iOS 앱입니다. 앱 코드는 `TripJJIM/`, UI 테스트는 `TripJJIMUITests/`에 있습니다. Xcode 프로젝트는 `TripJJIM.xcodeproj`, Scheme은 `TripJJIM`입니다.

## 빌드와 테스트

Xcode가 설치된 macOS에서 저장소 루트를 기준으로 실행합니다.

```sh
# 시뮬레이터용 빌드
xcodebuild -project TripJJIM.xcodeproj -scheme TripJJIM -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/TripJJIM CODE_SIGNING_ALLOWED=NO build

# 테스트에 사용할 시뮬레이터 UUID 확인
xcrun simctl list devices available
```

아래 `SIMULATOR_UUID`는 위 목록에서 선택한 실제 UUID로 바꿉니다.

```sh
xcodebuild -project TripJJIM.xcodeproj -scheme TripJJIM -configuration Debug \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -derivedDataPath .build/TripJJIM CODE_SIGNING_ALLOWED=NO test
```

빌드 후 앱을 설치하고 실행하려면 `bash scripts/run-simulator.sh SIMULATOR_UUID`를 사용합니다.

## 코드 변경과 보호 대상

- 수정하는 파일의 기존 명명 방식과 들여쓰기를 따릅니다. 관련 없는 전체 포맷 변경은 하지 않습니다.
- `project.pbxproj`, `Trip.swift`, `TripStore.swift`처럼 함께 수정할 가능성이 높은 파일은 작업 전에 팀에 공유합니다. 팀에 보낼 내용은 사용자에게 정리해 전달하고, 메시지 전송은 명시적으로 요청받았을 때 수행합니다.
- 관광 API 키 등 비밀값은 팀에서 정한 비공개 설정에 보관하고 커밋하지 않습니다.
- `.build/`, `DerivedData/`, `xcuserdata/` 등 생성물과 개인 설정은 커밋하지 않습니다.

## Git 협업 규칙

`main`은 팀원이 받아서 바로 빌드하고 실행할 수 있는 브랜치입니다. **작업 하나를 브랜치 하나와 PR 하나로 관리**합니다.

### 작업 대상 확인

Git 작업 전 아래 명령으로 저장소 루트와 원격 주소를 확인합니다. 원격 대상은 `estcamp-ios7/TripJJIMApp`입니다. 현재 폴더가 Git 저장소가 아니면 인접 저장소를 임의로 선택하지 않습니다.

```sh
git rev-parse --show-toplevel
git remote -v
```

### 브랜치

브랜치 이름은 `종류/작업-이름` 형식이며 작업 이름은 소문자 영문과 하이픈으로 짧게 씁니다.

| 종류 | 용도 | 예시 |
| --- | --- | --- |
| `feat/` | 기능 추가 | `feat/tour-api-client` |
| `fix/` | 버그 수정 | `fix/location-feedback` |
| `refactor/` | 동작을 유지하면서 코드 정리 | `refactor/trip-store` |
| `test/` | 테스트 추가·수정 | `test/reminder-lifecycle` |
| `docs/` | 문서 작성·수정 | `docs/git-guide` |
| `chore/` | 프로젝트 설정과 도구 관리 | `chore/xcode-settings` |

새 작업은 최신 `main`에서 시작합니다. 기존 로컬 변경이 있으면 먼저 확인하고 보존합니다.

```sh
git switch main
git pull --ff-only origin main
git switch -c fix/location-feedback
```

서로 연결되는 기능은 먼저 전달 모델을 합의합니다. 예를 들어 관광 API 호출(`feat/tour-api-client`)과 지역·관광지 선택 화면(`feat/tour-place-picker`)은 관광지 이름·위도·경도의 전달 모델을 정한 뒤 나눠 작업합니다. 두 PR 병합 후 최신 `main`에서 일정 저장 연결 작업(`feat/tour-place-to-visit`)을 시작합니다.

### 커밋 메시지

제목은 `타입: 변경 내용` 형식으로 작성합니다. 타입은 아래 소문자 영문을 사용하고, 콜론 뒤에는 공백 하나를 둡니다. 변경 내용은 한국어로 간결하게 작성하되 대상과 달라진 동작을 구체적으로 적습니다.

| 타입 | 사용 기준 | 예시 |
| --- | --- | --- |
| `feat` | 사용자 기능 추가 | `feat: 관광지 검색 결과에서 방문 일정 추가` |
| `fix` | 잘못된 동작 수정 | `fix: 위치 권한 거부 시 안내 메시지 표시` |
| `docs` | 문서 작성·수정 | `docs: 에이전트 지침에 커밋 메시지 규칙 추가` |
| `style` | 동작 변화 없는 들여쓰기·공백 등 코드 형식 정리 | `style: 여행 목록 코드의 들여쓰기 통일` |
| `refactor` | 동작을 유지하면서 코드 구조 개선 | `refactor: 방문 일정 검증 로직 분리` |
| `test` | 테스트 추가·수정 | `test: 방문 알림 해제 시나리오 추가` |
| `chore` | 빌드 설정·개발 도구 등 관리 작업 | `chore: 시뮬레이터 실행 스크립트 추가` |

- 타입은 브랜치 이름을 그대로 복사하지 말고 해당 커밋의 실제 변경 목적에 맞춰 선택합니다. `style`은 코드 형식 변경에 사용하며, 화면 디자인이나 UX 변경은 목적에 따라 `feat` 또는 `fix`를 사용합니다. 브랜치 종류는 위 브랜치 규칙을 따릅니다.
- 한 커밋에는 하나의 변경 목적을 담습니다. 관련 없는 기능 추가·오류 수정·문서 수정은 별도 커밋으로 나눕니다.
- `update code`, `fix bug`, `수정`, `작업 완료`처럼 대상과 결과를 알 수 없는 제목은 사용하지 않습니다.
- 제목만으로 이유를 설명하기 어려우면 빈 줄 다음 본문에 변경 이유와 주요 영향을 적습니다. 관련 이슈가 있으면 본문에 `관련 이슈: #번호`로 남깁니다.
- 커밋 전 `git status`와 `git diff --staged`로 실제 변경이 메시지와 일치하는지, 불필요한 파일이나 비밀값이 없는지 확인합니다.

참고: [깃 git 활용 가이드 — Commit 메시지 규칙](https://wikidocs.net/332862)

### PR과 병합

- PR의 `base`는 `main`, `compare`는 작업 브랜치로 설정합니다.
- `main` 반영은 팀원 한 명 이상의 리뷰를 받은 PR로 진행합니다.
- 충돌은 작업 브랜치에서 최신 `main`을 합친 뒤 해결합니다.
- **Squash and merge**로 PR당 커밋 하나를 남기고, 병합 후 GitHub의 작업 브랜치를 삭제합니다.
- PR에는 아래 내용을 작성합니다. 관련 이슈가 없다면 없다고 명시합니다.

```markdown
## 변경 내용
- 어떤 문제를 해결했고 무엇이 달라졌는지

## 확인 방법
- 시뮬레이터 또는 실기기와 iOS 버전
- 앱에서 눌러 볼 화면과 버튼
- 확인한 결과

## 관련 이슈
- #이슈번호
```

## 완료 기준과 지침 관리

- 앱 코드 변경은 `TripJJIM` Scheme 빌드와 수정한 동작의 시뮬레이터 또는 실기기 확인을 마친 뒤 PR로 올립니다. UI 흐름 변경은 관련 UI 테스트도 실행하고, 화면이 바뀌면 PR에 스크린샷을 붙입니다.
- 문서만 변경했다면 빌드 대신 경로·명령·문서 내 참조와 `git diff --check`를 확인합니다.
- 실행하지 못한 검증은 그 사실과 이유를 명시합니다. 완료 보고에는 변경 내용과 확인 결과를 적습니다.
- 폴더 구조나 빌드·테스트 명령이 바뀌면 같은 PR에서 이 파일도 갱신합니다. 한시적 지침에는 삭제 조건을 적고, 실제 프로젝트와 맞지 않는 지침은 근거를 확인해 사용자에게 알립니다.
