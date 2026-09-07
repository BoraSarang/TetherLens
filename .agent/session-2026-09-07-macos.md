# 세션 로그 — 2026-09-07 (macOS)

## 무엇을
- 프로세스 CPU/RAM 표시 (T-175~190, v0.32.0): `SystemResourceMonitor` 신규 (libproc+host_statistics 직접 호출, 서브프로세스 없음)
- 팝오버 상세 보기 `시스템 리소스` 섹션 (CPU Top3 + 메모리 Top3) + 표시 토글. 간략 보기에서는 제거
- 플로팅 3칸 (프로세스 Top3 3열헤더 / CPU Top3 / RAM Top3) + 칸별 토글 3개 + `fitToContent()` 자동 높이 (루트 스택 구조 — overlay 미기여 붕괴 수정)
- 네트워크 리스트 CPU/MEM 원복 (리소스는 독립 영역에만)
- 버그 수정 (P0): 랭킹이 네트워크 기록 프로세스 안에서만 뽑혀 java/node 누락 → 전체 스냅샷 기준 (`allResources` + `topResources` 헬퍼). 캡처에서 java 5.0GB/node 3.1GB 확인
- 테스트 13개 신규 (총 77개), 릴리즈 v0.32.0 (태그 + GitHub Release + zip)

## 플랫폼
- macOS (SwiftPM, SwiftUI/AppKit, TrafficMonitor 편승 수집)

## 빌드 + PERF + CACHE
- swift test 77개 통과, build-macos.sh debug/release 성공
- PERF: 수집 1회 수 ms (332프로세스), wakeup 추가 0개 (nettop 주기 편승), NFR-01/02 유지. CACHE 영향 없음 (DB 쓰기 없음)

## 남은 TODO
- 저전력 모드에서 리소스 값 동결 동작 실기 확인 (코드는 기존 setLowPower 상속)
- 슬라이더 드래그(nonactivating 패널) 사용자 확인 요청 상태 (기존 잔여)

## 전달 로그
- `[INFO] [SysRes]` 진입 2종 (병합 시작/기준 샘플), `[ERROR] E-MAC-PERF-3201` 1회 스로틀, `[ACTION] [Floating]` 자동 높이·acquire/release

## 문서 갱신
- docs/plans/PLAN_v0.32.0_macos.md + docs/TODO.md T-175~190 + docs/CHANGELOG.md [0.32.0] + Resources/Info.plist 0.32.0/32 + 본 세션 로그

## 큐 상태
- bd 전부 close (TetherLens-y8j, -isx, -4sx, -09u, -mt5). 브랜치 main, origin/main 동기화 + 태그 v0.32.0 + GitHub Release

## E2E
- 실화면 캡처 4회로 렌더 직접 확인 (3칸 9행·3열 헤더·자동 높이·java/node). 수동 GUI 잔여는 사용자 확인분 없음
