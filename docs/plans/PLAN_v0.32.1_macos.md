# PLAN v0.32.1 — 플로팅 외곽 테두리 호버시에만 표시

- **버전**: v0.32.1 (build 33)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-09
- **상태**: 진행 중
- **이슈**: bd TetherLens-ix5
- **요청**: 플로팅 화면의 4각 테두리를 없앨 수 있나 → 호버시에만 표시로 합의

---

## 1. 개요

### 1.1 배경

- 플로팅 창(`FloatingWindowView`) 루트에 `RoundedRectangle.stroke(separatorColor, 1)` 오버레이가 상시 표시됨.
- 패널 자체는 이미 `.borderless` + `backgroundColor=.clear` + `hasShadow=true`라 윈도우 크롬이 아니며, 테두리는 순수 SwiftUI 장식임.
- 평소에는 그림자로만 구분하고, 마우스 호버 시에만 테두리를 보여줘 경계를 인지시키는 방향으로 변경.

### 1.2 목표

1. 평소 테두리 제거, `isHovering=true`일 때만 1pt 테두리 표시.
2. `fitToContent()` 실측 구조 유지 (루트 `Group` + `.background`, overlay 조건분기만 추가).
3. full/compact 레이아웃 모두 동일 동작.

### 1.3 범위 외

- 설정 토글 추가 없음 (이번은 무조건 호버 방식).
- 그림자(`hasShadow`) 변경 없음.
- 내부 디바이더·행 스타일 변경 없음.

---

## 2. 변경 설계

- **파일**: `Sources/TetherLens/Views/FloatingWindowView.swift:35-38`
- **변경 전**: `.overlay { RoundedRectangle(...).stroke(...) }` 무조건 표시
- **변경 후**: `.overlay { if isHovering { RoundedRectangle(...).stroke(...) } }`
- **상태 재사용**: 기존 `@State isHovering(:15)` + `.onHover(:60)` 그대로 사용, 신규 상태 없음.
- **레이아웃 안전성**: overlay 조건분기는 ideal size에 기여하지 않으므로 `fittingSize` 붕괴 없음 (v0.32.3 교훈 유지).

## 3. 검증

1. `./scripts/test.sh` (smoke+unit, 변경 파일 관련만 우선)
2. `./build_and_run.sh debug macos` 성공
3. 플로팅 표시 → 평소 테두리 없음 / 호버 시 테두리 나타남 / 해제 시 사라짐 확인
4. full(3칸) + compact(줄 전부 OFF) 모두 확인
5. DebugPanel ERROR 0

## 4. 문서

- `docs/CHANGELOG.md` Unreleased 또는 v0.32.1 항목 1줄
- `docs/TODO.md` v0.32.1 섹션 T-191 등록
- 세션 로그

---

## 5. 후속 v0.32.2 — Tahoe 글래스 엣지 제거 (2026-09-09, bd TetherLens-vie)

### 5.1 증상

- v0.32.1 적용·재실행 후에도 사용자가 "테두리가 없어지지 않았다"고 보고.
- 캡처 확대 결과: 둥근 스트로크(r=10)가 아닌 **직각의 선명한 선**이 창 경계에 잔류.

### 5.2 픽셀 측정 (ffmpeg rawvideo 샘플링)

- 수정 전 상단 엣지: 외곽 14 → 딥 5 → **피크 67** → 내부 24. 좌측 엣지 x 일정(직각, r=10 아님).
- 피크가 양쪽보다 밝음 = 그림자(감쇠만)가 아닌 발광성 하이라이트 → Tahoe 글래스 엣지.
- 일반 타이틀 창(설정 창) 가장자리에도 동일 림+선 존재 → 시스템 차원 처리.

### 5.3 진단 실험 (각각 빌드+캡처)

1. 머티리얼→단색 채우기 교체: 림 잔류(딥→피크 60) → 머티리얼 무죄.
2. `hasShadow=false`: 림 소실(외곽→내부 단일 계단) → **림은 그림자와 함께 렌더링되는 글래스 엣지** 확정.

### 5.4 최종 수정

- `FloatingWindowController.swift`: `hasShadow=false` (대가로 드롭 섀도우 없음).
- `FloatingWindowView.swift`: 머티리얼 원복 (블러 유지), 호버 스트로크 유지.
- 머티리얼+그림자OFF 캡처: 외곽 15 → 내부 23 단일 계단, 피크 없음. `swift test` 76개 통과.

---

## 6. 후속 v0.32.3 — 플로팅 모서리 16pt + 투명도 70% (2026-09-09, bd TetherLens-1xz)

### 6.1 요청

- 사용자: "직각이 아니라 원처럼 깎인 듯한 표현" → 모서리 16pt(은은하게) + 투명도 70%로 합의.
- 배경: 투명도 35%에서는 r=10 경계가 희미해 직각처럼 보임.

### 6.2 설계

- `FloatingWindowView` 배경+호버 스트로크 radius 10 → **24** (16pt로 1차 적용 후 캡처 확인했으나 패널 폭 대비 밋밋하다는 피드백으로 상향). `TLRound.medium`은 리포트 카드 등 10곳 공용이라 플로팅 전용 로컬 상수로 분리.
- 투명도는 코드 기본값이 아닌 저장값(`floatingOpacity`)이라 `defaults write`로 적용 (재실행 불필요, 설정 슬라이더와 동일 키라 동기화).
- `fitToContent` 영향 없음.

### 6.3 검증

- `swift build` + `swift test`(76개) + 재실행 캡처로 모서리 곡선 확인 (좌하단 큰 곡선 육안 확인).
- 사용자 확인: 투명도 슬라이더는 사용자가 직접 100%로 조정 (70% 적용 후 사용자가 상향).
