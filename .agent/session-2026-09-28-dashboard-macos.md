# session-2026-09-28-dashboard-macos (v0.39 대시보드 8칸 · GUI 검증)

1. 이어서 작업: 대시보드 셀을 **8칸(4행×2열)** 로 재구성 — CPU·GPU·RAM 개별 분리 + 프로세스 리스트 추가
2. 사용자 요구: "넣을 수 있는 거 다 넣어서 cpu/gpu/ram 추가하고 모자라면 프로세스 리스트까지 꽉 채워"
3. `DashboardLayout` 재작성 — 8카드(`speed`/`quality`/`quota`/`pattern`/`cpu`/`gpu`/`memory`/`process`), rows 4행
4. 신규 카드 4종: `DashboardCpuCard`(load·게이지·코어바·스파크·Top3) · `DashboardGpuCard` · `DashboardMemoryCard`(압력색) · `DashboardProcessCard`(CPU/MEM/NET 12행 스크롤 + 더보기)
5. 신규 카드 1종: `DashboardPatternCard` — 24시 구간 막대 + 최근 8일 스파크 + 합계/일평균. `DashboardStore`에 `hourBuckets`·`dailyTotals` 추가
6. `MetricCard.fillsRow` 신설 (RelayConsole `DroidCards.shell(fillsRow:)` 이식) — 기존 3-in-1 `SystemMetricsCards`는 ⑤⑥⑦로 해체
7. **GUI 검증 3건 발견·수정** (스크린샷 기반 실측):
   ① `Grid`/`GridRow` 이 자식의 `maxHeight:.infinity` 를 확장하지 않음 → **`HStack(alignment:.top)` 로 교체**. PLAN/RelayConsole 이식이 실측에서 뒤집힘
   ② `fillsRow` 프레임을 배경 **뒤**에 붙여 배경을 늘리지 못함 → **앞으로 이동**. 추가로 content 뒤 `Spacer` 로 남는 공간 흡수(제목이 가운데로 밀리던 문제 해결)
   ③ ① 카드의 Top3 값이 **구간 합계**로 표시(5.0MB) → "실시간 속도" 카드에 맞게 **초당 환산**(5.0MB/s). `AppTraffic` 값은 측정 구간(≈interval) 합계
8. 빈 여백을 장식이 아닌 실제 데이터로 채움 — ②에 정상응답/미해소경고/자동화 칩, ③에 8일 평균 대비 배율 + 최근 8일 합계/일평균
9. 8칸 렌더 확인: 상태바·KPI 5종·8카드·푸터 모두 정상. 행 높이 동기화 동작. CPU 게이지 0%는 정상(상위 프로세스 0.9%/10코어, load 4.56은 과거 포함 지표)
10. 남은 ② 카드 하단 여백은 장식 금지 원칙에 따라 값 있는 정보가 추가될 때만 채움(T-276)
11. 테스트 29개(`DashboardLayoutTests`) — 8칸/4행 검증 + 시간대 버킷 포함. **171개/22스위트 통과**
12. 문서: CHANGELOG(8칸 표 + GUI 3건) · TODO T-264~279 · PLAN 진행중 · **DESIGN §14.3.1 행높이 동기화(실측)** · AGENTS 테스트 수
13. 스크린샷: `docs/images/dashboard/dashboard-8cells.png`
14. 검증: `swift build` OK(신규 경고 0) + `scripts/test.sh` 171개 통과 + `build-macos.sh debug` 실행 확인
15. 큐: bd TetherLens-7xd(P0)/89f(P1) 은 09-27에 close. 8칸 확장은 T-264c~264e 로 기록
16. E2E: 해당 없음. 남은 GUI 항목 T-276(여백)만 수동
17. 커밋·푸시 없음 (Conservative 프로필)
