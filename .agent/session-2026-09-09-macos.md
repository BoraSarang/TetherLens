# 세션 로그 — 2026-09-09 (macOS) — v0.34 통계 재구축

## 무엇을
- v0.34 통계 재구축 1차분 (bd TetherLens-rqk, T-194~198):
  - DB v11: `daily_rollup`/`app_daily_rollup`/`insight_log` + backfill + 마이그레이션 전 자동 백업 (`data.sqlite.pre-v11-*`, 실DB 8MB 백업 확인)
  - StatsEngine: `(profile, period) → 스냅샷` 단일 진입점 + 인사이트 4종 (소진예측·주범·이상치·세션효율)
  - InsightsView: 리포트 창 최상단 병행 운영 (팝오버 시각 언어)
- 디버깅 기록: "인사이트 없음" 보고 → 실DB 직접 조회로 pace 발동 조건 확인(9.9GB/2GB) → 바이너리 바이트 검증 → 실DB 복사본 재현 테스트로 엔진 정상 확정(인사이트 3개) → 임시 빨간 마커로 렌더 확정(snap=3) → 마커 제거·최종 빌드
- 원인 추정: 중간 과정의 프로세스/윈도우가 구 코드 상태였음 (신규 프로세스+새 창에서 정상 렌더 확인)

## 플랫폼
- macOS (SwiftPM, GRDB, SwiftUI/Charts)

## 빌드 + PERF + CACHE
- swift test 89개 전체 통과 (2026-09-09 21:00 재확인: 기존 + v11 3 + StatsEngine 9)
- ./build_and_run.sh debug macos 성공 (21:00 재확인, DebugPanel ON)
- 실DB 8MB 마이그레이션 무손실 (backfill + EXACT 대조 테스트)
- PERF: 스냅샷 실DB 기준 0.1s 이하 (rollup 기반, 실측 0.095s). recordUsage 핫패스 쓰기 추가 없음
- CACHE 영향 없음

## 남은 TODO
- T-194~198 전부 완료 (21:00 재검증: test 89 + build 성공)
- v0.34.1 분리+구 카드 제거 완료 (T-199~201): UsageReportView 1252→415줄, test 89 + build 경고 0
- 미커밋: v0.34.1 (분리 4파일 + UsageReportView 정리 + CHANGELOG/TODO) — 명시적 요청 시 커밋

## 전달로그
- `[ACTION] [Stats]` 스냅샷 인사이트 수·버킷 수 (리포트 로드마다 1회)

## 문서갱신
- docs/plans/PLAN_v0.34.0_macos.md 신규 + docs/TODO.md T-194~198 + docs/CHANGELOG.md [0.34.0] + 본 세션 로그

## 큐상태
- bd TetherLens-rqk in_progress (후속 분리 작업 남음)

## E2E
- 실DB 복사본 재현 테스트 (일회성 ReproTests, 실행 후 삭제) + 실화면 캡처 5회
