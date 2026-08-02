# Session: 영문 현지화 + SSID 별칭 + 세션 타임라인 + 핫스팟 히트맵

**날짜**: 2026-07-30
**목표**: 4개 기능 전면 구현
**브랜치**: `feat/ios-localization-all`

---

## 작업 순서

1. **Phase 0**: 인프라 — Localized.swift, Package.swift, Info.plist 버전 싱크
2. **Phase 1**: 영문 현지화 — PopoverView, ProfileEditor, Settings, About, SavingMode, UsageReport, OnboardingView
3. **Phase 2**: SSID 별칭 — Popover 헤더 profile.name, autoRegisterIfNeeded name 개선, ProfileEditor UI 분리
4. **Phase 3**: 세션 타임라인 — DB v5 마이그레이션(session_id FK), SessionTimelineView, UsageReportView 탭
5. **Phase 4**: 핫스팟 히트맵 — DB v5 위치 컬럼, 7×24 Grid, MapKit 뷰

---

## 변경 파일 목록

| 파일 | 상태 | 설명 |
|------|------|------|
| `Package.swift` | 수정 | `.resources: [.process("Resources")]` 추가 |
| `Sources/TetherLens/Info.plist` | 수정 | 버전 0.11.1, CFBundleLocalizations |
| `Resources/Info.plist` | 수정 | 버전 0.11.1, CFBundleLocalizations |
| `Sources/TetherLens/Utils/Localized.swift` | **신규** | ~100개 키 한/영 분기 enum |
| `Sources/TetherLens/Views/PopoverView.swift` | 수정 | ~45개 문자열 → Localized |
| `Sources/TetherLens/Views/ProfileEditorView.swift` | 수정 | ~12개 문자열 → Localized |
| `Sources/TetherLens/Views/SettingsView.swift` | 수정 | ~20개 문자열 → Localized |
| `Sources/TetherLens/Views/AboutView.swift` | 수정 | ~5개 문자열 → Localized |
| `Sources/TetherLens/Views/SavingModeSheet.swift` | 수정 | ~15개 문자열 → Localized |
| `Sources/TetherLens/Views/UsageReportView.swift` | 수정 | ~25개 문자열 → Localized + 히트맵/타임라인 탭 |
| `Sources/TetherLens/Views/OnboardingView.swift` | **신규** | 첫 실행 시 권한 안내 시트 |
| `Sources/TetherLens/Views/SessionTimelineView.swift` | **신규** | 세션 타임라인 브라우징 |
| `Sources/TetherLens/Views/HeatmapView.swift` | **신규** | 히트맵 컨테이너 (Grid + Map 탭) |
| `Sources/TetherLens/Views/HeatmapGridView.swift` | **신규** | 7×24 그리드 |
| `Sources/TetherLens/Views/HeatmapMapView.swift` | **신규** | MapKit 핀 뷰 |
| `Sources/TetherLens/Services/DataStore.swift` | 수정 | v5 마이그레이션 (session_id, lat/lng) |
| `Sources/TetherLens/Services/ProfileManager.swift` | 수정 | recordUsage sessionId, getSessionUsage, startSession 위치 |
| `Sources/TetherLens/Models/Session.swift` | 수정 | latitude, longitude 필드 추가 |
| `Sources/TetherLens/Models/UsageLog.swift` | 수정 | sessionId 필드 추가 |
| `Sources/TetherLens/App/App.swift` | 수정 | OnboardingView 시트 추가 |

---

## DB 마이그레이션 v5

```swift
m.registerMigration("v5_session_usage_link") { db in
    try db.alter(table: "usage_log") { t in
        t.add(column: "session_id", .text)
    }
    try db.create(index: "idx_usage_log_session", on: "usage_log", columns: ["session_id"])
    
    try db.alter(table: "session") { t in
        t.add(column: "latitude", .double)
        t.add(column: "longitude", .double)
    }
}
```

---

## 검증

- `./build_and_run.sh debug macos` 빌드 성공
- DebugPanel ERROR 0개
- PopoverView 열어서 모든 UI 문자열 영문/한글 확인
- 프로필 편집 → SSID 별칭 저장 후 Popover 헤더에 표시 확인
- 세션 기록 → 사용량 연결 확인
- 히트맵 Grid 표시 확인
