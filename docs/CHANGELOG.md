# Changelog

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
