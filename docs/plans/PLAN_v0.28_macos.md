# PLAN_v0.28_macos — 에너지 최적화 (폴링 기본값 조정 + TrafficMonitor 지연 시작 + 저전력 강화)

> 작성: 2026-08-12 (macOS)
> 버전: v0.28 (성능/에너지 최적화)
> 관찰 근거: 배터리 '많은 에너지 사용' 리포트 + 실측(nettop CPU 130%, 팝오버/시트 닫힘에도 TrafficMonitor 상시 가동)

## 1. 개요

배터리 이슈 심층 조사 결과, 방전의 직접 원인은 시스템 충전 인식 실패(하드웨어)로 확인됐지만
**앱 측에서도 nettop 상시 가동이라는 확실한 에너지 낭비 지점**이 실측으로 드러났다.

- `TrafficMonitor`가 `MenuBarManager.startMonitoring()`에서 무조건 `start()` → 팝오버·시트가 닫혀 있어도 5초마다 `nettop -l 6`(실행 6초) → 사실상 상시 nettop 구동 → CPU 130% 관측과 일치
- 폴링 간격 기본값이 불필요하게 짧음 (메뉴바 2초, ping 3초, traffic 5초)
- 저전력 모드는 IP/위치 갱신에만 적용되고 메뉴바/트래픽 모니터에는 미적용

이번 버전은 이 3가지를 개선해 에너지 절감을 달성한다. (충전 인식 문제는 하드웨어 확인 사항으로 분리)

## 2. 확정 범위

| 항목 | 결정 |
|------|------|
| 기본값 조정 | menuBarRefreshInterval 2.0→3.0, trafficMonitorInterval 5.0→10.0, pingInterval 3.0→5.0 (cacheRefreshInterval 5.0 유지) |
| TrafficMonitor 지연 시작 | 상시 구동 제거 → 참조 카운팅 `acquire()/release()` 기반. 카운트 0→1일 때만 `start()`, 1→0일 때 `stop()` |
| 저전력 모드 강화 | `powerStateChanged` 구독 → 저전력 ON 시 traffic stop + ping 간격 확대 + 메뉴바 갱신 주기 확대, OFF 시 복원 |
| 비고 | 차단 목록이 있으면 TrafficMonitor 상시 유지(차단 감지 보존), 팝오버 미리보기/시트 표시 시 acquire |

## 3. 구현 단계

### T-137 — PLAN 작성 + TODO 등록 (문서)
- 본 PLAN + `docs/TODO.md` v0.28 섹션

### T-138 — 폴링 기본값 조정 (SettingsManager + Localized)
- `SettingsManager.defaultMenuBarRefreshInterval: 2.0 → 3.0`
- `SettingsManager.defaultTrafficMonitorInterval: 5.0 → 10.0`
- `SettingsManager.defaultPingInterval: 3.0 → 5.0`
- `SettingsManager.defaultCacheRefreshInterval: 5.0 유지`
- 기존 설정 UI 옵션(menuBar 1/2/3초, traffic 3/5/10/15초, ping 3/5/10초)에 기본값이 모두 포함되므로 Localized 옵션 변경 불필요

### T-139 — TrafficMonitor 지연 시작 (참조 카운팅) — 최대 수확
- `Services/TrafficMonitor.swift`
  - `acquire()` / `release()` 추가. 내부 `usageCount`(main actor에서 관리) 기반, 0→1일 때 실제 `start()`, 1→0일 때 `stop()`
  - `start()`/`stop()`은 기존 시그니처 유지 (acquire/release가 호출)
- `App/MenuBarManager.swift`
  - `startMonitoring()`에서 `TrafficMonitor.shared.start()` → `TrafficMonitor.shared.acquire(reason: .appLaunch)`로 교체하되, 차단 목록이 비어 있으면 시작 안 함
  - `blockedAppsChanged` 노티 구독 → 차단 목록 0→1이면 acquire, 1→0이면 release
  - `stopMonitoring()`/슬립/깨움에서도 acquire/release 균형 유지
- `Views/PopoverView.swift`
  - `onAppear` → `TrafficMonitor.shared.acquire(reason: .popover)`, `onDisappear` → `release(reason: .popover)`
  - (기존 `@ObservedObject trafficMonitor` 구독 유지 — 미리보기는 표시 시에만 데이터 수신)
- `Views/AppTrafficView.swift`
  - `onAppear` → acquire, `onDisappear` → release (시트 열림 동안만 nettop 가동)

> 보장: 차단 감지 유지(차단 목록 있으면 상시), 팝오버 미리보기 유지, 앱이 아무 UI도 보지 않고 차단도 없으면 nettop 완전 중지.

### T-140 — 저전력 모드 강화 (MenuBarManager + PingMonitor)
- `App/MenuBarManager.swift`
  - `powerStateChanged` 노티 구독 → `applyPowerState()` 호출
  - 저전력 ON: `TrafficMonitor.shared.release(reason: .lowPower)` (차단 감지는 상시 유지하되 refresh 간격 확대 대신 중지 → 차단 목록 존재 시에는 ping만 유지)
  - 저전력 ON: 메뉴바 갱신 주기를 설정값 무관하게 최소 5초로 확대, OFF 시 원복
- `Networking/PingMonitor.swift`
  - `effectiveInterval` 계산: 저전력이면 `max(설정값, 15초)`, 아니면 설정값
  - `pingLoop`에서 `SettingsManager.shared.pingInterval` 대신 `effectiveInterval` 사용

### T-141 — 검증 + 문서 마무리
- `swift build` + `./scripts/test.sh` (SettingsAndSavingTests 기본값 검증)
- 수동 검증: 팝오버 닫힘 + 차단 없음 → `pgrep -f nettop` 0개 확인
- `docs/CHANGELOG.md` v0.28 기록 + `docs/TODO.md` ✅ 처리 + 세션 로그 저장

## 4. 영향 파일

- `Services/SettingsManager.swift` (기본값)
- `Services/TrafficMonitor.swift` (acquire/release)
- `App/MenuBarManager.swift` (시작/중지 제어 + 저전력)
- `Networking/PingMonitor.swift` (저전력 간격)
- `Views/PopoverView.swift`, `Views/AppTrafficView.swift` (acquire/release)
- 문서: PLAN/TODO/CHANGELOG

## 5. 테스트 계획

- 자동: `./scripts/test.sh` 전체 통과 (defaultPollingInterval 변경에도 static 참조라 무리 없음)
- 수동: `pmset -g`/DebugPanel 확인, 팝오버·시트 열고 닫으며 `pgrep nettop` 빈도 확인, 저전력 모드 토글 시 ping/메뉴바 주기 변화 확인
- 성능 관측: `ps`로 nettop/ping 스폰 빈도 감소 확인 (BEFORE/AFTER)

## 6. 롤백 계획

- 커밋 단위 `git revert`로 부분 복구 (기본값·지연 시작·저전력 각각 분리)
- `TrafficMonitor.acquire/release` 제거 시 기존 상시 `start()` 복귀 (회귀 없음)

## 7. 성능 예산

| 지표 | BEFORE | AFTER |
|------|--------|-------|
| nettop 프로세스 | 상시(~6초/5초 주기) | 팝오버/시트/차단 목록 있을 때만 |
| ping spawn | 3초마다 2개 교대 | 5초마다 2개 교대 (저전력 15초) |
| 메뉴바 갱신 | 2초 | 3초 (저전력 5초) |

## 8. 에러코드

- 신규 없음 (내부 로그만 추가, 사용자 노출 메시지 없음)
