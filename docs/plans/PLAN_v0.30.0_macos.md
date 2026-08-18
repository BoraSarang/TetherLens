# PLAN v0.30.0 — 맥 앱 메뉴바 강화 + Cmd-K 커맨드 팔레트

- **버전**: v0.30.0 (build 30)
- **플랫폼**: [macOS]
- **작성일**: 2026-08-18
- **상태**: 진행 중 (사용자: "다른창도 확인 했음 다음 진행해")
- **스킬**: macos-app-design (§4 메뉴바, §5 단축키, §6 커맨드 팔레트)

---

## 1. 개요

### 1.1 배경
- v0.29.0 릴리즈 완료 (Phase 1~5 리디자인 + 잘림 수정). 사용자가 다른 창들도 확인 완료.
- macos-app-design 스킬 기준 미충족 항목: ① 상단 앱 메뉴바가 기본 상태(`.commands` 없음) ② 주요 동작에 단축키 없음 ③ Cmd-K 커맨드 팔레트 없음
- §4: "메뉴바는 신성하다. 단일 목적 유틸리티라도 File/Edit/View/Window/Help 메뉴 필요"
- §5: "모든 의미 있는 동작에 단축키"
- §6: "Cmd-K는 현대 Mac 앱 패턴 (Raycast/Linear/Codex)"

### 1.2 목표 (이번 범위)
1. **메뉴바 강화 (Phase 1)**: Window 메뉴에 리포트/앱트래픽/알림/정보 열기 + 단축키(Cmd-1~4), View 메뉴에 팝오버 토글(Cmd-Shift-P), DebugPanel 토글(Cmd-Shift-D, DEBUG만)
2. **Cmd-K 커맨드 팔레트 (Phase 2)**: SwiftUI Window scene 기반 팔레트 — 어디서든 Cmd-K로 열기. 액션 검색·실행

### 1.3 범위 외 (다음 단계)
- 온보딩 정제, 스크린샷 검증 자동화, AppIntents/Spotlight

---

## 2. 결정 사항

| 항목 | 결정 |
|------|------|
| 메뉴바 | SwiftUI `.commands {}`로 Window/View 메뉴 구성. 기존 기본 메뉴(Edit 등) 유지 |
| 단축키 | 리포트 `⌘1`, 앱트래픽 `⌘2`, 알림 `⌘3`, 정보 `⌘4`, 팝오버 토글 `⌘⇧P`, DebugPanel `⌘⇧D` |
| Cmd-K | SwiftUI `Window(id: "commandPalette")` scene (`.windowStyle(.hiddenTitleBar)` + `.windowResizability(.contentSize)`) — `@Environment(\.openWindow)`/`openSettings`을 팔레트 내부에서 직접 사용. 폭 420×높이 320. `.commands`의 `⌘K`로 열기 |
| 팝오버 유지 | MenuBarExtra(NSPopover) 그대로 — Cmd-K는 별도 오버레이 |

> 설계 변경(v0.30 구현 시): 초기 NSPanel 계획 → SwiftUI Window scene으로 전환. NSPanel(NSHostingController)은 `openWindow`/`openSettings` 환경값을 쓸 수 없어, 팔레트가 직접 창을 열기 어렵기 때문. `CommandPaletteController` 불필요해짐.

---

## 3. 구현 단계

### 3.1 Phase 1 — 메뉴바 + 단축키 (T-165)
- `App.swift` `Settings` scene에 `.commands` 체이닝:
  - `CommandGroup(after: .windowArrangement)` — 사용량 리포트(⌘1)/앱 트래픽(⌘2)/알림(⌘3)/정보(⌘4) → `openWindow(id:)` (App의 `@Environment(\.openWindow)`)
  - `CommandGroup(after: .sidebar)` — 팝오버 토글(⌘⇧P), DebugPanel 토글(⌘⇧D, DEBUG만)
- 팝오버 토글: `MenuBarManager`에 `"togglePopover"` NotificationCenter observer(`handleTogglePopover`) 추가 — `.commands` Button이 notification을 post

### 3.2 Phase 2 — Cmd-K 커맨드 팔레트 (T-166)
- `CommandPaletteView.swift` 신규 — 검색 TextField + 결과 List, `↑↓`/Enter/Esc(`onKeyPress`), 선택 행 accent 배경
- `App.swift`에 `Window(id: "commandPalette")` scene + `.commands`에 `⌘K` 버튼(`openWindow(id: "commandPalette")`)
- 액션 목록: 리포트/앱트래픽/알림/설정/정보/팝오버 토글/업데이트 확인/종료 + (DEBUG) DebugPanel — 팝오버 시트 액션(프로필/DNS/절약모드/IP히스토리)은 팔레트에서 제외

---

## 4. 파일 매핑

| 파일 | 작업 |
|------|------|
| `Sources/TetherLens/App/App.swift` | `.commands` 메뉴 구성 + 단축키 + 팔레트 Window scene |
| `Sources/TetherLens/App/MenuBarManager.swift` | `"togglePopover"` observer(`handleTogglePopover`) 추가 |
| `Sources/TetherLens/Views/CommandPaletteView.swift` | 신규 — 팔레트 UI (검색+리스트) |
| `Sources/TetherLens/Utils/Localized.swift` | `popoverToggle`/`commandPalette`/`palettePlaceholder` 추가 + `debugPanel` 이모지 제거 |

## 5. 테스트 계획
- `./scripts/test.sh` 43개 통과 유지
- `./scripts/build-macos.sh debug` 성공
- 수동: 메뉴바 단축키(⌘1~4, ⌘⇧P, ⌘⇧D) 동작, Cmd-K 열기/검색/↑↓/Esc/실행
- TrafficMonitor acquire/release balance=0 회귀 확인

## 6. 롤백 계획
- git revert + `./scripts/build-macos.sh debug` 재빌드
- Cmd-K 팔레트는 독립 파일(`CommandPaletteView.swift`)로 분리

## 7. 성능 예산
- 팔레트 열기/닫기 즉시 (Window scene, 팝오버와 무관)
- 단축키는 앱 메뉴(.commands) 경유 — 전역 키 모니터 불필요

## 8. 에러코드
- 신규 에러코드 없음 (UI 변경만)

## 9. 권한
- 변경 없음

## 10. DoD 체크리스트
- [x] 문서 우선: 본 PLAN + TODO T-165~166
- [ ] 코드 수정 + DebugLogger 경유 로그
- [ ] test.sh / build-macos.sh debug 성공
- [ ] docs/CHANGELOG.md [macOS] 반영
- [ ] 커밋 + 릴리즈