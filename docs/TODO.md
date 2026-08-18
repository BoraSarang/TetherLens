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
| 129 | 메뉴바 표시 필드 확장: BSSID/링크속도/DNS 옵션 + SettingsView 토글 | P2 | ✅ |
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
| 142 | acquire/release를 NSPopoverDelegate(popoverDidShow/DidClose)로 이전 — MenuBarManager가 정확히 제어 | P1 | 🔄 |
| 143 | PopoverView onAppear/onDisappear acquire/release 제거 (누수 원천 차단) | P1 | 🔄 |
| 144 | nettop 샘플 윈도우 축소 (interval+1 → 고정 2) + acquire/release balance 로그 | P1 | 🔄 |
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

## 🔄 v0.29.0 — 맥 앱 전면 리디자인 Phase 1~4 (구조 + 디자인 시스템 + 화면별 정제 + DebugPanel) (2026-08-15)

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

> 커밋: dab5d83 (T-155~160, Phase 1~2), 0c8b814 (T-162, Phase 3), 0868dc5 (Window 툴바 통일)
