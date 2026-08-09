# TetherLens — Technical Design (기술 설계)

- **버전**: v0.23.1 (build 24)
- **플랫폼**: [macOS]
- **작성일**: 2026-08-06
- **연계**: `docs/PRD.md`, `docs/plans/PLAN_v0.23.1_macos.md`, `AGENTS.macos.md`

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
| `App/` | 앱 수명주기, 메뉴바 상태 아이템, 팝오버 오케스트레이션 | `App.swift`, `AppDelegate.swift`, `MenuBarManager.swift`, `LocationManager.swift` |
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
- **표시 필드 옵션 (v0.26.0)**: `SettingsManager` 토글 3종 추가 — `showBSSIDInMenuBar`(BSSID), `showLinkSpeedInMenuBar`(링크 속도 Mbps), `showDNSInMenuBar`(DNS 1차 서버). 표시 우선순위: SSID > BSSID > 링크속도 > 총량, 하단열에는 DNS > 잔여
- **속성 캐싱 (v0.22.2)**: `cacheAttributesIfNeeded(fontSize:)` — fontSize 변경 시에만 폰트/문단스타일/속성/컬럼 폭 재생성, 매초 재생성 최소화
- 게이지 색: `colorForRatio` — green(< greenThreshold) / orange / red 경계 (`SavingModeManager` 단일화)
- 갱신 주기: `SettingsManager.menuBarRefreshInterval` (기본 2초)

## 6. 팝오버 설계 (v0.23.0 재설계)

- **2단 레이어**: `popover_summary_mode`(@AppStorage, 기본 요약)
  - 요약: 속도/SSID/할당량 QoS 게이지 + 하단 `▾/▴` 토글
  - 상세: 배너(고정 상단) + 연결 정보/주소 정보/트래픽/프로필 등 접이식 섹션
- QoS 게이지: `QoSGauge(used: todayGB, total: quotaGB)` — 오늘 기준
- QoS 미설정 시: `할당량 설정` 버튼 (프로필 있으면 편집, 없으면 프로필 관리)
- 배너 상단 고정: 핑/할당량/복사 상태 (요약·상세 공통)
- 폭: `TLSize.popoverWidth`(280)

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
- Sparkle(`SUFeedURL`/`SUPublicEDKey`) 유지 — 업데이트 채널 예정
- 에러코드 체계(`E-MAC-*`) 및 `error_message_ko.json`: **미도입** (필요 시 AGENTS.macos.md 규칙에 따라 도입)

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
