# 포토위젯

개인용 사진 위젯 앱(TestFlight 전용). SwiftUI + WidgetKit, XcodeGen(`project.yml`)으로 CI에서 프로젝트 생성.
빌드: `gh workflow run ios-build.yml -R Yewon419/photo-widget` → TestFlight 내부 그룹 "나"에 자동 배포.

## 식별자
- 앱 `com.windgarden.photowidget`, 위젯 `com.windgarden.photowidget.widget`
- App Group `group.com.windgarden.photowidget`
- ASC 앱 레코드 "포토위젯 개인용"(6816285381), 서명 키 = `_keys\JejuNow` ASC API 키(관리자)

## 빌드 함정 (겪은 것)
- iOS 26 SDK는 xcodebuild ad-hoc(`CODE_SIGN_IDENTITY=-`) 서명을 거부한다 → 무서명 아카이브 후 `codesign --sign - --entitlements`로 엔타이틀먼트를 직접 박는다(appex 먼저). 무서명 그대로 export하면 App Group이 빠진다.
- XcodeGen은 타깃 수준에서 `TARGETED_DEVICE_FAMILY`를 덮어쓴다 → 아이폰 전용은 타깃 settings에 넣는다. 아니면 iPad 멀티태스킹 방향 검증으로 업로드 거부.
- XcodeGen 생성 Info.plist는 `CFBundleVersion`이 고정 "1" → `$(CURRENT_PROJECT_VERSION)`을 명시해야 CI run number가 빌드 번호가 된다.
- App Group 생성과 번들 ID 연결, ASC 앱 레코드 생성은 API에 없다 → 웹에서 한다.
- 로컬에 Xcode가 없어 컴파일 확인이 CI 한 바퀴(~5분)다 → SwiftUI 모디파이어 반환 타입을 추측하지 말 것. `Image.widgetAccentedRenderingMode`는 `Image`가 아니라 `some View`를 반환한다.
