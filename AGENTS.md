# TripJJIMApp 에이전트 작업 지침

이 지침은 저장소 전체에 적용합니다.

## 프로젝트 정보

여행·방문 일정을 만들고 지도에서 장소를 선택하며 방문 알림을 설정하는 SwiftUI iOS 앱입니다.

- 앱 코드: `TripJJIM/` — `App/`(진입점), `Models/`(데이터), `Stores/`(상태·저장), `Views/`(화면), `Services/`(위치·알림·검색), `Resources/`(리소스)
- 화면: `TripJJIM/Views/` 아래 `Trips/`, `Visits/`, `PlaceSearch/`로 구분합니다.
- UI 테스트: `TripJJIMUITests/`
- Xcode 프로젝트: `TripJJIM.xcodeproj`, Scheme: `TripJJIM`

## 빌드·실행·테스트

1. 변경 영향에 맞는 최소한의 검증을 수행합니다.
2. 전체 테스트는 명시적인 요청이나 구체적인 필요가 있을 때만 실행합니다.
3. 필요한 검증이 통과하면 종료하며, 변경이나 새로운 문제가 없으면 반복하지 않습니다.

## 작업별 참고

- 브랜치 생성·전환, 커밋, 푸시, PR 작성·리뷰·병합 전에 [CONTRIBUTING.md](CONTRIBUTING.md)의 협업 규칙을 읽고 따릅니다.
- `project.pbxproj`, `Trip.swift`, `TripStore.swift` 등 공동 수정 가능성이 큰 파일을 변경하기 전에도 `CONTRIBUTING.md`의 작업 조율 규칙을 확인합니다.
- iOS API·플랫폼 동작 확인에는 Apple 공식 문서를, 개발 흐름·도구 선택에 참고가 필요할 때는 [OpenAI 공식 Native development 가이드](https://learn.chatgpt.com/use-cases/collections/native-development)의 관련 문서를 활용합니다.
