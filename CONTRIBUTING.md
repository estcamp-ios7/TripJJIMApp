# TripJJIMApp Git 협업 규칙

> `main`은 팀원이 받아서 바로 빌드하고 실행할 수 있는 브랜치입니다. 새 작업은 최신 `main`에서 시작하고, **작업 하나를 브랜치 하나와 PR 하나로 관리**합니다.

## 1. 브랜치 이름

`종류/작업-이름` 형식으로 작성합니다. 작업 이름은 소문자 영문과 하이픈으로 짧게 적습니다.

| 종류 | 용도 | 예시 |
| --- | --- | --- |
| `feat/` | 기능 추가 | `feat/tour-api-client` |
| `fix/` | 버그 수정 | `fix/location-feedback` |
| `refactor/` | 동작을 유지하면서 코드 정리 | `refactor/trip-store` |
| `test/` | 테스트 추가·수정 | `test/reminder-lifecycle` |
| `docs/` | 문서 작성·수정 | `docs/git-guide` |
| `chore/` | 프로젝트 설정과 도구 관리 | `chore/xcode-settings` |

예를 들면 한국관광공사 OpenAPI 연동은 `feat/tour-api-client`에서 API 호출을, `feat/tour-place-picker`에서 지역 선택과 관광지 목록 화면을 맡습니다. 두 작업을 시작하기 전에 **관광지 이름·위도·경도를 어떤 모델로 전달할지** 합의합니다. 두 PR이 합쳐지면 최신 `main`에서 `feat/tour-place-to-visit`을 만들어 방문 일정 저장 흐름에 연결합니다.

## 2. 작업 시작부터 PR까지

**① 최신 `main`에서 브랜치 만들기**

```sh
git switch main
git pull --ff-only origin main
git switch -c fix/location-feedback
```

**② 변경한 파일을 확인하고 커밋하기**

커밋 제목은 `종류: 변경 내용` 형식으로 작성합니다. 예를 들어 `fix: 시뮬레이터 위치 안내 문구 개선`처럼 어떤 동작이 바뀌었는지 적습니다.

```sh
git status
git add TripJJIM/LocationManager.swift
git commit -m "fix: 시뮬레이터 위치 안내 문구 개선"
git push -u origin fix/location-feedback
```

**③ GitHub에서 PR 열기**

`base`는 `main`, `compare`는 작업 브랜치로 선택합니다. 무엇을 바꿨는지와 팀원이 어떻게 확인할 수 있는지를 적습니다.

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

## 3. 리뷰와 병합

- `main`에 반영할 변경은 **PR로 올리고 팀원 한 명 이상의 리뷰**를 받습니다.
- PR 작성자는 `TripJJIM` Scheme으로 빌드하고, 자신이 수정한 동작을 시뮬레이터 또는 실기기에서 확인합니다. 화면이 바뀌었다면 PR에 스크린샷을 붙입니다.
- 충돌이 생기면 작업 브랜치에서 최신 `main`을 합친 뒤 해결합니다. `project.pbxproj`, `Trip.swift`, `TripStore.swift`처럼 함께 수정할 가능성이 높은 파일은 작업 전에 팀에 공유합니다.
- 병합은 **Squash and merge**로 진행해 `main`에 PR당 커밋 하나를 남깁니다. 병합이 끝난 작업 브랜치는 GitHub에서 삭제합니다.
- 관광 API 키 같은 비밀값은 팀에서 정한 비공개 설정에 보관합니다. 커밋 전에 `git status`와 `git diff --staged`로 올라갈 파일과 내용을 확인합니다.

## 4. Codex 지침 파일 위치와 확인

팀 공유 문서는 다음과 같이 저장소 루트에 둡니다.

```text
TripJJIMApp/              # 로컬 저장소 폴더명은 달라도 됩니다.
├── AGENTS.md             # Codex가 읽는 프로젝트 공통 지침
├── CONTRIBUTING.md       # 팀 Git 협업 규칙
├── TripJJIM.xcodeproj/
└── TripJJIM/
```

- `~/.codex/AGENTS.md`는 개인 전역 지침입니다. 모든 저장소에 적용할 개인 설정에 사용하고, 이 프로젝트의 팀 규칙은 루트 `AGENTS.md`에서 관리합니다. `CODEX_HOME`을 설정했다면 전역 지침 경로도 그 위치를 따릅니다.
- 디렉터리별 규칙이 필요할 때만 해당 디렉터리에 `AGENTS.md`를 추가합니다. 같은 디렉터리의 `AGENTS.override.md`는 `AGENTS.md` 대신 선택되므로 사용에 주의합니다.
- GitHub에 문서를 올리는 것만으로 다른 로컬 폴더에 반영되지는 않습니다. 실제 `TripJJIMApp` 복제본을 최신 상태로 받고 그 폴더를 Codex 프로젝트로 엽니다.
- 변경 후 새 Codex 실행 또는 새 CLI 세션에서 “현재 적용된 지침 파일 경로와 Git 규칙을 요약해줘”라고 요청해 로딩 결과를 확인합니다. 누락되면 작업 폴더, override 파일, `CODEX_HOME`을 점검합니다.

공식 참고: [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
