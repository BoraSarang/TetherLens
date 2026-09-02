# PLAN v0.31.0 — 플로팅 창 (메뉴바 축소판 + 프로세스 트래픽)

- **버전**: v0.31.0 (build 31)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-02
- **상태**: 진행 중
- **스킬**: macos-app-design (플로팅 HUD 표면) — "딱 맥 앱 같아야"

---

## 1. 개요

### 1.1 배경
- v0.30.0 릴리즈 완료. 사용자 요청: "메뉴바에 표시되고 있는 것을 플로팅 창으로 별도 구성, 바탕화면에 떠다니도록".
- 요구사항 (사용자): ① 플로팅 창 생성 ② 메뉴바 표시 내용 동일 반영(설정 연동) ③ 투명 + 투명도 설정 ④ 드래그 위치 이동 ⑤ 아래에 프로세스 트래픽(업/다운 상위 3)
- 사용자 선택: 트래픽 토글+기본 ON(저전력 자동 중지) / 진입점 우클릭 메뉴+⌘ 단축키 / 축소판(동일 폰트 반영)
- 추가 제안 반영 (승인): 트래픽 행 클릭 → 앱 트래픽 창 열기, ⌘K 팔레트 "플로팅 창" 액션

### 1.2 목표 (이번 범위)
1. **플로팅 창**: borderless NSPanel — 메뉴바 표시 내용(설정 동일 반영) + 프로세스 트래픽 상위 3
2. **투명도·드래그**: 투명도 슬라이더(0.35~1.0), `isMovableByWindowBackground` 위치 이동, 위치 UserDefaults 저장/복원
3. **진입점**: 우클릭(더보기) 메뉴 토글 + `⌘⇧F` + 설정(시작 시 표시/투명도/트래픽) + ⌘K 액션

### 1.3 범위 외
- 팔레트의 다른 시트 액션 연동(프로필/DNS/절약모드), NSPanel 단축키 커스텀

---

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| 창 | `NSPanel` borderless + `.nonactivatingPanel` — `DiagnosticsWindowController` 패턴 재사용. `level = .floating`, `canJoinAllSpaces`+`fullScreenAuxiliary` |
| 투명 | `isOpaque=false` + `backgroundColor=.clear` + `hasShadow=true`. SwiftUI 배경 `.regularMaterial` + `opacity(floatingOpacity)` |
| 드래그 | `isMovableByWindowBackground = true` (borderless + 호스팅뷰 배경 클릭 시 이동). 불가 시 `mouseDown`→`performDrag` 전환 |
| 위치 | UserDefaults `floatingWindowOrigin` ("x,y") 저장/복원. 기본: 화면 우상단(메뉴바 아래) |
| 메뉴바 연동 | `MenuBarManager.updateMenuBarText()` 말미에 `"floatingContentChanged"` Notification 발행(up/down/col3Top/col3Bottom/ratio) → 플로팅 뷰가 구독. 설정·tick 경로에서 자동 발행되어 동일 반영 |
| 트래픽 | `TrafficMonitor.shared.apps` + `SystemProcesses.set` 필터 상위 3 — `PopoverView.appTrafficPreview` 로직 재사용. `Usage.floating` 추가로 acquire/release 결정적 제어(컨트롤러 유일 소유) |
| 저전력 | 기존 `setLowPower`/`suspend` 메커니즘 그대로 — floating 참조 중에도 자동 중지 |
| 에너지 | floating visible + `floatingShowTraffic` ON 동안만 nettop 가동. 기본 ON(사용자 선택) |
| 설정 키 | `floatingShowAtLaunch`(기본 false) / `floatingOpacity`(기본 0.9) / `floatingShowTraffic`(기본 true) — `SettingsManager`에 추가 |

---

## 3. 구현 단계

### 3.1 공유 데이터 (T-169)
- `TrafficMonitor.Usage`에 `.floating` case 추가
- `MenuBarManager.updateMenuBarText()` 발행: `NotificationCenter.post(name: "floatingContentChanged", userInfo: ["up":…,"down":…,"col3Top":…,"col3Bottom":…,"ratio":…])`
- `stopMonitoring()`에서 플로팅 해제(acquire 잔류 방지) 없음 — 컨트롤러가 직접 소유하므로 컨트롤러 hide 시 release

### 3.2 플로팅 창 (T-170, T-171)
- `FloatingWindowController`(App/) — 토글/표시/숨김, 위치 저장·복원, 트래픽 acquire/release 소유
- `FloatingWindowViewModel`(ObservableObject) — `floatingContentChanged` 값 바인딩
- `FloatingWindowView`(Views/) — 메뉴바 축소판(폰트 크기 `menuBarFontSize` 반영, ratio 색상, col3 숨김) + 구분선 + 트래픽 상위3 + 호버 닫기(X)

### 3.3 진입점 / 설정 (T-172, T-173)
- `MenuBarManager.showMoreMenu()`: "플로팅 창 표시/숨기기" 토글 항목
- `App.swift` `.commands`(sidebar): `⌘⇧F` 버튼
- `CommandPaletteView`: "플로팅 창" 액션(`FloatingWindowController.shared.toggle()`)
- `SettingsView` 메뉴바 탭: "플로팅 창" 섹션 — 시작 시 표시 토글 / 투명도 슬라이더 / 트래픽 표시 토글(`settingsChanged` 발행으로 컨트롤러 동기화)
- `Localized.swift`: floating 7키 추가

### 3.4 검증 / 문서 (T-174)
- `./scripts/test.sh`(43개) → `build-macos.sh debug` → DebugPanel 로그 확인
- 수동: 표시/드래그/투명도/트래픽/메뉴바 설정 연동/저전력
- `Info.plist` v0.31.0/31, TODO/CHANGELOG/세션 문서

---

## 4. 파일 매핑

| 파일 | 작업 |
|------|------|
| `Sources/TetherLens/App/FloatingWindowController.swift` | 신규 — 패널 + 뷰모델 |
| `Sources/TetherLens/Views/FloatingWindowView.swift` | 신규 — 축소판 + 트래픽 UI |
| `Sources/TetherLens/App/MenuBarManager.swift` | 발행 + 더보기 토글 항목 |
| `Sources/TetherLens/Services/TrafficMonitor.swift` | `Usage.floating` |
| `Sources/TetherLens/Services/SettingsManager.swift` | floating 3키 |
| `Sources/TetherLens/App/App.swift` | `⌘⇧F` |
| `Sources/TetherLens/Views/CommandPaletteView.swift` | 팔레트 액션 |
| `Sources/TetherLens/Views/SettingsView.swift` | 플로팅 창 섹션 |
| `Sources/TetherLens/Utils/Localized.swift` | 키 7개 |
| `Resources/Info.plist` | v0.31.0/31 |

## 5. 테스트 계획
- `./scripts/test.sh` 43개 통과 유지 (Usage enum·SettingsManager 확장 — 기존 무관)
- `./scripts/build-macos.sh debug` 성공
- 수동: 플로팅 표시/드래그/투명도/트래픽 top3/메뉴바 설정 연동/⌘⇧F/⌘K/우클릭/닫기X/저전력 자동 중지
- TrafficMonitor acquire/release balance=0 회귀 확인

## 6. 롤백 계획
- git revert + `./scripts/build-macos.sh debug` 재빌드. 플로팅은 독립 파일 2개로 분리

## 7. 성능 예산
- 플로팅 창 렌더: 메뉴바 tick(3s 기본)당 문자열 갱신 — 경량
- 트래픽: nettop `-l 2` + self-rescheduling 기존 유지 (floating 참조 시만)
- 투명 material: `hasShadow`+`regularMaterial` — GPU 합성 소폭 증가 허용치 내

## 8. 에러코드
- 신규 에러코드 없음(UI 기능). 단 DebugLogger 경유 로그 의무:
  - `[INFO] [Floating] 플로팅 창 표시/숨김` / `acquire/release(floating)`

## 9. 권한
- 변경 없음

## 10. DoD 체크리스트
- [ ] 문서 우선: 본 PLAN + TODO T-168~174 + bd 이슈 (TetherLens-9a5)
- [ ] 코드 수정 + DebugLogger 경유 로그
- [ ] test.sh / build-macos.sh debug 성공
- [ ] docs/CHANGELOG.md [macOS] 반영
- [ ] 커밋 + 릴리즈