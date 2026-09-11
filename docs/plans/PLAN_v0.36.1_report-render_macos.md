# PLAN v0.36.1 — 리포트 미리보기 렌더링 (macOS)

> bd: TetherLens-ik3 / 상태: 진행 중 / 작성: 2026-09-11

## 1. 문제
- 리포트 탭 미리보기가 마크다운 원문을 mono 텍스트로 그대로 표시.
- `AttributedString(markdown:)`은 표(할당량·상위 앱 테이블)를 렌더하지 못하므로 부적합.

## 2. 방식
- 마크다운 파싱이 아닌 **요약 데이터(`ReportSummary`) 직접 네이티브 렌더링** (생성 스키마 고정이라 파싱 불필요, 깨질 여지 없음).
- 상단 세그먼트 토글: 렌더링 | 원문. 복사 버튼은 원문 MD 복사 유지.
- 표는 `Grid`, 섹션 제목·메타 행은 기존 TL 타이포/색상.

## 3. 파일
- 수정 `Views/ReportView.swift` (렌더 뷰 + 토글, 원문 뷰 유지)
- 수정 `Utils/Localized.swift` (렌더링/원문 문구 2개)
- `CHANGELOG [Unreleased]` 기록

## 4. 검증
- `swift build` + `./scripts/test.sh` (로직 변경 없음, 테스트 추가 없음)
- `./scripts/build-macos.sh debug` 후 육안 확인 + DebugPanel ERROR 0
