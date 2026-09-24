# PLAN v0.37.0 — iStat 스타일 트래픽 + CPU/GPU/MEM 그래프 (macOS)

- **버전**: v0.37.0 (build 37)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-24
- **상태**: 완료 (2026-09-24)
- **bd**: TetherLens-4kb
- **출처**: 사용자 요청 — "프로세스별 트래픽을 iStat Menus 처럼. CPU/GPU/MEMORY 그래프 추가. UI는 RelayConsole 참고"
- **확정**: 범위 3면 전부 / GPU IOKit 실패 시 숨김 / 프로세스는 가로 점유율 바만

---

## 1. 목표

### 1.1 프로세스 트래픽 — iStat Menus 점유율 바로 표현 (3면)

| 화면 | 변경 |
|------|------|
| 플로팅 창 | 네트워크/CPU/RAM Top3 행 하단 2pt 바 |
| 팝오버 | 트래픽 미리보기 Top3 + 리소스 섹션 행 하단 바 |
| 앱 트래픽 창 | Top15 행 하단 바 |

- **비율**: 네트워크 = 표시 목록 전체 합 대비 / CPU = 표시 CPU 목록 합 대비 / RAM = 시스템 총메모리 대비
- 색: 네트워크 `TLPalette.download` / CPU `cpuHeat` / RAM `TLPalette.accent`

### 1.2 시스템 지표 — iStat/RelayConsole 카드 대시보드

- 3면 공통 `SystemMetricsCards`: CPU / GPU / MEMORY 카드 (큰 수치 + 게이지 + 스파크라인)
- **detail**: compact(플로팅) / standard(팝오버, load+Top3) / full(앱 트래픽, 코어바+Top5+더보기)
- **히스토리**: `MetricsHistory` 60점 링 버퍼 — `TrafficMonitor.refresh()` 주기 편승 (기본 10초 → 약 10분)
- **CPU**: 전체 % + 1분 load average + 코어별 `host_processor_info` 델타(%)
- **GPU**: IOKit `PerformanceStatistics` (`Device Utilization %` 등 키 후보) 실측. 실패/미지원 시 **GPU 칸 숨김** (오류 아님, info 1회)
- **MEMORY**: `4.9 / 7 GB` 형식 + 사용률 게이지 + Top RSS (UI 라벨 통일: **RAM**)
- 카드 수치: CPU/GPU/RAM 모두 `MetricCard` trailing — 제목 오른쪽 우측 정렬 (hero 제거)
- 카드 투명도: 플로팅 슬라이더 → 창 배경 + `MetricCard.backgroundOpacity`(배경·테두리만)
- 앱 트래픽 창: 카드+프로세스 15행 스크롤 (고정 560 초과 잘림 방지, List→LazyVStack)
- 토글: 설정·플로팅 창 섹션 + **플로팅 호버 드롭다운**(차트 아이콘) — `showCPUGraph`(기본 OFF)·`showGPUGraph`(기본 OFF)·`showMemGraph`(기본 ON). 단일 `showSystemGraphs`는 제거

### 1.3 레퍼런스

- 그래프/카드 패턴: RelayConsole `OPSparkline` (Path + min-max 정규화) → `TLSparkline` 포팅
- 프로세스 바: iStat Menus Top Talkers (합계 대비 가로 바)

## 2. 파일

| 구분 | 파일 |
|------|------|
| 신규 | `Services/MetricsHistory.swift` — 링 버퍼 + push |
| 신규 | `DesignSystem/Components.swift` — `TLSparkline`·`TLShareBar`·`TLShare`·`MetricCard`·`TLGaugeBar`·`TLCoreBars`·`SystemMetricsCards`(compact/standard/full) |
| 수정 | `Services/SystemResourceMonitor.swift` — `SystemLoad.gpuPercent`/`perCore`/`load1` + IOKit GPU + `host_processor_info` 코어 + `getloadavg` + `formatMemUsedTotal` |
| 수정 | `Services/TrafficMonitor.swift` — systemLoad 갱신 시 `MetricsHistory.push` |
| 수정 | `Views/FloatingWindowView.swift` · `PopoverView.swift` · `AppTrafficView.swift` |
| 수정 | `Services/SettingsManager.swift` · `Views/SettingsView.swift` · `Utils/Localized.swift` — CPU/GPU/MEM 개별 토글 |
| 수정 | `Package.swift` — IOKit 링크 |
| 신규 | `DesignSystem/TLNetworkSpeedChart.swift` — 팝오버/플로팅 공용 업·다운 오버레이 차트 + `ByteRateFormat` |
| 수정 | `Networking/NetworkMonitor.swift` — `ObservableObject` + `shared` (팝오버/플로팅 공유 관찰) |
| 신규 | `Tests/TetherLensTests/MetricsHistoryTests.swift` (링/비율/GPU 파싱) |
| 문서 | CHANGELOG · TODO · 세션 로그 |

### 3.1 후속 — 플로팅 재구성 (v0.37.1, 2026-09-24)

- 네트워크 카드 **항상 표시**: 대형 업/다운 + `TLNetworkSpeedChart` + 네트워크 프로세스 Top3
- 프로세스/그래프 **분리 토글 제거**: `floatingShowProcess`·`floatingShowCPU`·`floatingShowRAM`·`floatingShowUsage`·`floatingVisibleLines` 삭제
- 시스템 카드는 `showCPUGraph`/`showGPUGraph`/`showMemGraph` 하나로 통합 (그래프+그 아래 Top3)
- 플로팅 show 시 `TrafficMonitor` 항상 acquire (네트워크 카드 생존 동안 수집)

### 3.2 후속 — 메뉴 rename + 순서 통일 (v0.37.2, 2026-09-24)

- **rename**: `프로세스별 트래픽`/`App Traffic` → **`시스템 대시보드`/`System Dashboard`** — `appTraffic`·`appTrafficButton`·`showAppTrafficLabel`·`App.swift` 창 제목. 식별자(window id / `@AppStorage` / DB)는 유지. 리포트 탭명만 `프로세스 트래픽`(Process Traffic)
- 관련 안내 문구: 리포트 빈 상태·트래픽 갱신·주범 칩 툴팁·리셋 컨펌·차단 고지 → 시스템/트래픽 표기
- **P1 중복 제거**: 팝오버 … 메뉴에서 `사용량 리포트` 항목 제거 (좌측 주 버튼과 동일)
- **P1 순서 동일 그리드**: 창(리포트·대시보드·알림·정보) → 표면(플로팅·팝오버…"메뉴) → 도구(진단·프로필) → 시스템(설정·업데이트·디버그). ⌘K 팔레트에 네트워크 진단·프로필 관리 추가, 프로필은 `moreAction`으로 팝오버 오버레이 (메뉴바 더보기와 동일 경로)

### 3.3 후속 — 안정성·성능 리팩터링 (v0.38.0/v0.38.1, 2026-09-24)

- **v0.38.0 안정성 (bd hx3, closed)**: NWPathMonitor cancel 후 재생성 / NetworkMonitor start 멱등 + `ifa_addr` NULL 가드 / DataStore·ProfileManager `try!`·`as!` 안전화(+in-memory 폴백) / LocationManager 강제언래핑 제거
- **v0.38.1 성능 (bd mt9)**: `NetworkMonitor`·`TrafficMonitor`·`MetricsHistory` `@Published` 다중 → 단일 스냅샷. `AppBlockManager` CSV 캐시, `DebugLogger` DateFormatter·MainActor 직push, `HotspotDetector` route/DNS 백그라운드, 뷰 sort/filter/share 1회 hoisting
- 검증: `swift build` + `./scripts/test.sh` 122개 통과

### 3.4 재점검 조사 + 패치 (v0.38.2, 2026-09-24, bd k5o·rsk closed)

- **안정성 P1 (k5o)**: `IPResolver` URL! → guard / `isCurrentPathExpensive` continuation 이중 resume → `ResumeOnceGate` / `DNSManager.currentServersAsync()` 백그라운드(PopoverView DNS 시트·`dnsLeakCheck`)
- **성능 P1 (rsk)**: PopoverView 리소스 섹션·ReportView markdown(@State 캐시)·ReportAppTrafficView prefix(10)·HeatmapMapView 클러스터·MovementTimeline/SessionTimeline DB·DateFormatter() → body 1회/`onAppear` 계산, static DateFormatter, NetworkMonitor 타이머 leeway 100ms, FloatingWindowViewModel 단일 스냅샷
- 검증: `swift build` + `./scripts/test.sh` 122개 통과

## 3. 검증

- `./scripts/test.sh` 통과 (기존 + 신규)
- `./scripts/build-macos.sh debug` 경고 0 + DebugPanel ERROR 0
- 수동: 3면 점유율 바 육안 / GPU 칸 실기기 표시 또는 숨김 확인
- 수동: 플로팅 네트워크 카드(차트·큰 숫자·Top3) + 카드 토글 / 앱 트래픽 리사이즈 금지
- Info.plist 갱신: `0.36.0/36` → `0.37.0/37` (2026-09-24 릴리즈)
