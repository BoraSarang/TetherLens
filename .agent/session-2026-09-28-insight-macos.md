# session-2026-09-28-insight-macos (v0.39 P2 — ⑨ 눈여겨볼 점 + 기존 버그 1건)

1. 이어서 작업: P2 남은 **⑨ 눈여겨볼 점 카드**(인사이트 6종 상시화) 구현
2. `InsightProvider`(신규) — 인사이트 입력 조립을 `UsageReportView.refreshInsights` 인라인에서 분리.
   대시보드·리포트 공용으로 DRY 충족. `dailyDays=8`·`ipWindowDays=7` 상수화
3. `InsightPresenter`(신규) — 아이콘·색·히어로·제목·본문 표시 규칙을 한곳에 모음.
   `InsightSectionView` 는 위임만 하도록 변경(종류 추가 시 1곳만 수정)
4. `DashboardCard.insight` 추가 → **전폭(`wideCards`)** 으로 배치. 목록형이라 2열 그리드에 섞지 않음
5. `DashboardInsightCard` — 2열 `LazyVGrid`, 히어로 값 + 제목 + 본문, `topOffender`→시스템 대시보드 /
   `ipChurn`→진단 버튼 이동. 빈 상태는 "특이사항 없음"(0 으로 오해하지 않음)
6. `DashboardStore.Snapshot.insights` 추가 — 60초 주기로 상시 계산. **리포트 차트 탭 진입 불필요**
7. **GUI 검증에서 기존 버그 발견**: 심야 시간대 소모가 **186%** 로 표시(비율인데 100% 초과)
8. 원인: `InsightEngine.nightDrainShare` 의 분자 `getHourlyUsage(days: 1)` 은 `now - 1day` 기준이라
   **어제 00~06시 데이터가 섞이는 반면**, 분모 `getTodayUsage` 는 **오늘 자정 이후**. 분자/분모 기간 불일치.
   v0.38 이전부터 존재하던 버그이며 대시보드가 노출시킨 것
9. 수정: `ProfileManager.getHourlyUsageToday`(신규, 오늘 자정 이후 한정) + `nightDrainShare` 에
   `min(share, 1)` 방어적 클램프. 대시보드 24시 막대도 같은 API 를 쓰고 있어 함께 정정
10. 검증: 재캡처로 **186% → 100%** 확인
11. 회귀 테스트 4개(100% 클램프·정상 입력·기준 미달·총량 미달) + 프리젠터 테스트 5개 추가
12. 테스트 중 오류 가정 1건 정정 — "프로필 0개면 인사이트 0개" 라 가정했으나 `topOffender` 는
    **전역** 집계라 프로필과 무관하게 나올 수 있다(코드 결함 아님)
13. 카드 토글 기능 자체를 검증에 활용 — `dashboard.card.*` 키로 insight 만 ON 하여 단독 렌더 확인 후 키 삭제(기본 복원)
14. `key code 116`(PageDn) 이 TetherLens 대신 Finder 로 전달돼 창이 열린 사건 — macOS 자동화에서
    blind 키 전송 금지. 이후 스크롤 대신 카드 토글로 검증 경로를 바꿨다
15. 검증: `swift build` OK(신규 경고 0) + `scripts/test.sh` **183개/22스위트 통과**
16. 문서: CHANGELOG(⑨ + 버그 항목) · TODO T-277/277b/278 · PLAN · DESIGN §14 · AGENTS 테스트 수
17. 스크린샷: `docs/images/dashboard/dashboard-insight.png`
18. 남음: T-278 카드 On/Off 설정 UI(P3) · T-276 ② 카드 하단 여백
19. 커밋·푸시 없음 (Conservative 프로필)
