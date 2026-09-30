# session-2026-09-27-dashboard-macos (v0.39 대시보드)

1. 요청: 메뉴바 팝오버 `상세 보기` 항목을 RelayConsole 콘솔 대시보드처럼 **창 1개로 전부 출력**. UI/UX 제안 후 구현
2. 리서치: RelayConsole `DashboardLayout`/`DroidDashboardView`/`Components` 6 원칙 추출 + TetherLens 표시 가능 정보 인벤토리(팝오버 5섹션·인사이트 6종·리포트 6탭·실시간 소스 12종) 전량 조사
3. 제안 3안: A 단일 대시보드(권장) / B 사이드바 콘솔 / C 팝오버 확장(기각 — 패널이라 화면 밖 접근 불가)
4. 사용자 결정: ① 리포트 유지 + 대시보드 **신규** ② 상세보기 토글 제거·요약 고정 ③ **P0+P1 함께**
5. 신규 단축키 **⌘5** 채택 (⌘1~⌘4가 기존 창. ⌘D는 ⌘⇧D 디버그 패널과 혼동 위험)
6. PLAN 작성 — `docs/plans/PLAN_v0.39.0_dashboard_macos.md` (레이아웃·성능 설계·DoD)
7. 신규 파일 5개: `DashboardLayout`(순서 단일 진실원처) · `DashboardStore`(60초 단일 스냅샷) ·
   `DashboardView`(본체) · `DashboardCards`(카드 5종+KPI+상태바) · `AppServices`(인스턴스 레지스트리)
8. `AppServices` 신규 사유: `HotspotDetector`·`PingMonitor`·`IPResolver` 는 `MenuBarManager` 소유 인스턴스라
   SwiftUI `Window` 씬에서 주입 불가. `NetworkMonitor.shared` 처럼 싱글턴이 아니라 참조만 노출
9. P0: 상태바(세션경과·마지막갱신) + KPI 5종(오늘사용량/업/다운/남은/오늘세션) + ① 실시간 속도(차트+Top3 앱)
10. P1: ② 연결 품질 · ③ 할당량&예측 · ④ 시스템(기존 `SystemMetricsCards` 재사용) · ⑦ 연결 상세(전폭 `FlowRow` 칩) · 배너
11. **핵심 성능 설계**: `DashboardView` 는 `@Published` 를 하나도 관찰하지 않는다. 카드가 자기 것만 관찰하고
    1초 값(세션경과·상대시각)은 `DashboardClock` 서브뷰로 격리 → 감사에서 확인된 "팝오버 1Hz tick이 body 전체
    재렌더" 결함 재발 방지. `Grid`+`GridRow`+`maxHeight:.infinity`(LazyVGrid 은 행 높이 제어 불가)
12. 진입점 4곳 배선: ⌘5 · 우클릭 최상단 · 팝오버 주 버튼 · 커맨드 팔레트 최상단
13. **팝오버 `상세 보기` 제거** — 토글·`summaryMode` 파이프라인 삭제, 스크롤 180→92pt, 주 버튼을 대시보드로
14. 팝오버 죽은 코드 369행 제거(`detailSections`·5섹션·7헬퍼·`@AppStorage` 5개) — **1,543 → 1,145줄**
15. 토큰 신설: `TLSize.dashboardWindow`(900×680)·`dashboardInset`(20)·`TLFont.dashboardValue`·`SettingsManager.isCardEnabled`
16. Localized 9종 추가. `DashboardStore.ssid(of:)`·`DashboardClock.durationString` 을 `nonisolated`/internal 로 열어 테스트 가능
17. 테스트 21개 추가 — `DashboardLayoutTests`(순서 정의·포맷·스냅샷·SSID 추출·MAC 가드). **163개/22스위트 통과**
18. 테스트가 오류 가정 2건을 잡아 수정 — 카드 집합 assertion 이 `wideCards` 누락, `todayUsedGB` 를 KB 로 가정. 코드 결함 아님
19. MAC 조회에 길이 가드 추가 — `macAddress(forInterface:)` 의 7자 이상 무한루프(T-250)를 5초 주기 호출이 재노출하므로 방어
20. 문서: CHANGELOG([Unreleased] 신규 + Part 2로 감사 항목 분리) · TODO T-255~275 · PLAN 진행중 · DESIGN §2/§6/§14 신규 · AGENTS 테스트 수 163/22
21. 검증: `swift build` OK · **대시보드 신규 경고 0건** (전체 17건은 기존과 동일)
22. 남은: T-272 ⑤인사이트 상시화 · T-273 ⑥오늘 패턴 · T-274 카드 토글 UI · T-275 GUI 육안
23. 큐: bd TetherLens-d1a/d2b (P0/P1)
24. E2E: 해당 없음(macOS 메뉴바 앱). `build-macos.sh debug` 로 번들 재설치·실행 후 육안 검증 예정
