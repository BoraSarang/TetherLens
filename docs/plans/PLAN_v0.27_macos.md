# PLAN v0.27 — 백로그 T-33 / T-34 처리 (macOS)

- **작성일**: 2026-08-10
- **플랫폼**: macOS
- **목표**: 백로그에 남은 T-33(앱별 트래픽 초기화 버튼), T-34(다크 모드)를 검증·정리해 완료 처리

## T-33 — 앱별 트래픽 per-app 누적 total 초기화 버튼

**현재 상태**: `Sources/TetherLens/Views/AppTrafficView.swift`의 헤더에 `Localized.resetTraffic` 버튼이 이미 존재하며 `TrafficMonitor.resetAccumulated()`(in-memory `accumulated`/`lastSavedAccumulated` 초기화)를 호출. → 기능은 구현 완료 상태.

**추가 개선**: 초기화는 막대한 누적 데이터를 소거하는 동작이므로 실수 방지를 위해 confirmation dialog 추가.

### 구현
1. `AppTrafficView`에 `@State private var confirmReset = false` 추가
2. 초기화 버튼 → `confirmReset = true`
3. `.confirmationDialog`로 "누적 트래픽을 초기화할까요?" 확인 후 `monitor.resetAccumulated()` 호출
4. 다이얼로그 문구는 기존 i18n 방식(`Localized.*`) 확인 후 오프라인 다이얼로그 패턴(PopoverView 시트/다이얼로그)과 동일하게 표기

### 검증
- Reset 버튼 → 다이얼로그 → 확인 시 `resetAccumulated` 호출 보장
- 실행 중 `monitor.apps`가 즉시 0 기준으로 갱신되는지 확인

## T-34 — 다크 모드 대응

**현재 상태**: 전역 디자인 시스템 `DesignSystem/Theme.swift`가 시스템 팔레트(`Color.primary`/`.secondary`, `Color(nsColor:)`) 기반이라 대부분 자동 대응.

**조사 결과**:
- `HeatmapGridView` — `colorScheme` 분기로 다크 전용 셀 색상 이미 구현 ✅
- `DebugPanelView` — 검정 배경 고정 (디버그 패널 의도적 설계, 다크 무관) ✅
- `HeatmapMapView` 흰색 마커 테두리 — 지도 위 표기라 다크 무관 ✅
- `ProfileEditorView` `Color.black.opacity(0.25)` — 모달 오버레이 dim (의도) ✅
- 나머지 뷰 — `TLPalette.textPrimary/textSecondary`, `TLPalette.windowBackground` 등 시스템 색 기반으로 자동 대응 ✅
- 하드코딩 라이트 전용 배경(`.background(Color.white)` 등) 없음 ✅

**결론**: 별도 코드 수정 없이 "다크 모드 대응"은 완료 상태. TODO 상태를 ✅로 정리하고 PLAN에 기록.

## 회귀 방지
- `AppTrafficView` 변경은 뷰 레이어만 — TrafficMonitor 로직 무변경
- 빌드 후 `xcodebuild` 통과 확인 + 앱 실행 스냅샷

## 롤백
- `git revert` 해당 커밋 (뷰 1개 + 문서)