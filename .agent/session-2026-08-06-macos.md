# Session — 2026-08-06 (macOS) — v0.22.2

1. 무엇을: **v0.22.2 MenuBarView 속성 캐싱 재적용 (T-77~T-78)** — 성능 조사에서 `PERFORMANCE_OPTIMIZATION.md`에 "적용 완료"로 기록됐으나 실제 코드에 미반영된 P3 캐싱을 재적용. 이전: v0.22.1 핫스팟 감지(T-74~76) + 3개 커밋/v0.22.1 태그 완료.
2. 플랫폼: [macOS]
3. 빌드: swift test 32개/7스위트 통과, build-macos.sh debug 성공. 수동: 메뉴바 표시 정상, 글자 크기 변경 즉시 반영(캐시 무효화 정상).
4. 남은 TODO: 성능 후보(P1) 화면 슬립 시 폴링 중지 / 팝오버 닫힘 tick 중지 / refreshCache 비동기 — 미착수. 위젯 T-47은 SwiftPM 불가능 확정(대안 C안 메뉴바 강화 추천). 다음 버전 기획(Sparkle/공증/Launch Agent) 미착수. **커밋/태그 대기 (v0.22.2)**.
5. 전달 로그:
   - **P3 불일치**: 문서는 static let 캐싱 완료로 기록했지만 실제는 `setText()` 문자열 비교만 적용. `menuBarFontSize`가 가변이라 static let 부적합 → fontSize별 재생성으로 해결.
   - **수정**: `cacheAttributesIfNeeded(fontSize:) -> Bool` — fontSize 변경 시에만 폰트/문단스타일/속성/컬럼폭 재생성, 화살표 `sizeToFit()`은 캐시 갱신 시에만(초기값 "▲"와 동일해 스킵되던 문제 → 반환값으로 강제).
   - `col2FixedW`/`col3FixedW` computed property → `cachedCol2W`/`cachedCol3W`. `totalAttr`만 매초 가변 색상이라 재생성 유지.
   - **조사 결과**: 위젯은 SwiftPM으로 `.appex` 생성 시 `chronod` 거부(실증). 유일 경로는 Xcode 서브프로젝트(App Group + 샌드박스 필수). 성능 다음 후보: 슬립 시 폴링 중지(P1, 이득 최대), 팝오버 닫힘 tick 중지, Timer tolerance, ping watchdog cancel 누락, TrafficMonitor accumulated 무한 성장.
6. 문서: PLAN_v0.22.2, TODO T-77~78, CHANGELOG v0.22.2, PERFORMANCE_OPTIMIZATION.md P3 정정 + v0.22.2 섹션.
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(32개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.23.0

1. 무엇을: **v0.23.0 디자인 시스템 + 팝오버 재설계 (T-79~T-84)** — 팝오버 감사 보고서(구조/직관성/통일성)에서 도출. 전 뷰 하드코딩 값(폰트 8~11px, 색상, 간격, 모서리, 시트/라벨 폭)을 `DesignSystem/Theme.swift` 토큰으로 치환 + 팝오버 요약/상세 2단 재설계.
2. 플랫폼: [macOS]
3. 빌드: swift test 32개/7스위트 통과, build-macos.sh debug 성공(번들 생성 + 앱 실행, DebugPanel ON). turbo 캐시: SwiftPM이라 N/A. [PERF] 이슈 없음.
4. 남은 TODO: v0.23.0 완료. 다음 후보(미착수): 시트 폭 값 자체 변경(현행 유지 — 회귀 위험), DebugPanelView 토큰화(개발자 패널이라 제외 결정), 성능 후보(슬립 폴링 중지 등 P1), Sparkle/공증/Launch Agent.
5. 전달 로그:
   - **Info.plist 버전 0.20.0/20 → 0.23.0/23 동기화** — 0.21~0.22에서 버전 누락이 있었음.
   - **팝오버 재설계 확정**: `popover_summary_mode` 기본 true(요약), 하단 `▾/▴` 토글 버튼, 배너 상단 고정, QoS 미설정 시 `할당량 설정` 버튼(프로필 있으면 editingProfile/없으면 showProfileManager), DNS 행 chevron.right 단서. 연결/주소 정보는 접이식 유지.
   - **토큰 치환 원칙**: 시맨틱 색(upload/download/success/danger/accent) + 텍스트/구분 + 폰트 스케일(8~11px) + 간격(4~20) + 시트/컬럼 폭. 시트 폭 값은 현행 유지(토큰 참조만).
   - **제외 3종**: DebugPanelView(개발자 전용 다크 패널), 히트맵 그라데이션/지도 핀 색(시각화 고유), 시스템 표준 폰트 title2/title3/largeTitle(난립 아님).
   - **커밋**: 38e9788(v0.22.2 선커밋), c03fe4b(PLAN/TODO), 7660951(T-79), 92b6c44(T-80/81), 9439fc9(T-82), 886de39/5707425/a47a596(T-83 전반), 2f78ee8(T-83 후반 8개 뷰), 7a87fd2(T-84 문서).
   - **검증**: 테스트 32/32 통과, 빌드 완료. GUI 수동 확인(토글/배너/할당량 버튼)은 사용자 확인 필요.
6. 문서: PLAN_v0.23.0_uiux.md, TODO T-79~84 ✅, CHANGELOG v0.23.0.
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(32개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.23.1

1. 무엇을: **v0.23.1 메뉴바 할당량 기준 "오늘" 통일 (T-85~T-87)** — 메뉴바 상태바의 할당량 컬럼이 "오늘 사용량/잔여"여야 하는데 "총 누적 사용량/잔여"로 표시되는 버그 수정. v0.21 커밋(40bd1f6)에서 기준이 todayGB→totalGB로 변경됐으나 팝오버 QoS 게이지는 여전히 오늘 기준이라 불일치가 있었음.
2. 플랫폼: [macOS]
3. 빌드: swift build 성공, test.sh 32개/7스위트 통과, build-macos.sh debug 성공(번들 생성 + 실행). GUI 수동 확인(오늘 사용량/잔여 표시, 팝오버 게이지 색·비율 일치) 필요.
4. 남은 TODO: v0.23.1 완료. 다음 후보(미착수): 시트 폭 값 자체 변경(현행 유지), DebugPanelView 토큰화(제외 결정), 성능 후보(슬립 폴링 중지 등 P1), Sparkle/공증/Launch Agent.
5. 전달 로그:
   - **원인**: v0.21(40bd1f6)에서 메뉴바 할당량 로직이 `todayGB`(오늘) → `totalGB`(총 누적)로 의도적으로 변경. 팝오버 게이지(PopoverView:552 `getTodayUsage`)는 오늘 기준 유지 → 위치별 기준 불일치.
   - **수정**: updateMenuBarText에서 상단 사용량/잔여/절약모드 자동활성/임계값 알림(50/80/95/100%)/게이지 색 경계(quotaRatio) 전부 `todayGB` 기준으로 통일. `totalGB` 변수·계산 제거, `checkQuotaThresholds` 파라미터명 `usedGB`로 명확화.
   - **유지**: 할당량 미설정 시(라인 477) "총 사용량" 표시와 `cachedTotalUsage` 캐시는 유지(여전히 사용됨).
   - **함의**: 오늘 기준이므로 자정 리셋 → 임계값 알림·절약모드 자동활성이 매일 재평가됨 (사용자 선택).
   - **기타**: Localized `showTotalInMenuBar` → "메뉴바에 사용량 표시" 중립화, Info.plist 0.23.1/build 24.
   - **커밋**: be51234(T-85 PLAN/TODO), 0be6108(T-86 코드), 52912ad(T-87 문서).
   - **검증**: 테스트 32/32, 빌드 완료. 메뉴바 vs 팝오버 게이지 기준 일치 확인은 수동 필요.
6. 문서: PLAN_v0.23.1_macos.md, TODO T-85~87 ✅, CHANGELOG v0.23.1.
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(32개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.23.1 구조 정리

1. 무엇을: **에이전트 규칙(AGENTS.md/AGENTS.local.md)에 맞는 폴더/문서 정리 (T-88~T-91)** — 조사에서 Info.plist 중복(실제 번들은 루트 Resources/Info.plist v0.13.0), AGENTS.macos.md·DESIGN.md 누락, tetherlens.db 추적, PLAN.md symlink 구식화 발견.
2. 플랫폼: [macOS]
3. 빌드: swift build 성공, test.sh 32/7 통과, build-macos.sh debug 성공. **배포 번들 Info.plist가 0.23.1/24로 정상화** (plutil 확인) — 기존 v0.13.0이 번들에 들어가던 버그 픽스 효과.
4. 남은 TODO: v0.23.1 정리 완료. 다음 후보(미착수): Sparkle appcast 배포, 성능 후보(슬립 폴링 중지 등 P1), 시트 폭 값 변경(회귀 위험 보류).
5. 전달 로그:
   - **Info.plist 단일 원본**: 루트 `Resources/Info.plist`만 수정. `Sources/TetherLens/Info.plist`는 삭제(죽은 파일 — 빌드 스크립트가 루트만 번들에 복사, Package.swift exclude 제거). 이후 버전 갱신은 반드시 `Resources/Info.plist` (AGENTS.macos.md 3장 명시).
   - **문서 정리**: AGENTS.macos.md(플랫폼 규칙), docs/DESIGN.md(기술 설계) 신설, AGENTS.local.md 2건 정정(CLAUDE.md ❌, 테스트 32개), docs/PLAN.md symlink→로드맵 문서 전환, icon.png→images/ 이동.
   - **잔재**: tetherlens.db(0B, git 추적 중) → .gitignore + rm --cached + 로컬 삭제 (실제 DB는 App Support), 빈 Sources/TetherLens/Resources/ 삭제.
   - **커밋**: 2c07318(T-88), 53673ed(T-89), d7a039f(T-90), 70844c5(T-91), 189b59b(문서 마무리).
   - **검증**: 테스트 32/32, 빌드 완료, 번들 버전 0.23.1/24 확인. AboutView 버전 표시(0.23.1) 수동 확인 권장.
6. 문서: TODO T-88~91 ✅, CHANGELOG v0.23.1 Chore 섹션.
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(32개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.24.0

1. 무엇을: **v0.24.0 정밀 분석 기반 버그 수정 + 리팩토링 (T-92~T-111)** — 서브에이전트 5회 재분석(데이터 정합성/타이머·리소스/뷰 계층/High급) + 핵심 파일 직접 검증으로 예상 버그 **27건** 확정·수정. 자동 테스트 32→38개.
2. 플랫폼: [macOS]
3. 빌드: `./scripts/test.sh` 38개/8스위트 전부 통과 + 아티팩트 안티체크 PASS, build 성공. Info.plist 0.24.0/25.
4. 남은 TODO: Y3 nettop 측정은 커버리지 약 50% 간단 개선(사용자 선택) — 100% 커버리지(상시 nettop 데몬)는 v0.25 후보. 기존 성능 후보(슬립 폴링 중지 등 P1)·Sparkle 공증 배포 미착수.
5. 전달 로그:
   - **1차(H1~H11)**: 프로필 전환 이중 계상(H1), 음수 델타 시 양수까지 폐기(H2·테스트가 버그 고정), TrafficMonitor data race(H3), 죽은 코드 todayUsage(M1), 자정 경계 캐시(M2), up/dn 분리 read(M3), v8 FK no-op(M4), SSID 전환 중복 세션(M5), watchdog 미취소(M6), cooldown 상승 억제(M7), 캐시/위치 미중지(M8), 1년 활성 세션(M9), refresh 백로그(M10), CSV 쿼팅(M11).
   - **2차(V1~V6)**: getIPForSession N+1→SQL, popover 타이머 body 재생성→static, 알림 클리어 race, 폰트 슬라이더 폭주→onEditingChanged, 블록 토글 미반영→ObservableObject, DebugPanel 인덱스→UUID.
   - **3차(W1~W5)**: SSID 스테일 캐시로 세션 오염, 80% "초과" 오정보·중복 알림, elapsed 하드코딩, 종료 시 app 로그 유실, 토글 알림 폭주.
   - **4차(X1~X2)**: connection_type 카멜/스네이크 혼재로 핫스팟 분류 붕괴(+v9 정규화 마이그레이션), autoSwitchProfile OFF 시 스테일 캐시.
   - **5차(Y1~Y3)**: 단절 시 마지막 구간 사용량 유실, 프로필 삭제 후 FK 위반 `try!` 크래시, nettop 1초 델타로 과소 집계(간단 개선).
   - **가드 트레이드오프**: PingMonitor watchdog weak 캡처는 `@Sendable` 컴파일 오류 → `DispatchWorkItem { [weak task] ... }` 패턴으로 우회. TrafficMonitor persistAccumulated는 `@MainActor` DebugLogger 호출을 main async로 dispatch.
   - **커밋**: efedfd6(T-92~98), 2838361(T-99~101), 4402758(2차 문서), 839ad14+141cc4d(T-103~106), a952f75+f2ce83d(T-107~108), 66c012d+7554f24(T-109~111), +CHANGELOG/세션/Info.plist.
   - **검증**: 테스트 38/38, 빌드 완료. GUI 수동 확인 필요(메뉴바 할당량·핫스팟 프로필 분류·세션 타임라인·앱 트래픽 리포트).
6. 문서: PLAN_v0.24.0_macos.md (T-92~111), TODO T-92~111, CHANGELOG v0.24.0.
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(38개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.25.0

1. 무엇을: **v0.25.0 통계 전면 개편 — T-112 대시보드 인사이트 카드 완료** — 사용량 리포트 요약 헤더를 상황이 보이는 인사이트 카드 2행 그리드로 재구성. 벤치마킹(DataGuard/DataUsage) 기반 대시보드 전환의 첫 단계.
2. 플랫폼: [macOS]
3. 빌드: swift build 성공, swift test 39개/7스위트 전부 통과. turbo 캐시: SwiftPM N/A. [PERF] 이슈 없음.
4. 남은 TODO: T-113 그래프 고도화(기간 단위 세분화+할당량 임계선+누적 라인) → T-114 클러스터 → T-115 이동 이력 → T-116 리포트 → T-117 메뉴 통일 → T-118 검증.
5. 전달 로그:
   - **신설**: `ProfileManager.getUsageTotal(profileId:from:to:)` — [from,to) 구간 총합, profileId nil이면 전체 프로필 합계 (전기간 비교용). 기존 getTotalUsage(전체 누적)와 별개.
   - **인사이트 카드**: 1행 [총 사용량+일평균 / 전기간 대비 ▲▼% / 최다 사용일], 2행 [최다 핫스팟 / 할당량%+예상 소진일(개별 할당량 설정 시) 또는 상위 앱(그 외)].
   - **전기간 비교**: `loadInsights()`가 `selectedPeriod.days * 2` 구간을 조회해 이전 절반과 비교. allProfiles 브랜치의 조기 return 전에 호출 배치.
   - **quotaGB**: 현재 프로필은 자동 등록으로 전부 nil → 할당량 카드는 ProfileEditor에서 설정 시에만 표시 (없으면 상위 앱 카드로 대체).
   - **테스트**: getUsageTotal 경계([from,to) — 하한 포함/상한 미포함) + 프로필 필터(nil=전체) 2건. 처음 경계 가정 오류로 2회 수정.
   - **커밋**: 5281e7e (feat(macos): T-112) — 7파일 +318/-26.
   - **검증**: 테스트 39/39, 빌드 완료. 인사이트 카드 GUI 수동 확인 필요(주기별 전기간 비교 %, 할당량 설정 시 예상 소진일).
6. 문서: PLAN_v0.25.0_macos.md (T-112~118), TODO T-112 ✅, CHANGELOG v0.25.0 (Added/Changed).
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(39개) + 수동 확인.

---

# Session — 2026-08-06 (macOS) — v0.25.0 (T-113~T-118)

1. 무엇을: **v0.25.0 통계 전면 개편 T-113~T-118 완료** — 그래프 고도화 → 지도 클러스터 → 이동 이력 → 기간 리포트 → 프로필 미니 통계 → 검증 마무리.
2. 플랫폼: [macOS]
3. 빌드: swift build 성공, **swift test 43개/7스위트 전부 통과**. `./scripts/build-macos.sh debug` 번들 생성 + 앱 실행 성공 (DebugPanel ON). [PERF] 이슈 없음.
4. 남은 TODO: v0.25.0 완료. 다음 후보(미착수): 성능 후보(슬립 폴링 중지 등 P1), Sparkle/공증/Launch Agent.
5. 전달 로그:
   - **T-113 (8d2217f)**: 그래프 기간 단위 세분화(1일=시간대 0~23시, 7일=요일, 30일=일, 6개월/1년=월) + 할당량 임계선 RuleMark + 누적 LineMark. `getHourlyUsage`/`HourlyUsage` 신설, 테스트 40개.
   - **T-114 (17a7408)**: 지도 핀 클러스터(좌표 소수점 3자리 그룹핑, >1이면 숫자 배지) + GPS(검정/파랑)/IP(주황) 마커·라벨, 최근 위치 적색 링. `Session.locationSource` + **v10_session_location_source 마이그레이션** 추가. `MenuBarManager.bestLocation`이 source(gps/ip) 반환, startSession 2곳 전달. HeatmapMapView의 미사용 region/timeLabel 제거. 테스트 41개.
   - **T-115 (2100173)**: `ProfileManager.getMovementTimeline` — 위치 세션 + IPLog를 시간순 병합(MovementEvent), HeatmapView에 이동 이력 탭 추가, 행 클릭 시 지도 탭 전환 + 해당 좌표 포커스(HeatmapMapView focusCoordinate + cameraPosition onChange). `Views/MovementTimelineView.swift` 신규. 테스트 42개.
   - **T-116 (50ca928)**: 리포트 탭(ViewMode.report) + `ProfileManager.reportSummary`(총 업/다운·세션·이동 이력·Top앱·할당량 달성률) + `Views/ReportView.swift` 마크다운 미리보기·복사. Localized reportTab/copy 추가. 테스트 43개.
   - **T-117 (784c162)**: 프로필 미니 통계 — 현재 프로필 행·프로필 관리 목록에 오늘 사용량 + 할당량 % 게이지(90% 이상 danger). Localized today 추가.
   - **T-118**: 최종 빌드·테스트 43개 통과 + 앱 실행 검증 + TODO/CHANGELOG/세션 로그 갱신. 커밋 전체: 3ab7c0c/8d2217f/17a7408/2100173/50ca928/784c162.
   - **검증**: GUI 수동 확인 필요 — 이동 이력 탭의 지도 포커스, 리포트 탭 마크다운 복사, 프로필 미니 통계 게이지.
6. 문서: PLAN_v0.25.0_macos.md (T-112~118), TODO T-112~118 ✅, CHANGELOG v0.25.0 (T-112~117).
7. 오프라인 큐: N/A.
8. E2E/k6: N/A — 자동화 단위 테스트(43개) + 수동 확인.
