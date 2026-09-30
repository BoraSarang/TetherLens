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
| 27 | ~~Sparkle~~ 자동 업데이트 → **자체 `UpdaterManager`(GitHub Releases)로 대체** (2026-09-27 정정) | P0 | ✅ (구현체 교체) |
| 28 | 코드 서명 + Notarization | P0 | ✅ (로컬 서명 완료, Notarization은 유료 계정 필요 시 추후 — CI는 ad-hoc 서명) |
| 29 | GitHub Actions CI/CD | P0 | ✅ |
| 30 | ~~Buy Me a Coffee~~ 후원 링크 | P1 | ❌ **제거됨** (v0.14에서 후원 버튼 삭제 — 2026-09-27 정정) |
| 31 | 로그인 시 자동 실행 | P1 | ✅ |

## ⬜ Future (Backlog)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 32 | NEFilterDataProvider System Extension — **보류 확정** (Apple 유료 개발자 계정 + 시스템 확장 필요, 무료/OSS 배포와 충돌. 2026-08-09 부록 A 코드베이스 검증으로 P0→보류) | P1 | ⏸ |
| 33 | 앱별 트래픽 per-app 누적 total 초기화 버튼 | P2 | ✅ (v0.27) — 기존 리셋 버튼 + 확인 다이얼로그 |
| 34 | 다크 모드 대응 | P3 | ✅ (v0.27) — 시스템 팔레트 기반 자동 대응 점검 완료 |
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
| 47 | 위젯 (WidgetKit) — **보류 확정** (SwiftPM이 .appex 미지원 + Xcode 전환 대작업, 배포는 유료 개발자 계정 필수. 로컬 개발만 무료 가능 — 유료 계정 확보 시 재검토, 2026-08-10) | P3 | ⏸ |

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

## ✅ v0.22.2 — MenuBarView 속성 캐싱 재적용 (성능 P0, 2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 77 | MenuBarView fontSize 캐싱 (폰트/스타일/속성/width 재생성 최소화) | P0 | ✅ |
| 78 | 성능 검증 (빌드 + 수동 확인 + 문서 정합) | P1 | ✅ |

## ✅ v0.23.0 — 디자인 시스템 + 팝오버 재설계 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 79 | Theme.swift 생성 (폰트/색상/간격/모서리/시트·라벨 폭 토큰) + Info.plist v0.23.0 | P0 | ✅ |
| 80 | PopoverView 요약/상세 2단 재설계 + 배너 상단 고정 | P0 | ✅ |
| 81 | 팝오버 UX (할당량 설정 버튼, DNS chevron, 토글 버튼) | P1 | ✅ |
| 82 | 팝오버 내 하드코딩 값 토큰 치환 | P1 | ✅ |
| 83 | 나머지 뷰 토큰 치환 + 시트 폭 토큰화 (뷰별 커밋) | P1 | ✅ |
| 84 | 검증 (테스트/빌드/수동) + 문서 (CHANGELOG/세션/TODO) | P1 | ✅ |

> 커밋: 7660951(T-79), 92b6c44(T-80/81), 9439fc9(T-82), 886de39/5707425/a47a596(T-83 전반), 2f78ee8(T-83 후반), 7a87fd2(T-84 문서)

## ✅ v0.23.1 — 메뉴바 할당량 기준 "오늘" 통일 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 85 | PLAN 작성 + TODO 등록 | P0 | ✅ |
| 86 | MenuBarManager 오늘 기준 통일 + Localized 라벨 + Info.plist | P0 | ✅ |
| 87 | 검증 (테스트/빌드) + 문서 (CHANGELOG/TODO/세션) | P1 | ✅ |
| 88 | Info.plist 단일화 (루트 Resources 최신화 + Sources 삭제) | P0 | ✅ |
| 89 | 루트 잔재 정리 (tetherlens.db 추적 해제 + 빈 폴더) | P1 | ✅ |
| 90 | 에이전트 규칙 문서 완성 (AGENTS.macos.md/DESIGN.md 신설 + AGENTS.local.md 정정) | P1 | ✅ |
| 91 | PLAN.md 로드맵 전환 + icon 이동 + 검증/문서 | P2 | ✅ |

> 커밋: be51234(T-85), 0be6108(T-86), 52912ad(T-87), 2c07318(T-88), 53673ed(T-89), d7a039f(T-90), 70844c5(T-91)
> 결정: 메뉴바 사용량/잔여/절약모드/임계값 알림/게이지 색 전부 오늘 기준 (팝오버 게이지와 통일). 할당량 미설정 시 총 사용량 유지. v0.21에서 totalGB로 변경된 것을 복원.
> 정리: Info.plist는 루트 Resources/ 단일 원본 (배포 버전 0.13.0→0.23.1 정상화). AGENTS.macos.md/DESIGN.md 신설.

## 🔄 v0.24.0 — 정밀 분석 기반 버그 수정 + 리팩토링 (2026-08-06)

> 소스 전면 분석(2 에이전트 + 직접 검증)으로 예상 버그 확정. 자동 테스트 반복 실행으로 회귀 확인.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 92 | ProfileManager: 음수 델타 시 양수 방향만 기록 (H2) + `resetCounter` 추가 (H1) | P0 | ✅ |
| 93 | MenuBarManager: SSID 전환 시 이전 기록 + 새 프로필 카운터 시드 + getActiveSession 재사용 (H1, M5) | P0 | ✅ |
| 94 | ProfileManager: getTodayUsage 자정 경계 캐시 + up/dn 단일 read (M2, M3) | P1 | ✅ |
| 95 | ProfileManager: cleanupOldLogs 활성 세션 정리 (M9) + csvEscape 쿼팅 보강 (M11) | P1 | ✅ |
| 96 | TrafficMonitor: start 리셋 queue 직렬화 (H3) + refresh 백로그 skip (M10) / NetworkMonitor todayUsage 제거 (M1) | P0 | ✅ |
| 97 | PingMonitor: watchdog 취소 (M6) + cooldown 레벨 상승 허용 (M7) / HotspotDetector start 가드 / MenuBarManager 가드·시드·종료 기록 (M8) | P1 | ✅ |
| 98 | DataStore v8 orphan 정리 (M4) + 테스트 수정/추가 (H2 기존 테스트 고정 해제) | P1 | ✅ |
| 99 | ProfileManager: getIPForSession SQL 쿼리화 (V1) / PopoverView: 타이머 publisher static + 알림 클리어 값 비교 (V2, V3) | P2 | ✅ |
| 100 | SettingsView: 폰트 슬라이더 onEditingChanged (V4) / AppBlockManager: ObservableObject + AppTrafficView 구독 (V5) | P2 | ✅ |
| 101 | DebugPanelView: 선택 추적 UUID 기반 (V6) | P2 | ✅ |
| 102 | 검증: 테스트 전체 + 재분석 반복 + 문서 마무리 (CHANGELOG/세션/TODO) | P1 | ✅ |
| 103 | MenuBarManager: SSID 전환 시 cachedProfile 무효화 (W1) + autoActivate "초과" 알림 제거 (W2) | P0 | ✅ |
| 104 | NetworkMonitor: 실제 경과 시간 기반 속도 계산 (W3) | P1 | ✅ |
| 105 | TrafficMonitor: 종료용 동기 flush + handleAppTermination 호출 (W4) | P1 | ✅ |
| 106 | PingMonitor: 연결 토글 알림 쿨다운 (W5) | P1 | ✅ |
| 107 | MenuBarManager: connectionTypeString 스네이크 통일 + DataStore v9 정규화 마이그레이션 + 테스트 (X1) | P0 | ✅ |
| 108 | MenuBarManager: SSID 변경 시 캐시 무효화를 autoSwitchProfile과 무관하게 (X2) | P0 | ✅ |
| 109 | MenuBarManager: SSID 단절 시 마지막 구간 recordUsage (Y1) | P0 | ✅ |
| 110 | MenuBarManager: handleCurrentProfileDeleted에서 currentSession/lastTrackedSSID 리셋 (Y2) | P0 | ✅ |
| 111 | TrafficMonitor: nettop 샘플 윈도우 확장 + 타이머 self-rescheduling (Y3) | P1 | ✅ |

> 커밋: [T-92~98 코드/테스트/문서 각각 분리], [T-99~101 코드], [T-102 문서]
> 상태: 전부 완료 — 92~98 (efedfd6), 99~101 (2838361), 102 문서 (4402758), 103~106 (839ad14, 141cc4d), 107~108 (a952f75, f2ce83d), 109~111 (66c012d, 7554f24), 마무리(CHANGELOG/세션/Info.plist 0.24.0) 미커밋
> 회귀: v0.24.0 5차 재분석 완료 — 남은 High 급 없음 (Y3는 50% 커버리지 간단 개선, 100%는 v0.25 후보)

## 🔄 v0.25.0 — 통계 전면 개편 (2026-08-06)

> 벤치마킹(DataGuard/DataUsage 등) 기반 대시보드 인사이트 + 이동 이력 + 기간 리포트. 위치는 표현만 개선(수집 변경 없음).

| # | Task | Priority | Status |
|---|------|----------|--------|
| 112 | 리포트 대시보드 인사이트 카드 (총/일평균/한도%/예상 소진일, 전기간 비교, 상위 항목) | P0 | ✅ |
| 113 | 그래프 고도화 (시간대/요일별 세분화 + 할당량 임계선 + 누적 라인) | P1 | ✅ |
| 114 | 지도 핀 클러스터 + 위치(GPS/IP) 라벨 | P0 | ✅ |
| 115 | 이동 이력 타임라인 + 지도 포커스 | P0 | ✅ |
| 116 | 기간 리포트 화면 (기간+프로필 선택 → 요약 화면 + 마크다운 미리보기·복사) | P1 | ✅ |
| 117 | 메뉴 구성 통일 + 프로필 행 미니 통계 (사용량/할당량 %) | P1 | ✅ |
| 118 | 검증: 테스트 전체 + a11y-dump 수동 확인 + 마무리 (CHANGELOG/세션/TODO) | P1 | ✅ |


> 참고: DebugPanelView는 개발자 전용 다크 패널이라 토큰 대상 제외, 히트맵 그라데이션/지도 핀 색은 시각화 고유 로직으로 유지

## 🔄 v0.25.1 — 슬립 시 폴링 중지 + tick 최적화 (2026-08-06)

> 시스템 슬립 시 네트워크/핑/트래픽 폴링 일시중지 → 깨어나면 자동 재개. 성능 후보 P1 중 이득 최대.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 119 | 슬립/깨움 이벤트 구독 + 모니터 일시중지/재개 (MenuBarManager) | P1 | ✅ |
| 120 | 팝오버 닫힘 시 1초 tick 중지 (PopoverView) | P2 | ✅ |
| 121 | Timer tolerance 부여 (MenuBarManager/TrafficMonitor) | P2 | ✅ |

## 🔄 v0.25.2 — 팝오버 시트 좀비 상태 방지 (2026-08-06)

> admin 프롬프트(절약 모드/DNS 프리셋)로 앱이 resignActive → popover 강제 닫힘 시 시트 @State가 좀비로 남아
> 다음 오픈에서 팝오버 클릭 무반응. 재오픈 시 모든 시트 상태 리셋으로 해결.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 122 | PopoverView.resetPopoverState() + 재오픈 시 시트 상태 초기화 (togglePopover show 직전) | P1 | ✅ |
| 123 | 검증: 빌드/테스트 + 수기 재현 대비 (절약 모드 포함) | P1 | ✅ |

## 🔄 v0.25.3 — 팝오버 프로필 UI 정리 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 124 | 프로필 행 [통계]/[편집] 버튼을 세로 2줄 스택으로 변경 | P2 | ✅ |
| 125 | 팝오버 '프로필 관리' 버튼 제거 + 더보기(우클릭) 메뉴에 '프로필 관리' 추가 | P2 | ✅ |

## 🔄 v0.25.4 — 네트워크 연결 알림 누락 수정 (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 126 | PingMonitor 상태 전환 감지를 매 루프로 + 알림 발송 디버그 로그 (useDNS에만 의존하던 누락) | P1 | ✅ |

## 🔬 관찰 기록 — 에너지 사용 (2026-08-06) — ✅ 종결

> 사용자: 배터리 '많은 에너지 사용' 1위가 TetherLens. 나중에 `bd`/에너지 프로파일로 원인 확인 필요.
> **2026-08-09 종결**: v0.25.1(슬립 폴링 중지 + tick 중지 + tolerance) 이후 괜찮다는 사용자 확인으로 종결.

| 관찰 | 조치 |
|------|------|
| macOS 배터리 메뉴에서 TetherLens가 에너지 사용 1위 | v0.25.1(슬립 폴링 중지 + tick 중지 + tolerance)이 어느 정도 완화하는지 먼저 확인 → 이후에도 1위면 `Instruments Energy Log`/`sample`로 핫스팟 분석 |
| 의심 지점 | NetworkMonitor 1초 폴링(getifaddrs), MenuBarManager 메뉴바 갱신 타이머, TrafficMonitor nettop 주기 실행, PingMonitor 지속 ping, PopoverView 1초 tick, LocationManager 주기 위치 갱신 |

## 🔄 v0.26.0 — 네트워크 진단 센터 + SSID 자동화 트리거 + 메뉴바 확장/export (2026-08-09)

> 경쟁 분석(COMPETITOR_ANALYSIS 부록 A)을 코드베이스 기준 정정 후 도출된 실질 격차 3종 통합.
> 계획: docs/plans/PLAN_v0.26.0_macos.md

| # | Task | Priority | Status |
|---|------|----------|--------|
| 127 | 연결 진단 센터 패널: VPN/proxy · DNS 누수 · 커스텀 ping · traceroute · bufferbloat · Markdown 리포트 | P1 | ✅ |
| 128 | SSID 자동화 트리거: AutomationRule/Manager + 프로필 전환 훅 + 절약 모드 연동 | P1 | ✅ |
| 129 | 메뉴바 표시 필드 확장: BSSID/링크속도/DNS 옵션 + SettingsView 토글 | P2 | ❌ **미구현 — v0.31에서 3열 자동 전환 설계로 대체, 재도입 불필요로 확정** (2026-09-27 정정) |
| 130 | 사용 내역 CSV/Markdown export (UsageReportView Save) | P2 | ✅ |
| 131 | 검증: 빌드/delta/a11y-dump + CHANGELOG + 커밋 | P1 | ✅ |

## ✅ v0.27.0 — 백로그 T-33/T-34 정리 (2026-08-10)

> 계획: docs/plans/PLAN_v0.27_macos.md — 백로그 잔여 2건 마무리 (Future 섹션 33/34 ✅ 처리)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 132 | 트래픽 초기화 확인 다이얼로그 (T-33 기존 리셋 버튼 + 실수 방지 오버레이) | P2 | ✅ |
| 133 | 다크 모드 점검 (T-34) — 시스템 팔레트 기반 자동 대응 확인 + 잔여 하드코딩 의도적 설계 검증 | P3 | ✅ |
| 134 | 검증: 빌드 + 테스트(43개) + CHANGELOG/TODO/PLAN/세션 문서 | P1 | ✅ |
| 135 | 프로세스별 트래픽 가로 폭 확장 (320→400, TLSize.sheetTraffic 토큰 신설) | P2 | ✅ |
| 136 | 검증: 재설치·실행 확인 + CHANGELOG/AGENTS.local 갱신 | P1 | ✅ |

## 🔄 v0.28 — 에너지 최적화 (2026-08-12)

> 관찰: 배터리 이슈 조사 실측 — TrafficMonitor가 팝오버/시트 닫힘에도 상시 nettop 가동(CPU 130%). 충전 인식 문제는 하드웨어 확인 사항이라 앱 측 낭비만 최적화.
> 계획: docs/plans/PLAN_v0.28_macos.md

| # | Task | Priority | Status |
|---|------|----------|--------|
| 137 | PLAN 작성 + TODO 등록 | P1 | ✅ |
| 138 | 폴링 기본값 조정 (menuBar 2→3, traffic 5→10, ping 3→5 — cache 유지) | P1 | ✅ |
| 139 | TrafficMonitor 지연 시작 (acquire/release 참조 카운팅 + PopoverView/AppTrafficView 제어) | P1 | ✅ |
| 140 | 저전력 모드 강화 (powerStateChanged 구독 → traffic 중지 + ping 15초 + 메뉴바 5초) | P1 | ✅ |
| 141 | 검증 (빌드/test.sh + pgrep nettop 확인) + CHANGELOG/세션 문서 | P1 | ✅ |

## 🔄 v0.28.1 — nettop 잔여 스폰 수정 (팝오버 acquire 누수) (2026-08-12)

> 원인: v0.28의 PopoverView `onAppear/onDisappear` 기반 acquire/release가 NSPopover transient 닫힘(외부 클릭/ESC)에서 onDisappear 미호출 → `usageRefs[.popover]` 잔류 → 앱 재시작 직후엔 없으나 팝오버 열고 닫은 뒤부터 주기적 nettop 스폰 (에너지 영향도 2,004 / 12h Power 2,315 실측).

| # | Task | Priority | Status |
|---|------|----------|--------|
| 142 | acquire/release를 NSPopoverDelegate(popoverDidShow/DidClose)로 이전 — MenuBarManager가 정확히 제어 | P1 | ✅ (2026-09-27 코드 확인: `MenuBarManager:12` NSPopoverDelegate 채택, `:393/:397` 구현) |
| 143 | PopoverView onAppear/onDisappear acquire/release 제거 (누수 원천 차단) | P1 | ✅ (2026-09-27 코드 확인: `MenuBarManager`가 담당, PopoverView 주석 명시) |
| 144 | nettop 샘플 윈도우 축소 (interval+1 → 고정 2) + acquire/release balance 로그 | P1 | ⚠️ **부분 되돌림 (2026-09-27)** — 고정 2는 유지했으나 원인이 "10초 주기 중 1초만 측정해 총합이 실제의 ~1/10로 과소 계상"으로 판명되어 `samples`를 재조회 주기에 맞춰 되돌림(bd TetherLens-4e6). acquire/release balance 로그는 미구현 |
| 145 | 검증: 재시작→팝오버 여닫기→pgrep nettop 0 + 에너지 영향도 + CHANGELOG/세션 문서 | P1 | ✅ |

## ✅ v0.28.2 — 네트워크 API 호출 최적화 (IP/위치 갱신 절감) (2026-08-13)

> 관찰: DebugPanel 로그 분석 — 30분마다 IP 조회(ipify + ipapi.co 2회)를 IP가 동일해도 무조건 호출(12시간 96회), 위치는 5분마다 동일 좌표 갱신, 저전력 "IP 건너뜀" 로그도 30분마다 반복 노이즈.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 146 | IP 동일 시 ipapi.co 지역 조회 생략 + lastFetch 갱신 (IPResolver) | P1 | ✅ |
| 147 | ipRefreshTimer 1800→3600초 (SSID 변경 force 체크는 유지) | P1 | ✅ |
| 148 | 저전력 "IP 갱신 건너뜀" 로그 info 레벨로 하향 | P2 | ✅ |
| 149 | 위치 갱신 쿨다운: 최근 15분 내 획득 시 스킵 (LocationManager) | P1 | ✅ |
| 150 | 검증: 빌드/test.sh + DebugPanel 로그(IP/위치 스킵 확인) + 문서/커밋 | P1 | ✅ |

## 🔄 v0.28.3 — GitHub 링크 + 랜딩 페이지 리디자인 (2026-08-15)

> 사용자 요청: "프로그램에 깃헙 링크가 없네?" → AboutView에 GitHub 저장소/페이지 링크 추가 + GitHub Pages 랜딩 페이지를 ui-ux-pro-max 스킬로 리디자인.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 151 | AboutView: GitHub(github.com/BoraSarang/TetherLens) + GitHub Pages(borasarang.github.io/TetherLens) 링크 버튼 추가 | P1 | ✅ |
| 152 | 랜딩 페이지 docs/index.html ui-ux-pro-max 리디자인 (Real-Time/Operations 패턴 + OLED 네온 HUD 스타일, SVG 아이콘, reduced-motion, 반응형) | P1 | ✅ |
| 153 | 스크린샷 검증: 데스크톱/모바일 렌더링 + docs/screenshots 저장 + 다운로드 링크 302 확인 | P2 | ✅ |
| 154 | 검증: test.sh + build-macos.sh debug + 문서/커밋/릴리즈 | P1 | ✅ |

## 🔄 v0.29.0 — 맥 앱 전면 리디자인 Phase 1~5 (구조 + 디자인 시스템 + 화면별 정제 + DebugPanel + 모션) (2026-08-15)

> 사용자 요청: 3개 스킬(macos-app-design / ios-the-final-5-percent / apple-design) 기반 전체 UI/UX 변경. 목표 "아.. 맥 앱이구나". 확정: 별도 윈도우 전환 / 메뉴바 아이콘+숫자 병행 / Phase 1~2 먼저. 계획: docs/plans/PLAN_v0.29.0_macos.md

| # | Task | Priority | Status |
|---|------|----------|--------|
| 155 | Theme.swift: TLPalette Display P3 브랜드 4색 + on-color 토큰 추가 | P1 | ✅ |
| 156 | MenuBarManager: 메뉴바 SF Symbol 아이콘+숫자 병행 (템플릿 착색, 폭 계산 안정화) | P1 | ✅ |
| 157 | App.swift: Settings scene 교체 + Window scene(리포트/앱트래픽/알림/정보) 추가 + openWindow | P1 | ✅ |
| 158 | PopoverView: 320pt 슬림화 + 시트 제거 + More→openWindow | P1 | ✅ |
| 159 | AppDelegate: 온보딩 window.title Localized | P2 | ✅ |
| 160 | material/radius/폰트 토큰 일원화 (팝오버 material, QoSGauge radius 등) | P2 | ✅ |
| 161 | 검증: test.sh/build + 6화면 스크린샷 + 다크/라이트 + 문서/커밋/릴리즈 | P1 | 🔄 |
| 162 | Phase 3 화면별 정제: Settings TabView+Form(.grouped) / UsageReport NavigationSplitView / Window 뷰 닫기 버튼 제거 | P1 | ✅ |
| 163 | Phase 4 DebugPanel: 시스템 팔레트(다크/라이트 대응) + SF Symbol 정제 | P1 | ✅ |
| 164 | Phase 5 모션: 배너/섹션 전환 0.2s + QoSGauge 채움 0.5s | P2 | ✅ |

> 커밋: dab5d83 (T-155~160, Phase 1~2), 0c8b814 (T-162, Phase 3), 0868dc5 (Window 툴바 통일), 7d72b5a (T-163, Phase 4)

## 🔄 v0.30.0 — 맥 앱 메뉴바 강화 + Cmd-K 커맨드 팔레트 (2026-08-18)

> 사용자: "다른창도 확인 했음 다음 진행해". macos-app-design §4~§6 미충족 항목(메뉴바/단축키/Cmd-K) 보완. 계획: docs/plans/PLAN_v0.30.0_macos.md

| # | Task | Priority | Status |
|---|------|----------|--------|
| 165 | 메뉴바 강화: Window 메뉴(리포트 ⌘1/트래픽 ⌘2/알림 ⌘3/정보 ⌘4) + View 메뉴(팝오버 ⌘⇧P, DebugPanel ⌘⇧D) | P1 | ✅ |
| 166 | Cmd-K 커맨드 팔레트: Window scene + 검색 + ↑↓/Enter/Esc + ⌘K | P1 | ✅ |
| 167 | 검증: test.sh/build + 메뉴바/팔레트 수동 확인 + 문서/커밋/릴리즈 | P1 | ✅ |

> 릴리즈 완료: v0.30.0 태그 + main push + release 빌드 (DebugPanel OFF). 커밋: 3ac7fbe (feat 메뉴바+팔레트), 82f0111 (fix 설정 제목), 1abf6c9 (세션 로그)
> 후속: e9669e4 (스크린샷 분리 + Info.plist 0.30.0/30) — T-167 릴리즈 완료 마감

## 🔄 v0.32.0 — 프로세스 CPU/RAM 보조 표시 (2026-09-07)

> 사용자 요청: 네트워크 프로세스 보기처럼 CPU/RAM도 표시. B안(정렬까지) + 3면(앱 트래픽 창/팝오버 top5/플로팅 top3).
> 계획: docs/plans/PLAN_v0.32.0_macos.md (bd: TetherLens-y8j)
> 원칙: 추가 타이머·서브프로세스 없음 — TrafficMonitor.refresh() 주기 편승 (libproc 직접 호출).

| # | Task | Priority | Status |
|---|------|----------|--------|
| 175 | PLAN 작성 + bd 등록 + TODO 등록 | P0 | ✅ |
| 176 | SystemResourceMonitor 신규 (libproc 수집 + 순수 헬퍼 + SysRes 로그) | P1 | ✅ |
| 177 | TrafficMonitor 연동 (AppTraffic cpu/mem 확장 + refresh 병합 + systemLoad 발행) | P1 | ✅ |
| 178 | UI 3면 (AppTraffic 정렬+컬럼+요약 / Popover top5 / Floating top3 + Localized + Theme 토큰) | P1 | ✅ |
| 179 | 검증 (test.sh 75개 + build + 라이브 샘플링 실측 + Info.plist v0.32.0/32 + CHANGELOG/세션) | P1 | ✅ (GUI 수동 확인 — 앱 트래픽 창/팝오버/플로팅 표시 — 은 사용자 몫으로 남음) |
| 180 | 팝오버 독립 리소스 섹션 (CPU Top3 + MEM Top3, 요약/상세) + `TLPalette.cpuHeat` 공용화 | P1 | ✅ |
| 181 | 플로팅 독립 리소스 섹션 (CPU순 Top3 한 줄 행 + 고정 높이 244) | P1 | ✅ |
| 182 | 검증 (test.sh 75개 + build-macos.sh debug + CHANGELOG/PLAN/TODO 갱신) | P1 | ✅ (GUI 수동 확인은 사용자 몫으로 남음) |
| 183 | 네트워크 리스트 CPU/MEM 원복 (AppTraffic 컬럼·정렬·요약 / Popover·Floating 행 2행째 제거) | P1 | ✅ |
| 184 | 팝오버 간략보기 프로세스·리소스 제거 (상세만) + 상세 리소스 토글 | P1 | ✅ |
| 185 | 플로팅 3줄 요약 (프로세스/CPU/RAM 각 1위) + 줄별 표시 토글 3개 + 높이 가변 | P1 | ✅ |
| 186 | 검증 (test.sh 75개 + build-macos.sh debug + CHANGELOG/PLAN/TODO/bd) | P1 | ✅ (GUI 수동 확인은 사용자 몫으로 남음) |
| 187 | 플로팅 3칸 (프로세스/CPU/RAM Top3) + 높이 자동 맞춤(fitToContent) + 팝오버 간략보기 정리 + 설정 토글 | P1 | ✅ (캡처로 렌더 확인) |
| 188 | 플로팅 자동높이 루트 구조 수정 (overlay 미기여 → 콘텐츠 스택 + background, 캡처 재확인) | P1 | ✅ |
| 189 | 플로팅 프로세스칸 3열 헤더 복원 (프로세스/업로드/다운로드, 캡처 확인) | P1 | ✅ |
| 190 | 리소스 랭킹 전체 프로세스 기준으로 수정 (allResources, java/node 누락 버그, 캡처 확인) | P0 | ✅ |

## ✅ v0.31.0 — 플로팅 창 (메뉴바 축소판 + 프로세스 트래픽) (2026-09-02)

> 사용자 요청: 메뉴바 표시 내용을 바탕화면 플로팅 창으로 별도 구성. 계획: docs/plans/PLAN_v0.31.0_macos.md (bd: TetherLens-9a5)
> 2026-09-24 상태 점검: 코드베이스 구현 완료 확인 후 마감 (드래그·글래스엣지·자동높이 등 v0.32.x 후속 포함)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 168 | PLAN 작성 + bd 등록 | P0 | ✅ |
| 169 | TrafficMonitor `Usage.floating` + MenuBarManager `floatingContentChanged` 발행 | P1 | ✅ (코드 확인: FloatingWindowController:34, MenuBarManager:779) |
| 170 | FloatingWindowController: borderless NSPanel + 위치 저장/복원 + 트래픽 acquire/release | P1 | ✅ |
| 171 | FloatingWindowView: 메뉴바 축소판(폰트 반영) + 트래픽 top3 + 투명도/닫기 + 행 클릭→앱트래픽 | P1 | ✅ (후속 v0.37.1 네트워크 카드·시스템 카드 통합 포함) |
| 172 | 진입점: 우클릭 더보기 토글 + ⌘⇧F + ⌘K 팔레트 액션 | P1 | ✅ (메뉴/팔레트/팝오버 … 토글 확인) |
| 173 | SettingsView 플로팅 창 섹션(시작 시 표시/투명도/트래픽) + SettingsManager 3키 + Localized | P1 | ✅ (SettingsView:208~242, SettingsManager floatingShowAtLaunch/Opacity) |
| 174 | 검증: test.sh + build + DebugPanel(ERROR 0) + 문서(CHANGELOG/TODO/세션) | P1 | ✅ (test 122 통과; Info.plist bump는 릴리즈 시점) |

## 🔄 v0.32.1 — 플로팅 테두리 호버시에만 표시 (2026-09-09)

> 사용자 요청: 플로팅 화면의 4각 테두리 제거 → 호버시에만 표시로 합의. 계획: docs/plans/PLAN_v0.32.1_macos.md (bd: TetherLens-ix5)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 191 | 플로팅 외곽 테두리 호버시에만 표시 (`FloatingWindowView` overlay 조건분기) + 검증/문서 | P2 | ✅ |

## 🔄 v0.32.2 — 플로팅 Tahoe 글래스 엣지 제거 (2026-09-09)

> 후속: overlay 제거 후에도 직각의 밝은 림 잔류 → 픽셀 측정으로 Tahoe 글래스 엣지 확정 → `hasShadow=false`로 제거. 계획: docs/plans/PLAN_v0.32.1_macos.md 追記 (bd: TetherLens-vie)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 192 | 플로팅 글래스 엣지 제거 (`hasShadow=false`, 머티리얼 원복) + 캡처 검증/문서 | P2 | ✅ |

## 🔄 v0.32.3 — 플로팅 모서리 16pt + 투명도 70% (2026-09-09)

> 사용자 요청: 직각이 아니라 원처럼 깎인 둥근 표현 → 16pt + 투명도 70%로 합의. 계획: docs/plans/PLAN_v0.32.1_macos.md §6 (bd: TetherLens-1xz)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 193 | 플로팅 모서리 24pt(전용 상수, 16→24 상향) + 투명도 70%(defaults) + 캡처 검증/문서 | P2 | ✅ |

## 🔄 v0.34.0 — 통계 재구축: 인사이트 중심 (2026-09-09)

> 사용자 요청: 현행 통계는 "아 썼네 끝"이라 도움 안 됨 → 행동 유도형으로 전면 재구축. DB 재설계 포함, 데이터 보존 전제. 계획: docs/plans/PLAN_v0.34.0_macos.md (bd: TetherLens-rqk)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 194 | PLAN 작성 + bd 등록 + TODO 등록 | P0 | ✅ |
| 195 | DB v11 (daily_rollup/app_daily_rollup/insight_log + backfill + 백업 + 대조 테스트) | P0 | ✅ |
| 196 | StatsEngine + 인사이트 4종 (소진예측·주범·이상치·세션효율) + 단위 테스트 | P1 | ✅ |
| 197 | InsightsView 신규 + 병행 운영 (구 화면 분리는 후속) | P1 | ✅ |
| 198 | 검증 (test.sh + build + 실데이터 캡처 + CHANGELOG/세션) | P1 | ✅ (test 89개 + build 성공, 2026-09-09 21:00 재확인) |

## 🔄 v0.34.1 — 리포트 화면 분리 + 구 카드 제거 (2026-09-09)

> PLAN_v0.34.0 §6 3단계 후속 (bd: TetherLens-rqk). UsageReportView 1252줄 분리 + InsightsView로 대체 완료된 구 insightCards 제거 + 데드 쿼리 정리.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 199 | ReportShared/Charts/Sessions/AppTraffic 4파일 분리 (HoverRow·formatTotalBytes 공용화) | P1 | ✅ |
| 200 | 구 카드 제거 (insightCards/statCard/heroRow + topHotspot/topApps 상태·쿼리 + 데드 포맷 함수) | P1 | ✅ |
| 201 | 검증 (test.sh + swift build + CHANGELOG/세션) + 커밋 | P1 | ✅ (test 89개 + build 경고 0, UsageReportView 1252→415줄) |
| 202 | 인사이트 섹션 제거 (사용자 요청, Unreleased) — 호출+스냅샷 배선 삭제, 엔진 파일 보존 | P2 | ✅ (test 89개 + build 성공) |
| 203 | 인사이트 엔진 전체 삭제 (사용자 요청) — 엔진·뷰·롤업·테스트 파일 + v11 마이그레이션 + 문구 | P2 | ✅ (test 77개 + build 성공, GRDB 미등록 무시 확인) |

## 🔄 v0.35.0 — 속도 테스트 + 연결 유지 (2026-09-09)

> COMPETITOR_ANALYSIS 벌점 아이디어 2종 정식 등록 (09-05 이후 미등록 상태였음). 계획: docs/plans/PLAN_v0.35.0_macos.md

| # | Task | Priority | Status |
|---|------|----------|--------|
| 204 | PLAN 작성 + bd 등록 + TODO 등록 | P0 | ✅ |
| 205 | 속도 테스트 (NetworkDiagnostics.speedTest + DiagnosticsView + 핫스팟 경고) | P1 | ✅ (test 82개 + build 경고 0, 실측은 수동) |
| 206 | 연결 유지 (ConnectionGuardian + 재연결 액션 + 자동 토글 OFF) | P1 | ✅ (test 88개 + build 성공, 실 networksetup은 수동) |
| 207 | 검증 (test.sh + build + 수동 실측 + CHANGELOG/세션) + 커밋/푸시 | P1 | ✅ (test 88개 + build + 재시작 + 푸시, 실측은 사용자 몫) |
| 208 | 팝오버 "..." 메뉴를 우클릭 더보기와 정렬 (리포트·플로팅·진단 추가) | P2 | ✅ (test 88개 + build 성공) |
| 209 | 속도 테스트 다운로드원 교체 (hetzner 차단 실측 → Cloudflare 1차 + hetzner 폴백) | P1 | ✅ (test 88개 + build 성공) |
| 210 | 느린 회선 대응 (10MB 고정 → 10MB·12초 선착 + 디버그 로그 3종) | P1 | ✅ (test 88개 + build 성공) |

## ✅ v0.37.0 — iStat 스타일 트래픽 + CPU/GPU/MEM 그래프 (2026-09-24)

> 사용자 요청: 3면 프로세스 트래픽 iStat Menus 점유율 바로 표현 + 시스템 CPU/GPU/MEM 스파크라인. RelayConsole UI 참고. GPU 실패 시 숨김.
> 계획: docs/plans/PLAN_v0.37.0_iStat_macos.md (bd: TetherLens-4kb, closed 2026-09-24)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 211 | PLAN 작성 + bd 등록 + TODO 등록 | P0 | ✅ |
| 212 | MetricsHistory 링버퍼 + TLSparkline/TLShareBar + SystemMetricsStrip | P0 | ✅ (Components 신규, 60점 링, GPU 칸 조건부) |
| 213 | SystemResourceMonitor GPU(IOKit) + SystemLoad.gpuPercent + TrafficMonitor push | P0 | ✅ (IOKit 3클래스·4키 후보, 실패 시 nil/info 1회) |
| 214 | 3면 UI (점유율 바 + 시스템 그래프 스트립) + 설정 토글 + Localized | P0 | ✅ (플로팅/팝오버/앱트래픽 + showSystemGraphs, 후속 T-217에서 개별 토글로 대체) |
| 215 | 검증 (test.sh + build + DebugPanel ERROR 0) + 문서(CHANGELOG/세션/bd) | P1 | ✅ (test 114개 + build 경고 0, GUI 육안은 사용자 몫) |
| 216 | SystemMetricsStrip → SystemMetricsCards 카드형 재구성 (iStat) + perCore/loadavg | P0 | ✅ (MetricCard/TLGaugeBar/TLCoreBars, host_processor_info+getloadavg, 3면 detail 분기, test 120개 통과) |
| 217 | 설정 플로팅 창: CPU/GPU/RAM 그래프 개별 토글 (기본 RAM만 ON) | P0 | ✅ (showCPUGraph/showGPUGraph/showMemGraph, 단일 showSystemGraphs 제거) |
| 218 | 플로팅 RAM 카드: `17 / 32 GB`를 제목 오른쪽 우측 정렬로 이동 | P1 | ✅ (MetricCard trailing 헤더, hero 텍스트 제거) |
| 219 | CPU/GPU 카드 trailing 통일 + 플로팅 호버 지표 토글 메뉴 + RAM 라벨 통일 | P1 | ✅ (제목 우측 수치, 차트 아이콘 드롭다운, Localized memory/sortByMemory/showMemGraph → RAM) |
| 220 | 플로팅 카드 배경 투명도 연동 + 앱 트래픽 창 프로세스 목록 잘림 수정 | P1 | ✅ (MetricCard.backgroundOpacity, AppTraffic ScrollView+LazyVStack) |
| 221 | 앱 트래픽 창: 카드 스타일 통일 + 항상 전체 표시 + 640×760 고정(리사이즈 금지) | P1 | ✅ (MetricCard 셸, alwaysShowAll, windowResizability.contentSize) |
| 222 | 플로팅 재구성: 네트워크 카드(팝오버 차트+큰 숫자+프로세스Top3) 항상 표시 + 프로세스/그래프 분리 토글 제거 | P0 | ✅ (TLNetworkSpeedChart 공용, NetworkMonitor.shared, showCPUGraph 등 카드 통합, floatingShow* 제거) |

## ✅ v0.38.2 — 안정성·성능 재점검 후속 (2026-09-24)

> 조사 + 코드 패치 완료 (bd k5o 안정성 / bd rsk 성능, 둘 다 close). test 122 + build OK.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 223 | 안정성 P1: IPResolver URL! 가드 / isCurrentPathExpensive continuation resume-once / DNS 메인스레드 Process → 백그라운드 | P0 | ✅ (ResumeOnceGate, currentServersAsync, PopoverView/dnsLeakCheck) |
| 224 | 성능 P1: PopoverView·ReportView·ReportAppTrafficView·MovementTimeline·SessionTimeline body 고비용 연산 hoisting | P0 | ✅ (@State 캐시 + onAppear/onChange 1회 계산, HeatmapMapView 포함) |
| 225 | 성능 P2: NetworkMonitor 타이머 tolerance/leeway, DateFormatter static 재사용, FloatingWindowViewModel 스냅샷 발행 | P1 | ✅ (leeway 100ms, static DateFormatter, 단일 스냅샷) |
| 226 | 검증 (test.sh + build) + 문서(CHANGELOG/PLAN §3.4/세션/bd close) | P1 | ✅ (build OK + test 122 통과, 문서 갱신) |

## 🔔 v0.38.0 — 스로틀링 알림 잔류 수정 + 문서 정리 (2026-09-24)

> 스로틀링 경고 해소 API + 시스템 알림 제거 + UI 마킹. 문서(README/CHANGELOG/랜딩) + 릴리즈 v0.38.0. test 126 + build OK.

| # | Task | Priority | Status |
|---|------|----------|--------|
| 227 | AppNotification 해소 API (resolvedAt/isActive/isWarningLike) + NotificationManager resolveWarnings | P0 | ✅ |
| 228 | PingMonitor 복구 시 시스템 알림 제거 + activeSystemNotificationIds 추적, ConnectionGuardian connectionLost 해소 | P0 | ✅ |
| 229 | NotificationListView 해소 경고 UI (opacity 0.55 + 체크 + "해소됨" + 시각) + Localized | P1 | ✅ |
| 230 | NotificationManagerTests 5개 신규 + 전체 검증 | P1 | ✅ (test 126 통과) |
| 231 | 문서 정리 (README/README_EN 배지 v0.38.0 + 다운로드 링크 + 연결 품질 카드 해소 설명, CHANGELOG 0.38.0, DESIGN §8 해소, 랜딩 v0.38.0 링크 + 피처) | P1 | ✅ |
| 232 | release-notes/v0.38.0.md + Info.plist 0.38.0/38 + 세션 로그 | P1 | ✅ |
| 233 | 커밋 → 브랜치 → PR → 머지 → 태그 v0.38.0 → release CI 확인 | P0 | ✅ |

## ✅ 플로팅 창 가로 300pt 고정 (2026-09-24)

> RelayConsole 플로팅과 동일한 고정 300pt. minWidth 240만 있어 fitting 시 좁아지던 문제 수정.
> bd: TetherLens-8z6 (closed)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 234 | `TLSize.floatingWindow=300` 토큰 + SwiftUI 고정 폭 + fitToContent 가로 강제 + NSPanel 초기 폭 토큰 참조 | P1 | ✅ (build OK + test 132 통과, 실측 폭 300 확인) |
| 235 | 문서 정리 (CHANGELOG [Unreleased] / PLAN 최신 / TODO / 세션 로그) + 커밋·PR·머지 | P1 | ✅ |

## 🔔 2026-09-27 — 전체 코드·문서 감사 후 P0/P1 정합성 일괄 처리

> 문서 5개(PRD/PLAN/DESIGN/TODO/CHANGELOG)와 소스 83파일(15,923줄)을 코드 대조 감사.
> P0 2건 + P1 5건 코드 수정, 문서 정합 20건, 테스트 11개 추가.
> bd: TetherLens-fif/4px/4e6/uwk/zvo/u23 (전부 closed)
> 검증: `swift build` OK + `scripts/test.sh` **142개/21스위트 통과** (기존 131개/19스위트)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 236 | P0 절약모드 `/etc/hosts` 영구 오염 — BEGIN/END 블록 마커 + 멱등화 (bd fif) | P0 | ✅ (임시 파일로 완전 제거·멱등 실증) |
| 237 | P0 프록시 진단 100% 무효 — `scutil --proxy` 따옴표 조건 제거 + `parseProxyOutput` 분리 (bd 4px) | P0 | ✅ (+회귀 테스트 4개) |
| 238 | P1 앱별 트래픽 10배 과소 — nettop 샘플 수를 재조회 주기에 맞춤 + 전 블록 합산 (bd 4e6) | P1 | ✅ (+테스트 7개) |
| 239 | P1 프로세스명 공백 손실 — `OpenCode Helper.56898` → `OpenCode`로 잘리던 파서 수정 | P1 | ✅ |
| 240 | P1 핀 고정 후 팝오버 재오픈 불가 — `popoverDidClose`에서 핀 리셋 (bd uwk) | P1 | ✅ |
| 241 | P1 진단 센터 "닫기" 무동작 — Raw NSWindow라 `dismiss`가 no-op → `onClose` 위임 (bd uwk) | P1 | ✅ |
| 242 | P1 DB 복구 이중 실패 시 in-memory 폴백 마이그레이션 누락 (bd u23) | P1 | ✅ |
| 243 | P1 메뉴바 단축키 8개 동작 불가 — `AppShortcuts`(NSEvent 모니터) 신규 도입 (bd zvo) | P1 | ✅ (build OK, GUI 확인 필요) |
| 244 | 문서 정정: FR-24·Sparkle 미구현 확정 (PRD/CHANGELOG/DESIGN/TODO/COMPETITOR 5곳) | P1 | ✅ |
| 245 | 문서 정정: FR-20(발열 없음·임계값 100/250ms)·FR-21(미구현)·PRD §7 스택 3건 | P1 | ✅ |
| 246 | 문서 정정: 테스트 수 32/7 → 142/21 (AGENTS.local·AGENTS.macos), stale T-142/143/144, CHANGELOG `[Unreleased]` 중복 1건 | P1 | ✅ |
| 247 | 문서 정정: COMPETITOR_ANALYSIS §0 정정표(12개 항목), DESIGN 헤더 미갱신 경고 | P1 | ✅ |
| 248 | 검증: `swift build` + `scripts/test.sh` 142개 통과 | P1 | ✅ |

### 남은 항목 (다음 세션)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 249 | GUI 육안 검증 — ⌘1~⌘4·⌘⇧F·⌘⇧P·⌘K 동작, 진단 창 닫기, 핀 고정 후 재오픈, 절약모드 ON→OFF 후 `/etc/hosts` 정합 (bd u23/uwk/zvo/fif 관련) | P0 | ⬜ 수동 필요 |
| 250 | 아래 11건 중간 강도 버그 (P2) — `ReportView` ForEach 중복 ID, `NetworkMonitor.macAddress` `continue` 무한루프, `PingMonitor` 게이트웨이 RTT 폴백·교대 판정, `TrafficMonitor` 종료 시 `queue.sync` 8초 블로킹, 리포트 N+1 쿼리 3건, `HeatmapGridView` hover O(168×N), `IPResolver` GeoIP country 필드 | P2 | ✅ (2026-09-30 전건 해결, bd TetherLens-axc) |
| 251 | `Info.plist` 죽은 키 `SUFeedURL`/`SUPublicEDKey` 제거 (릴리즈 시점) | P2 | ⬜ 사용자 승인 필요 |
| 252 | DESIGN.md v0.28~v0.38 절 추가(16개 파일 누락분) + PLAN.md 버전표 v0.28~v0.38 보충 | P2 | ⬜ |
| 253 | 경고 25건 정리 — `AutomationManager` 비-Sendable 캡처, `MovementTimelineView` 결정론적 ID, `init(cString:)` 4건, `try?` 무효 3건, 미사용 변수 4건 | P2 | ⬜ |
| 254 | `error_message_ko.json` 도입 (E-MAC-* 매핑) / `docs/api/`·`docs/screenshots/macos/` 생성 여부 결정 | P2 | ⬜ |

## 🔔 2026-09-27 — v0.39 대시보드 창 (P0+P1) · 팝오버 상세보기 통합

> RelayConsole 콘솔 대시보드 패턴 이식. `docs/plans/PLAN_v0.39.0_dashboard_macos.md`
> bd: TetherLens-d1a (P0), TetherLens-d2b (P1)
> 검증: `swift build` OK(신규 경고 0) + `scripts/test.sh` **183개/22스위트 통과** (기존 142개/21스위트)
> GUI: `build-macos.sh debug` → 8칸 렌더 확인, 스크린샷 `docs/images/dashboard/dashboard-8cells.png`

| # | Task | Priority | Status |
|---|------|----------|--------|
| 255 | PLAN 작성 — 레이아웃·성능 설계·DoD | P0 | ✅ |
| 256 | `DashboardLayout` — 카드 enum + `rows`/`wideCards`/`ordered` (순서 단일 진실원처) | P0 | ✅ |
| 257 | `DashboardStore` — 60초 DB 집계 단일 스냅샷 + acquire/release | P0 | ✅ |
| 258 | `AppServices` 레지스트리 — Window 씬에서 MenuBarManager 소유 인스턴스 접근 | P0 | ✅ |
| 259 | `DashboardStatusBar` + `DashboardClock`(1초 타이머 격리) + KPI 5종 | P0 | ✅ |
| 260 | ① 실시간 속도 카드 (차트 + 큰 숫자 + Top3 앱 점유바) | P0 | ✅ |
| 261 | ② 연결 품질 (RTT·지터·20회 도트·링크/채널/PHY + 정상응답/경고/자동화 칩) | P1 | ✅ |
| 262 | ③ 할당량 & 예측 (QoSGauge + 오늘 + 자정 예측 + 8일 평균 대비) | P1 | ✅ |
| 263 | ④ 오늘 사용 패턴 (24시 구간 막대 + 최근 8일 스파크) | P1 | ✅ |
| 264 | ⑤ CPU / ⑥ GPU / ⑦ RAM — 개별 셀로 분리 (기존 `SystemMetricsCards` 3-in-1 해체) | P1 | ✅ |
| 264b | ⑧ 프로세스 리스트 (CPU·MEM·NET 랭킹 12행, 스크롤, 더보기) | P1 | ✅ |
| 264c | 8칸(4행×2열) 구성 확정 — `DashboardLayout` enum 8개 + `rows` 4행 | P1 | ✅ |
| 264d | GUI 검증 3건 수정 — ① `Grid`→`HStack`(행높이 확장 안 됨) ② `MetricCard.fillsRow` 프레임 위치(배경 뒤→앞) + content 뒤 `Spacer` ③ ① Top3 구간합계→초당 환산 | P1 | ✅ |
| 264e | ③ 8일 평균 대비 배율 + 최근 8일 합계/일평균 — 빈 여백을 실제 데이터로 채움 | P1 | ✅ |
| 265 | 배너 스택 (끊김 / 할당량 경고 5초 자동 해제) | P1 | ✅ |
| 266 | 진입점 4곳 — ⌘5 / 우클릭 / 팝오버 주 버튼 / 커맨드 팔레트 | P1 | ✅ |
| 267 | Window 씬 등록 + `TLSize.dashboardWindow`/`dashboardInset`/`TLFont.dashboardValue` 토큰 | P1 | ✅ |
| 268 | **팝오버 `상세 보기` 토글 제거** — 요약 고정, 스크롤 180→92pt | P1 | ✅ |
| 269 | 팝오버 죽은 코드 제거 — `detailSections`·5섹션·7헬퍼 369행 (1,543→1,145줄) | P1 | ✅ |
| 270 | `DashboardLayoutTests` **29개** (순서 정의·8칸/4행 검증·포맷·스냅샷·시간대 버킷·SSID 추출·MAC 가드) | P1 | ✅ (테스트가 오류 가정 2건을 잡아 수정 — 코드 결함 아님) |
| 271 | 검증: `swift build` + `scripts/test.sh` 163개 통과 | P1 | ✅ |

### 남은 (P2/P3 — 다음 세션)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 272 | ⑤ 눈여겨볼 점 카드 — 인사이트 6종 상시화 (`InsightEngine`를 차트 탭 조건에서 분리, `DashboardStore`로 이동) | P2 | ⬜ |
| 273 | ⑥ 오늘 사용 패턴 — 24시 바 + 8일 스파크 + 세션 요약 + 시간대 Top3 앱 | P2 | ⬜ |
| 274 | 카드 On/Off 설정 UI (`SettingsManager.isCardEnabled` 키는 배선 완료, 토글 UI만 없음) | P3 | ✅ (274와 278이 중복 — 278에서 처리) |
| 275 | GUI 육안 검증 — ⌘5 / 8칸 렌더 / 행 높이 정합 / KPI / ②③ 데이터 — **완료** (스크린샷 `docs/images/dashboard/dashboard-8cells.png`) | P0 | ✅ |
| 276 | ② 연결 품질 카드 하단 여백 정리 (정보량 대비 빈 공간) | P3 | ✅ — `PingMonitor.recentLatencies` 추가 + "지연 추이" 스파크라인 & min/avg/max (장식이 아닌 실측값) |
| 277 | ⑨ 눈여겨볼 점 카드(전폭) + `InsightProvider`/`InsightPresenter` 분리 + 인사이트 상시화 | P2 | ✅ |
| 277b | **기존 버그 수정: 심야 소모 비율 100% 초과(186% 관측)** — `getHourlyUsage(days:1)` 의 `now-1day` 기준이 분자에 어제 야간을 섞고, 분모 `getTodayUsage` 는 오늘 자정 이후라 기간 불일치. `getHourlyUsageToday` 추가 + `nightDrainShare` 100% 클램프 + 회귀 4개 | P1 | ✅ |
| 278 | 카드 On/Off 설정 UI (`SettingsManager.isCardEnabled` 키는 배선·동작 확인 완료, 토글 UI만 없음) | P3 | ✅ — 설정 > 대시보드 탭 신설, 9카드 토글 + "모든 카드 표시" |
| 279 | v0.38.3 부수 개선: nettop `samples == interval` 로 넓혀 첫 앱 트래픽 데이터가 창 열림 후 ~10초 소요 — 스켈레톤/로딩 표기 검토 | P2 | ⬜ |

## 🔔 2026-09-30 — v0.39 P3 마감 (카드 설정 UI + ② 카드 하단)

> bd: TetherLens-44t
> 검증: `swift build` OK(신규 경고 0) + `scripts/test.sh` **188개/22스위트 통과** (기존 183개/22스위트)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 280 | 설정 > **대시보드 탭 신설** — 9카드 토글, `DashboardCard.ordered` 로 표시 순서 미러링 | P3 | ✅ |
| 281 | "모든 카드 표시" 버튼 — 전부 OFF 상태에서 한 번에 복원 (전부 ON 시 비활성) | P3 | ✅ |
| 282 | 카드 토글 → `settingsChanged` 발신 — 열려 있는 대시보드가 60초 대기 없이 즉시 반영 | P3 | ✅ |
| 283 | ② 연결 품질 카드 하단 — `PingMonitor.recentLatencies` 신규 + "지연 추이" 스파크라인 & min/avg/max | P3 | ✅ |
| 284 | 회귀 테스트 5개 (기본 전부 ON · 저장/조회 · 전체 복원 · 같은 행 독립 토글 · 재실행 유지) | P3 | ✅ |

## 🔔 2026-09-30 — P2 버그 11건 일괄 해결 (T-250)

> bd: TetherLens-axc · 검증: `swift build` OK + `scripts/test.sh` **197개/23스위트 통과**
> (±11건 전부 코드 수정. GUI 육안 검증은 별도 — `docs/TODO.md` T-249)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 285 | `NetworkMonitor.macAddress` 무한루프 — `continue` 가 `ptr = next` 를 건너뜀. 7자 이상 인터페이스명에서 실제 관측됨. `ifa_name` nil 가드도 함께 추가 | P2 | ✅ |
| 286 | `PingMonitor` 게이트웨이 RTT 위장 — 미해석 시 8.8.8.8 결과를 `gatewayRTT` 에 써서 OR 판정이 항상 통과, 게이트웨이 단절 미감지. 미측정은 `nil` 로 남김 | P2 | ✅ |
| 287 | `TrafficMonitor` 종료 시 8초 블로킹 — nettop 이 queue 를 최대 30초 점유. 진행 중 프로세스를 먼저 종료시키고 상한 2초만 대기 | P2 | ✅ |
| 288 | `ReportView.renderedBody` N+1 — `summary` 계산 프로퍼티가 body 평가마다 DB 재조회. `cacheKey` 기준 `@State` 캐시 + `onAppear`/`onChange` 로만 갱신 | P2 | ✅ |
| 289 | `UsageReportView.loadData` 메인 스레드 동기 쿼리 (전체 프로필 1년 ≈ SELECT 100회). 계산은 `nonisolated static` 로 분리해 `Task.detached` 에서 수행, 결과만 `MainActor` 로 적용. 늦게 도착한 이전 요청은 token 으로 폐기 | P2 | ✅ |
| 290 | `HeatmapGridView.gridData` O(168×N) — 계산 프로퍼티라 셀마다 재집계. 순수 `static buildGridData` + `@State` 1회 계산, hover 는 실제 변화가 있을 때만 반영 | P2 | ✅ |
| 291 | `IPResolver` GeoIP country 필드 — ipapi.co 의 `country`(국가명)를 2자리 코드로 착각해 잘못된 국기 렌더링. `country_code` 디코딩 + alpha-2 검증 + 강제 해제 크래시 제거. 회귀 테스트 9개 | P2 | ✅ |
| 292 | `MovementTimelineView` 행 ID `UUID()` — 재계산마다 전 행 재생성. 프로필+시각+종류+IP 조합의 결정론적 ID 로 교체(중복 시 출현 순번) | P2 | ✅ |
| 293 | `ReportView` ForEach `id: .element.profileName` — 이름 중복 시 중복 ID. `quotaEntries` 에 `profileId` 추가해 UUID 사용 | P2 | ✅ |
| 294 | `PopoverView` 1Hz tick — 읽는 계산 프로퍼티가 v0.39 에서 대시보드로 옮겨져 **죽었는데** 타이머가 남아 매초 body 전체 재평가. 1Hz 제거 + 죽은 `sessionDurationString` 삭제 | P2 | ✅ |
| 295 | 커서 push/pop 불균형 — hover-out 없이 뷰가 사라지면 pointingHand 가 스택에 남아 앱 전체에 고정. `pointingHandCursor()` modifier 로 3곳 교체 | P2 | ✅ |

> 부수: `DailyUsage`/`MonthlyUsage`/`HourlyUsage`/`DailySessionSummary`/`MonthlySessionSummary`/`Session`/`Profile`/`InsightItem`/`InsightKind` 에 `Sendable` 추가 (T-289 의 백그라운드 이동 전제)
> 신규: `scripts/tlbuild.sh` — swift build 출력에서 컴파일러 커맨드라인을 걷어낸 압축 출력 스크립트

## 🔔 2026-09-30 — 프로세스 리스트 초당률 표기 + 라벨 중복 (T-2ds)

> bd: TetherLens-2ds · 검증: `swift build` OK + `scripts/test.sh` **205개/24스위트 통과**

| # | Task | Priority | Status |
|---|------|----------|--------|
| 296 | 플로팅 창 프로세스 리스트 초당률 오류 — `bytesIn/bytesOut`(구간 합계)을 초당 포맷터에 직접 전달, 기본 10배 과대 | P2 | ✅ |
| 297 | 앱 트래픽 창 동일 오류 + 중복 포맷터(`formatByteRate`) 제거 → `ByteRateFormat` 통합 | P2 | ✅ |
| 298 | 배율 기준을 설정값 → **실제 관측 구간**으로 (`TrafficMonitor.windowSeconds`) — 워치독이 nettop 을 일찍 끊어도 배율 유지 | P2 | ✅ |
| 299 | 차트 범례 중복 제거 — `TLNetworkSpeedChart.showsLegend`(기본 false). 플로팅·팝오버·대시보드 ① 3곳 모두 히어로와 값 중복 | P2 | ✅ |
| 300 | 트래픽 갱신 **2초 선택지** 추가 (기본값 10초 유지 — nettop 상시 실행 배터리 부담) | P3 | ✅ |
| 301 | `WindowRateTests` 8개 (배율·경계·반올림·단위) | P2 | ✅ |

## 🔔 2026-09-30 — 프로세스 리스트 복구 + 실시간 주기 (사용자 지적)

> **중점: 네트워크 사용량 + 어떤 놈이 네트워크를 많이 쓰냐.**
> 검증: `swift build` OK + `scripts/test.sh` **209개/24스위트 통과**

| # | Task | Priority | Status |
|---|------|----------|--------|
| 302 | **팝오버 프로세스 리스트 복구** — v0.39 대시보드 통합 과정에서 제거돼 "누가 쓰지?" 에 답할 수 없었음. 네트워크 히어로 아래 **고정 영역**에 상시 배치 | P0 | ✅ |
| 303 | `NetworkProcessList` 공용 컴포넌트 — 팝오버·플로팅이 같은 표시 규칙 공유 (어긋남 구조 제거) | P0 | ✅ |
| 304 | **실시간 주기** — 창이 열려 있으면 2초, 닫으면 설정값(기본 10초). `.appBlock` 은 백그라운드라 제외 | P0 | ✅ |
| 305 | 가시성 변경 시 타이머 즉시 재예약 — 팝오버를 연 직후 2초가 바로 적용되도록 | P1 | ✅ |
| 306 | `SettingsManager.processListInterval` (기본 2초) + 테스트 4개 | P1 | ✅ |

## 🔔 2026-09-30 — nettop 137% CPU 근본 해결 (A+C) · 첫 블록 버그

> **사용자 지적 → 실측 → 구조 변경.** 검증: 218개/25스위트 · 런타임 5% CPU / nettop 0개
> bd: TetherLens-2ds 후속

| # | Task | Priority | Status |
|---|------|----------|--------|
| 307 | nettop CPU 실측 — `-l`/`-s` 무관 ~135% CPU 확인. 설정으로 낮출 수 없음을 실측으로 확정 | P0 | ✅ |
| 308 | **첫 블록 = 누적 카운터 스냅샷** (전 블록 합산 버그) — 인터페이스 델타 64,671 B vs block1 16,050,290 B 대조로 확정. 첫 블록 제외 + `interval+1` 보정 | P0 | ✅ |
| 309 | A: 상시 측정 기본 OFF (`processListEnabled`) — 평상시 nettop 미실행 | P0 | ✅ |
| 310 | CPU/RAM 을 nettop 에서 분리 — 값싼 libproc 조회가 137% CPU 에 종속돼 있었음 | P0 | ✅ |
| 311 | C: 요청 1회 측정 — `지금 측정` 버튼 → 3초 스냅샷 | P0 | ✅ |
| 312 | 목록 필터 정정 — `totalBytes* > 0` OR 제거 (현재 구간만) | P0 | ✅ |
| 313 | 절약모드(`.appBlock`)만 예외적으로 상시 측정 유지 | P1 | ✅ |
| 314 | 설정 토글 + 테스트 12개 (Nettop 5 · Settings 7) · 기존 픽스처 4개 정정 | P1 | ✅ |
| 315 | 이전 커밋의 가시성 2초 폴링 폐기 (138% CPU 유발) | P0 | ✅ |
