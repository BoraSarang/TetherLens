# Changelog

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
- **정보 창** (`AboutView`) — 앱 버전, 제작자(OkStart), 이메일, ☕️ 후원하기
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

