# TetherLens — Technical Design (기술 설계)

- **버전**: v0.23.1 (build 24) → **⚠️ 본문은 v0.23.1 시점 기준 (2026-09-27 감사 확인)**
- **플랫폼**: [macOS]
- **작성일**: 2026-08-06
- **정정일**: 2026-09-27 (v0.38.x 코드 대조 — §5 표시 필드, §10 Sparkle 정정)
- **연계**: `docs/PRD.md`, `docs/plans/PLAN_v0.23.1_macos.md`, `AGENTS.macos.md`

> **미갱신 경고 (2026-09-27)**: 본 문서는 v0.28~v0.38에 추가된 기능 절이 없다.
> 아래가 실제 코드와 불일치한다 — §2 모듈표(파일 16개 누락, `Formatters.swift` 위치 오기),
> §4 스키마(실제 v1~**v10**), §6 팝오버 폭(실제 `TLSize.popoverWidth` 360, 문서 280),
> §7 `TLSpace.inset`(실제 20, 문서 16), §9 IP 갱신 주기(실제 60분, 문서 30분).
> 누락 기능: 플로팅 창(FloatingWindowController) · 자동 재연결(ConnectionGuardian) ·
> 인사이트(InsightEngine) · 시스템 자원(SystemResourceMonitor) · 컴포넌트 라이브러리(Components) ·
> 커맨드 팔레트 · 속도 테스트 · 단축키 디스패처(AppShortcuts).

---

## 1. 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│  AppKit + SwiftUI (macOS 14+, Swift 6, SwiftPM)             │
│                                                             │
│  ┌───────────────┐   ┌──────────────────┐   ┌───────────┐  │
│  │ MenuBarView   │   │ PopoverView      │   │ DebugPanel │  │
│  │ (NSStatusItem)│   │ (요약/상세 2단)    │   │ (DEBUG)    │  │
│  └──────┬────────┘   └────────┬─────────┘   └───────────┘  │
│         │        MenuBarManager (수집 오케스트레이터)         │
│  ┌──────┴──────────────────────────────────────┐           │
│  │ NetworkMonitor · TrafficMonitor · PingMonitor│           │
│  │ HotspotDetector · IPResolver · LocationManager│          │
│  └──────────────┬───────────────────────────────┘           │
│                 ▼                                            │
│  ┌──────────────────────────────┐                            │
│  │ ProfileManager (도메인/계산)   │──▶ DataStore (GRDB/SQLite) │
│  └──────────────────────────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

## 2. 모듈 구조

| 폴더 | 역할 | 핵심 파일 |
|------|------|-----------|
| `App/` | 앱 수명주기, 메뉴바 상태 아이템, 팝오버 오케스트레이션 | `App.swift`, `AppDelegate.swift`, `MenuBarManager.swift`, `LocationManager.swift`, `AppServices.swift` |
| `Views/Dashboard*` | 대시보드 (v0.39) — 순서 정의·카드·본체 | `DashboardLayout.swift`(단일 진실원처), `DashboardCards.swift`, `DashboardView.swift` |
| `Services/` | 도메인 로직, DB 접근, 설정, 절약모드 | `ProfileManager.swift`, `DataStore.swift`, `SettingsManager.swift`, `SavingModeManager.swift`, `TrafficMonitor.swift`, `AppBlockManager.swift` |
| `Networking/` | 실시간 네트워크 수집 | `NetworkMonitor.swift` (+ PingMonitor, HotspotDetector, IPResolver) |
| `Models/` | GRDB 레코드/도메인 모델 | `Profile`, `Session`, `UsageLog`, `IPLog`, `AppTrafficLog`, `AppNotification` |
| `Views/` | SwiftUI 화면 | `PopoverView`, `UsageReportView`, `SettingsView`, `AppTrafficView`, `HeatmapView` 외 |
| `DesignSystem/` | UI 토큰 (v0.23.0+) | `Theme.swift` (TLPalette/TLFont/TLSpace/TLRound/TLSize) |
| `Utils/` | 로컬라이즈/포맷터/디버그 로거 | `Localized.swift`, `Formatters.swift`, `DebugLogger.swift` |

## 3. 데이터 흐름 — 사용량 추적

```
NetworkMonitor.totalUpload/Download   (앱 실행 이후 누적 카운터, 초당 갱신)
        │ 5분 주기 (recordCurrentUsage, SSID 전환 시 flush)
        ▼
ProfileManager.recordUsage(totalUpload:totalDownload:)   ← 델타 계산 후 INSERT
        │  usage_log(upload_delta, download_delta, recorded_at, session_id)
        ▼
DataStore (SQLite via GRDB)
        │
        ├─ getTodayUsage  : 오늘(자정 이후) delta SUM      → 메뉴바/팝오버 게이지
        ├─ getTotalUsage  : 전체 delta SUM (365일 보존분)  → 할당량 미설정 컬럼
        ├─ getDailyUsage  : 일별 집계 (리포트)
        └─ getMonthlyUsage: 월별 집계 (리포트)
```

### 할당량(quota) 기준 — v0.23.1 통일 규칙
- **오늘 기준**: 메뉴바 사용량/잔여, 절약모드 자동활성, 임계값 알림(50/80/95/100%), 게이지 색 경계
  → 전부 `getTodayUsage` 기반 (`todayGB`)
- **총 누적 기준**: 할당량 미설정 시 메뉴바 "총 사용량" 컬럼만 (`cachedTotalUsage`)
- 자정 리셋이므로 임계값 알림/절약모드는 매일 재평가됨 (사용자 결정 사항)

## 4. DataStore 스키마 (마이그레이션 v1~v8)

| 버전 | 내용 |
|------|------|
| v1 | `profile` (SSID 자동등록, quota, hotspot 여부) |
| v2 | `usage_log` (업로드/다운로드 델타) |
| v3 | `session` (핫스팟 세션 — start/end, 위경도) |
| v4 | `app_traffic_log` (앱별 트래픽) |
| v5 | `session_usage_link` (세션 ↔ 사용량 연결, FK) |
| v6 | `connection_type` (Wi-Fi/hotspot/iOS/Android 분류) |
| v7 | `ip_log` (외부 IP 변경 이력 — 1800초 dedup·merge) |
| v8 | `perf_indexes` (조회 성능 인덱스, usage_log 재구성) |

- DB 파일: `~/Library/Application Support/` (런타임 생성, gitignore)
- 보존 정책: 365일 초과 로그 자동 정리 (`cleanupOldLogs`)

## 5. 메뉴바 설계

- `MenuBarView` (NSView): 3열 레이아웃
  - 1열: ▲ 업로드 속도 / ▼ 다운로드 속도
  - 2열: 업로드/다운로드 속도 값 (고정 폭, 모노스페이스)
  - 3열: 할당량 컬럼 — 상단 사용량(오늘), 하단 잔여(오늘) / SSID 표시 모드 / 속도 전용 모드
- **표시 필드 옵션**: ❌ **미구현 (2026-09-27 정정)**. 아래 3종 토글(`showBSSIDInMenuBar`/`showLinkSpeedInMenuBar`/`showDNSInMenuBar`)은 문서에만 존재했고 코드에는 없다. 대신 v0.31에서 3열을 "할당량 설정 여부에 따른 자동 전환"(`showTotalColumn`)으로 재설계했다. 실제 `SettingsManager` 토글은 `showTotalColumn`/`showLatency`/`showRSSI` 3종 + v0.37의 `showCPUGraph`/`showGPUGraph`/`showMemGraph`
- **속성 캐싱 (v0.22.2)**: `cacheAttributesIfNeeded(fontSize:)` — fontSize 변경 시에만 폰트/문단스타일/속성/컬럼 폭 재생성, 매초 재생성 최소화
- 게이지 색: `colorForRatio` — green(< greenThreshold) / orange / red 경계 (`SavingModeManager` 단일화)
- 갱신 주기: `SettingsManager.menuBarRefreshInterval` (기본 2초)

## 6. 팝오버 설계 (v0.23.0 재설계 → v0.39 요약 고정)

- **요약 고정 (v0.39)**: `상세 보기` 토글과 `popover_summary_mode` 파이프라인 **제거**.
  상세 정보(연결 정보·주소 정보·앱 트래픽·시스템 리소스·프로필)는 전부 **대시보드(§14)** 로 이동했다.
  팝오버는 "지금 상태를 1눈에"만 담당하고, "자세히"는 창을 연다
- 구성: 헤더(아이콘·제목·부제·핀·벨) / 상태행(도트·게이트웨이·외부IP 칩) / 대형 속도 / QoS 게이지
  / 사용 기록 차트 / 연결성 도트(고정) → 스크롤(인터페이스 섹션만, 92pt) → 하단 버튼
- QoS 게이지: `QoSGauge(used: todayGB, total: quotaGB)` — 오늘 기준
- QoS 미설정 시: `할당량 설정` 버튼 (프로필 있으면 편집, 없으면 프로필 관리)
- 배너 상단 고정: 핑/할당량/복사 상태
- 하단: **주 버튼 = 대시보드**, `…` 메뉴에 리포트·시스템 대시보드·알림·플로팅·진단·프로필
- 폭: `TLSize.popoverWidth`(360)

## 7. 디자인 시스템 (v0.23.0)

`Sources/TetherLens/DesignSystem/Theme.swift` — 전역 UI 토큰:

| 토큰 | 내용 |
|------|------|
| `TLPalette` | upload(orange)/download(blue)/success(green)/danger(red)/accent, textPrimary/Secondary, copyHint, separator, textBackground, windowBackground |
| `TLFont` | 고정 스케일 8~11px (badge~detail) + semantic (caption~headline, speed) |
| `TLSpace` | 4/6/8/10/12/16/20 + inset(16) |
| `TLRound` | 6/10 |
| `TLSize` | 시트 폭 240~640, 테이블 컬럼 폭 (값 변경은 회귀 위험으로 보류) |

- 뷰 하드코딩 값(폰트/색상/간격/모서리/폭) 토큰화 완료
- 예외 유지: `DebugPanelView`(개발자 전용 다크 패널), 히트맵/지도 시각화 색, 시스템 표준 폰트(title2/title3/largeTitle)

## 8. 절약모드 / 알림

- `SavingModeManager`: `greenThreshold`/`orangeThreshold`, `shouldAutoActivate(used:quota:)` — v0.23.1부터 오늘 기준
- `AppBlockManager`: 절약모드 시 /etc/hosts 차단 (sudo 필요)
- 알림: 임계값(50/80/95/100%) 도달 시 UNUserNotification + 인앱 배너, 프로필별 `quota_notified_thresholds`(UserDefaults)로 중복 방지
- **해소 (v0.38.0)**: `AppNotification.resolvedAt?` + `isActive` + `isWarningLike`(pingWarning/pingCritical/connectionLost만 true, quota 제외). `NotificationManager` `resolveWarnings()`/`resolve(type:)` — PingMonitor 복구 시 시스템 알림센터 제거(`activeSystemNotificationIds` 추적) + 앱 목록 경고 마킹. ConnectionGuardian 재연결 시 `connectionLost` 해소. UI: 해소 경고 opacity 0.55 + 체크 + "해소됨" + `→ HH:mm`

## 9. 성능 예산

| 지표 | 목표 |
|------|------|
| 메뉴바 갱신 | 1초 주기, 속성 캐싱으로 재생성 최소화 |
| 기록 | 5분 주기 recordUsage (델타만 INSERT) |
| IP 갱신 | 30분 주기 (저전력 모드 시 건너뜀) |
| 위치 | 5분 주기 (저전력 모드 시 중지) |
| DB | 365일 보존, 인덱스(v8), 캐시(getTodayUsage) |

## 10. 버전/배포

- Info.plist 단일 원본: `Resources/Info.plist` (`build-macos.sh`가 번들 복사)
- **자동 업데이트: 자체 구현** — `Services/UpdaterManager.swift`. GitHub API `/releases/latest` 우선, 403/429 rate limit 시 `/releases/latest` HTML 302 태그 조회 + `raw release-notes/{tag}.md` 폴백(`GitHubReleaseParser`)
- ~~Sparkle~~ **미사용** — `Info.plist`의 `SUFeedURL`/`SUPublicEDKey`는 읽는 코드가 없는 죽은 키(2026-09-27 확인). 제거는 릴리즈 시점으로 보류
- 에러코드(`E-MAC-*`)는 `SystemResourceMonitor`에서 실제 사용 중이나, `error_message_ko.json` 매핑 파일은 **미도입**

## 11. 네트워크 진단 센터 (v0.26.0)

- 진입점: 메뉴바 우클릭 `showMoreMenu()` → "네트워크 진단" → `DiagnosticsWindowController.show()`
  - floating NSWindow (DebugPanelController 패턴), `DiagnosticsView` SwiftUI 패널
- `Networking/NetworkDiagnostics.swift` (`@MainActor` 싱글턴) — 요청 시에만 실행, 상시 폴링 없음:
  | 항목 | 구현 |
  |------|------|
  | 프록시/VPN | `/usr/sbin/scutil --proxy` 파싱 (Enable 키 + 서버 항목) |
  | DNS 누수 | `scutil --dns` resolver 집합 vs `DNSManager.currentServers()` 대조 → 존재 여부 판정 |
  | 커스텀 ping | `/sbin/ping -c 5` Process 실행 (인자 배열 직접 전달 — 셸 주입 방지) |
  | traceroute | `/usr/sbin/traceroute -m 12 -q 1` — 12홉 경로 |
  | bufferbloat | idle RTT 3회 평균 vs 다운로드 부하(Hetzner 1MB) 병행 RTT 평균 증가 폭 (≤5 양호 / ≤30 완충 / >30 위험) |
  | Markdown 리포트 | `renderMarkdown(_:)` — 결과 5종을 마크다운으로 복사 |
- Process 실행 헬퍼: `withCheckedContinuation` + `readDataToEndOfFile`, 타임아웃 시 `terminate()`

## 12. SSID 자동화 트리거 (v0.26.0)

- `Services/AutomationManager.swift` (`@MainActor`) + `AutomationRule`(Codable, UserDefaults `automation_rules_v1`)
- 규칙 구조: `ssid` + `trigger(onConnect/onDisconnect)` + `action(launchApp/quitProcess/savingModeOn/savingModeOff)` + `target`
- 평가 훅: `MenuBarManager.updateMenuBarText()` — SSID 변경(양/음) 시 `AutomationManager.evaluate(ssid:connected:)` 호출
- 실행: 앱 실행 `NSWorkspace.openApplication`(Application 폴더 후보 탐색) / 프로세스 종료 `killall -q` / 절약 모드 `SavingModeController`
- **쿨다운 60초**: `UserDefaults` 타임스탬프 키 `\(60)|\\(rule.id)` — 동일 규칙 중복 발화 방지

## 13. 사용 내역 export (v0.26.0)

- `ProfileManager.exportData(profileId:)` → `(csv, json, markdown)` 3종 반환 (v0.26.0에서 md 추가)
- `UsageReportView` 내보내기 메뉴: CSV / JSON / Markdown (NSSavePanel)

---

## 14. 대시보드 창 (v0.39)

RelayConsole 콘솔 대시보드 패턴 이식. **메뉴바 팝오버 `상세 보기` 의 대체** — 상세 정보가 180pt
ScrollView 에 들어 있던 구조를 900×680 창으로 분리했다.

### 14.1 구성

```
DashboardStatusBar   프로필·SSID·RSSI·세션경과·마지막갱신  (고정)
bannerStack          끊김 / 할당량 경고 (5초 자동 해제)  (조건부)
kpiRow               오늘 사용량·업·다운·남은·오늘 세션   (전폭 5칸)
cardGrid             HStack(alignment:.top) 2열 × 4행 + 전폭 1칸 = 9칸
  rows[0]     = [.speed(①)  , .quality(②)]
  rows[1]     = [.quota(③)  , .pattern(④)]
  rows[2]     = [.cpu(⑤)    , .gpu(⑥)]
  rows[3]     = [.memory(⑦) , .process(⑧)]
  wideCards   = [.insight(⑨)]                          (목록형 → 전폭)
footer               설정·진단·리포트·대시보드·종료        (고정)
```

### 14.2 순서의 단일 진실원처

`Views/DashboardLayout.swift` — RelayConsole `DashboardLayout.swift` 와 동일 구조.
`rows: [[DashboardCard]]` + `wideCards: [DashboardCard]`, `ordered` = 행 펼침 + 전폭.
레이아웃 순서 변경은 이 파일 1개만 고치면 된다(뷰 코드 불필요).
`SettingsManager.isCardEnabled(_:)` 로 카드별 토글 — **행 전체가 OFF 면 그 행이 사라진다**
(RelayConsole `compactMap` 패턴). 설정 UI는 P3.

### 14.3 갱신 주기 계층화 — 본체는 1초 틱에 참여하지 않는다

감사에서 확인된 "팝오버 1Hz tick이 body 전체를 재렌더" 결함의 재발을 막기 위한 구조:

| 주체 | 주기 | 근거 |
|------|------|------|
| `DashboardView` 본체 | — | **어떤 `@Published` 도 관찰하지 않는다** |
| `DashboardStore` | 60초 | DB 집계 (프로필·오늘 사용량·할당량·오늘 세션) |
| ① `DashboardSpeedCard` | 1초 | `@ObservedObject NetworkMonitor` (기존 단일 스냅샷) |
| ⑤⑦⑧ CPU/RAM/프로세스 | 10초 | `TrafficMonitor.allResources` + `MetricsHistory` (refresh 편승) |
| `DashboardClock` | 1초 | **격리된 서브뷰** — 세션경과·상대 시각만 |
| ② `DashboardQualityCard` | 5초 | `PingMonitor` 비발행 값 → 자체 타이머 |
| ⑦ `DashboardDetailCard` | 5초 | `HotspotDetector` 비발행 값 → 자체 타이머 |

`DashboardStore` 는 창이 열려 있을 때만 폴링한다(`acquire`/`release` → `Timer` 60초, tolerance 5s).
프로필 편집·할당량 변경은 `settingsChanged` 로 `refreshNow()` 를 즉시 호출한다.

### 14.3.1 행 높이 동기화 (실측 검증 완료)

`Grid`/`GridRow` 은 자식의 `maxHeight: .infinity` 를 **실제로 확장하지 않아**
높이가 다른 카드가 같은 행에서 어긋났다(캡처로 확인). `HStack(alignment: .top)` 로 교체해 해결했다.

`MetricCard.fillsRow` 는 두 조건을 모두 만족해야 한다:

1. `.frame(maxHeight: .infinity)` 가 **배경보다 앞**에 있어야 한다.
   뒤에 붙이면 뷰만 늘어나고 배경은 자연 높이 그대로다.
2. `content` 뒤에 `Spacer(minLength: 0)` 가 있어야 한다.
   없으면 남는 공간이 content 에 배분돼 **카드 제목이 가운데로 밀린다**.

이 두 가지는 RelayConsole `DroidCards.shell(fillsRow:)` 의 `fillsRow` 분기와 동일하며,
실측으로 재확인했다.

### 14.4 표시 규칙

- **값 없는 지표를 0으로 그리지 않는다** (RelayConsole 원칙 5) —
  할당량 미설정 / 프로필 미등록 / 측정 실패(`nil`) 를 각각 구분해 `—` 로 표기
- **마지막 갱신 시각을 헤더에 고정 표기** — 데이터가 오래됐음을 사용자가 인지
- `DashboardView` 의 카드 가시성은 `@State cardConfigVersion` 신호로만 갱신 —
  `@Published` 관찰을 추가하지 않는다(PLAN DoD 항목)
- MAC 조회는 `DashboardDetailCard.mac` 의 길이 가드로 방어 —
  `NetworkMonitor.macAddress` 의 7자 이상 인터페이스명 무한루프(T-250 미해결)를 5초 주기 호출이 재노출

### 14.5 진입점

⌘5 · 메뉴바 우클릭 최상단 · 팝오버 하단 주 버튼 · 커맨드 팔레트 최상단.
**`usageReport`(⌘1)는 유지** — 리포트 표면은 대시보드로 대체하지 않는다.

### 14.6 카드 On/Off 설정 (v0.39 P3)

- **설정 > 대시보드 탭**이 유일한 토글 진입점. 9개 카드를 `DashboardCard.ordered` 순서로 노출하며,
  이 배열이 **대시보드 렌더 순서와 설정 목록 순서를 동시에 결정**한다(순서를 두 곳에 두지 않는다)
- **저장 경로** — `SettingsManager.setCardEnabled` → `UserDefaults("dashboard.card.<rawValue>")`
  → `settingsChanged` 알림 → `DashboardView.cardConfigVersion` 증가 → 레이아웃만 재계산.
  `DashboardView` 는 알림을 받지만 `DashboardStore` 를 새로 만들지 않으므로 집계 비용이 늘지 않는다
- **설정 화면이 `@State` 로 스냅샷을 갖는 이유** — `SettingsManager` 는 `@Published` 가 아니다.
  카드 목록이 늘어도 설정 화면 코드는 손댈 필요가 없다(배열 순회만 함)
- **행 전체 OFF 시 그 행이 사라진다** — 사용자에게 "같은 행의 카드를 모두 끄면 행이 사라진다"를
  푸터 문구로 명시한다. 카드 1개만 꺼둔 것과 결과가 달라 혼동 원인이 된다

### 14.7 ② 연결 품질 카드의 하단 (v0.39 P3)

1행은 ① 속도 카드(차트)가 행 높이를 결정하므로, 내용이 적은 ② 의 하단이 비어 보인다.
RelayConsole 원칙(장식 금지)에 따라 **높이를 맞추는 패딩·스페이서를 넣지 않고,
값 있는 정보로 채웠다**.

- **추가한 정보** — `PingMonitor.recentLatencies` 기반 `TLSparkline` + `min · avg · max`
- **기준 일치** — 지연 추이는 `jitter` 와 **같은 대상**(게이트웨이 우선 → 8.8.8.8)을 쓴다.
  두 지표가 서로 다른 대상을 재면 카드 안에서 값이 어긋난다
- **미측정 표기** — 기록이 없으면 스파크라인 자리를 `측정 중` 텍스트로 대체한다.
  빈 그래프나 0으로 채운 축을 그리지 않는다(§14.4 원칙과 동일)
