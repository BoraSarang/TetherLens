# PLAN v0.35.1 — 팝오버 빠른 복사 (macOS)

> bd: TetherLens-te5 / 상태: 진행 중 / 작성: 2026-09-11

## 1. 문제
- 간략 보기(기본값 `popover_summary_mode=true`)에서 외부/내부 IP 복사 불가.
- 복사까지: 상세 보기 토글 → 스크롤 → IP 행 클릭 3단계.

## 2. 결정 (사용자 선택)
- **A+B안**: 상태행 우측 외부 IP 칩 + 우클릭 메뉴. 범위: 외부+내부 IP 우선 (+게이트웨이/SSID/BSSID 메뉴).

## 3. 변경
- `Views/PopoverView.swift`
  - `statusRow`: `HStack { 도트+상태 | Spacer | 외부IP 칩 }` + `.contextMenu` (외부/내부/게이트웨이/SSID/BSSID 복사).
  - `detailRow` 복사 4줄 → `copyToPasteboard(_:source:)` 헬퍼로 추출, 칩·메뉴·기존 행이 공유. 기존 `copiedBanner` 재사용.
  - 외부 IP nil → `—` + 비활성화. IPv6 길면 middle-truncate.
  - `[ACTION] [UI] 빠른 복사` 로그 1개 (`[INFO] [FEATURE] QuickCopy`).
- `Utils/Localized.swift`: 메뉴 문구 5개 (`외부 IP 복사` 등 한/영).

## 4. 하지 않는 것
- 전역 단축키, 메뉴바 아이콘 클릭 복사, 진단 리포트 메뉴, IPHistory 행 복사는 후속.

## 5. 검증
- `./build_and_run.sh debug macos` 성공, DebugPanel ERROR 0.
- 수동: 간략 보기 칩 1클릭→붙여넣기, 우클릭 5항목, nil/IPv6/오프라인 케이스.
- `./scripts/test.sh` 통과 (신규 자동 테스트 없음, GUI 영역).
