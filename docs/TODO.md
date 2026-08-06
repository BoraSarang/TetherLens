# TetherLens — TODO

> 작업 추적: pending | in_progress | completed | cancelled
> 버그는 `bd`로 관리 (절대 TODO.md에 기록 금지)

---

## ✅ Phase 0 — PoC (2026-07-24)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 1 | Xcode 프로젝트 생성 + 기본 구조 설정 | P0 | ✅ |
| 2 | CoreWLAN SSID/BSSID 획득 (CoreLocation 권한) | P0 | ✅ |
| 3 | getifaddrs() 네트워크 속도 측정 | P0 | ✅ |
| 4 | NWPathMonitor 핫스팟 감지 + 게이트웨이 IP 분석 | P0 | ✅ |
| 5 | 기본 NSStatusItem + SwiftUI Popover | P0 | ✅ |
| 6 | iPhone/iPad 핫스팟, Android 핫스팟 실기기 검증 | P0 | ✅ |

## ✅ Phase 1 — Core App (2026-07-25)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 7 | 메뉴바 UI 완성 (2줄 속도 + 오늘 사용량) | P0 | ✅ |
| 8 | 연결 상세 정보 팝오버 | P0 | ✅ |
| 9 | 핫스팟 iOS/Android OS 구분 | P0 | ✅ |
| 10 | 외부 IP + GeoIP 조회 | P0 | ✅ |
| 11 | Ping 품질 모니터링 (8.8.8.8 + 게이트웨이) | P0 | ✅ |
| 12 | QoS 방지 게이지 (초록/노랑/빨강) | P0 | ✅ |
| 13 | SSID 기반 프로필 관리 + SQLite 저장소 | P0 | ✅ |
| 14 | 데이터 할당량 설정 + 경고 알림 | P0 | ✅ |
| 15 | DNS 표시 + 프리셋 변경 | P1 | ✅ |
| 16 | 설정 UI (col3 표시 토글) | P1 | ✅ |
| 17 | 프로필 편집기 + ZStack 오버레이 | P1 | ✅ |
| 18 | 프로필 삭제 시 SSID 자동 재등록 | P1 | ✅ |
| 19 | UUID DB BLOB 타입 매칭 수정 | P1 | ✅ |
| 20 | col3 데이터 usage_log 기준 변경 | P1 | ✅ |
| 21 | col3 total/잔여 2줄 표시 | P1 | ✅ |
| 22 | 잔여 용량 MB/GB 자동 단위 | P2 | ✅ |

## ✅ Phase 2 — Advanced (2026-07-25)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 23 | 스마트 절약 모드 | P1 | ✅ |
| 24 | 통계 그래프 (Swift Charts) | P1 | ✅ |
| 25 | 연결 이력 리포트 | P1 | ✅ |
| 26 | 세션 시간 추적 | P2 | ✅ |

## ✅ Phase 3 — Release (Completed)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 27 | Sparkle 자동 업데이트 | P0 | ✅ |
| 28 | 코드 서명 + Notarization | P0 | ✅ (로컬 서명 완료, Notarization은 유료 계정 필요 시 추후) |
| 29 | GitHub Actions CI/CD | P0 | ✅ |
| 30 | Buy Me a Coffee 후원 링크 | P1 | ✅ |
| 31 | 로그인 시 자동 실행 | P1 | ✅ |

## ⬜ Future (Backlog)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 32 | NEFilterDataProvider System Extension | P1 | ⬜ |
| 33 | 앱별 트래픽 per-app 누적 total 초기화 버튼 | P2 | ⬜ |
| 34 | 다크 모드 대응 | P3 | ⬜ |
| 35 | IP 변경 이력 추적 (ip_log 테이블 + onIPChange 콜백) | P2 | ✅ |
| 36 | 영문 현지화 (Localized.swift ~150개 키) | P1 | ✅ |
| 37 | 세션 타임라인 뷰 (SessionTimelineView) | P2 | ✅ |
| 38 | 핫스팟 히트맵 뷰 (HeatmapView/Grid/Map) | P2 | ✅ |
| 39 | OnboardingView (첫 실행 권한 안내) | P2 | ✅ |
| 40 | SettingsView 권한 섹션 + 용어 통일 | P2 | ✅ |

## ✅ v0.20 — Big Features (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 41 | 버전 v0.20.0 (build 20) Info.plist 동기화 | P0 | ✅ |
| 42 | 세션 타임라인 IP 표시 (getIPForSession) | P1 | ✅ |
| 43 | CSV/JSON 데이터 내보내기 (UsageReportView) | P1 | ✅ |
| 44 | 메뉴바 커스텀 모드 (속도/사용량/SSID 조합) | P1 | ✅ |
| 45 | 앱 트래픽 차단/허용 (AppBlockManager + 감지 알림) | P2 | ✅ |
| 46 | 프로필 자동전환 학습 (autoSwitchProfile 토글) | P2 | ✅ |
| 47 | 위젯 (WidgetKit) — SwiftPM이 .appex 미지원, Xcode 전환 필요로 제외 | P3 | ❌ |

## ✅ v0.21 — 2차 반복 분석 버그 수정 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 48 | 절약모드 hosts 차단 `\\n` 리터럴 버그 수정 | P0 | ✅ |
| 49 | v8 유니크 인덱스 충돌 회귀 + DB 삭제 fallback 개선 | P0 | ✅ |
| 50 | 온보딩 표시(데드 코드) + 위치 권한 요청 시점 이동 | P0 | ✅ |
| 51 | handleSettingsChanged guard 역전 + TrafficMonitor 주기 반영 | P1 | ✅ |
| 52 | TrafficMonitor.stop() 마지막 300초 flush 복원 + nettop 타임아웃 | P1 | ✅ |
| 53 | SSID 전환 시 마지막 사용량 flush | P1 | ✅ |
| 54 | 할당량 의미론 누적 기준 통일 (잔여/게이지/알림) | P1 | ✅ |
| 55 | LocationManager 배터리 개선 (첫 획득 후 중지 + 저전력) | P2 | ✅ |
| 56 | HotspotDetector 10.x 오분류 수정 | P1 | ✅ |
| 57 | PingMonitor gatewayTask/클램프/nil 폴백 | P2 | ✅ |
| 58 | UI 소소한 버그 (legend/로케일/CSV 이스케이프/빈 이름) | P2 | ✅ |
| 59 | 수동 테스트 가이드 문서화 (docs/tests/v0.21.0_macos.md) | P1 | ✅ |
| 60 | 메뉴바 오른쪽 클릭 → 더보기 드롭다운 메뉴 | P1 | ✅ |

## ✅ v0.21.1 — Low 후보 6건 개선 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 61 | QoS 임계값 단일화 (QoSGauge + MenuBarManager → SavingModeManager) | P2 | ✅ |
| 62 | AppTrafficView 상태 @AppStorage 유지 | P2 | ✅ |
| 63 | SettingsView 폴링 간격 즉시 저장 (onDisappear 의존 제거) | P2 | ✅ |
| 64 | UsageReportView appTraffic 조건부 로드 | P2 | ✅ |
| 65 | HeatmapGridView 키보드 접근성 | P3 | ✅ |
| 66 | DebugPanelView 하드코딩 문자열 로컬라이즈 | P3 | ✅ |

## 🔄 v0.22 — 자동화 테스트 도입 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 67 | 주입 리팩토링 (DataStore/ProfileManager/SettingsManager/SavingModeManager) | P1 | ✅ |
| 68 | Package.swift 테스트 타겟 추가 | P1 | ✅ |
| 69 | DataStore/ProfileManager 테스트 | P1 | ✅ |
| 70 | SettingsManager/SavingModeManager 테스트 | P1 | ✅ |
| 71 | SystemProcesses/Localized 테스트 | P2 | ✅ |
| 72 | scripts/test.sh 자동화 스크립트 | P1 | ✅ |
| 73 | 문서화 (PLAN/TODO/CHANGELOG/TEST) | P1 | ✅ |

## 🔄 v0.22.1 — Android 핫스팟 감지 보강 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 74 | Android 핫스팟 감지 보강 (SSID 키워드 확장 + 게이트웨이 대역 + 분기 순서) | P1 | ✅ |
| 75 | isAndroidSSID/isAndroidHotspotGateway 단위 테스트 | P2 | ✅ |
| 76 | 수동 재확인 (OkStart 연결 시 타입 표시) | P1 | ✅ |
