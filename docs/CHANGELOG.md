# Changelog

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

