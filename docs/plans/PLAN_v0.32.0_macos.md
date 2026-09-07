# PLAN v0.32.0 — 프로세스 CPU/RAM 보조 표시 (B안)

- **버전**: v0.32.0 (build 32)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-07
- **상태**: 진행 중
- **이슈**: bd TetherLens-y8j
- **스킬**: macos-app-design (밀집 테이블 표면) — "딱 맥 앱 같아야"
- **선행**: v0.31.0 플로팅 창 진행 중 — 본 작업은 그 위에 리베이스

---

## 1. 개요

### 1.1 배경

- 앱에 네트워크 프로세스 보기(`TrafficMonitor` + nettop 기반 `AppTrafficView`/팝오버 미리보기/플로팅 top3)가 있음.
- 사용자 요청: "이것처럼 CPU, RAM 사용량도 추가할 수 있을까? 너무 오버헤드인가? 앱과 너무 동떨어진 기능인가?"
- 합의: **B안(정렬까지 지원) + 표시 3면(앱 트래픽 창 / 팝오버 top5 / 플로팅 top3)** 으로 진행.
- **범위 명확화 (2026-09-07)**: 사용자는 네트워크 행 보조지표가 아니라 **프로세스 리스트처럼 따로 독립적인 CPU/RAM 섹션**을 원한다고 확인. 팝오버 프로세스 밑 + 플로팅에 각각 독립 랭킹 섹션 추가 (T-180/181). 같은 스냅샷 재정렬이라 추가 폴링 없음.
- **범위 확정 2차 (2026-09-07, v0.32.1)**: ① 네트워크 프로세스 리스트의 CPU/MEM 보조 표시 전면 제거 (T-183) — 리소스는 독립 영역에만. ② 팝오버 간략 보기에서 프로세스·리소스 섹션 제거, 상세 보기만 표시 + 리소스 표시 토글 (T-184). ③ 플로팅은 Top3 리스트 대신 3줄 요약 (프로세스/CPU/RAM 각 1위) + 줄별 표시 토글 3개, 높이 가변 (T-185).
- **범위 확정 3차 (2026-09-07, v0.32.2)**: 플로팅도 상세 보기처럼 3칸 (프로세스/CPU/RAM Top3, 칸별 토글) (T-187). 높이는 고정값 대신 `fitToContent()` 실측 자동 맞춤 — 사용자 질문("자동으로 사이즈 변경 되는거 맞지?")에 맞게 상단 고정·40~420 클램프, 수집 갱신/토글 시 재적합.
- **버그 수정 (2026-09-07, v0.32.3, T-188)**: 실측 높이가 40으로 붕괴해 패널이 쪼그라듦. 원인 — 루트가 `RoundedRectangle + .overlay{콘텐츠}` 구조라 overlay 속 콘텐츠가 ideal size에 기여하지 않음. 루트를 콘텐츠 스택(`Group`) + `.background` 구조로 변경해 해결. 캡처로 3칸 9행 렌더 확인.
- **버그 수정 (2026-09-07, v0.32.4, T-190, P0)**: CPU/MEM Top이 네트워크 기록 있는 프로세스 안에서만 뽑혀 네트워크 안 쓰는 java/node가 순위에 안 뜸 (사용자 지적). `TrafficMonitor.allResources`(전체 스냅샷) 신설 + `topResources(_:limit:value:)` 헬퍼로 전체 기준 랭킹. 캡처에서 java 5.0GB / node 3.1GB 메모리 1·2위 확인.

### 1.2 목표 (이번 범위)

1. **CPU%/MEM 보조 지표**: 네트워크 행에 프로세스별 CPU% + 메모리(RSS) 표시.
2. **정렬 전환**: 앱 트래픽 창에서 네트워크순 / CPU순 / 메모리순 전환 (`AppStorage` 저장).
3. **표시 3면**: 앱 트래픽 창(전체 테이블) + 팝오버 top5(보조 텍스트) + 플로팅 top3(보조 텍스트). 팝오버/플로팅 정렬은 네트워크순 유지(혼란 방지).
4. **독립 리소스 섹션**: 팝오버 프로세스 밑 `시스템 리소스` 섹션 (CPU Top3 + 메모리 Top3, 요약/상세 모두) + 플로팅 트래픽 밑 CPU순 Top3 섹션.
5. **에너지 무증가**: 추가 타이머·추가 서브프로세스(`ps`/`top` 스폰) 없음. 기존 `TrafficMonitor.refresh()` 주기(`trafficMonitorInterval`, 기본 10초)에 편승.

### 1.3 범위 외 (Non-goals)

- 강제 종료, CPU 그래프, 상시 백그라운드 수집.
- DB 스키마 변경 (`app_traffic_log` 손대지 않음 → 마이그레이션 없음).
- 메뉴바 숫자에 CPU/MEM 추가.
- Activity Monitor급 전체 시스템 탭.

---

## 2. 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| 수집 API | `libproc(proc_listpids/proc_pidinfo PROC_PIDTASKINFO/proc_pidpath)` + `host_statistics64` + `sysctl hw.memsize` | 서브프로세스 스폰 없이 수십 ms. `task_for_pid`는 권한 문제로 사용 금지 |
| CPU% 정의 | `(pti_total_user+pti_total_system 델타) / 경과시간 × 100` (1코어=100%, 멀티코어 100% 초과 가능) | `top`과 동일 정의. 첫 샘플은 `nil`→"–" 표시 |
| MEM 정의 | `pti_resident_size`(RSS) 합산 + `hw.memsize` 대비 %는 툴팁/요약에만 | 동일 프로세스명 다중 pid는 RSS 합산, CPU 합산 |
| 이름 매칭 | nettop `Foo.1234`→`Foo`(`dropLast`)와 `proc_pidpath`→`lastPathComponent` 매칭 재사용 | 기존 파싱 로직 재사용. 불일치 시 행 유지 + "–" |
| 타이밍 | `TrafficMonitor.refresh()` 직렬 `queue` 안에서 nettop 파싱 직후 1회 조회 | wakeup 추가 0개. 저전력/슬립 가드는 기존 `acquire/release`·`setLowPower`·`suspend/resume` 상속 |
| 정렬 상태 | `@AppStorage("appTrafficSort")` (network/cpu/mem) | 설정 화면 신설 없이 툴바 피커로 충분 |
| 팝오버/플로팅 | 네트워크 정렬 유지, 2행째 보조 텍스트 `CPU x% · MEM y` | 주 지표(네트워크) 혼란 방지 |

---

## 3. 구현 단계

### 3.1 신규 모니터 (T-176)

- `Sources/TetherLens/Services/SystemResourceMonitor.swift` 신규
  - `struct ProcessResource { cpuPercent: Double?, rssBytes: Int64 }`
  - `struct SystemLoad { cpuTotalPercent: Double?, memUsedBytes: Int64, memTotalBytes: Int64 }`
  - `final class SystemResourceMonitor` (shared + 주입식 init으로 테스트 가능)
    - `fetchResources(now:) -> (perName: [String: ProcessResource], system: SystemLoad)`
    - 이전 샘플(`[pid: (totalTime, at)]` + 이전 host cpu ticks) 보관 → 델타 계산
    - 순수 함수 분리: `normalizeNettopName(_:)`, `cpuPercent(delta:elapsed:)`, `formatCPU(_:)`, `formatMemory(_:)`, `sortApps(_:by:)`
  - `[INFO] [SysRes]` 진입 로그 1개 + 실패 경로 `[ERROR] E-MAC-PERF-...` — 에러코드 형식은 기존 `DebugLogger.error("Traffic")` 선례를 따르되 신규 코드는 PLAN §8 참조.

### 3.2 TrafficMonitor 연동 (T-177)

- `Services/TrafficMonitor.swift`
  - `AppTraffic`에 `cpuPercent: Double?`, `memBytes: Int64` 추가 (기본값 있어 기존 init 깨지지 않게).
  - `@Published var systemLoad: SystemResourceMonitor.SystemLoad?` 추가 (헤더 요약용).
  - `refresh()`에서 `parse()` 직후 `SystemResourceMonitor.shared.fetchResources()` 1회 호출 → 이름 기준 병합.
  - 타이머·`Usage` enum 변경 없음.

### 3.3 UI 3면 (T-178)

- `Utils/Localized.swift`: `cpu`/`memory`/`sortByNetwork`/`sortByCPU`/`sortByMemory`/`systemLoadSummary`/`systemResources` 키 (한/영).
- `DesignSystem/Theme.swift`: `TLSize.trafficCPUCol`(56) / `trafficMemCol`(72) + `TLPalette.cpuHeat(_:)` 히트 색상 공용.
- `Views/AppTrafficView.swift`: 헤더 CPU/MEM 컬럼 + 행 값 + 툴바 정렬 피커 + 상단 시스템 요약 1행 (`CPU n% · MEM x/y GB`).
- `Views/PopoverView.swift` `topProcessRows` 행: 2행째 보조 텍스트 (네트워크 정렬 유지).
- `Views/FloatingWindowView.swift` `trafficRow`: 동일 보조 텍스트.

### 3.4 독립 리소스 섹션 (T-180, T-181 — 범위 명확화 후 추가)

- `Views/PopoverView.swift`: `topProcessesSection` 바로 밑 + 상세 모드 `appTrafficPreview` 밑에 `resourceSection` (CPU Top3 + 메모리 Top3, 네트워크 순위 무관). 데이터 게이팅은 토글과 무관하게 `apps` 비어있지 않음 기준. 헤더 탭 → 앱 트래픽 창.
- `Views/FloatingWindowView.swift`: `trafficSection` 밑에 CPU순 Top3 한 줄 행 (아이콘 + 명 + CPU% + 메모리, 탭 → 앱 트래픽 창). `showTraffic` 토글 공유. 고정 높이 172→244 (`FloatingWindowController` 3곳).
- 정렬은 인라인 `sorted` (선언적 2줄이라 별도 테스트 없음 — 포맷터는 기존 테스트 커버).

### 3.5 테스트·검증·문서 (T-179, T-182)

- `Tests/TetherLensTests/SystemResourceMonitorTests.swift`: 이름 정규화 / CPU 델타 계산 / 정렬 / 포맷 (라이브 샘플링 없는 결정적 테스트).
- `./scripts/test.sh` → `./scripts/build-macos.sh debug` → DebugPanel ERROR 0.
- `pgrep -f "ps |top "` 추가 스폰 없음 확인 (libproc 직접 호출이라 프로세스 없음).
- `Resources/Info.plist` v0.32.0/32, `docs/CHANGELOG.md [macOS]`, `docs/TODO.md`, 세션 로그.

---

## 4. 파일 매핑

| 파일 | 작업 |
|------|------|
| `Sources/TetherLens/Services/SystemResourceMonitor.swift` | 신규 — 수집 + 순수 헬퍼 |
| `Sources/TetherLens/Services/TrafficMonitor.swift` | `AppTraffic` 확장 + `refresh()` 병합 + `systemLoad` 발행 |
| `Sources/TetherLens/Utils/Localized.swift` | 키 7개 (`systemResources` 포함) |
| `Sources/TetherLens/DesignSystem/Theme.swift` | 컬럼 폭 토큰 2개 + `cpuHeat(_:)` |
| `Sources/TetherLens/Views/AppTrafficView.swift` | 컬럼 + 정렬 피커 + 시스템 요약 |
| `Sources/TetherLens/Views/PopoverView.swift` | top5 보조 텍스트 + 독립 `resourceSection` (요약/상세) |
| `Sources/TetherLens/Views/FloatingWindowView.swift` | top3 보조 텍스트 + 독립 리소스 섹션 |
| `Sources/TetherLens/App/FloatingWindowController.swift` | 고정 높이 172→244 |
| `Tests/TetherLensTests/SystemResourceMonitorTests.swift` | 신규 테스트 |
| `Resources/Info.plist` | v0.32.0/32 |
| `docs/CHANGELOG.md`, `docs/TODO.md` | 기록 |

## 5. 테스트 계획

- 신규 단위 테스트: 정규화(`Foo.1234`→`Foo`, 빈 문자열 폴백) / CPU%(1초에 0.5초 사용→50%) / 0除 방지 / 정렬 3종 / 포맷(`–`, `12.3%`, `1.2 GB`).
- 기존 43개+ 회귀 유지.
- 수동: 앱 트래픽 창 정렬 전환 → 팝오버/플로팅 보조 표시 → 저전력 모드에서 값 동결(수집 중지) → 슬립/깨움 후 재개.

## 6. 롤백 계획

- `TrafficMonitor` 병합 10줄 + 신규 파일 1개가 전부라 `git revert` 1회로 복원. UI는 보조 텍스트라 미표시돼도 동작 무관.

## 7. 성능 예산

- 추가 wakeup 0개 (nettop 주기 편승, 기본 10초).
- 수집 1회당 목표 <30ms (300프로세스 기준 `proc_pidinfo`+`proc_pidpath`). 초과 시 `[WARN]` + bd perf 이슈.
- PRD NFR-01(idle <1%)·NFR-02(<100MB) 유지. DB 쓰기 없음.

## 8. 에러코드

- `E-MAC-PERF-3201` — 리소스 샘플링 실패 (libproc/host 호출 실패, 사용자 메시지는 `error_message_ko.json`… 본 프로젝트는 `Localized` 사용이므로 로그 전용 + 행 "–" 폴백).
- 성공/스킵 경로는 DebugLogger `info/action` 레벨.

## 9. 권한

- 변경 없음 (libproc/host_statistics/sysctl은 샌드박스 외 추가 권한 불필요).

## 10. DoD 체크리스트

- [x] 문서 우선: 본 PLAN + TODO T-175~190 + bd 5건 (y8j/isx/4sx/09u/mt5)
- [x] 코드 + `[INFO] [SysRes]` 진입 로그 1개 이상 + 실패 경로 `[ERROR]` (E-MAC-PERF-3201, 1회 스로틀)
- [x] `Localized` 한/영 키 (한국어 문서 유지)
- [x] `./scripts/test.sh` 77개 통과 (신규 13개) + `./scripts/build-macos.sh debug` 성공 + 라이브 실측 (332프로세스, 수 ms)
- [x] DebugPanel ERROR 0 로그 확인 (`log show` 무에러 + 실화면 캡처 렌더 확인)
- [x] `docs/CHANGELOG.md [macOS]` 기록 + `Resources/Info.plist` v0.32.0/32 동기화
- [x] GUI 확인: 실화면 캡처 4회로 직접 확인 (3칸 9행·3열 헤더·자동 높이·java 5.0GB/node 3.1GB)
- [x] TODO T-175~190 + bd close + 세션 로그
