# TripJJIMApp 에이전트 작업 지침

이 지침은 저장소 전체에 적용합니다.

## 프로젝트 정보

여행·방문 일정을 만들고 지도에서 장소를 선택하며 방문 알림을 설정하는 SwiftUI iOS 앱입니다.

- 앱 코드: `TripJJIM/` — `App/`(진입점), `Models/`(데이터), `Stores/`(상태·저장), `Views/`(화면), `Services/`(위치·알림·검색), `Resources/`(리소스)
- 화면: `TripJJIM/Views/` 아래 `Trips/`, `Visits/`, `PlaceSearch/`로 구분합니다.
- UI 테스트: `TripJJIMUITests/`
- Xcode 프로젝트: `TripJJIM.xcodeproj`, Scheme: `TripJJIM`

## 빌드·실행·테스트

Xcode가 설치된 macOS의 저장소 루트에서 실행합니다. `SIMULATOR_UUID`는 조회 결과의 실제 UUID로 바꿉니다.

```sh
xcodebuild -project TripJJIM.xcodeproj -scheme TripJJIM -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/TripJJIM CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
bash scripts/run-simulator.sh SIMULATOR_UUID
```

테스트는 위 명령의 destination을 `'platform=iOS Simulator,id=SIMULATOR_UUID'`, 마지막 `build`를 `test`로 바꿉니다. 스크립트는 빌드·설치·실행을 수행하며 로컬 환경의 Build 액션에 연결할 수 있습니다.

변경 영향에 맞는 검증을 선택하고, 완료 시 실행한 명령·결과와 미실행 항목의 이유를 보고합니다. 문서만 변경하면 경로·명령·링크와 `git diff --check`를 확인합니다.

## 작업별 참고

- 브랜치 생성·전환, 커밋, 푸시, PR 작성·리뷰·병합 전에 [CONTRIBUTING.md](CONTRIBUTING.md)의 협업 규칙을 읽고 따릅니다.
- `project.pbxproj`, `Trip.swift`, `TripStore.swift` 등 공동 수정 가능성이 큰 파일을 변경하기 전에도 `CONTRIBUTING.md`의 작업 조율 규칙을 확인합니다.
- iOS API·플랫폼 동작 확인에는 Apple 공식 문서를, 개발 흐름·도구 선택에 참고가 필요할 때는 [OpenAI 공식 Native development 가이드](https://learn.chatgpt.com/use-cases/collections/native-development)의 관련 문서를 활용합니다.
