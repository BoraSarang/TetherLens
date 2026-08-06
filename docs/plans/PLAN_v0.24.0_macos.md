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

## 3. 수정 계획 (T-번호)

- **T-92** ProfileManager: 음수 델타 시 양수 방향만 기록 (H2) + 카운터 재시드 메서드 `resetCounter` 추가 (H1 용)
- **T-93** MenuBarManager: SSID 전환 시 이전 기록 후 새 프로필 카운터 시드 + getActiveSession 재사용 (H1, M5)
- **T-94** ProfileManager: getTodayUsage 자정 경계 캐시 + up/dn 단일 read + getTotalUsage 단일 read (M2, M3)
- **T-95** ProfileManager: cleanupOldLogs 활성 세션 정리 (M9) + csvEscape 쿼팅 보강 (M11)
- **T-96** TrafficMonitor: start() 리셋 queue 직렬화 (H3) + refresh 백로그 skip (M10) / NetworkMonitor: todayUsage 죽은 코드 제거 (M1)
- **T-97** PingMonitor: watchdog 취소 (M6) + cooldown 레벨 상승 허용 (M7) / HotspotDetector: start 중복 가드 / MenuBarManager: startMonitoring 가드·시드·종료 기록 (M8)
- **T-98** DataStore: v8 rebuild orphan 정리 (M4) + 테스트 수정/추가
- **T-99** 검증: 테스트 전체 실행 + 재분석 반복 + 문서 마무리

## 4. 테스트 계획 (TC)

- 기존 테스트 수정: `recordUsage_누적_델타_계산` (H2 동작 변경 반영 — 음수 방향만 재시드)
- 신규 테스트: resetCounter 후 이중 계상 방지, 자정 경계 캐시(날짜 변경), CSV 따옴표 쿼팅, cleanup 활성 세션
- TC-099: `swift test` 전체 통과, `build-macos.sh debug` 성공, 테스트 반복 실행으로 회귀 0

## 5. 롤백 계획

- 커밋 단위 분리: H1/H2/H3 관련 커밋은 독립이라 `git revert`로 부분 복구 가능
- DB 스키마 변경 없음 (v8 마이그레이션 내부 orphan 정리만 추가 — 기존 DB 영향 없음)
- 테스트 실패 시: 기존 32개 + 신규 테스트에서 어느 파일 실패인지 식별 후 해당 커밋만 revert

## 6. 성능 예산

- 실질 성능 변화 없음. TrafficMonitor refresh skip으로 nettop 중복 실행 감소, getTodayUsage 단일 read로 DB 조회 1회 절감.
