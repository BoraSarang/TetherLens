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
