# PLAN v0.22.0 — 자동화 테스트 도입 (macOS)

> 작성일: 2026-08-06 · 플랫폼: macOS · 기반: v0.21.1 (완료)

## 개요
현재 수동 테스트 가이드(`docs/tests/v0.21.0_macos.md`)에만 의존하던 검증을 자동화한다.
서비스 로직은 Swift Testing 단위 테스트로, 자동화 불가한 UI/권한/네트워크 항목은
`scripts/test.sh` 실행 후 수동 체크리스트로 안내하는 2단계 방식을 표준화한다.

## 결정 사항
1. 테스트 프레임워크: **Swift Testing** (`import Testing`, swift-tools 6.0, macOS 14+)
2. 테스트 타겟 `TetherLensTests` 추가, `@testable import TetherLens`
3. 테스트 가능하도록 주입 리팩토링 (동작 변경 없음):
   - `DataStore`: `init(dbQueue:)` 테스트 이니셜라이저 + `makeMigrator` internal 노출
   - `ProfileManager`: `init(db:)` db 주입
   - `SettingsManager`: `init(defaults:)` UserDefaults 주입
   - `SavingModeManager`: `init(defaults:)` UserDefaults 주입
4. 자동화 스크립트 `scripts/test.sh`:
   - `swift test` 실행 (자동화 가능 항목)
   - 실패 시 종료 코드 + 실패 목록 출력
   - 성공 시 자동화 불가 수동 체크리스트를 화면에 출력 (docs/tests 기준)
5. 자동화 불가 항목(수동): 메뉴바/팝오버 UI, 온보딩·위치·알림 권한, 절약모드 실제 hosts 차단(sudo), nettop 실측, ping 실측, 핫스팟 실제 연결, 저전력 모드, DebugPanel

## 아키텍처
- SwiftPM 단일 앱 타겟 + 테스트 타겟. UI(AppKit/SwiftUI)는 테스트 타겟에서 컴파일되지만 실행하지 않음.
- 테스트는 인메모리 SQLite(`DatabaseQueue()`)와 격리된 `UserDefaults(suiteName:)` 사용 → 실제 데이터/설정 오염 없음.

## 구현 단계
| T# | 작업 | Priority |
|----|------|----------|
| T-67 | 주입 리팩토링 (DataStore/ProfileManager/SettingsManager/SavingModeManager) | P1 |
| T-68 | Package.swift 테스트 타겟 추가 | P1 |
| T-69 | DataStore/ProfileManager 테스트 (스키마, CRUD, 델타, 세션, IP, CSV 이스케이프, cleanup) | P1 |
| T-70 | SettingsManager/SavingModeManager 테스트 (기본값, 리셋, 임계값) | P1 |
| T-71 | SystemProcesses/Localized 테스트 | P2 |
| T-72 | scripts/test.sh 자동화 스크립트 (자동 + 수동 체크리스트 안내) | P1 |
| T-73 | 문서화 (PLAN/TODO/CHANGELOG/TEST 가이드) | P1 |

## 테스트 계획 (자동화)
- TC-01: v1~v8 마이그레이션 후 스키마(테이블/인덱스/FK) 존재
- TC-02: 프로필 CRUD + autoRegisterIfNeeded (기존 갱신/신규 생성)
- TC-03: recordUsage 누적 델타 계산 (오버플로/음수 방지, 초기값 시드)
- TC-04: getTodayUsage/daily/monthly 요약 정합성
- TC-05: 세션 start/end/active/usage 연계 (session_id FK)
- TC-06: IP 로그 1800s dedup + mergeStaleIPLogs + getIPForSession
- TC-07: cleanupOldLogs (365일 초과 제거, 세션-usage 연쇄 삭제)
- TC-08: exportData CSV 이스케이프 (콤마/따옴표/개행)
- TC-09: SettingsManager 기본값/reset/isUsingDefault
- TC-10: SavingModeManager green/orange 임계값 + shouldAutoActivate
- TC-11: SystemProcesses 주요 시스템 프로세스 포함
- TC-12: Localized ko/en 선택

## 수동 체크리스트 (자동화 불가)
`scripts/test.sh` 통과 후 아래를 순서대로 확인한다 (상세: docs/tests/v0.21.0_macos.md T-01~T-56):
1. 메뉴바 표시/오른쪽 클릭 더보기/팝오버
2. 온보딩 첫 실행 + 위치/알림 권한
3. 실제 핫스팟 연결 감지 (SSID/OS 구분)
4. 절약모드 hosts 차단 (sudo, T-41~T-43)
5. 트래픽 실측 (nettop) + 메뉴바 속도/할당량
6. ping/레이턴시 게이지 색상
7. 알림 (할당량 50/80/95/100%, 레이턴시)
8. DebugPanel (Cmd+D) + 로그 검사
9. 배터리 (저전력 모드 동작)

## 롤백 계획
- 주입 리팩토링은 동작 변경 없음 → 회귀 시 각 파일 개별 원복
- 테스트 타겟/스크립트는 앱 동작과 무관, 삭제만으로 롤백 가능
- 실제 DB/설정 접근 없음 (인메모리/suite 격리)

## 성능 예산
- 테스트 실행 ≤ 30초. 앱 빌드 성능 영향 없음 (테스트 타겟은 빌드 시에만 추가).
