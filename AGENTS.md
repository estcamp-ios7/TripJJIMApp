# TripJJIMApp 에이전트 작업 지침

이 지침은 저장소 전체에 적용합니다.

## 적용 범위와 문서 위치

- 팀 공통 지침은 이 파일처럼 Git 저장소 루트의 `AGENTS.md`에 유지합니다. 개인 전역 지침 경로인 `~/.codex/AGENTS.md`와 구분합니다. `CODEX_HOME`을 별도로 설정한 환경에서는 해당 디렉터리가 전역 지침의 기준입니다.
- Codex는 프로젝트 루트에서 현재 작업 디렉터리까지 지침을 읽습니다. 하위 디렉터리의 지침은 해당 경로에서 더 구체적으로 적용되므로, 작업 경로에 추가 지침이 있는지 확인합니다.
- 같은 디렉터리에 `AGENTS.override.md`가 있으면 `AGENTS.md`보다 우선하여 선택됩니다. 팀 공통 규칙을 가리는 override 파일은 의도와 적용 범위를 확인합니다.
- 상세 Git 규칙은 `CONTRIBUTING.md`를 기준으로 합니다. 이 파일을 통해 명시적으로 읽으며, `CONTRIBUTING.md` 자체가 기본 탐색 파일이라고 가정하지 않습니다.

## Git 협업 규칙

- 브랜치 생성, 커밋, push, PR 작성·병합 전에 반드시 루트의 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽고 따릅니다.
- Git 작업 전 `git rev-parse --show-toplevel`과 `git remote -v`로 작업 대상이 `estcamp-ios7/TripJJIMApp`인지 확인합니다. 이름이 비슷한 `estcamp-ios7/TripJJIM` 저장소와 혼동하지 않습니다. 현재 폴더가 Git 저장소가 아니면 인접 저장소를 임의로 작업 대상으로 선택하지 않습니다.
- 브랜치 이름은 임의로 정하지 않습니다. `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/` 중 작업 목적에 맞는 종류를 선택하고, 작업 이름은 소문자 영문과 하이픈으로 짧게 작성합니다.
- 새 작업은 최신 `main`에서 시작하고 작업 하나를 브랜치 하나와 PR 하나로 관리합니다.
- 커밋 제목은 `종류: 변경 내용` 형식으로 작성합니다.
- 커밋 전에 `git status`와 `git diff --staged`를 확인하고 비밀값을 포함하지 않습니다.
- PR은 `main`을 대상으로 작성하며 변경 내용, 확인 방법, 관련 이슈를 포함합니다.
- PR 작성 전 `TripJJIM` Scheme으로 빌드하고 수정한 동작을 시뮬레이터 또는 실기기에서 확인합니다. 화면 변경이 있으면 PR에 스크린샷을 첨부합니다. 실행하지 못한 검증은 그 사실과 이유를 명시합니다.
- `project.pbxproj`, `Trip.swift`, `TripStore.swift` 등 함께 수정할 가능성이 높은 파일은 작업 전에 팀에 공유해야 합니다. 팀에 메시지를 보내야 한다면 사용자에게 전달할 내용을 정리하고, 전송은 명시적으로 요청받았을 때 수행합니다.
- `main` 반영은 팀원 한 명 이상의 리뷰를 받은 PR을 **Squash and merge**하는 방식으로 진행하고, 병합 후 GitHub의 작업 브랜치를 삭제합니다.
- 충돌은 작업 브랜치에서 최신 `main`을 합친 뒤 해결합니다.

자세한 절차와 예시는 `CONTRIBUTING.md`를 기준으로 확인합니다.

공식 참고: [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
