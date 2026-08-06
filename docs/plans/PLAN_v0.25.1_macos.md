# PLAN_v0.25.1_macos — 슬립 시 폴링 중지 + 팝오버 tick 최적화

> 작성: 2026-08-06 (macOS)
> 기준 커밋: 7472d4f (v0.25.0 완료)
> 버전: v0.25.1 (성능 최적화)

## 1. 개요

시스템이 슬립(화면 꺼짐/전체 슬립)일 때 네트워크 폴링·핑·트래픽 측정이 계속 돌아 배터리/CPU를 낭비한다.
macOS 슬립 이벤트를 구독해 슬립 진입 시 측정을 일시 중지하고, 깨어나면 자동 재개한다.
(성능 후보 중 이득 최대인 P1 항목 — PERFORMANCE_OPTIMIZATION.md에 후보로 기록됨)

## 2. 확정 범위

| 항목 | 결정 |
|------|------|
| 슬립 감지 | `NSWorkspace.willSleepNotification` / `didWakeNotification` (전체 슬립) + 화면 절전은 제외(네트워크는 화면 꺼짐에도 동작) |
| 중지 대상 | NetworkMonitor(1초 폴링), TrafficMonitor(nettop), PingMonitor(ping 루프), MenuBarManager의 record/ipRefresh/location/cache/timer |
| 재개 | 깨어난 직후 모든 모니터 재시작 + 캐시 무효화 + 즉시 메뉴바 갱신 |
| 부수 최적화 | 팝오버 닫힘 시 1초 tick 중지(별도 커밋), Timer tolerance(별도 커밋) |

## 3. 구현 단계

- **T-119** 슬립/깨움 이벤트 구독 + 모니터 일시중지/재개 (MenuBarManager)
  - `willSleepNotification` 수신 시 `suspendMonitoring()` — 네트워크/핫스팟/핑/트래픽 중지 + 타이머 invalidate + 활성 세션 종료(아니면 사용량 기록만) + 위치 중지
  - `didWakeNotification` 수신 시 `resumeMonitoring()` — startMonitoring과 동일하게 재시작(중복 방지 가드)
  - DebugLogger에 `[SYSTEM] 슬립/깨움` 로그
- **T-120** 팝오버 닫힘 시 tick 중지 (PopoverView)
  - `onAppear`/`onDisappear` 또는 NSPopover close 시 tickTimer 일시 중지
- **T-121** Timer tolerance 부여 (MenuBarManager/TrafficMonitor)
  - `timer.tolerance = interval * 0.1` — 타이머 병합으로 전력 절감

## 4. 영향 파일

- `App/MenuBarManager.swift` (슬립 구독·suspend/resume·timer tolerance)
- `Views/PopoverView.swift` (tick 중지)
- `Services/TrafficMonitor.swift` (timer tolerance, stop/start 유지)

## 5. 테스트 계획

- 단위 테스트: suspend/resume이 메서드 존재·호출 시 상태 전환되는지 (MenuBarManager는 @MainActor + NSObject라 직접 테스트 어려움 → 최소 검증)
- 수동 검증: `pmset sleepnow`로 슬립 → 깨움 후 메뉴바 속도/사용량 재개 확인, DebugPanel 로그 확인
- 빌드: `swift build` + `swift test` 전체 통과

## 6. 롤백 계획

- 각 T 커밋 단위 `git revert` (메서드 추가라 기존 동작과 독립)
- 슬립 구독 제거 시 이전처럼 항상 폴링(회귀 없음)

## 7. 성능 예산

- 슬립 중 CPU: 0 (모든 폴링 중지)
- 깨어남 후 재개 지연: < 1초 (didWakeNotification 즉시)
- 기존 성능 예산 유지 (슬립 외 동작 변경 없음)

## 8. 에러코드

- 신규 없음 (내부 로그만 추가, 사용자 노출 메시지 없음)
