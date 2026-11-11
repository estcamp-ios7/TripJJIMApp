# TripJJIMApp 에이전트 작업 지침

이 지침은 저장소 전체의 개발 작업에 적용합니다.

## iOS 개발

SwiftUI 여행 일정 앱입니다. 앱 코드는 `TripJJIM/`, UI 테스트는 `TripJJIMUITests/`, 프로젝트는 `TripJJIM.xcodeproj`, Scheme은 `TripJJIM`입니다.

- 기존 모델·내비게이션·공용 코드와 지원 기기·iOS 범위를 유지하며 요청한 기능만 수정합니다. 작업 전 프로젝트·타깃·Scheme·시뮬레이터 설정을 확인하고 같은 설정으로 검증합니다.
- 화면은 작은 `View`로 나누고 필요한 값·`@Binding`·콜백만 전달합니다. 큰 `body`를 여러 개의 큰 computed `some View`로 옮기는 데 그치지 않습니다.
- 상태는 `@State`·`@Environment`를 우선하고 ViewModel은 필요한 경우에만 둡니다. iOS 17+의 루트 `@Observable` 모델은 소유 뷰의 `@State`로 관리합니다. 부수 효과는 `body` 밖으로, 업무 로직은 모델·서비스로 분리합니다.
- 리팩터링은 동작·레이아웃·내비게이션을 보존합니다. 루트 뷰를 통째로 바꾸는 조건 분기보다 부분 조건·modifier로 뷰 트리를 안정적으로 유지하고, 의미 있는 분리마다 검증합니다.
- CLI를 우선합니다. 시뮬레이터 자동화에는 사용 가능한 XcodeBuildMCP·Build iOS Apps 플러그인을, 성능·동시성 등 전문 작업에는 해당 스킬을 활용합니다.
- 변경을 증명하는 최소 빌드·테스트·프리뷰부터 실행하고 통과 후 필요시 검증을 확대합니다. UI 변경은 시뮬레이터의 해당 흐름과 스크린샷으로 확인합니다.
- 버그는 한 번에 한 재현 경로를 대상으로 합니다. 현재 화면·접근성 계층을 읽고 라벨·ID로 조작하며, 화면이 바뀌면 다시 읽습니다. 로그·필요시 LLDB로 원인을 찾아 최소 수정 후 같은 경로로 재검증합니다.
- Liquid Glass 작업은 먼저 적용할 흐름을 점검하고 시스템 컨트롤·네이티브 API로 단계적으로 변경합니다. 효과는 조작 요소 중심으로 적용하고 일반 콘텐츠의 가독성을 보존하며, 지원 OS에 따라 availability 검사·대체 UI를 둡니다.
- Liquid Glass의 `glassEffect`는 레이아웃·시각 modifier 뒤에 적용하고, 관련 요소는 `GlassEffectContainer`로 묶습니다. `.interactive()`는 실제 조작 요소에만, `glassEffectID` 전환은 필요한 경우에만 사용합니다.
- App Intents 작업은 유용한 최소 동작·엔터티부터 정의합니다. 시스템 안에서 완료할 동작과 앱의 특정 화면으로 연결할 동작을 구분하고, App Shortcuts의 이름·호출 문구와 실제 실행 결과를 검증합니다.
- 완료 시 변경·Scheme·기기·iOS·명령·결과·미실행 이유를 보고합니다. 문서 수정은 경로·명령·참조와 `git diff --check`로 확인합니다.

이 문서의 iOS 개발 지침은 [OpenAI 공식 Native development 가이드](https://learn.chatgpt.com/use-cases/collections/native-development)에 수록된 iOS 관련 문서 5종을 참조하여, 본 프로젝트의 개발 환경과 작업 흐름에 맞추어 작성되었습니다.

### 실행 명령

Xcode가 설치된 macOS의 저장소 루트에서 실행합니다. `SIMULATOR_UUID`는 조회 결과의 실제 UUID로 바꿉니다.

```sh
xcodebuild -project TripJJIM.xcodeproj -scheme TripJJIM -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/TripJJIM CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
bash scripts/run-simulator.sh SIMULATOR_UUID
```

테스트는 위 명령의 destination을 `'platform=iOS Simulator,id=SIMULATOR_UUID'`, 마지막 `build`를 `test`로 바꿉니다. 스크립트는 빌드·설치·실행을 수행하며 로컬 환경의 Build 액션에 연결할 수 있습니다.

## Git 작업 시

브랜치 생성·전환, 커밋, 푸시, PR 작성·리뷰·병합 전에 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽고 해당 협업 규칙을 따릅니다.
