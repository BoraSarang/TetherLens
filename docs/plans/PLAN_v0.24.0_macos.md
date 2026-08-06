# PLAN_v0.24.0_macos — 정밀 분석 기반 버그 수정 + 리팩토링

> 작성: 2026-08-06 (macOS)
> 기준 커밋: 56ac472 (v0.23.1 완료)

## 1. 개요

프로젝트 소스(약 8,500줄)를 정밀 분석해 발견한 예상 버그/리팩토링 후보를 수정한다.
2개 조사 에이전트(타이머·리소스 / 데이터 정합성)의 보고 + 핵심 파일 직접 검증으로 확정했다.
수정 후 자동 테스트(32개) 반복 실행, 재분석으로 중요한 발견이 없을 때까지 반복한다.

## 2. 확정 버그 (심각도 순)

### High
| # | 위치 | 문제 |
|---|------|------|
| H1 | MenuBarManager.swift:420-446 + ProfileManager.swift:109-139 | 프로필(SSID) 전환 시 `cumulativeCounters`를 재시드하지 않음 → 이전 프로필에 타 프로필 기간 트래픽 이중 계상 |
| H2 | ProfileManager.swift:116-119 | 음수 델타 발생 시 반대 방향 양수 델타까지 폐기 (예: dn +100도 버림) — 테스트가 버그를 정답으로 고정 |
| H3 | TrafficMonitor.swift:26-28 vs 97-108 | `start()`가 main 스레드에서 `accumulated` 직접 리셋, `refresh()`는 serial queue에서 접근 → data race |

### Medium
| # | 위치 | 문제 |
|---|------|------|
| M1 | NetworkMonitor.swift:104-118 | `todayUsage`는 사용처 없는 죽은 코드 + 자정 리셋 로직 도달 불가 (오늘 사용량이 부팅 후 누적 전체와 동일) |
| M2 | ProfileManager.swift:20-23,172-194 | getTodayUsage 캐시가 날짜 미포함 → 자정 직후 3초간 전날 합계 반환 |
| M3 | ProfileManager.swift:177-188,330-337 | up/dn 각각 별도 read → 시점 불일치 |
| M4 | DataStore.swift:116-135 | v8 rebuild가 트랜잭션 내 `PRAGMA foreign_keys=OFF` no-op → orphan session_id 시 전체 DB 초기화 위험 |
| M5 | MenuBarManager.swift:432-437 | SSID 전환 시 getActiveSession 미확인 → crash 후 중복 활성 세션 |
| M6 | PingMonitor.swift:257 | 정상 완료 시 watchdog 미취소 (불필요한 terminate 시스템콜) |
| M7 | PingMonitor.swift:207-210 | cooldown이 레벨 상승(warning→critical) 알림을 억제 |
| M8 | MenuBarManager.swift:86-102 | 설정 변경 시 cache 미무효화 + stopMonitoring 시 location 미중지 |
| M9 | ProfileManager.swift:157-170 | 1년 넘은 활성 세션(end_time NULL)이 cleanup 대상에서 제외 → 영구 잔존 |
| M10 | TrafficMonitor.swift:97 | nettop(~2초) 동안 queue 점유 → refresh 백로그 (중복 실행 skip 필요) |
| M11 | ProfileManager.swift:396-402 | CSV에서 `"`만 포함된 값 미쿼팅 → 파싱 오류 |

### 2차 발견 (뷰 계층 — 에이전트 보고 + 직접 검증 확정)

| # | 위치 | 문제 |
|---|------|------|
| V1 | ProfileManager.swift getIPForSession | 세션별 IP 조회 시 프로필 전체 IPLog `fetchAll` → 세션 N개면 O(N×M) |
| V2 | PopoverView.swift:148-150 | 1초 타이머 publisher를 body 내부에서 생성 → body 재평가마다 Timer 재생성 |
| V3 | PopoverView.swift:97-114 | 5초 알림 클리어가 비동기 무조건 nil → 5초 내 새 알림이 있어도 지워짐 (race) |
| V4 | SettingsView.swift:119-124 | 폰트 슬라이더 onChange마다 settingsChanged → TrafficMonitor stop/start 폭주 |
| V5 | AppTrafficView.swift:8,131 | 블록 토글 시 TrafficMonitor.apps 갱신까지 body 미재평가 → 즉시 반영 안 됨 |
| V6 | DebugPanelView.swift:5-6,65 | 선택 추적을 배열 인덱스로 → 로그 삭제/clear 시 밀려 잘못된 줄 선택 |

## 3. 수정 계획 (T-번호)

- **T-92** ProfileManager: 음수 델타 시 양수 방향만 기록 (H2) + 카운터 재시드 메서드 `resetCounter` 추가 (H1 용)
- **T-93** MenuBarManager: SSID 전환 시 이전 기록 후 새 프로필 카운터 시드 + getActiveSession 재사용 (H1, M5)
- **T-94** ProfileManager: getTodayUsage 자정 경계 캐시 + up/dn 단일 read + getTotalUsage 단일 read (M2, M3)
- **T-95** ProfileManager: cleanupOldLogs 활성 세션 정리 (M9) + csvEscape 쿼팅 보강 (M11)
- **T-96** TrafficMonitor: start() 리셋 queue 직렬화 (H3) + refresh 백로그 skip (M10) / NetworkMonitor: todayUsage 죽은 코드 제거 (M1)
- **T-97** PingMonitor: watchdog 취소 (M6) + cooldown 레벨 상승 허용 (M7) / HotspotDetector: start 중복 가드 / MenuBarManager: startMonitoring 가드·시드·종료 기록 (M8)
- **T-98** DataStore: v8 rebuild orphan 정리 (M4) + 테스트 수정/추가
- **T-99** ProfileManager: getIPForSession을 SQL 쿼리화 (V1) / PopoverView: 타이머 publisher static + 알림 클리어 값 비교 (V2, V3)
- **T-100** SettingsView: 폰트 슬라이더 onEditingChanged(드래그 종료 시 1회) (V4) / AppBlockManager: ObservableObject + AppTrafficView 구독 (V5)
- **T-101** DebugPanelView: 선택 추적을 UUID 기반으로 (V6)
- **T-102** 검증: 테스트 전체 실행 + 재분석 반복 + 문서 마무리

### 3차 발견 (3차 재분석 — 서브에이전트 + 직접 검증 확정)

| # | 위치 | 문제 |
|---|------|------|
| W1 | MenuBarManager.swift:419-453 | SSID 전환 시 `cachedProfile`(이전 프로필) short-circuit → 새 세션이 이전 프로필 소유로 생성, usage_log 프로필 오염 (High) |
| W2 | MenuBarManager.swift:481-486,645-672 | autoActivate(80%)가 "할당량 초과" 알림 발송 → 80% 시점 오정보 + 임계 알림과 중복 |
| W3 | NetworkMonitor.swift:33-39 | 속도 계산 `elapsed` 하드코딩 1.0 → 타이머 지연 시 과대계상 |
| W4 | TrafficMonitor.swift:47-59 + MenuBarManager:123-127 | 종료 시 `saveAccumulated`가 queue.async라 마지막 구간 app_traffic_log 유실 가능 |
| W5 | PingMonitor.swift:98-110 | 연결 토글 알림에 쿨다운 없음 → 플래핑 시 알림 폭주 |

- **T-103** MenuBarManager: SSID 전환 시 `cachedProfile` 즉시 무효화 (W1) + autoActivate의 "초과" 알림 제거(임계 알림과 통합) (W2)
- **T-104** NetworkMonitor: 실제 경과 시간 기반 속도 계산 (W3)
- **T-105** TrafficMonitor: 종료용 동기 flush 추가 + handleAppTermination에 호출 (W4)
- **T-106** PingMonitor: 연결 토글 알림 최소 간격(쿨다운) 적용 (W5)

### 4차 발견 (4차 재분석 — 서브에이전트 + 직접 검증 확정)

| # | 위치 | 문제 |
|---|------|------|
| X1 | MenuBarManager.swift:640-647 + Profile.swift:27-38 | `connectionTypeString(for:)`가 카멜케이스("iOSHotspot") 반환, `Profile.isHotspot`은 스네이크("ios_hotspot")만 인식 → 재접속 시 autoRegisterIfNeeded가 연결 타입을 덮어써 데이터 파괴 (High) |
| X2 | MenuBarManager.swift:420-430,432 | autoSwitchProfile OFF 시 SSID 변경에도 cachedProfile 미무효화 → 새 트래픽이 이전 프로필 세션에 귀속 (High) |

- **T-107** MenuBarManager: `connectionTypeString(for:)` 스네이크케이스 통일 (X1) / DataStore: v9 마이그레이션으로 카멜→스네이크 정규화 (X1) / 테스트 추가
- **T-108** MenuBarManager: SSID 변경 시 cachedProfile·cachedUsage·cachedTotalUsage를 autoSwitchProfile과 무관하게 즉시 무효화 (X2)

## 4. 테스트 계획 (TC)

- 기존 테스트 수정: `recordUsage_누적_델타_계산` (H2 동작 변경 반영 — 음수 방향만 재시드)
- 신규 테스트: resetCounter 후 이중 계상 방지, 자정 경계 캐시(날짜 변경), CSV 따옴표 쿼팅, cleanup 활성 세션
- 2차 수정(V1~V6)·3차 수정(W1~W5)은 뷰/비동기/알림 계층이라 자동 테스트 대상 아님 — 빌드 + 수동 확인
- TC-102: `swift test` 전체 통과, `build-macos.sh debug` 성공, 테스트 반복 실행으로 회귀 0

## 5. 롤백 계획

- 커밋 단위 분리: H1/H2/H3 관련 커밋은 독립이라 `git revert`로 부분 복구 가능
- DB 스키마 변경 없음 (v8 마이그레이션 내부 orphan 정리만 추가 — 기존 DB 영향 없음)
- 테스트 실패 시: 기존 32개 + 신규 테스트에서 어느 파일 실패인지 식별 후 해당 커밋만 revert

## 6. 성능 예산

- 실질 성능 변화 없음. TrafficMonitor refresh skip으로 nettop 중복 실행 감소, getTodayUsage 단일 read로 DB 조회 1회 절감.
