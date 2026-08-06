# PLAN v0.21.1 — Low 후보 6건 개선 (macOS)

> 작성일: 2026-08-06 · 플랫폼: macOS · 기반: v0.21 (완료)

## 개요
v0.21 반복 분석에서 남긴 Low 등급 후보 6건을 정리한다. 기능 변경 없이 코드 품질/접근성/일관성 개선만 진행한다.

## 결정 사항
1. QoS 임계값 단일화: `SavingModeManager.greenThreshold/orangeThreshold`를 유일한 소스로 사용
   - `QoSGauge`의 `saving` 파라미터 제거, 내부에서 `SavingModeManager.shared` 임계값 사용
   - `MenuBarManager.colorForRatio` 동일하게 단일화
2. AppTrafficView: `showSystemProcesses`를 `@State` → `@AppStorage`로 전환 (닫아도 상태 유지)
3. SettingsView: 폴링 간격 변경을 `onDisappear` 의존 → 각 Picker `onChange` 즉시 저장 + 방어적 `onDisappear` 유지
4. UsageReportView: `appTrafficData`를 `viewMode == .appTraffic`일 때만 로드 (불필요한 쿼리 제거)
5. HeatmapGridView: 셀에 `.focusable()` + `.onKeyPress(.return)` + `.onTapGesture` + `.accessibilityLabel` 추가 (키보드 접근성)
6. DebugPanelView: 하드코딩 UI 문자열을 `Localized.string(ko, en)`으로 로컬라이즈

## 아키텍처
- iOS/Android 없음, macOS 단일. SwiftUI + AppKit 혼합 그대로 유지.

## 구현 단계
| T# | 작업 | Priority |
|----|------|----------|
| T-61 | QoS 임계값 단일화 (QoSGauge + MenuBarManager) | P2 |
| T-62 | AppTrafficView 상태 @AppStorage 유지 | P2 |
| T-63 | SettingsView 폴링 즉시 저장 (onChange) | P2 |
| T-64 | UsageReportView appTraffic 조건부 로드 | P2 |
| T-65 | HeatmapGridView 키보드 접근성 | P3 |
| T-66 | DebugPanelView 로컬라이즈 | P3 |

## 테스트 계획
- TC-01: 절약모드 ON/OFF에서 메뉴바 게이지·팝오버 게이지 색상 경계가 동일한지 (0.4/0.6, 0.65/0.85)
- TC-02: AppTrafficView에서 "시스템 프로세스 제외" 토글 후 닫았다 다시 열면 상태 유지
- TC-03: SettingsView에서 폴링 간격 변경 즉시 SettingsManager에 반영 (onDisappear 없이)
- TC-04: 사용량 리포트에서 앱 트래픽 탭 전환 시에만 로드 (DebugPanel 로그로 확인)
- TC-05: HeatmapGridView 셀을 Tab으로 포커스 + Return으로 선택 → 상세 텍스트 갱신
- TC-06: DebugPanel UI 문자열이 영문 로케일에서 영어로 표시

## 롤백 계획
- 단순 소스 롤백: `git revert` (커밋 전이므로 staged 상태에서 부분 되돌리기 가능)
- 동작 회귀 시 개별 파일만 원복, 별도 DB 마이그레이션 없음

## 성능 예산
- 코드 품질 개선으로 성능 영향 없음 (UsageReportView의 불필요 쿼리 제거로 로드 시간 약간 개선)
