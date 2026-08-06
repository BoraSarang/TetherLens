# AGENTS.macos.md — TetherLens macOS 플랫폼 특화 에이전트 가이드

> **적용 범위**: TetherLens macOS 앱 (Swift Package Manager 기반)
> **읽기 순서**: 공통(`~/.config/opencode/AGENTS.md`) → `AGENTS.local.md` → **이 파일(AGENTS.macos.md)**
> **버전**: v1.0.0-macos (2026-08-06) — v0.23.1 구조 정리 시점

---

## 1. 플랫폼 구성

| 항목 | 값 |
|------|-----|
| 언어/스택 | Swift 6, AppKit + SwiftUI 혼용 |
| 빌드 | SwiftPM (`Package.swift`) — **Xcode 프로젝트 직접 수정 금지** |
| 최소 버전 | macOS 14.0 |
| 데이터베이스 | SQLite via GRDB (`Sources/TetherLens/Services/DataStore.swift`) |
| 제품 유형 | `.executableTarget` + `.testTarget` (Swift Testing) |

## 2. 빌드/실행 표준

```bash
./build_and_run.sh debug macos     # 디스패처 → scripts/build-macos.sh
./build_and_run.sh release macos   # 릴리스 (strip + 코드 서명)
./scripts/build-macos.sh debug     # 실제 빌드 로직 (스킵 금지, 디스패처 경유 권장)
./scripts/test.sh                  # 자동화 테스트 (32개 / 7스위트)
./scripts/package.sh               # 배포 패키징 (해당 시)
```

- `scripts/build-macos.sh`가 번들 생성 · 코드 서명 · 앱 실행까지 담당
- 디버그 빌드에서 `DebugPanel` ON (Cmd+D 토글)

## 3. Info.plist 단일 관리 (필수)

- **위치**: 루트 `Resources/Info.plist` — 유일한 원본
- `scripts/build-macos.sh`가 이 파일을 번들 `Contents/Info.plist`로 복사함
- **버전 갱신 시 반드시 `Resources/Info.plist`만 수정** (다른 위치에 사본 만들지 않기)
  - `CFBundleShortVersionString` / `CFBundleVersion` 동시 갱신
  - 예: v0.23.1 / build 24
- `Resources/TetherLens.entitlements`, `Resources/TetherLens.icns`도 이 폴더에서 관리
- 유지 항목: `SUFeedURL`, `SUPublicEDKey` (Sparkle), `CFBundleIconFile`, `LSUIElement`

## 4. 테스트 표준

- 위치: `Tests/TetherLensTests/` (Swift Testing)
- 실행: `./scripts/test.sh` — 현재 32개 테스트 / 7개 스위트
  (DataStore, ProfileManager, SavingModeManager, SettingsManager, SystemProcesses, HotspotDetector, Localized)
- 코드 수정 후 반드시 `swift build` + `./scripts/test.sh` 통과
- GUI/네트워크 의존 항목(메뉴바, 핫스팟 실측, 절약모드 hosts 차단)은 수동 확인
  (`docs/tests/v0.21.0_macos.md` 체크리스트 참조)

## 5. 문서 구조 (macOS)

| 파일 | 역할 |
|------|------|
| `docs/PRD.md` | 제품 요구사항 |
| `docs/DESIGN.md` | 기술 설계 (아키텍처/데이터 흐름/디자인 시스템) |
| `docs/PLAN.md` | 로드맵 (버전 이력 + 최신 plans/ 참조) |
| `docs/TODO.md` | 작업 추적 (bd 우선, 보조 참조) |
| `docs/CHANGELOG.md` | 변경 이력 (`[macOS]` 태그) |
| `docs/plans/PLAN_v{버전}_macos.md` | 버전별 계획 |
| `docs/tests/v{버전}_macos.md` | 버전별 테스트 |
| `docs/screenshots/macos/` | 스크린샷/덤프 |
| `Resources/Info.plist` | 앱 번들 정보 (단일 원본) |

## 6. 규칙 요약

- 문서 우선: 코드 수정 전 `docs/plans/PLAN_v{버전}_macos.md` 작성 → `docs/TODO.md` T-번호 → 코드
- 커밋: `feat(macos)`, `fix(macos)`, `chore(macos)`, `docs(macos)` + T-번호 참조
- 변경 요약/추론/문서는 한국어 (코드 주석·로그는 영어 허용)
- 에러코드 필요 시 `E-MAC-{CAT}-{NNNN}` 체계 (`error_message_ko.json`에 매핑)
- 디자인 토큰: `Sources/TetherLens/DesignSystem/Theme.swift` (TLPalette/TLFont/TLSpace/TLRound/TLSize) — 뷰 하드코딩 값 금지
- 파괴적 변경 가드: `Resources/Info.plist` 권한 항목, entitlements, DB 스키마 마이그레이션(v1~v8) 변경 시 사용자 확인 필수

## 7. 롤백

- 커밋 단위가 뷰/기능별로 분리되어 `git revert`로 부분 복구
- 앱: `pkill TetherLens` 후 `./scripts/build-macos.sh debug` 재실행
