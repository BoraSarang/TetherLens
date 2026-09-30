# PLAN — v0.39.0 대시보드 창 (Dashboard Window)

- **작성일**: 2026-09-27
- **플랫폼**: [macOS]
- **선행 감사**: 2026-09-27 전체 코드·문서 감사 (P0 2건·P1 5건 정합성 처리 완료)
- **참고 모델**: `/Users/lee/Documents/Apps/RelayConsole` 콘솔 대시보드
  (`Views/DashboardLayout.swift`, `Views/DroidDashboardView.swift`, `DesignSystem/Components.swift`)

---

## 0. 목적

메뉴바 팝오버의 `상세 보기` 토글로 열던 정보를 **대시보드 창 1개로 통합**한다.
팝오버는 요약 모드로 고정하고, 상세 정보는 전부 대시보드가 흡수한다.

### 배경 — 정보가 없는 게 아니라 컨테이너가 잘못됐다

| 문제 | 근거 |
|---|---|
| 상세 정보가 **180pt ScrollView**에 crammed | `PopoverView.swift:150-160` |
| 하위 행이 접혀 있어 2단 클릭 필요 | `expandedConnectionInfo`/`expandedAddressInfo` (A6~A8, B1·B5) |
| 3번째 스크롤 이후에 주요 섹션 | `detailSections` L297/L301/L304 |
| 6개 인사이트가 **차트 탭 진입 시에만** 계산 | `UsageReportView.swift:367-370` (`viewMode == .chart` 조건) |
| 같은 정보가 7개 표면에 분산 | 팝오버·플로팅·Window 5개·Diagnostics |

### 선행 결정 (2026-09-27 사용자 확정)

1. **`usageReport` 리포트는 유지** — 대시보드는 **신규 Window**로 만든다. ⌘1은 리포트에 남긴다.
2. **팝오버 `상세 보기` 토글 제거** — 요약 모드 고정, 상세는 대시보드로 통합
3. **P0 + P1 함께 구현** (인사이트·통계 카드인 P2는 다음 세션)

### 신규 단축키

| 키 | 대상 | 비고 |
|---|---|---|
| **⌘5** | 대시보드 | ⌘1~⌘4가 기존 창이라 5 사용. ⌘D는 ⌘⇧D(디버그 패널)와 혼동 위험으로 채택하지 않음 |

---

## 1. 레이아웃 (RelayConsole 패턴)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ ● TetherLens  집 (iOS 핫스팟) · −48dBm      1:23:45   ⟳ 갱신 3초 전      │ 고정
├────────────────────────────────────────────────────────────────────────────┤
│ ⚠  한도 소진 예상 21:40 · 끊김                              [×] 5초      │ 조건부
├────────────────────────────────────────────────────────────────────────────┤
│  오늘 사용량     │  업로드      │  다운로드     │  남은       │  오늘 세션   │ 전폭 KPI
│  4.62 / 30 GB   │  820 MB      │  3.80 GB     │  25.4 GB    │  1:23:45    │
│  ▓▓▓░░░ 15%     │  오늘 8%     │  오늘 92%    │  15% 남음   │  4회 연결   │
├───────────────────────────────┬────────────────────────────────────────────┤
│ ① 실시간 속도                  │ ② 연결 품질                                │
├───────────────────────────────┼────────────────────────────────────────────┤
│ ③ 할당량 & 예측                │ ④ 시스템                                   │
├───────────────────────────────┴────────────────────────────────────────────┤
│ ⑦ 연결 상세 (전폭)                                                      │
├────────────────────────────────────────────────────────────────────────────┤
│ ⚙설정  🌐진단  📊리포트  🔔알림 3  ⏻                          ⟳ 대시보드  │ 고정
└────────────────────────────────────────────────────────────────────────────┘
```

**카드 순서 = `DashboardLayout.swift` 단일 진실원처** (RelayConsole `DashboardLayout.swift:16-27` 동일 구조).
2열 `rows` + 전폭 `wideCards`. 행 안 카드는 `Grid`+`GridRow`+`maxHeight: .infinity`로 높이 동기화
(`LazyVGrid`은 행 높이 제어가 불가 — RelayConsole `DroidDashboardView.swift:115-146` 주석 근거).

| Phase | 카드 | 상태 |
|---|---|---|
| P0 | 상태바 · KPI 5종 · ① 실시간 속도 | 이번 세션 |
| P1 | ② 연결 품질 · ③ 할당량&예측 · ④ 시스템 · ⑦ 연결 상세 · 배너 · 진입점 4곳 | 이번 세션 |
| P2 | ⑤ 눈여겨볼 점(인사이트 6종) · ⑥ 오늘 사용 패턴(24시/8일/세션) | 다음 세션 |
| P3 | 카드 On/Off 토글 · 더보기 배선 · 안 B(사이드바) 전환 판단 | 미정 |

---

## 2. 파일 구조

| 파일 | 역할 | Phase |
|---|---|---|
| `Views/DashboardLayout.swift` | 카드 enum + `rows`/`wideCards`/`ordered` — 순서 단일 진실원처 | P0 |
| `Services/DashboardStore.swift` | `@MainActor` 단일 스냅샷 + 60초 DB 집계 + acquire/release | P0 |
| `Views/DashboardView.swift` | 상태바/배너/KPI/그리드/푸터 | P0 |
| `Views/DashboardCards.swift` | 카드 ①②③④⑦ + KPI + 상태바 서브뷰 | P0·P1 |
| `App/App.swift` | `Window(id: "dashboard")` 등록 + ⌘5 | P0 |
| `App/MenuBarManager.swift` | 우클릭 "대시보드" 항목 | P1 |
| `Views/PopoverView.swift` | `상세 보기` 토글 제거, `detailSections` 제거 | P1 |
| `Tests/TetherLensTests/DashboardLayoutTests.swift` | `rows` 행 구성·순서 순수 함수 테스트 | P0 |

**재사용 자산 (신규 없음)**: `MetricCard` · `TLSparkline` · `TLShareBar` · `TLGaugeBar` · `TLCoreBars` ·
`SystemMetricsCards` · `TLNetworkSpeedChart` · `QoSGauge` · `HoverRow` · `TLPalette/TLFont/TLSpace/TLSize`

---

## 3. 성능 설계 (감사에서 확인된 이 앱의 리스크를 반복하지 않기)

| 감사 리스크 | 대시보드 대응 |
|---|---|
| 팝오버 1Hz tick이 body 전체 재렌더 | **`DashboardView`는 어떤 `@Published`도 관찰하지 않는다.** 카드가 자기 것만 관찰 |
| body 평가마다 동기 N+1 DB 쿼리 | `DashboardStore`가 60초 주기로 1회만 집계 → 단일 스냅샷 1회 대입 |
| `@Published` insert+trim 2중 대입 | 스냅샷은 불변 복사 후 1회만 대입 |
| `objectWillChange` 광역 구독 | 카드별 최소 구독. 헤더/②/⑦은 자체 좁은 타이머 |
| `DateFormatter` 반복 생성 | 전 카드 `private static let` |
| 메인 스레드 DB | `DashboardStore.refresh()`는 1회만 호출. 창이 백그라운드면 타이머 정지 |

### 갱신 주기 계층화

```
[DashboardView]  데이터 관찰 없음 — 레이아웃 전용
[DashboardStore]  60초  DB 집계 (프로필·오늘 사용량·할당량·오늘 세션)
[① SpeedCard]      1초   @ObservedObject NetworkMonitor (기존 단일 스냅샷)
[④ SystemCard]    10초   SystemMetricsCards 자체 구독 (기존)
[StatusClock]      1초   자체 타이머 — 세션 경과·상대 시각만. 카드 전체를 리렌더하지 않음
[② QualityCard]    5초   자체 타이머 — PingMonitor 비발행 값
[⑦ DetailCard]     5초   자체 타이머 — HotspotDetector 비발행 값
```

### 5분류 상태 강제 (RelayConsole `AGENTS.local.md:55-59`)

`정상` / `경고` / `미측정(—)` / `권한 없음` / `미연결` — **측정 실패를 "정상"으로 표시하지 않는다.**
감사에서 `PingMonitor`·`TrafficMonitor`가 무응답 시 이전 값을 정상으로 보여주는 문제가 확인됐으므로
`nil` 은 반드시 `Localized`-기반 `—` 로 표기한다.

---

## 4. UI/UX 원칙 (RelayConsole 이식)

1. 카드 순서·행 구성은 **뷰 코드가 아닌 enum 파일**에 둔다 (RelayConsole 원칙 1)
2. `Grid`+`GridRow` — `LazyVGrid` 금지, 행 높이 동기화 (원칙 2)
3. 전폭 카드는 `wideCards`로 분리 (원칙 3)
4. **값 없는 지표는 0으로 그리지 말고 표시하지 말 것** (원칙 5)
5. 헤더에 **마지막 갱신 시각** 고정 표기 (원칙 6)
6. 카드 → 상세는 **기존 창으로 "더보기"만** 배선. **새 창을 만들지 않는다** (원칙 6)
7. 상태는 **색 + 텍스트 병기** (색맹 대비, `DESIGN.md:42-45` 대비 10:1)
8. 텍스트 항상 선명 — 배경만 투명도 (`MetricCard.backgroundOpacity` 재사용)

---

## 5. 진입점 4곳

| 경로 | 구현 |
|---|---|
| ⌘5 | `AppShortcuts.register("cmd+5")` |
| 메뉴바 우클릭 | `MenuBarManager.showMoreMenu()` 맨 위 |
| 팝오버 하단 | 버튼 추가 |
| 커맨드 팔레트 | 항목 추가 |

---

## 6. DoD

- [ ] `swift build` 성공 (신규 경고 0)
- [ ] `scripts/test.sh` 통과 (기존 142개 + 신규)
- [ ] `DashboardLayoutTests` 통과 (`rows` 행 구성)
- [ ] 팝오버에서 `상세 보기` 토글·`detailSections` 완전 제거
- [ ] ⌘5 / 우클릭 / 팝오버 / 팔레트 4개 진입점 동작
- [ ] `DashboardView`가 `@Published`를 관찰하지 않음 (코드 리뷰로 확인)
- [ ] CHANGELOG [Unreleased] · TODO T-255~ · PLAN 갱신 · 세션 로그
- [ ] DebugPanel ERROR 0 (수동 — T-249와 함께)
