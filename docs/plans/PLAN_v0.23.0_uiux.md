# PLAN v0.23.0 — 디자인 시스템 도입 + 팝오버 UI/UX 재설계

- **버전**: v0.23.0 (build 23)
- **플랫폼**: [macOS]
- **작성일**: 2026-08-06
- **상태**: 승인됨 (사용자 확정: 전체 토큰화 / 팝오버 통합 진행 / DesignSystem/Theme.swift)

---

## 1. 개요

### 1.1 배경
- 팝오버가 280px 폭에 10개 섹션이 세로로 쌓여 **정보 과부하** 상태. 핵심 데이터(속도·잔여·QoS)가 중하단에 묻힘
- 모든 섹션이 동일한 `─── 제목 ───` 구분자로 **시각적 위계 없음**
- 폰트 크기 8/9/10/11 + semantic 혼용(90+곳), 간격/모서리/시트 폭 난립 → 디자인 토큰 부재

### 1.2 목표
1. **디자인 시스템(토큰) 도입** — 폰트/색상/간격/모서리/시트·라벨 폭 전역 토큰화
2. **팝오버 2단 레이어 재설계** — 요약(기본)/상세 토글, 섹션 위계 차별화
3. 정보 위계 정립 → 사용자 시나리오(핫스팟 데이터 확인)에서 최우선 정보를 상단에

---

## 2. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|------|------|
| 토큰 범위 | 폰트·색상·간격·모서리·시트/라벨 폭 **전체 토큰화** |
| 파일 위치 | `Sources/TetherLens/DesignSystem/Theme.swift` (신규 폴더) |
| 진행 방식 | Theme.swift 생성 → 팝오버 재설계(P0)와 통합 → 나머지 뷰 치환 |
| 전환 UI | 하단 "상세 보기 ▾ / 요약 보기 ▴" 토글 버튼, `@AppStorage("popover_summary_mode")`로 상태 기억, **기본 = 요약** |
| 경고 배너 | 핑/할당량/복사 배너는 **상단 고정** (요약·상세 공통) |

---

## 3. 디자인 시스템 설계 (Theme.swift)

### 3.1 토큰 스키마

```swift
import SwiftUI

enum TLPalette {          // 색상 (다크모드 대응 위해 시스템 색 래핑)
  static let upload   = Color.orange                    // 업로드/핫스팟/경고
  static let download = Color.blue                      // 다운로드
  static let success  = Color.green                     // 복사 성공/핑 회복
  static let danger   = Color.red                       // 핑 임계/종료
  static let accent   = Color.accentColor               // 강조/링크
  static let textPrimary   = Color.primary
  static let textSecondary = Color.secondary
  static let copyHint      = Color.secondary.opacity(0.4) // 복사 아이콘
  static let separator     = Color(nsColor: .separatorColor)
}

enum TLFont {             // 폰트 스케일 (semantic + 고정 스케일)
  static let badge       = Font.system(size: 8)                  // 알림 배지
  static let badgeMono   = Font.system(size: 8, design: .monospaced)
  static let small       = Font.system(size: 9)                  // 복사 아이콘/헬퍼
  static let smallBold   = Font.system(size: 9, weight: .bold)   // 테이블 헤더
  static let medium      = Font.system(size: 10)                 // 테이블 본문
  static let mediumMono  = Font.system(size: 10, design: .monospaced)
  static let detail      = Font.system(size: 11, weight: .bold)  // detailRow 라벨/값
  static let caption     = Font.caption                          // 부가 설명
  static let caption2    = Font.caption2                         // 구분자/최소
  static let body        = Font.body
  static let headline    = Font.headline                         // 시트 제목
  static let speed       = Font.system(.title3, design: .monospaced) // 속도 값
}

enum TLSpace {            // 간격
  static let xs: CGFloat = 4
  static let sm: CGFloat = 6
  static let md: CGFloat = 8
  static let lg: CGFloat = 10
  static let xl: CGFloat = 12
  static let xxl: CGFloat = 16
  static let inset: CGFloat = 16    // 팝오버 인셋
}

enum TLRound {            // 모서리
  static let small: CGFloat = 6
  static let medium: CGFloat = 10
}

enum TLSize {             // 시트/표준 폭
  static let popoverWidth: CGFloat = 280
  static let sheetCompact: CGFloat = 280   // 팝오버/프로필/DNS/IP히스토리/알림
  static let sheetStandard: CGFloat = 320  // 설정/절약/트래픽
  static let sheetWide: CGFloat = 640      // 사용량 리포트
  static let detailLabelWidth: CGFloat = 96   // detailRow 라벨
  static let trafficUploadCol: CGFloat = 62
  static let trafficDownloadCol: CGFloat = 68
}
```

### 3.2 치환 매핑 (현행 → 토큰)

| 현행 | 토큰 | 대상 |
|------|------|------|
| `.system(size: 8)` | `TLFont.badge` | 알림 배지 |
| `.system(size: 9)` | `TLFont.small` | 복사 아이콘/헬퍼 텍스트 |
| `.system(size: 9, weight: .bold)` | `TLFont.smallBold` | 앱트래픽 헤더 |
| `.system(size: 10)` | `TLFont.medium` | 앱트래픽 값 |
| `.system(size: 11, weight: .bold)` | `TLFont.detail` | detailRow |
| `.orange`(업로드/경고) | `TLPalette.upload` | — |
| `.blue`(다운로드) | `TLPalette.download` | — |
| `.green`/`.red` | `TLPalette.success`/`.danger` | — |
| `Color(nsColor: .separatorColor)` | `TLPalette.separator` | 구분자 |
| `.cornerRadius(6)` | `TLRound.small` | 배너 |
| `frame(width: 280)` | `TLSize.popoverWidth` | 팝오버 |
| `frame(width: 260)` | `TLSize.sheetCompact` | DNS 피커 |
| `padding` 6/12/16 | `TLSpace.sm/xl/xxl` | — |

---

## 4. 팝오버 재설계 (PopoverView.swift)

### 4.1 상태
```swift
@AppStorage("popover_summary_mode") private var summaryMode = true
```

### 4.2 레이아웃 — 요약 모드 (기본)
```
[앱아이콘] [연결명]              [🔔] [📌] [●]      ← headerView
(배너: 핑/할당량/복사 — 있으면 상단 고정)          ← bannerStack
▲ 2.3 MB/s           ▼ 5.1 MB/s                   ← speedView (강조)
[▓▓▓▓▓▓▓▓░░░░]  68% · 잔여 0.9GB                  ← qosGaugeBody
─────────────────────────────
[상세 보기 ▾]             [더보기 ⋯] [종료]        ← bottomButtons
```
- 할당량 미설정 시: 게이지 자리에 **"할당량 설정" 버튼** (프로필 있으면 편집, 없으면 프로필 관리)

### 4.3 레이아웃 — 상세 모드 (토글 시 확장)
```
[앱아이콘] [연결명]              [🔔] [📌] [●]      ← headerView
(배너 상단 고정)                                  ← bannerStack
▲ 2.3 MB/s           ▼ 5.1 MB/s
[▓▓▓▓▓▓▓▓░░░░]  68% · 잔여 0.9GB
────── 연결 정보 ──────  (collapsible, ⓧ 기존 유지)
유형 / 세션 / 네트워크 / BSSID / (확장 시 규격/채널/링크속도)
────── 연결 주소 ──────  (collapsible)
게이트웨이 / 로컬IP / 외부IP / DNS(chevron 단서) / 핑
── 프로세스별 트래픽 ──  (showAppTraffic && !empty)
미리보기 3개 + 더보기
─────── 프로필 ────────
현재 프로필 + 통계/편집 + 프로필 관리
─────────────────────────────
[요약 보기 ▴]             [더보기 ⋯] [종료]
```

### 4.4 섹션 위계 (상세 모드)
- **주요**: 프로필, 프로세스별 트래픽 → 기존 `── 제목 ──` 유지 (강조)
- **부가**: 연결 정보, 연결 주소 → 기존 `collapsibleSectionDivider` (접힘 기본, chevron)

### 4.5 UX 세부
1. **배너 상단 고정**: quota/ping/copied 3종 배너를 `headerView` 아래 공통 영역으로 이동 (중간 삽입 제거 → 레이아웃 시프트 감소). 공통 컴포넌트 `bannerStack` 분리
2. **할당량 미설정 → 설정 버튼**: `noQuota` 텍스트 대신 "할당량 설정" 버튼 (프로필 있으면 `editingProfile`, 없으면 `showProfileManager`)
3. **DNS 행 chevron 단서**: DNS detailRow 값 옆에 `chevron.right` (클릭 가능 명시)
4. **요약/상세 토글**: bottomButtons에 첫 버튼으로 추가 (`.bordered`, chevron ▾/▴)

### 4.6 구조 변경 요약
```swift
var body: some View {
  mainContent
    .sheet(...) // 시트 10개 기존 유지
}

private var mainContent: some View {
  VStack(spacing: TLSpace.xl) {
    headerView
    bannerStack                       // 신규 (배너 3종 상단 고정)
    speedView
    qosGaugeBody
    if !summaryMode { detailSections } // 신규 분리
    Divider()
    bottomButtons                     // 상세/요약 토글 추가
  }
  .padding(TLSpace.inset)
  .frame(width: TLSize.popoverWidth)
  // Timer/onReceive/onAppear 기존 유지
}

@ViewBuilder private var detailSections: some View {
  collapsibleSectionDivider(연결 정보, $expandedConnectionInfo)
  connectionInfoView
  collapsibleSectionDivider(연결 주소, $expandedAddressInfo)
  connectionAddressView
  if showAppTraffic, !trafficMonitor.apps.isEmpty {
    trafficSectionDivider
    appTrafficPreview
  }
  sectionDivider(Localized.profile)
  profileSection
}
```

---

## 5. 나머지 뷰 토큰 치환 (점진)

치환 순서 (파일별 1커밋):
1. `UsageReportView.swift` — 9px/10px/`caption` 난립 최다
2. `SettingsView.swift` — 8px 진단 텍스트 + 슬라이더 간격
3. `AppTrafficView.swift`, `SavingModeSheet.swift`
4. `ProfileEditorView.swift`, `HeatmapGridView.swift`, `DebugPanelView.swift`
5. `SessionTimelineView.swift`, `AboutView.swift`, `NotificationListView.swift`, `IPHistoryView.swift`, `ConnectionDetailView.swift`, `HeatmapMapView.swift`, `OnboardingView.swift`

- 시트 폭: `TLSize.sheetCompact/Standard/Wide` 적용 (레이아웃 회귀 방지 위해 변경 시 해당 파일에서 시각 확인)
- 단, **시트 폭 값 자체는 현행 유지** (토큰으로 대입만) — 폭 숫자 변경은 회귀 위험 있어 이번 버전에서 보류

---

## 6. 테스트 계획

| TC | 검증 항목 | 방법 |
|----|-----------|------|
| TC-01 | 요약 모드 기본 열림 + 속도/게이지 표시 | 수동 (팝오버 열기) |
| TC-02 | 상세/요약 토글 + 상태 유지 (앱 재시작 후에도 마지막 모드) | 수동 |
| TC-03 | 할당량 미설정 프로필 → "할당량 설정" 버튼 동작 (편집/관리) | 수동 |
| TC-04 | DNS 행 chevron 단서 + 클릭 → DNS 프리셋 시트 | 수동 |
| TC-05 | 핑/할당량/복사 배너가 상단 고정 + 5초 후 자동 해제 | 수동 |
| TC-06 | 상세 모드에서 연결/주소 접기/펼치기 동작 | 수동 |
| TC-07 | 토큰 치환 후 회귀 (다른 뷰 폰트/간격 정상) | 수동 + `swift test` |

- 자동화 테스트: 기존 32개/7스위트 유지 (UI 로직 변경 없음, 실패 없어야 함)
- 빌드: `build-macos.sh debug` 성공

---

## 7. 롤백 계획

- `Theme.swift`는 신규 파일 → 삭제 시 기존 코드 무영향
- 뷰 치환은 뷰별 개별 커밋 → `git revert <commit>`로 부분 복구
- 팝오버 재설계 롤백: `git revert` 후 `@AppStorage` 분기 제거 시 단일 레이아웃 복원
- 시트 폭은 값 변경 없음 → 레이아웃 회귀 시 별도 대응 불필요

---

## 8. 구현 단계 (T-번호)

| T# | 작업 | 산출물 |
|----|------|--------|
| T-79 | Theme.swift 생성 (토큰 전체) + Info.plist v0.23.0 | `DesignSystem/Theme.swift` |
| T-80 | PopoverView 요약/상세 2단 재설계 + 배너 상단 고정 | `PopoverView.swift` |
| T-81 | 팝오버 UX (할당량 설정 버튼, DNS chevron, 토글 버튼) | `PopoverView.swift` |
| T-82 | 팝오버 내 하드코딩 값 토큰 치환 | `PopoverView.swift` |
| T-83 | 나머지 뷰 토큰 치환 + 시트 폭 토큰화 (뷰별 커밋) | 13개 뷰 |
| T-84 | 검증 (테스트/빌드/수동) + 문서 (CHANGELOG/세션/TODO) | — |

## 9. 에러코드

- 신규 에러코드 없음 (기능 변경이 아닌 UI/UX 재구성)

## 10. 권한

- `manifest.json`/엔트이틀먼트 변경 없음 (macOS 앱, 권한 불변)

## 11. 성능 영향

- 요약 모드 기본 → 팝오버 렌더링 뷰 수 감소 (DetailRow 표시 줄어듦), tick 타이머 동일(1초)
- 성능 예산 영향 없음 (CPU 추가 작업 없음)
