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
- 실행하지 못한 검증은 그 사실과 이유를 명시합니다.
- 팀에 메시지를 보내야 한다면 사용자에게 전달할 내용을 정리하고, 전송은 명시적으로 요청받았을 때 수행합니다.

자세한 절차와 예시는 `CONTRIBUTING.md`를 기준으로 확인합니다.

공식 참고: [Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
