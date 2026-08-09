# PLAN_v0.26.0_macos — 네트워크 진단 센터 + SSID 자동화 트리거 + 메뉴바 커스터마이징/export

> 작성: 2026-08-09 (macOS)
> 기준 커밋: b230b56 (v0.25.4 + 부록 A 코드베이스 검증 정정 완료)
> 버전: v0.26.0 (진단·자동화·메뉴바 강화)

## 1. 개요

경쟁 분석(COMPETITOR_ANALYSIS.md 부록 A)을 코드베이스 기준으로 정정한 결과,
TetherLens가 "측정만 하는 모니터"에서 "진단 + 자동화하는 관리도구"로 확장해야 할 실질 격차 3개를 한 버전에 통합한다.

- **A. 연결 진단 센터**: VPN/proxy 감지 · DNS 누수 검사 · 커스텀 ping · traceroute · bufferbloat · Markdown 리포트
- **C. WiFi/SSID 자동화 트리거**: 프로필(SSID) 전환 → 앱 실행/종료 · 절약 모드 자동 적용
- **B. 메뉴바 커스터마이징 확장 + 사용 내역 export**: 표시 필드 추가(BSSID/링크속도/DNS) + CSV/Markdown export

## 2. 확정 범위

| 항목 | 결정 |
|------|------|
| 진단 진입점 | 메뉴바 우클릭 `showMoreMenu()`에 "네트워크 진단" 항목 → floating NSPanel 전용 창 |
| 진단 항목 | scutil --proxy 파싱(VPN/proxy), DNS 누수(시스템 vs 설정 대조), 커스텀 ping(PingMonitor 재사용), traceroute -m 12, bufferbloat(idle RTT vs 부하 RTT), Markdown 리포트 복사 |
| 자동화 규칙 | `AutomationRule(ssid?, onConnect/onDisconnect, action: launch/quit/savingMode)` / UserDefaults 저장 / 60s 쿨다운 |
| 자동화 훅 | MenuBarManager의 `connectionChanged`/프로필 전환 지점에서 SSID 기준 매칭 |
| 메뉴바 옵션 | `SettingsManager` 신규 키 3종: `showBSSIDInMenuBar`, `showLinkSpeedInMenuBar`, `showDNSInMenuBar` |
| export | UsageReportView에 SavePanel(Range.CSV/Markdown) — 기간별 트래픽/세션/IP 덤프 |

**제외**: per-app 네트워크 차단(NEFilter) — Apple 유료 + Network Extension 필요, 무료/OSS 배포와 구조적 충돌.

## 3. 구현 단계

### T-127 연결 진단 센터 (진단 패널)
- `Networking/NetworkDiagnostics.swift`: `DiagnosticsRunner` — `runVPNProxyCheck()`, `runDNSLeakCheck()`, `runTraceroute(host:)`, `runBufferbloat()`, `runCustomPing(host:)`, `renderMarkdown()`
  - `scutil --stat`/CFNetworkCopySystemProxySettings로 proxy 감지
  - DNS 누수: 사용자 설정 DNS(내부기록) vs 시스템 DNS 대조 + 테스트 도메인 질의 응답 서버 확인
  - `traceroute`/`ping`은 비동기 Process로 실행, 결과 파싱
- `Views/DiagnosticsView.swift` — SwiftUI 패널, 진행/결과 배열·스크린, "Markdown 복사" 버튼
- `App/DiagnosticsWindowController.swift` — `NSPanel(.floating)`, 메뉴 `showMore()`에서 open

### T-128 SSID 자동화 트리거
- `Models/AutomationRule.swift` — Codable 규칙
- `Services/AutomationManager.swift` — `evaluate(ssid:connected:)`, 쿨다운 60초, 액션 실행(`NSWorkspace.openApplication`, `killall`/`_workspace_close`, `SavingModeController`)
- MenuBarManager의 프로필 전환 지점에 `automation.evaluate(ssid:)` 호출
- SettingsView에 "자동화" 섹션 (규칙 추가/삭제 뷰)

### T-129 메뉴바 표시 필드 확장
- SettingsManager 신규 keys + SettingsView 토글 그룹
- MenuBarView(updateMenuBarText) 조합 확장

### T-130 사용 내역 CSV/Markdown export
- UsageReportView "내보내기(Save)" 버튼 — NSSavePanel, CSV(트래픽/세션/IP) + Markdown 요약

### T-131 검증
- `./build_and_run.sh debug macos` 성공, DebugPanel 로그(ERROR 0), `a11y-dump`, CHANGELOG 기록

## 4. 영향 파일
- 신규: `Networking/NetworkDiagnostics.swift`, `Views/DiagnosticsView.swift`, `App/DiagnosticsWindowController.swift`, `Models/AutomationRule.swift`, `Services/AutomationManager.swift`
- 수정: `Services/SettingsManager.swift`, `App/MenuBarManager.swift`, `Views/SettingsView.swift`, `Views/UsageReportView.swift`, `Services/ProfileManager.swift`

## 5. 테스트 계획
- 단위: AutomationRule Codable 왕복, 쿨다운 로직, SettingsManager 새 키 기본값
- 수동: 진단 패널 열기(각 항목 실행), 자동 규칙 "테더링" SSID → 메모 앱 실행, 메뉴바 필드 3종 온오프
- 빌드: `swift build test` 전체 통과

## 6. 롤백 계획
- T커밋 단위 `git revert`(모든 기능이 신규/독립)
- 진단·자동화·메뉴바 옵션 제거 시 기존 동작과 무관

## 7. 성능 예산
- 진단: 요청 시에만 실행(백그라운드 폴링 없음)
- 자동화: 1초 미만 즉시 실행, 쿨다운 제한
- 메뉴바 옵션: update 시 기존 비용에 필드 문자열 조립만 추가

## 8. 에러코드
- 신규: `E-MAC-NET-2001`(진단 실행 실패), `E-MAC-AUTO-2001`(자동화 규칙 실행 실패) — Diagnostics/Automation 내부 로그, 사용자 노출은 DebugPanel