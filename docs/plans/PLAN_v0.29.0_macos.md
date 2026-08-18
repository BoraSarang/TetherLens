# PLAN v0.29.0 — 맥 앱 전면 리디자인 (Phase 1: 구조 + Phase 2: 디자인 시스템)

- **버전**: v0.29.0 (build 29)
- **플랫폼**: [macOS]
- **작성일**: 2026-08-15
- **상태**: 승인됨 (사용자 확정: 별도 윈도우 전환 / 메뉴바 아이콘+숫자 병행 / Phase 1~2 먼저)
- **스킬**: macos-app-design / ios-the-final-5-percent / apple-design

---

## 1. 개요

### 1.1 배경
- 전면 UI 조사 완료 (2026-08-15). 목표: "대충 봐서 맥 스럽고, 아.. 맥 앱이구나.." 느낌.
- 핵심 문제: ① 메뉴바가 유니코드 ▲▼ + NSTextField 수동 배치 ② 팝오버 위 시트 9종 + `Settings { EmptyView() }` ③ material 0건 ④ 하드코딩 색/radius/폰트 다수 ⑤ `onTapGesture`+수동 커서 남용

### 1.2 목표 (이번 범위 = Phase 1~2)
1. **구조(Phase 1)**: 메뉴바 SF Symbol 아이콘+숫자 병행 / 설정·리포트·앱트래픽·알림·정보 → 별도 Window / 팝오버 320pt 슬림 대시보드화 / 온보딩 타이틀 Localized
2. **디자인 시스템(Phase 2)**: TLPalette Display P3 브랜드 팔레트 + on-color 토큰 / material 적용 / radius·폰트 토큰 일원화

### 1.3 범위 외 (다음 단계)
- Phase 3 화면별 정제 (NavigationSplitView 리포트, Form 그룹 설정 등)
- Phase 4 DebugPanel/진단 창, Phase 5 모션

---

## 2. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|------|------|
| 시트→윈도우 | 설정(`Settings` scene, Cmd-,) · 리포트 · 앱트래픽 · 알림 · 정보 → 별도 Window. DNS/프로필/절약모드는 팝오버 내 유지 |
| 메뉴바 | SF Symbol 템플릿 아이콘 + 속도/사용량 숫자 텍스트 병행 (전력 추적 유지) |
| 진행 방식 | Phase 1~2 먼저 구현 → 검증 → 이후 Phase 3~5 |
| 팔레트 | TLPalette → Display P3 브랜드 4색 + on-color 토큰 추가, OKLCH 설계 |
| 모션 | Phase 5에서 도입 (이번 범위 제외) |

---

## 3. 구현 단계

### 3.1 Phase 2-1 — Theme.swift 브랜드 팔레트 (T-155)
- `upload`/`download`/`success`/`danger` → `Color(.displayP3, red:…)` 4종
- `onUpload/onDownload/onSuccess/onDanger` on-color 토큰 추가 (배너 `.white` 교체용)

### 3.2 Phase 1-1 — MenuBarManager 메뉴바 아이콘+숫자 (T-156)
- 유니코드 ▲▼ → SF Symbol `arrow.up`/`arrow.down` 템플릿 아이콘, `isTemplate = true`
- MenuBarView 배치: 아이콘 1열 + 속도 1열 + 사용량/잔여 1열 (2줄), 폭 계산 안정화

### 3.3 Phase 1-2/1-3 — App.swift Window scene (T-157)
- `Settings { SettingsView() }` 교체 (EmptyView 제거)
- `Window("사용량 리포트"/"앱 트래픽"/"알림 목록"/"정보")` scene 추가 + `.unified` + `openWindow`

### 3.4 Phase 1-4 — PopoverView 슬림화 (T-158)
- 폭 280→320, 패딩 16→20, More 메뉴 항목 → `openWindow(id:)`, 시트 제거

### 3.5 Phase 1-5 — AppDelegate 온보딩 (T-159)
- `window.title` → `Localized`, 340×420 유지

### 3.6 Phase 2-2/2-3 — material/radius/폰트 토큰 (T-160)
- 팝오버 배경 `.regularMaterial`, hover `.label.opacity(0.06)`
- QoSGauge radius 4→6, HeatmapGrid 3/2→4, Diagnostics 8→10 → TLRound 경유

---

## 4. 파일 매핑

| 파일 | 작업 |
|------|------|
| `Sources/TetherLens/DesignSystem/Theme.swift` | P3 팔레트 + on-color + radius 토큰 보강 |
| `Sources/TetherLens/App/MenuBarManager.swift` | 메뉴바 아이콘+숫자, 폭 계산, openWindow 연결 |
| `Sources/TetherLens/App/App.swift` | Settings scene + Window scene 5종 |
| `Sources/TetherLens/Views/PopoverView.swift` | 320pt 슬림화, 시트 제거, More→openWindow |
| `Sources/TetherLens/Views/SettingsView.swift` | Settings scene 프레임 조정 |
| `Sources/TetherLens/App/AppDelegate.swift` | 온보딩 타이틀 Localized |
| `Sources/TetherLens/Views/QoSGauge.swift` | radius 토큰화 |

## 5. 테스트 계획

- `./scripts/test.sh` 43개 + 자동화 44개 통과
- `./scripts/build-macos.sh debug` 성공
- 6개 화면(팝오버/설정/리포트/앱트래픽/알림/정보) 스크린샷 + a11y-dump
- 다크/라이트·Reduce Transparency 확인
- TrafficMonitor acquire/release balance=0, nettop 잔여 스폰 없음 (v0.28.1 회귀 방지)
- `Cmd-,`·트래픽라이트·메뉴바 템플릿 착색 확인

## 6. 롤백 계획
- git revert + `./scripts/build-macos.sh debug` 재빌드
- Window scene 전환 시 팝오버 시트로 되돌릴 수 있도록 커밋 분리

## 7. 성능 예산
- 메뉴바 아이콘 합성: NSPaintCode 불필요, `NSImage(size:)`+draw → 스폰당 코스트 무시 가능
- Window scene 전환: 기존 팝오버 시트 대비 윈도우 오픈 코스트 유사
- material: `regularMaterial` 단일 — 성능 영향 무시 가능

## 8. 에러코드
- 신규 에러코드 없음 (UI 변경만)

## 9. 권한
- 변경 없음 (permissions 유지)

## 10. DoD 체크리스트
- [x] 문서 우선: 본 PLAN + TODO T-155~160
- [ ] 코드 수정 + DebugLogger 경유 로그
- [ ] test.sh / build-macos.sh debug 성공
- [ ] 스크린샷 6화면 + a11y-dump
- [ ] docs/CHANGELOG.md [macOS] 반영
- [ ] 커밋 + 릴리즈