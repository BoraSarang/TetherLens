# Changelog

## [Unreleased] — 팝오버 재설계 (Osaurus 패턴 반영, 네이티브 유지)

### Changed
- **팝오버 헤더** — 앱 아이콘 20→28px(continuous 라운드) + 2행 명패(프로필명/SSID·RSSI 부제, 프로필명=SSID 시 유형 표시로 중복 회피). 핀·알림 유지, 상태 도트 제거
- **상태 1행 신설** — 배너 3종(할당량/Ping/복사)을 도트 8px+11pt 텍스트 1행으로 통합(정상/주의/위험/측정 중, 기존 TLPalette 임계 재사용). 배너는 자동 해제 유지 + 오버레이로 이동해 높이 점프 제거
- **하단 액션바** — Primary "사용량 리포트"(`borderedProminent`) + 요약/상세 토글 + `ellipsis` 더보기 메뉴 + 종료(power 아이콘, danger) 구성. 기존 Menu 12개 항목 유지
- **메뉴바 호버 툴팁** — `{SSID} · ▼다운 ▲업 · QoS n%` 1줄 상태 표시 (클릭 없이 확인)

### Changed (Phase A — 통계 의미 개선)
- **할당량 카드 부제** — "예상 소진 N일"(기간평균 기반) → "오늘 N까지 · 최근3일 M/일" (오늘 잔여 + 최근 페이스, 행동 기준). `expectedExhaustionDays`·`expectedExhaustion` 키 제거
- **인사이트 카드 드릴다운** — 증감률→그래프, 최다 사용일→상세, 최다 핫스팟→해당 프로필 선택, 상위 앱→앱 트래픽 탭으로 이동. 카드를 `Button(.plain)`으로 전환
- **총 사용량 카드 부제** — 일평균 → "↑업 ↓다운" 합산 우선 표시 (일평균은 최근 페이스로 대체, `dailyAverage` 키 제거)

## [0.31.0] — 2026-09-03 — 메뉴바 col3 재설계 + 안드로이드 핫스팟 판별 개선 + UI 정비

> 할당량 유무에 따라 메뉴바 col3(지연/RSSI ↔ 사용량/잔여) 자동 전환, 안드로이드 테더링 SSID 기반 감지 강화, 프로필 편집 창 크기·프로세스 툴바 정리. 계획: docs/plans/PLAN_v0.31.0_macos.md

### Added
- **메뉴바 col3 자동 전환 (할당량 유무)** — 할당량 설정 + 사용량 열 ON 시 사용량(top)/잔여(bottom), 할당량 미설정 시 RSSI(top)/지연시간(bottom). 기존 3모드(`speedOnly`/`speedAndTotal`/`speedAndSSID`)와 SSID/BSSID/링크속도/DNS 표시는 폐지
- **설정 키** — `showLatency`/`showRSSI`(기본 true) 신설. 폐기: `menuBarMode`/`showSSIDInMenuBar`/`showBSSIDInMenuBar`/`showLinkSpeedInMenuBar`/`showDNSInMenuBar`
- **RSSI/지연 색상** — RSSI: ≥-50 초록 / -67~-50 주황 / <-67 빨강, 없으면 `--`. 지연: <50ms 초록 / <150ms 주황 / ≥150ms 빨강. 지연은 게이트웨이 우선(없으면 외부 대체). RSSI·지연 둘 다 끄면 col3 숨김
- **`MenuBarSignalTests`** — RSSI/지연 형식·색상 테스트

### Changed
- **MenuBar col3 렌더링 개선** — `totalRatio<0`을 "col3 숨김" 신호로 쓰던 구조를 분리(`col3Hidden`+`col3TopColor`/`col3BottomColor`). col3 폭을 두 줄 실제 텍스트 중 최대 폭으로 동적 계산(오른쪽 정렬 유지) → 지연/RSSI가 메뉴바에 정상 표시
- **플로팅 창 동기화** — 메뉴바와 동일 col3 형식(지연+RSSI/사용량+잔여). `floatingContentChanged` userInfo에 `rssi`/`latencyMS`/`col3IsLatency` 추가
- **거짓 "연결 끊김" 알림 수정** — `ReachabilityPolicy` 순수 상태 머신 + `PingMonitor` 3패킷(1성공=RTT) + OS 교차 검증(OS unsatisfied만 즉시 끊김, 기본 스트라이크 3)
- **안드로이드 핫스팟 판별 강화** — SSID 득점(`hotspot`/`tether`/갤럭시 모델명 `s\d+`·`galaxy`·`note`) + 게이트웨이 대역(high/low 등급) + `isExpensive` + 안드로이드 제조사 BSSID OUI를 **종합 득점(임계 ≥4)**. `10.x`(통신사 CGNAT 가능성) 대역은 low 등급으로 단독 매칭 배제 → 일반 공유기 오판 방지. 판별 근거 `[HOTSPOT]` DebugLogger 기록
- **프로필 편집 창 크기** — 고정 높이 220 → 할당량 ON 시 `286`으로 자동 확대(입력/에러 줄 겹침 해소)
- **프로세스 툴바 아이콘화** — [차단 라벨/체크박스/bordered 버튼] → SF Symbol 아이콘 버튼(`hand.raised.fill` 차단 배지, `gearshape` 시스템 포함 토글, `arrow.counterclockwise` 초기화) + `.help()` 툴팁
- **사용량 토글 라벨** — "메뉴바에 사용량 표시" → "할당량 설정 시 사용량 표시" + 부연 설명 추가

### Fixed
- **앱 트래픽 창 제목이 "설정"으로 바뀌는 버그** — 설정 창의 제목 고정 `onReceive(NSWindow.didUpdateNotification)`이 다른 창(앱 트래픽 등) 제목까지 "설정"으로 덮어씀. `WindowCapture`(NSViewRepresentable)로 설정 뷰가 속한 자기 `NSWindow`만 캡처하여 대상 제한
- **앱 시작 시 설정 창 자동 복원** — `Settings` scene이 마지막 열림 상태를 복원. `AppDelegate` 시작 직후 자동 복원된 설정 창 닫기(`closeAutoRestoredSettings`)
- **앱 트래픽 툴바 배치** — 창을 `.windowStyle(.hiddenTitleBar)`로 바꾸고 아이콘 3개(차단/시스템/초기화)를 하나의 `ToolbarItemGroup(.primaryAction)`으로 묶어 우측 정렬·일정 간격 확보

## [0.30.0] — 2026-08-18 — 메뉴바 강화 + Cmd-K 커맨드 팔레트

> macos-app-design 스킬 §4~§6 미충족 항목(메뉴바/단축키/Cmd-K) 보완. 계획: docs/plans/PLAN_v0.30.0_macos.md

### Added
- **메뉴바 Window/View 메뉴 + 단축키 (T-165)** — `.commands` 체이닝: Window 메뉴에 사용량 리포트(⌘1)/앱 트래픽(⌘2)/알림(⌘3)/정보(⌘4) 열기, View 메뉴에 팝오버 토글(⌘⇧P)/DebugPanel 토글(⌘⇧D, DEBUG만). 팝오버 토글은 `MenuBarManager`의 `"togglePopover"` observer(`handleTogglePopover`) 경유
- **Cmd-K 커맨드 팔레트 (T-166)** — `CommandPaletteView`(420×320, `.regularMaterial` 라운드 카드 + 시스템 팔레트) + `Window(id: "commandPalette")` scene(hiddenTitleBar + contentSize). `@Environment(\.openWindow)`/`openSettings`으로 직접 창 열기. 검색 필터 + `↑↓`/Enter/Esc(`onKeyPress`) + 행 선택 accent 배경. 액션: 리포트/트래픽/알림/설정/정보/팝오버 토글/업데이트 확인/종료 + (DEBUG) DebugPanel
- **`Localized` 키** — `popoverToggle`/`commandPalette`/`palettePlaceholder` 신설, `debugPanel` 이모지(🐛) 제거

### Changed
- **CommandPalette 설계 변경** — 초기 NSPanel(`CommandPaletteController`) 계획 → SwiftUI Window scene. NSHostingController는 `openWindow`/`openSettings` 환경값을 쓸 수 없어 팔레트가 직접 창을 열 수 없기 때문. 팝오버 시트 액션(프로필/DNS/절약모드/IP히스토리)은 팔레트에서 제외

## [0.29.0] — 2026-08-18 — 맥 앱 전면 리디자인 Phase 1~5 (구조 + 디자인 시스템 + 화면별 정제 + DebugPanel + 모션)

> 사용자 요청: 3개 스킬(macos-app-design / ios-the-final-5-percent / apple-design) 기반으로 "아, 맥 앱이구나" 느낌의 전체 UI 리디자인. 확정 사항: 시트→별도 윈도우 전환 / 메뉴바 아이콘+숫자 병행 / Phase 1~2 먼저. 계획: docs/plans/PLAN_v0.29.0_macos.md

### Added
- **메뉴바 SF Symbol 템플릿 아이콘 + 숫자 병행 (T-156)** — 유니코드 ▲▼ → `arrow.up`/`arrow.down` SF Symbol(`isTemplate=true`, 다크/라이트 자동 착색) + 속도 숫자 색(orange/blue) 병행. 아이콘 폭을 폰트 크기 기반으로 캐시해 레이아웃 안정화
- **별도 Window scene 5종 (T-157)** — 설정(`Settings` scene + `Cmd-,`), 사용량 리포트(640×600), 앱 트래픽(520×560), 알림 목록(400×440), 정보(380×420). 팝오버 내 시트 9종 중 5종을 `openWindow(id:)`로 전환, 닫기는 `@Environment(\.dismiss)`
- **TLSize Window 크기 토큰** — `settingsWindow`/`reportWindow`/`trafficWindow`/`notificationsWindow`/`aboutWindow` (w,h) 튜플 추가

### Changed
- **TLPalette Display P3 브랜드 팔레트 (T-155)** — upload/download/success/danger를 OKLCH 균형의 Display P3 고정색으로 교체 + `onUpload/onDownload/onSuccess/onDanger` on-color 토큰 신설. `rowHover`(행 hover 배경) 토큰 추가
- **배너 on-color 교체** — 팝오버 quota/ping/copied 배너의 하드코딩 `.white` → on-color 토큰 (`pingOnColor` 매핑 함수 신설)
- **QoSGauge 토큰화 (T-160)** — radius 4→`TLRound.small`(6), gaugeColor 시스템 색 → TLPalette, chevron 8pt → `TLFont.badge`
- **radius 일원화 (T-160)** — HeatmapGrid 셀 3→4·레전드 2→4, Diagnostics 카드 8→`TLRound.medium`(10)
- **팝오버 슬림화 (T-158)** — 폭 280→320, 인셋 16→20. DNS/프로필/절약모드/IP히스토리는 팝오버 내 시트로 유지
- **SettingsView 프레임** — 320×480 → `TLSize.settingsWindow`(580×480)

### Changed (Phase 3 — 화면별 정제, T-162)
- **SettingsView 맥 설정 앱 스타일로 재구성** — `TabView` 5탭(메뉴바/권한/알림/성능/자동화, 각각 `Label` + SF Symbol) + `Form` + `.formStyle(.grouped)` 섹션 카드. `onClose` 파라미터·닫기 버튼 제거, `formatInterval` 미사용 정리, `Localized.general` 신설
- **UsageReportView NavigationSplitView 전환** — 버튼 기반 사이드바(88pt) → `NavigationSplitView` + `List(selection:)` + `.listStyle(.sidebar)`(180~240pt) + viewMode별 SF Symbol 아이콘. 제목 헤더/내보내기 메뉴 → `.toolbar(.primaryAction)`. `onClose`·`TLSize.sidebarWidth` 제거
  - **리포트 창 잘림 수정** — 사이드바 공간 확보 위해 `reportWindow` 640×600 → 720×660, `.frame(width:height:)` 고정 → `.frame(minWidth:minHeight:)` + `windowResizability(.contentMinSize)` (창 크기 조절 시 콘텐츠가 잘리지 않음)
- **Window 뷰 닫기 버튼 제거** — AppTraffic/Notifications/About의 하단 `닫기` 버튼 + `onClose` + 래퍼의 `@Environment(\.dismiss)` 제거 (시스템 창 닫기로 통일)
- **Window 뷰 툴바 통일** — AppTraffic(차단 ON 배지/시스템 토글/초기화)와 Notifications(전체 지우기) 헤더 제거 → `.toolbar(.primaryAction)`로 이동
- **DebugPanel 시스템 팔레트 정제** — 하드코딩 검정 배경/흰 텍스트 → `Color(.windowBackgroundColor)`+`Color(.textBackgroundColor)` 다크/라이트 자동 대응. 이모지(🐛📌X) → SF Symbol(`ladybug`/`arrow.down.to.line`/`xmark`). 로그 레벨 색 하드코딩 RGB → 시스템 색상(`red`/`yellow`/`blue`/`green`/`purple`/`secondary`), 폰트 10pt→11pt SF Mono

### Changed (Phase 5 — 모션, T-164)
- **배너 모션** — quota/ping/copied 배너 등장·퇴장 `move(edge:.top)+opacity`(0.2s easeOut)
- **섹션 모션** — 연결 정보/주소 정보 접기·펼치기 0.2s easeOut (withAnimation)
- **QoSGauge 게이지 바** — 사용량 비율 변화 시 0.5s easeOut으로 부드럽게 채움
- **PingAlert Equatable 추가** — `.animation(value:)` 연동

### Fixed
- **`Settings { EmptyView() }` 제거 (T-157)** — 실제 SettingsView로 교체, 설정 창이 별도 윈도우로 열림

## [0.28.3] — 2026-08-15 — GitHub 링크 + 랜딩 페이지 리디자인

> 사용자 요청: AboutView에 GitHub 저장소/페이지 링크가 없음 → 링크 2개 추가. 동시에 GitHub Pages 랜딩 페이지(`docs/index.html`)를 ui-ux-pro-max 스킬 기반으로 전면 리디자인.

### Added
- **AboutView GitHub/GitHub Pages 링크 (T-151)** — 이메일(mailto) 버튼 아래에 GitHub 저장소(`github.com/BoraSarang/TetherLens`)와 GitHub Pages(`borasarang.github.io/TetherLens`) 버튼 2개 추가. accent+underline 스타일로 통일, 시트 높이 340→380

### Changed
- **랜딩 페이지 전면 리디자인 (T-152)** — `docs/index.html` (ui-ux-pro-max 스킬)
  - 패턴: **Real-Time / Operations Landing** — Hero(라이브 데모 텔레메트리) → 메트릭 → How it works → 스크린샷 → CTA 배너
  - 스타일: **OLED 다크 + 네온 HUD** (Cyberpunk 감성의 앱 브랜드 색상 블루/시안 절충), 스캔라인 오버레이, 네온 글로우, IBM Plex Mono 라벨
  - 접근성: 이모지 → 인라인 SVG 아이콘(Phosphor 계열 14개), `prefers-reduced-motion` 대응, `:focus-visible` 테두리, 375/560/768/1024px 반응형
  - 데모 텔레메트리: `prefers-reduced-motion` 시 정적 값 렌더링

## [0.28.2] — 2026-08-13 — 네트워크 API 호출 최적화 (IP/위치 갱신 절감)

> 관찰: DebugPanel 로그 분석 — IP가 동일한데도 30분마다 `ipify`+`ipapi.co` 2회씩 무조건 호출(12시간 약 96회), 위치도 동일 좌표를 5분마다 재요청. v0.28.1(.nettop 누수) 종결 후 남은 에너지 낭비 요인 정리.

### Changed
- **IP 지역 조회 중복 제거 (T-146)** — `IPResolver.refresh`: `ipify`로 받은 IP가 기존 `externalIP`와 동일하면 `ipapi.co` 지역 조회를 생략하고 `lastFetch`만 갱신. IP 변경 시에만 지역/위치 메타데이터 재호출
- **IP 갱신 타이머 30분→60분 (T-147)** — `MenuBarManager.ipRefreshTimer` 1800s → 3600s. SSID 변경 시 `force=true` 체크는 그대로 유지해 IP 변경 감지 능력 보존

### Fixed
- **불필요한 외부 API 호출** — IP가 변하지 않는 날 하루 2회(IP조회+지역조회)×48 → 지역 조회 0회 + IP 조회 24회

### Added (logging)
- **저전력 IP 스킵 로그 하향 (T-148)** — "저전력 모드 - IP 갱신 건너뜀"을 시스템레벨 → info 레벨로 낮춰 60분마다 찍히던 노이즈 제거
- **위치 갱신 쿨다운 (T-149)** — `LocationManager.startUpdating`에 최근 15분 내 획득 시 스킵 `cooldownFetchTime` 추가. 동일 좌표의 5분 주기 CoreLocation 재요청 절감

> 회귀 수정: v0.28의 TrafficMonitor 지연 시작에서 PopoverView `onAppear/onDisappear` 기반 acquire/release가 NSPopover transient 닫힘(외부 클릭/ESC)에서 onDisappear 미호출 → `usageRefs[.popover]` 잔류 → 팝오버 닫힌 뒤에도 주기적 nettop 스폰.
> 실측: 앱 재시작 직후엔 nettop 0개, 팝오버 열고 닫은 뒤부터 주기적 스폰. 에너지 영향도 2,004 / 12h Power 2,315.

### Fixed
- **팝오버 acquire 누수 (T-142/T-143)** — SwiftUI 수명주기 의존 제거. PopoverView의 onAppear/onDisappear acquire/release 삭제, `MenuBarManager`가 `NSPopoverDelegate`(`popoverDidShow`/`popoverDidClose`)로 표시/닫힘을 정확히 감지해 TrafficMonitor `acquire(.popover)`/`release(.popover)` 호출. transient·핀·시트 겹침 등 모든 닫힘 경로를 OS 레벨에서 확실히 수신
- **nettop 실행 시간 축소 (T-144)** — 샘플 윈도우를 `interval + 1`(기본 11초)에서 **고정 2**로 축소. 화면 표시는 기준+1초 델타만 필요. 스폰당 11초 → ~2초로 에너지 영향도 직접 경감

### Added
- **acquire/release balance 로그 (T-144)** — TrafficMonitor acquire/release에 balance 카운터 추가. 누수 발생 시 DebugPanel에서 즉시 확인 가능

> 계획: docs/plans/PLAN_v0.28_macos.md
> 관찰 근거: 배터리 이슈 심층 조사에서 실측 — 팝오버/시트가 닫혀 있어도 TrafficMonitor가 상시 nettop을 가동(nettop CPU 130%). 방전의 직접 원인은 시스템 충전 인식 실패(하드웨어)로 분리.

### Changed
- **폴링 기본값 조정 (T-138)** — 메뉴바 갱신 2초→**3초**, 트래픽 측정 5초→**10초**, ping 3초→**5초** (캐시 5초 유지). 기존 설정 UI 옵션 범위 내라 사용자 무개입 적용
- **TrafficMonitor 지연 시작 (T-139)** — 상시 구동을 제거하고 참조 카운팅 `acquire()/release()` 도입. 팝오버 표시·트래픽 시트·차단 앱 목록이 있을 때만 nettop이 실행되고, 그 외에는 완전 중지. 차단 감지·팝오버 미리보기 기능은 보존
- **저전력 모드 강화 (T-140)** — `powerStateChanged` 구독으로 저전력 ON 시 TrafficMonitor 강제 중지 + ping 주기 최소 15초 확대 + 메뉴바 갱신 최소 5초 확대, OFF 시 자동 복원

### Fixed
- **배터리 낭비** — nettop이 상시 스폰되던 문제 제거 (앱이 아무 UI도 보지 않고 차단도 없으면 nettop 프로세스 0개)

## [0.27.1] — 2026-08-10 — 프로세스별 트래픽 가로 확장

### Added
- **프로세스별 트래픽 시트 가로 폭 확장 (T-135)** — 폭을 320 → **400**으로 확장. `TLSize.sheetTraffic` 전용 토큰 신설로 설정 시트(320)와 분리. 긴 프로세스명 가독성 개선

### Changed
- **AGENTS.local.md §8** — 앱 실행 요청 시 항상 `build-macos.sh debug`로 최신 코드 빌드 → 번들 재설치 → 실행 (사용자 규칙 확정, `open`만으로 이전 바이너리 실행 금지)

## [0.27.0] — 2026-08-10 — 백로그 T-33/T-34 정리

> 계획: docs/plans/PLAN_v0.27_macos.md

### Added
- **트래픽 초기화 확인 다이얼로그 (T-33)** — 프로세스별 트래픽 헤더의 '초기화' 버튼이 즉시 초기화 대신 확인 오버레이(T-33 기존 ProfileEditor 패턴 재사용)를 거쳐 실행. 실수로 누적 데이터를 소거하는 것을 방지. `Localized.trafficResetConfirm` 신규

### Fixed
- **다크 모드 대응 점검 완료 (T-34)** — 전역 디자인 시스템 팔레트가 시스템 색(`Color.primary`/`nsColor`) 기반임을 확인해 자동 대응 상태로 정리. 잔여 하드코딩(HeatmapGrid `isDark` 분기, DebugPanel 검정 배경, 지도 마커 흰 테두리, 모달 dim)은 모두 의도적 설계로 다크 무관함을 점검

## [0.26.0] — 2026-08-09 — 네트워크 진단 센터 + SSID 자동화 + 메뉴바 확장

> 경쟁 분석(COMPETITOR_ANALYSIS 부록 A) 코드베이스 검증으로 도출된 실질 격차 3종 통합.
> 계획: docs/plans/PLAN_v0.26.0_macos.md

### Added
- **네트워크 진단 센터 (T-127)** — 메뉴바 우클릭 "네트워크 진단" → floating 패널. VPN/proxy 감지(`scutil --proxy`), DNS 누수 검사(시스템 resolver vs 설정 DNS 대조), 커스텀 ping(호스트 입력), traceroute(12홉), bufferbloat(idle/부하 RTT 증가 폭), 전체 결과 **Markdown 리포트 복사**
- **SSID 자동화 트리거 (T-128)** — `AutomationRule`(연결/해제 시점, 앱 실행/프로세스 종료/절약 모드), UserDefaults 저장, 프로필 전환 훅에서 평가, 동일 규칙 60초 쿨다운. 설정 뷰에서 규칙 추가/활성/삭제
- **메뉴바 표시 필드 확장 (T-129)** — 기존 토글(총량·모드·SSID)에 BSSID/링크 속도/DNS 3종 추가 (SettingsManager + MenuBarView)
- **사용 내역 Markdown export (T-130)** — 기존 CSV/JSON에 Markdown 형식 추가 (ProfileManager.exportData)

### Fixed
- POPOVER 진단 창이 시스템 프롬프트로 인해 resignActive 시 닫히는 문제는 기존 T-122와 동일 처리(시트 리셋) — 진단 패널 추가로 신규 회귀 없음

## [0.25.4] — 2026-08-06 — 네트워크 연결 알림 누락 수정

> 네트워크 끊김/복구 알림이 발생하지 않는 문제 수정

### Fixed
- **복구 알림 누락 (T-126)** — `PingMonitor.checkAndNotify`가 `useDNS`일 때만 실행되어 상태 전환(DNS ping 루프 주기 밖)을 감지하지 못하던 것 수정. 상태 전환 감지를 매 루프에서 수행하고, `postPingAlert`에 디버그 로그 추가해 발송 여부 추적 가능

## [0.25.3] — 2026-08-06 — 팝오버 프로필 UI 정리

> 프로필 행 [통계]/[편집] 버튼을 세로 배치, 프로필 관리 접근을 더보기/우클릭 메뉴로 이동

### Changed
- **프로필 행 버튼 세로 배치 (T-124)** — 프로필 미니 통계 옆 [통계]/[편집] 버튼을 가로 나란히 → 오른쪽 세로 2단 스택으로 변경
- **프로필 관리 메뉴 이동 (T-125)** — 팝오버 프로필 행의 '프로필 관리' 버튼 제거. 더보기(Menu)와 메뉴바 우클릭(NSMenu)에 '프로필 관리' 항목 추가 (`moreAction: profileManager`)

## [0.25.2] — 2026-08-06 — 팝오버 시트 좀비 방지

> admin 프롬프트(절약 모드/DNS 프리셋)로 인한 resignActive → 팝오버 강제 닫힘 후
> 재오픈 시 팝오버 클릭 무반응 버그 수정

### Fixed
- **시트 좀비 상태 제거 (T-122)** — `togglePopover`가 팝오버를 다시 열기 전에 `popoverWillShow` 알림을 보내고, `PopoverView.resetPopoverState()`가 남아있던 시트 플래그(DNS/설정/절약모드/트래픽/프로필/알림 등)를 전부 초기화. 절약 모드/DNS 적용으로 앱이 resignActive될 때 popover가 닫혀도 다음 오픈은 정상 동작

## [0.25.1] — 2026-08-06 — 슬립 시 폴링 중지 + tick 최적화

> 배터리 에너지 사용 최적화 (관찰: 배터리 메뉴에서 에너지 사용 1위 리포트 → 대응 착수)

### Changed
- **슬립 시 폴링 일시중지 (T-119)** — 시스템 슬립(`willSleepNotification`) 진입 시 네트워크/핫스팟/핑/트래픽 측정과 타이머를 일시중지하고 마지막 사용량을 기록, 깨어남(`didWakeNotification`) 시 자동 재개. 슬립 직전 사용량 유실 방지
- **팝오버 닫힘 시 tick 중지 (T-120)** — 1초 갱신 타이머를 autoconnect → onAppear connect/onDisappear cancel로 변경해 닫힌 동안 갱신 루프 제거
- **Timer tolerance 부여 (T-121)** — 메뉴바/기록/캐시/위치/트래픽 타이머에 주기 10% 허용 오차를 두어 타이머 병합으로 전력 절감

## [0.25.0] — 2026-08-06 — 통계 전면 개편

> 통계 화면을 데이터 나열 → 상황이 보이는 대시보드 인사이트로 재구성 (진행 중, T-112~118)

### Added
- **사용량 리포트 대시보드 인사이트 카드 (T-112)** — 총 사용량 + 일평균, 전기간 대비(▲▼ %),
  최다 사용일, 최다 핫스팟(전체 프로필), 할당량 % + 예상 소진일(개별 할당량 설정 시), 상위 앱 요약
- `ProfileManager.getUsageTotal(profileId:from:to:)` 전기간 비교용 구간 합계 집계 (profileId nil이면 전체 프로필)
- **그래프 기간 단위 세분화 (T-113)** — 1일=시간대(0~23시), 7일=요일별, 30일=일별, 6개월/1년=월별 차트
- **할당량 임계선 (RuleMark, T-113)** — 개별 프로필 할당량 설정 시 그래프에 점선 임계선 + 누적 사용량 라인
- **지도 핀 클러스터 + 위치 출처 배지 (T-114)** — 동일 좌표(정밀도 3자리) 세션을 숫자 배지로 클러스터링,
  최근 위치 적색 하이라이트 유지, GPS/IP 출처 색·라벨 배지. 세션에 `location_source` 저장 (v10 마이그레이션)
- **이동 이력 타임라인 + 지도 포커스 (T-115)** — 위치 세션 + IP 변경을 시간순 목록으로 병합, 행 클릭 시 지도에서 해당 좌표로 포커스
- **기간 리포트 화면 (T-116)** — 리포트 탭 추가, 기간·프로필 선택 기반 핫스팟 사용 현황/이동 요약/Top앱/할당량 달성률 마크다운 미리보기 + 클립보드 복사
- **프로필 미니 통계 (T-117)** — 현재 프로필·프로필 관리 행에 오늘 사용량 + 할당량 % 진행 게이지 표시

### Changed
- 요약 헤더(단일 행) → 인사이트 카드 그리드 2행으로 확장
- 인사이트 카드 HStack 2행 → 3열 LazyVGrid 균등 폭으로 정렬 (행 간 카드 수 불일치로 어긋나던 문제 해결)

### Fixed
- **7일 그래프 버그** — weeklyChartData가 `date=nil`이라 모든 요일이 `Date.distantPast` 한 지점에 겹쳐 "막대 1개 + X축 라벨 없음"으로 나오던 문제 수정. weekly는 요일(0=일~6=토)을 hour 기반으로 렌더링하고 7개 라벨 항상 표시, 요일 정렬 `wd % 7`→`wd - 1` 정정
- **누적 라인/할당량 임계선 창 벗어남** — yDomain이 막대 최대값(×2)만 기준이라 누적 합계·할당량이 차트를 위로 넘치던 문제 → yDomain에 누적 피크·할당량 포함(×1.1 여유)

## [0.24.0] — 2026-08-06 — 정밀 분석 기반 버그 수정 + 리팩토링

> 5차례 재분석(서브에이전트 5회 + 직접 검증)으로 예상 버그 27건 확정·수정. 자동 테스트 38개 통과.

### Fixed (High)
- **프로필(SSID) 전환 시 카운터 미재시드로 이전 프로필에 타 프로필 트래픽 이중 계상** — `resetCounter(profileId:totalUpload:totalDownload:)` 신설, SSID 전환 시 호출
- **음수 델타 시 반대 방향 양수 델타까지 폐기** — 음수 축만 재시드, 양수 축 단독 기록
- **자정 직후 3초간 전날 사용량 반환**(날짜 미포함 캐시) — 날짜별 캐시 격리
- **TrafficMonitor `start()` data race** — 리셋을 serial queue로 직렬화
- **1년 넘은 활성 세션 영구 잔존 / CSV 따옴표 미쿼팅** — cleanup 대상 확대, RFC 4180 쿼팅
- **프로필 삭제 후 recordUsage FK 위반 크래시** — 삭제 시 세션/추적 리셋
- **SSID 단절 시 마지막 구간 사용량 유실** — 단절 분기에서도 recordUsage
- **SSID 전환 시 스테일 캐시로 새 세션이 이전 프로필 소유** — 캐시 무효화를 autoSwitchProfile과 무관하게
- **connection_type 어휘 불일치(카멜/스네이크)로 핫스팟 분류 붕괴** — 스네이크 통일 + v9 정규화 마이그레이션
- **nettop 1초 델타만 캡처로 앱 트래픽 과소 집계** — 샘플 윈도우를 refresh 간격으로 확장 + self-rescheduling

### Fixed (Medium)
- 80% 자동 활성화 시 "할당량 초과" 오정보·중복 알림 제거
- 네트워크 속도 `elapsed` 하드코딩 → 실제 경과 시간 반영
- 앱 종료 시 마지막 구간 app_traffic_log 유실 → 종료용 동기 flush
- 핫스팟 신호 플래핑 시 알림 폭주 → 토글 알림 쿨다운(30초)
- PingMonitor watchdog 정상 완료 시 미취소 / cooldown 레벨 상승 억제
- popover 1초 타이머 body 재생성 / 5초 알림 클리어 race / 폰트 슬라이더 설정 폭주
- 블록 토글 즉시 반영(AppBlockManager ObservableObject) / DebugPanel 선택 인덱스 밀림(UUID)

### Refactored
- `getIPForSession` 프로필 전체 IPLog `fetchAll` → SQL 쿼리화 (N+1 제거)
- up/dn 각각 별도 read → 단일 read
- 죽은 코드 `todayUsage` 제거, v8 rebuild orphan DELETE 위치 정정

### Infra
- `Info.plist` — `0.24.0` / build `25`

### Tests
- 자동화 테스트 38개 / 8개 스위트 전부 통과 (신규: 이중계상 방지·자정 경계 캐시·CSV 쿼팅·활성 세션 정리·핫스팟 어휘)
- 기존 `recordUsage_누적_델타_계산` 기대값을 실제 동작(음수 축만 재시드)에 맞게 수정

### Docs
- `docs/plans/PLAN_v0.24.0_macos.md` (T-92~111), TODO T-92~111, 세션 로그

### Platform
- [macOS]

## [0.23.1] — 2026-08-06 — 메뉴바 할당량 기준 "오늘" 통일 (버그 수정)

### Fixed
- **메뉴바 상태바 할당량 수치가 "총 누적 사용량"으로 표시되던 버그** — v0.21에서 기준이 `todayGB`(오늘) → `totalGB`(총 누적)로 변경됐으나 팝오버 QoS 게이지는 여전히 오늘 기준이라 동일 할당량이 위치별로 다른 값/비율/색으로 표시됨
  - 메뉴바 오른쪽 상단: 총 누적 → **오늘 사용량** (`getTodayUsage`)
  - 잔여: `quota - totalGB` → **`quota - todayGB`** (오늘 기준)
  - 절약모드 자동활성·임계값 알림(50/80/95/100%)·게이지 색 경계 전부 **오늘 기준**으로 통일 → 팝오버 QoS 게이지와 일치
  - `checkQuotaThresholds` 파라미터명 `totalGB` → `usedGB`로 명확화
- **유지**: 할당량 미설정 시 "총 사용량" 컬럼은 현행 동작 보존 (`cachedTotalUsage` 캐시 유지)

### Refactored
- 미사용 `totalGB` 변수/계산 제거

### Chore (에이전트 규칙/구조 정리)
- **Info.plist 단일화** — 배포 번들이 실제 사용하는 루트 `Resources/Info.plist`를 0.23.1/24로 갱신, `Sources/TetherLens/Info.plist`(v0.13.0 방치된 죽은 파일) 삭제 → **배포 번들 버전 0.13.0 → 0.23.1 정상화**
- 루트 `tetherlens.db`(0바이트, 런타임 산출물) git 추적 해제 + `.gitignore` 추가, 빈 `Sources/TetherLens/Resources/` 삭제
- `AGENTS.macos.md` 신설 (플랫폼 특화 규칙 — 읽기 순서에 명시됐으나 없던 파일)
- `docs/DESIGN.md` 신설 (아키텍처/데이터 흐름/스키마/디자인 시스템)
- `AGENTS.local.md` 정정 (CLAUDE.md ❌, 테스트 타겟 32개 반영)
- `docs/PLAN.md` symlink(→v0.1.0) 해제 → 버전 이력 로드맵 문서로 전환
- `docs/icon.png` → `images/` 이동

### Changed
- 설정 라벨 `showTotalInMenuBar`: "메뉴바에 총 사용량 표시" → **"메뉴바에 사용량 표시"** (할당량 있으면 오늘/없으면 총 사용량이므로 중립화)

### Infra
- `Info.plist` — `0.23.1` / build `24`

### Tests
- 자동화 테스트 32개 / 7개 스위트 전부 통과, `build-macos.sh debug` 성공

### Docs
- `docs/plans/PLAN_v0.23.1_macos.md`, TODO T-85~T-87, 세션 로그

### Platform
- [macOS]

## [0.23.0] — 2026-08-06 — 디자인 시스템 + 팝오버 재설계 (UI/UX P0)

### Added
- **디자인 시스템 도입** — `DesignSystem/Theme.swift` (T-79)
  - `TLPalette`: 시맨틱 색상 (upload/download/success/danger/accent, textPrimary/Secondary, copyHint/separator/textBackground/windowBackground)
  - `TLFont`: 고정 스케일 (8~11px 밀집 UI) + semantic 스케일 (caption~headline/speed)
  - `TLSpace` (4~20), `TLRound` (6/10), `TLSize` (시트 폭 240~640, 테이블 컬럼 폭)
- **팝오버 요약/상세 2단 재설계** (T-80/81)
  - `popover_summary_mode` 기본 요약 모드 — 속도/SSID/할당량 게이지만 표시, 하단 `▾/▴` 토글 버튼으로 상세 펼치기
  - 연결 정보/주소 정보는 접이식 섹션(치프론)으로 유지, DNS 행에 chevron.right 단서 추가
  - QoS 미설정 시 `할당량 설정` 버튼 표시 (프로필 선택 여부에 따라 편집/프로필 관리로 분기)
- **배너 상단 고정** — 핫스팟 감지 상태 배너가 팝오버 최상단에 고정 표시

### Refactored
- **하드코딩 값 전면 토큰 치환** (T-82/83) — 팝오버 포함 13개 뷰에서 폰트 크기·색상·간격·모서리·시트/라벨 폭 숫자를 Theme 토큰으로 대체
  - PopoverView, UsageReportView, SettingsView, AppTrafficView, SavingModeSheet, ProfileEditorView, HeatmapGridView, SessionTimelineView, AboutView, NotificationListView, IPHistoryView, ConnectionDetailView, HeatmapMapView, OnboardingView
  - DebugPanelView는 개발자 전용 다크 패널(로그 레벨별 고유 색상)이라 시맨틱 토큰 대상에서 제외
  - 히트맵 그라데이션/지도 핀 색은 시각화 고유 로직이라 유지, 시스템 표준 폰트(title2/title3/largeTitle)는 난립 대상이 아니라 유지
  - 시트 폭 값은 현행 유지 (토큰 참조만 — 회귀 위험으로 값 변경은 후속 버전)

### Infra
- `Info.plist` — CFBundleShortVersionString `0.20.0` → `0.23.0`, CFBundleVersion `20` → `23` (0.21~0.22 미동기화 해소)

### Tests
- 자동화 테스트 32개 / 7개 스위트 전부 통과 (Swift Testing)

### Docs
- `docs/plans/PLAN_v0.23.0_uiux.md`, TODO T-79~T-84, 세션 로그

### Platform
- [macOS]

## [0.22.2] — 2026-08-06 — MenuBarView 속성 캐싱 재적용 (성능 P0)

### Performance
- **MenuBarView 속성 캐싱 실제 적용** — `PERFORMANCE_OPTIMIZATION.md`에 "적용 완료"로 기록됐으나 실제 코드에 미반영(P3 static 캐싱의 절반만 커밋)된 부분을 재적용:
  - `cacheAttributesIfNeeded(fontSize:)` 도입 — `menuBarFontSize` 변경 시에만 폰트/문단스타일/속성/컬럼 폭 재생성. 동일 fontSize면 매초 재생성하던 폰트 2개 + `NSMutableParagraphStyle` + 속성 딕셔너리 4개를 제거
  - `upArrow`/`downArrow` `sizeToFit()` — 캐시 갱신 또는 문자열 변경 시에만 호출 (매초 호출 제거)
  - `col2FixedW`/`col3FixedW` computed property → `cachedCol2W`/`cachedCol3W` 캐시로 대체 (width 측정 2회/초 제거)
  - `totalAttr`만 매초 가변 색상(`colorForRatio`)이라 재생성 유지, `boldFont`는 캐시 재사용

### Docs
- `docs/plans/PLAN_v0.22.2_macos.md`, TODO T-77~T-78, `PERFORMANCE_OPTIMIZATION.md` P3 항목 정정 + v0.22.2 섹션 추가

### Platform
- [macOS]

## [0.22.1] — 2026-08-06 — Android 핫스팟 감지 보강

### Fixed
- **Android 핫스팟이 "일반 WiFi"로 오분류되는 버그** — 감지가 게이트웨이 대역(`192.168.43/80/42`)과 제한적 SSID 키워드에만 의존해, 비표준 게이트웨이(`10.229.78.x`) + 비키워드 SSID(예: `OkStart`) 연결 시 `normalWiFi`로 분류되던 문제
  - `isAndroidHotspotGateway(_:)` 신설 — `192.168.43/42/44/49/80/81/111.x` 대역 처리
  - `isAndroidSSID(_:)` 키워드 확장 — `okstart`, `oppo`, `vivo`, `realme`, `infinix`, `tecno`, `tp-link` 추가
  - 분기 순서 개선 — 게이트웨이 대역 → iOS(172.20.10.x) → Android SSID → isExpensive(iOS) → normalWiFi 순으로 판정. SSID 기반 Android 판정이 isExpensive보다 우선해 Android 핫스팟이 iOS로 오분류되는 것을 방지

### Tests
- `HotspotDetectorTests` 스위트 추가 (4개 테스트): 안드로이드 SSID/비안드로이드 SSID/게이트웨이 대역/비안드로이드 대역 — 총 32개 테스트, 7개 스위트 통과

### Docs
- TODO T-74~T-76

### Platform
- [macOS]

## [0.22.0] — 2026-08-06 — 자동화 테스트 도입

### Added
- **자동화 테스트 (Swift Testing)** — `Tests/TetherLensTests/`에 28개 테스트, 6개 스위트:
  - DataStore: v1~v8 마이그레이션 스키마(테이블/인덱스/FK) 검증
  - ProfileManager: 프로필 CRUD, autoRegister, 누적 델타 계산, 일/월 요약, 세션 시작·종료·활성·사용량 연결, IP 로그 1800초 dedup·merge·getIPForSession, cleanupOldLogs(세션 연쇄 삭제), exportData CSV 이스케이프, appTraffic 집계
  - SettingsManager: 기본값/저장/잘못된 모드 폴백/resetPollingIntervals/MenuBarMode
  - SavingModeManager: 절약모드 임계값 단일화(green/orange), shouldAutoActivate
  - SystemProcesses: 주요 시스템 프로세스 포함/사용자 앱 제외
  - Localized: ko/en 반환
- **`scripts/test.sh` 자동화 스크립트** — `swift test` 실행 → 통과 시 자동화 불가 수동 체크리스트 10항목 안내, 실패 시 실패 목록 출력 후 exit 1 (macOS bash 3.2 유니코드 파싱 이슈로 ASCII + hex 이스케이프 사용)

### Changed
- 테스트 가능한 주입 리팩토링 (동작 변경 없음):
  - `DataStore.init(dbQueue:)` + `makeMigrator` internal 노출
  - `ProfileManager.init(db:)` DB 주입
  - `SettingsManager.init(defaults:)` / `SavingModeManager.init(defaults:)` UserDefaults 주입

### Docs
- `docs/plans/PLAN_v0.22.0_macos.md`, TODO T-67~T-73

### Platform
- [macOS]

## [0.21.1] — 2026-08-06 — Low 후보 6건 개선 (코드 품질·접근성)

### Fixed
- **QoS 게이지 임계값 3중 중복 제거** — `QoSGauge`·`MenuBarManager.colorForRatio`가 하드코딩하던 초록/주황 경계(0.4/0.6, 0.65/0.85)를 `SavingModeManager.greenThreshold/orangeThreshold`로 단일화. 절약모드 ON/OFF에 따른 색상 경계가 메뉴바·팝오버·게이지 전부 일치
- **AppTrafficView "시스템 프로세스 제외" 토글 상태 비유지** → `@State` → `@AppStorage("appTraffic_show_system")` 전환 (팝오버 닫아도 유지)
- **SettingsView 폴링 간격 저장 유실** — `onDisappear` 단독 저장(강제 닫힘 시 유실) → 각 Picker `onChange` 즉시 저장 + 방어적 `onDisappear` 유지
- **UsageReportView 불필요 appTraffic 로드** — `getAppTrafficLogs`를 `viewMode == .appTraffic`일 때만 쿼리 (탭 전환/프로필 변경 시 불필요한 DB 조회 제거)

### Accessibility
- **HeatmapGridView 키보드 접근성** — 셀에 `.focusable()` + `.onKeyPress(.return)` + `.onTapGesture` + `.accessibilityLabel`(요일·시간·분·횟수) 추가. 기존 hover 선택과 동일 동작
- **DebugPanelView 하드코딩 문자열 로컬라이즈** — "선택 복사/선택 해제/전체 복사/클리어/자동 스크롤/디버그 로그"를 `Localized.string(ko, en)`으로 전환

### Changed
- **후원 버튼 제거** — 팝오버 하단 "☕️ 후원" + 정보 창 "☕️ 후원하기" 버튼, `openDonation()`, `Localized.donate/donateButton` 제거 (향후 별도 후원 링크 도입 예정)
- **제작자/문의 메일 변경** — AboutView 제작자 OkStart → BoRaSaRang, 이메일 okstart@gmail.com → leeborasarang@gmail.com (mailto 링크 동기화)

### Docs
- `docs/plans/PLAN_v0.21.1_macos.md`, TODO T-61~T-66

### Platform
- [macOS]

## [0.21.0] — 2026-08-06 — 2차 반복 분석 버그 수정 (데이터 유실·크래시 회귀 제거)

### Fixed (High)
- **절약모드 hosts 차단 무효 버그** — `SavingModeController`의 `"\\n"` 리터럴로 도메인이 한 줄로 붙어 차단 안 되던 버그 → `"\n"` 개행으로 수정 (`docs/tests/v0.21.0_macos.md` T-41~T-43)
- **v8 마이그레이션 유니크 인덱스 충돌 회귀** — `addIPLog` 1800s 후 재접속 시 `SQLITE_CONSTRAINT` 크래시 + 마이그레이션 실패 시 DB 전체 삭제(데이터 유실) → 유니크 인덱스 제거, 손상 DB는 `.corrupt-{ts}` 백업 후 재생성 (T-20, T-44)
- **온보딩 절대 표시 안 되던 버그** — `Settings` 씬 onAppear(설정 메뉴 없는 액세서리 앱에선 미호출) → AppDelegate 첫 실행 시 NSWindow 표시 + 위치 권한 요청 시점을 온보딩 완료 시로 이동 (T-01~T-03)

### Fixed (Medium)
- `handleSettingsChanged` guard 역전 (`guard !isMonitoring`) → 설정 변경 미반영 + 이중 타이머 위험, TrafficMonitor 갱신 주기 즉시 반영 (T-26)
- `TrafficMonitor.stop()` 마지막 300초 트래픽 유실 → stop()에서 flush 후 초기화 (T-25)
- nettop 타임아웃 부재(큐 스레드 블로킹) → 15s watchdog + launch 오류 처리
- SSID 전환 시 마지막 사용량 미기록 → 이전 프로필/세션으로 recordUsage flush (T-19)
- `handleResignActive` 미등록 → 팝오버 자동 닫힘 (T-06)
- 할당량 의미론 통일 — 잔여/게이지/알림/절약모드 전부 누적(totalGB) 기준 (T-14~T-16)
- `showTotalColumn` 기본값 true (menuBarMode 기본과 일치) (T-05)
- LocationManager 연속 위치 갱신(배터리) → 첫 획득 후 중지 + 5분/저전력 반영 (T-49~T-50)
- PopoverView 트래픽 미리보기에 시스템 프로세스 필터 (T-22)
- HotspotDetector 10.x 전체 안드로이드 오분류 → 192.168.43/80/42 + SSID 키워드 보완 (T-27~T-29)

### Fixed (Low)
- PingMonitor: gatewayTask 저장·취소, pingInterval 1s 클램프, classifyLatency nil 폴백(단발 실패 오알림 방지)
- HeatmapGridView legend 색상 일치 + "분/회" 로컬라이즈 (T-39~T-40)
- MenuBarView `NSColor.white` → `labelColor` (라이트 모드 가독) (T-04)
- DateFormatter 하드코딩 "HH:mm" → 로케일 템플릿 (T-35)
- exportData CSV 이스케이프 (프로필명 콤마/따옴표) (T-37)
- ProfileEditorView 빈 이름 검증 + 토글 접근성 라벨 + 에러 리셋 (T-08, T-11)
- MenuBarView col3 폭 영어 로케일 클리핑 방지

### Changed
- DataStore v8: `usage_log` session_id FK + 복합 인덱스 유지 (유니크 인덱스만 제거), `cleanupOldLogs`가 세션·IP 포함 정리 (T-46)
- **메뉴바 오른쪽 클릭 → "더보기" 드롭다운 메뉴** — `MenuBarView.rightMouseDown` + `MenuBarManager.showMoreMenu()` (NSMenu), 선택 시 팝오버 열고 해당 시트 트리거 (`moreAction` notification). 팝오버 내부 "더보기" 메뉴와 동일한 항목 (T-51~T-58)

### Docs
- `docs/plans/PLAN_v0.21.0_macos.md`, `docs/tests/v0.21.0_macos.md` (T-01~T-58)

### Platform
- [macOS]

## [0.20.0] — 2026-08-06 — 세션 IP + 내보내기 + 메뉴바 커스텀 + 트래픽 차단

### Added
- **세션 타임라인 IP 표시** — `ProfileManager.getIPForSession(_:)` 추가, `SessionTimelineView.SessionRow`에 `· IP` 텍스트
- **CSV/JSON 데이터 내보내기** — `ProfileManager.exportData(profileId:)` (세션+IP 데이터), `UsageReportView` 헤더 Menu(CSV/JSON), `ExportFormat` + `NSSavePanel` + `UTType`
- **메뉴바 커스텀 모드** — `SettingsManager.MenuBarMode`(속도만/속도+사용량/속도+SSID) + `showSSIDInMenuBar` 토글, `MenuBarManager.updateMenuBarText()` 모드 기반 col3 처리
- **앱 트래픽 차단/허용** — `AppBlockManager` (차단 목록 UserDefaults), `AppTrafficView` 행별 차단 토글 + 차단 중 배지, 차단된 앱 트래픽 감지 시 로컬 알림
- **프로필 자동전환 학습** — `SettingsManager.autoSwitchProfile` 토글, 끄면 새 네트워크 자동 등록/재등록 중단

### Fixed
- `MenuBarManager.updateMenuBarText()` 누락된 중괄호 복구 (빌드 에러)

### Platform
- [macOS]

## [0.12.0] — 2026-08-02 — IP 변경 이력 + 한국어 용어 통일

### Added
- **IP 변경 이력 추적 (프로필별)** — `ip_log` 테이블 (v7 migration) + `IPLog` 모델
  - `IPResolver.onIPChange` 콜백으로 IP 변경 감지 → `ProfileManager.addIPLog()` 기록
  - `MenuBarManager`에서 초기 IP 조회 완료 시 자동 기록
  - 동일 IP 재접속 시 `last_seen_at`만 UPDATE (중복 최소화)
  - PopoverView "IP 변경 이력" 버튼 → `IPHistoryView` 시트
- `Localized.swift` ~150개 키 한/영 분기 enum (v1.9 표준 준수)
- `OnboardingView` — 첫 실행 권한 안내 시트
- Heatmaps: `HeatmapView`, `HeatmapGridView`, `HeatmapMapView`
  - 핀에 세션 시작 시간 (`HH:mm`) 레이블, region 자동 fit (min span 0.05°)
- `SessionTimelineView` — 시간대별 세션 막대 차트
- `Profile.connectionType` 필드 + DB v6 migration + 핫스팟 `(핫스팟)` 배지

### Fixed
- **할당량 색상 불일치** — `quotaRatio`가 `totalGB`(전체 누적) → `todayGB`(오늘 사용량) 기준으로 수정
  - "잔여 1.9 GB" 표시 시 빨간색이었던 문제 → GREEN/YELLOW 정상 표시
- **할당량 알림** — `getTodayUsage()` → `getTotalUsage()`로 변경, 다중 임계값(50/80/95/100%)
- **IPResolver** — ip-api.com → ipapi.co 교체 (`latitude`/`longitude` 직접 반환)
- **SettingsView** — `앱별 트래잽` → `프로세스별 트래픽` 용어 통일

### Changed
- macOS 26 (Tahoe) 대응 — `kCLErrorLocationUnknown` 기록 (`bd remember`)
- `MenuBarManager`에 `@MainActor class` + `@unchecked Sendable`
- SettingsView 권한 섹션 추가, threshold Picker 제거, ScrollView 하단 고정

### Platform
- [macOS]

## [0.11.1] — 2026-07-29 — IPResolver 안정화 + GitHub Pages + CI 릴리스

### Fixed
- **IPResolver: ip-api.com HTTPS 유료화 대응** — ip-api.com (HTTPS 유료/HTTP 차단) → ipinfo.io (HTTPS 무료) 교체
- **시작 IP 조회 타이밍** — SSID 대기 → NWPath.status==satisfied 대기로 변경, location callback 중복 refresh 제거
- **Cmd+D 단축키** — 한글 입력 상태에서도 동작하도록 keyCode 기반으로 수정

### Added
- **GitHub Pages 랜딩 페이지** — `docs/index.html` + `docs/icon.png` (다크 테마, 다운로드 링크, 기능 소개)
- **GitHub Actions 릴리스 워크플로우** — `.github/workflows/release.yml` (macOS 빌드 → .zip → Release 업로드)

### Removed
- ATS 예외 (ip-api.com HTTP) — 불필요

## [0.11.0] — 2026-07-28 — Debug Panel + 빌드 디스패처 + AGENTS v1.6

### Added
- **Debug Log Panel v1.6** — DebugLogger 싱글톤 (7 level, 5,000 제한, print 동시 출력)
- **DebugPanelView + DebugPanelController** — NSWindow floating 600×320, 화면 중앙, `.floating+100`
- **Line-based selection**: 클릭=1줄, Shift+클릭=범위, Cmd+클릭=토글
- **자동 스크롤**: 📌 버튼 토글, 드래그 시 2초 일시정지 후 DispatchWorkItem 자동 재개
- **선택/전체 복사**: 선택된 줄 join → NSPasteboard / formatForAgent() 포맷
- **Cmd+D 단축키** — `NSEvent.addLocalMonitorForEvents` (LSUIElement 메뉴바 없는 앱 대응)
- **Popover "더보기" → 🐛 디버그 패널** 진입 버튼
- **build_and_run.sh v1.6 디스패처** + `scripts/build-macos.sh` 분리
- **`[PLATFORM]` 필드** — 로그 포맷에 MACOS 태그 추가
- **DebugLogger 통합**: MenuBarManager(시작/중지/SSID), IPResolver(API 호출/응답), PingMonitor
- **AGENTS.md v1.6 정렬**: AGENTS.local.md에 DoD 체크리스트, Git 브랜치 규칙, 프로젝트 설정 갱신

### Changed
- `Package.swift` — `swiftSettings: [.define("DEBUG")]` 추가

### Fixed
- Debug Panel NSWindow crash — `close()`+destroy → `orderOut`/`makeKeyAndOrderFront` show/hide 패턴
- `isReleasedWhenClosed = false` — 시스템 닫기 버튼 dealloc 방지

## [0.10.0] — 2026-07-26 — Ping 알림 전면 개선 + 프로세스별 트래픽 탭 + UX 개선

### Added
- **핫스팟 Ping 알림 전면 개선** — 스펙 문서(`hotspot-ping-notification-spec.md`) 기반 전면 교체
  - 3단계 임계값: Warning 100ms / Critical 250ms (외부) / Critical 80ms (게이트웨이)
  - 연속 조건: 5회 연속 또는 10초 지속 시에만 알림
  - 쿨다운: 2분 시간 기반 (동일 등급 재발송 금지)
  - 패킷 손실 감지: 최근 10회 중 10% 이상 nil 시 추가 트리거
  - 복구 감지: 10초 정상 유지 후 🟢 "인터넷 연결이 다시 원활해졌습니다"
  - 핫스팟 전용: 핫스팟 연결 시에만 지연 알림 작동
  - 메시지 포맷: 헤드라인+원인+💡팁 3단 구조 (이모지+색상)
- **알림 배너 색상 다양화** — Warning🟡 Critical🔴 Recovery🟢 ConnectionLost🔵
- **프로세스별 트래픽 탭 DB 기반 전환** — 실시간 nettap → `app_traffic_log` 집계 데이터
  - 총 합계 / 사용자 합계 / 시스템 합계 행 고정 (스크롤 영역 분리)
  - 사용자 프로세스 / 시스템 프로세스 구분 (SystemProcesses 공유 상수)
  - 아코디언: 사용자↔시스템 상호 배타적 (기본 사용자 열림)
  - 정렬 Picker: 전체 순 / 업로드 순 / 다운로드 순
  - 각 섹션 상위 10개 표시
  - 스크롤 최상단 자동 이동
- **SystemProcesses 공유 상수** — `Utils/SystemProcesses.swift` 분리 (AppTrafficView, UsageReportView 공유)

### Changed
- 용어 일괄 변경: 앱별 트래픽 → 프로세스별 트래픽, 앱 → 프로세스
- 통계 창 레이아웃: 높이 400→480, 차트 200→280 (추가 공간 확보)
- 팝오버 "더보기" 버튼 스타일: `.bordered` → `.borderedProminent`
- `AppNotification.NotificationType` — `pingSlow`, `pingVerySlow` 제거, `pingWarning`, `pingCritical`, `pingRecovery` 추가

### Fixed
- 통계 창 하단 Legend/닫기 버튼 고정 (`Spacer()` 누락 복구)
- 차트 오버레이 문제 해결 (maxHeight: .infinity → height: 280 + Spacer)
- **통계 차트 날짜 그룹핑 UTC 기준 버그** — `DATE()`/`strftime()`에 `'localtime'` modifier 누락으로 KST(UTC+9) 사용자 오전 00:00~08:59 데이터가 어제 날짜로 표시되던 문제 수정 (ProfileManager.swift 4쿼리)

## [0.9.0] — 2026-07-25 — UX 개선 + 앱 트래픽 히스토리 + Ping 알림

### Added
- **데이터 할당량 초과/임박 시스템 알림** — macOS Notification Center 배너 + sound (UNUserNotificationCenter)
- **알림 기록** — NotificationManager 싱글톤 (50개, UserDefaults 저장), 팝오버 헤더 🔔 벨 아이콘 + 배지, "알림 기록" 시트
- **Ping 품질 알림** — PingMonitor 100ms/200ms 임계값 감지, 연결 끊김/복구 시 Notification Center + 팝오버 배너 + 알림 기록
- **메뉴바 폰트 크기 설정** — 설정 → 메뉴바 → 폰트 크기 슬라이더 (7~14pt, 기본 9pt)
- **할당량 알림 임계값 설정** — 설정 → 알림 → 할당량 알림 (50%/80%/90%/95%/사용 안 함)
- **차트 기간 확장** — 사용량 리포트 기간 선택 6개월/1년 추가, 데이터 보존 30일→365일
- **팝오버 고정(Pin) 버튼** — 헤더 영역 pin 버튼, behavior .transient ↔ .applicationDefined 전환
- **시스템 프로세스 필터** — AppTrafficView "시스템 프로세스 제외" 체크박스, 40+ 데몬 필터링
- **앱 트래픽 히스토리 DB 저장** — v4 마이그레이션 (app_traffic_log 테이블, 5분 주기 delta 저장)
- **프로필 데이터 초기화** — ProfileEditorView "데이터 초기화" 버튼, 사용량 로그만 삭제

### Changed
- 설정 창: 섹션별 하위 항목 indent 적용 (메뉴바/알림/성능)
- 설정 창: 알림 상태 "✅ 허용됨" 알림 섹션 타이틀 우측으로 이동
- 설정 창: 모든 Picker `.frame(width:)` → `.fixedSize()` (내용물 크기에 맞게, 우측 정렬 깔끔)
- 설정 창: "더보기" 더보기 메뉴 → `.bordered` 버튼 스타일 통일 (라이트 모드 가시성)
- 팝오버: 연결 정보/연결 주소 섹션 접기/펼치기 기능 (@AppStorage UserDefaults 저장)
- 팝오버: 헤더 아이콘 SF Symbol → 앱 아이콘 (NSApplication.applicationIconImage)
- 설정 창 높이 340→540 (메뉴바+알림+성능 섹션 추가)
- ProfileEditorView 높이 260→310 (데이터 초기화 버튼 추가)
- UsageReportView 차트 X축 stride: 90일 초과 시 .month 단위 + 연월 포맷
- NotificationDelegate 분리 (강한 참조 유지)
- CPU 4.6~5.5% → 0.5~1.5% (약 73% 감소)

### Fixed
- 프로필 편집기 창보다 큰 컨텐츠 표시 개선 (ZStack + Spacer 레이아웃)
- 앱별 트래픽 업로드/다운로드 반전 버그 (bytes_in/bytes_out 매핑)
- 메뉴바 줄간격 비정상 문제 (upArrow/downArrow sizeToFit 누락)
- 팝오버 앱별 트래픽 미리보기 다운로드 열 너비 62pt → 68pt

## [0.7.0] — 2026-07-25 — Release Candidate

### Fixed
- **앱별 트래픽 업로드/다운로드 반전 버그** — `nettop`의 `bytes_in`(다운로드)/`bytes_out`(업로드) 매핑 수정
- 팝오버 앱별 트래픽 미리보기 다운로드 열 너비 62pt → 68pt로 확장

### Changed
- 문서 정리 완료 (TODO.md, CHANGELOG.md)

## [0.6.0] — 2026-07-25 — 앱별 트래픽 모니터 + 메뉴 개선

### Added
- **앱별 트래픽 모니터** (`TrafficMonitor`) — `nettop` 기반 per-app bandwidth 추적
  - 3초 주기 폴링, current rate + 누적 total 관리
  - 팝오버 본문: QoS 게이지 아래 상위 3개 앱 ▲속도/▼속도 3열 표시
  - "더보기..." 클릭 → 전체 리스트 시트 (`AppTrafficView`)
  - 더보기 메뉴에서 "앱별 트래픽" 항목
  - 통계 창 사이드바에 "앱별 트래픽" 모드 — 누적 업로드/다운로드 표시
- **정보 창** (`AboutView`) — 앱 버전, 제작자(BoRaSaRang), 문의 메일, ☕️ 후원하기
- **프로필 통계 버튼** — 팝오버 프로필 영역 + 프로필 관리 목록에 "통계" 버튼
  - 클릭 시 해당 프로필이 선택된 UsageReportView로 이동
- **프로필 관리 마지막 접속 시간** — 비접속 중 프로필에 "마지막 접속: N분 전" 표시
- **프로필 피커 "전체 프로필"** — 통계 창에서 전체 프로필 데이터 합산

### Changed
- 더보기 메뉴 순서: 통계/앱별 트래픽 ─ DNS ─ 절약모드 ─ 정보 ─ 업데이트 확인 ─ 설정
- 더보기 메뉴 구분선: 앱별 트래픽 아래, 절약 모드 아래 Divider
- "통계" → "사용량 리포트" (더보기 메뉴)
- 통계 창 크기: 440×460 → 520×400
- 메뉴바 col3: 숫자와 단위 사이 공백 추가 ("잔여 8.5GB" → "잔여 8.5 GB")
- 팝오버 위치: `statusItem.button` 기준으로 개선
- 앱 아이콘 적용 (TetherLens.icns)

### Fixed
- `TrafficMonitor` 파싱 버그: 타임스탬프를 프로세스명으로 읽던 오류 수정

## [0.5.0] — 2026-07-25 — Sparkle 자동 업데이트 + CI/CD

### Added
- **Sparkle 자동 업데이트** (2.x, SPM) — `UpdaterManager`, 더보기 "업데이트 확인" 메뉴
- **GitHub Actions CI/CD** — `.github/workflows/ci.yml` (macos-14, SPM 캐싱, `swift build`)

### Changed
- `scripts/package.sh`: Sparkle.framework 임베드 + `--deep` 서명 + rpath 설정
- `Info.plist`: 버전 0.4.0, SUFeedURL/SUPublicEDKey 추가
- EdDSA 서명 키 생성 완료

## [0.4.0] — 2026-07-25 — Phase 2 통계·세션·절약 모드

### Added
- **Buy Me a Coffee 도네이션 링크** — 팝오버 하단 "☕️ 후원" 버튼
- **로그인 시 자동 실행** — 설정 토글 (`SMAppService.mainApp`)
- **스마트 절약 모드** (`SavingModeManager` + `SavingModeController`)
  - osascript admin으로 softwareupdate/tmutil/hosts 제어
  - 자동 활성화 (할당량 80% 도달 시)
  - 상이한 QoS 색상 임계값 (saving 모드: 40%/65%, 일반: 60%/85%)
  - 팝오버 "절약 모드 온" 버튼 (활성 시 주황 틴트)
- **통계 그래프** (Swift Charts, 내장 프레임워크)
  - 일별 업로드/다운로드 막대 차트
  - 그래프/상세/세션 탭 전환 (사이드바 레이아웃)
- **연결 이력 리포트** (`UsageReportView`)
  - 프로필별/기간별 사용량 조회 (1일/7일/30일/90일)
  - 일별 상세 리스트 (업로드/다운로드/합계)
  - 요약: 총 사용량 + 일 평균
- **세션 시간 추적** (`Session` 모델 + DB v3_migration)
  - SSID 변경 시 자동 세션 시작/종료
  - 팝오버 연결 정보에 실시간 세션 시간 표시
  - 리포트 세션 탭에서 과거 세션 목록 확인

### Fixed
- col1/col2 세로 정렬이 col3 텍스트 높이에 영향받던 문제 수정 (lineHeight에서 upTotal 제외)
- 절약 모드 해제 시 `SavingModeManager.isEnabled` 미갱신 버그
- `Session` 모델 `CodingKeys` 누락으로 인한 DB INSERT 크래시

### Changed
- 설정 "메뉴바에 총 사용량 표시" 기본값 `false`로 변경
- 할당량 없을 때 col3 하단 → 프로필 전체 기간 사용량 표시
- 설정 "메뉴바에 총 사용량 표시" OFF 시 할당량 유무와 관계없이 col3 완전히 숨김
- 팝오버 하단: 설정/통계/절약모드 → "더보기" 드롭다운 메뉴로 통합 (순서: 통계, DNS 프리셋 적용, 절약 모드, 설정)
- 후원 버튼 → 종료 왼쪽으로 이동
- UsageReportView: 사이드바(C) 레이아웃 적용 (그래프/상세/세션)
- 닫기 버튼 하단 오른쪽 정렬
- PopoverView 통계 버튼 → `UsageReportView` 연결

## [0.3.0] — 2026-07-25 — Phase 1 마무리

### Added
- 프로필 편집기 `ProfileEditorView` (별도 View 구조체)
- 삭제 확인 ZStack 오버레이 다이얼로그 (sheet 뒤 가려짐 해결)
- 프로필 삭제 시 접속 SSID 자동 재등록
- 프로필 관리 목록 "● 접속 중" 표시
- `ProfileManager.getTodayUsage(profileId:)` — 오늘 usage_log 합계 조회
- 메뉴바 col3 3번째 라인: total sum (잠시, 후에 제거됨)

### Fixed
- **UUID DB 비교 버그** — GRDB가 UUID를 BLOB(16바이트)으로 저장하는데 `uuidString`(TEXT)으로 비교 → WHERE 조건 매칭 안 됨. 모든 `uuidString` 비교를 UUID 직접 비교로 수정 (getProfile, deleteProfile, getUsageLogs)
- **SwiftUI `.alert` sheet 뒤 가려짐 버그** — macOS에서 SwiftUI `.alert`가 부모 `@State` 변경 시 body 재렌더링으로 sheet 뒤에 위치. ZStack 오버레이로 대체

### Changed
- **설정에서 할당량 제거** — settings엔 col3 토글만 남음, 할당량은 오직 프로필에만
- **QoS 게이지 & 메뉴바 col3 데이터 출처** — `networkMonitor` 누적 → 해당 프로필의 **오늘 `usage_log` delta 합계**
- **메뉴바 col3 2줄 레이아웃** — 1줄: total(up+down today) / 2줄: 잔여(quota - total)
- **잔여 용량 표시** — < 1.0GB면 MB 단위로 표시
- `SettingsManager` — `quotaEnabled`, `quotaGB` 제거, `showTotalColumn`만 유지
- PopoverView — `editName`, `editQuotaEnabled`, `editQuotaValue`, `confirmDelete` @State 제거 (ProfileEditorView로 이동)

## [0.2.0] — 2026-07-24 — Phase 0 PoC ✅

### Added
- 메뉴바 커스텀 NSView (2줄: ▲ 업로드 / ▼ 다운로드)
- 메뉴바 실시간 속도 표시 (KB/s / MB/s / GB/s)
- 메뉴바 오늘 사용량 (ByteCountFormatter)
- 메뉴바 total 텍스트 QoS 색상 적용 (green/orange/red)
- SwiftUI 팝오버 (연결 정보, 속도, QoS 게이지, 버튼)
- CoreWLAN SSID/BSSID 획득 (Location 권한)
- getifaddrs() 네트워크 속도 측정 (NetworkMonitor)
- NWPathMonitor 핫스팟 감지 + 게이트웨이 IP 분석
- iOS/Android 핫스팟 OS 구분
- 외부 IP + GeoIP 조회 (ip-api.com)
- Ping 모니터링 (8.8.8.8 + 게이트웨이)
- QoS 방지 게이지 (3단계 색상 바 + 남은 용량)
- 프로젝트 구조: AppKit + SwiftUI 하이브리드
- scripts/package.sh 번들 패키징

### Changed
- 메뉴바 레이아웃: frame 기반 6셀 → 고정폭 col2/col3 + 우측정렬
- 팝오버 속도 포맷: Kbps/Mbps → KB/s/MB/s (메뉴바와 통일)
- 연결 정보 라벨 bold + 값 우측 정렬
- Location 권한 요청 타이밍 개선 (activationPolicy보다 먼저)

