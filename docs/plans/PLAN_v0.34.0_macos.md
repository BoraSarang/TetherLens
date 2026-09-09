# PLAN v0.34.0 — 통계 재구축: 인사이트 중심 (데이터 보존)

- **버전**: v0.34.0 (build 34)
- **플랫폼**: [macOS]
- **작성일**: 2026-09-09
- **상태**: 진행 중
- **이슈**: bd TetherLens-rqk
- **스킬**: macos-app-design (밀집 테이블·카드 표면)
- **요청**: 현행 통계는 "아 썼네 끝" 수준이라 도움이 안 됨 → "그래서 뭘 하면 되나"가 답으로 나오는 구조로 전면 재구축. DB 재설계 포함, 기존 데이터 보존 전제.
- **시각 언어**: 팝오버 `speedMiniChart` + MacTools 카드 문법 (PLAN_v0.32.1 §7 확정 — 별도 문서로 분리하지 않고 본 PLAN §5에 고정)

---

## 1. 현행 진단

- **데이터 자산 (보존)**: `profile`·`usage_log`(델타+session_id)·`session`·`app_traffic_log`(프로세스별 이력)·`ip_log`, GRDB 마이그레이션 v1~v10.
- **문제**: `UsageReportView` 1240줄·6모드×5기간, `loadData()` 10개 쿼리 fan-out (`reportSummary`는 프로필×함수 N+1). 출력은 합산 나열뿐, 행동 유도가 없음.
- **미활용 자산**: `app_traffic_log`에 프로세스별 이력이 쌓이는데 UI는 실시간 Top만 노출.

## 2. 새 통계 철학: 원장 → 처방전

- 화면 최상단 = **인사이트 카드 4종** (hero 숫자 1개 + 컨텍스트 2줄):
  1. **소진 예측** — "이 페이스면 월 한도 N일 조기 소진 → 절약모드 권장" (할당량 있는 프로필만)
  2. **주범 지목** — "오늘 소모의 N% = {앱}" (`app_traffic_log` 기간 집계)
  3. **이상치** — "평소 대비 N배 사용 중" (최근 7일 일평균 baseline 대비 오늘)
  4. **세션 효율** — "시간당 소모 1위 세션" (세션 사용량/지속시간 랭킹)
- 하단 = 기존 원장 (그래프·테이블) 유지하되 파일 분리. 삭제는 대조 검증 후.

## 3. DB v11 (보존 전제, up/down 분리)

- **불변**: 기존 5테이블 row 삭제 없음. `cleanupOldLogs` 365일 정책 유지.
- **신설 테이블**:
  - `daily_rollup(day TEXT, profile_id TEXT, upload_bytes, download_bytes, session_count, session_seconds, PRIMARY KEY(day, profile_id))` — 기간 전환 고속 집계용
  - `app_daily_rollup(day TEXT, process_name TEXT, upload_bytes, download_bytes, PRIMARY KEY(day, process_name))` — 주범 추적용
  - `insight_log(id, kind, dedup_key UNIQUE, title, body, profile_id, created_at, shown_count)` — 인사이트 발행 이력 + 중복 방지
- **backfill**: v11 마이그레이션内で 기존 로그에서 집계 이관. 실패해도 빈 테이블로 시작 가능 (rollup은 원천에서 재생성 가능하므로 무손실).
- **백업**: 마이그레이션 전 `data.sqlite.pre-v11-<ts>` 자동 복사 (마커 키로 1회만).
- **down**: 신규 3테이블 DROP + 백업 경로 로그 (row 복원은 백업 파일로 수동).

## 4. StatsEngine (신규)

- `Sources/TetherLens/Services/StatsEngine.swift` — 단일 진입점 `snapshot(profileIds:days:) -> StatsSnapshot(insights:[Insight], buckets:[DayBucket], topApps:...)`.
- `refreshRollups()` — 조회 시 day 변경분만 증분 반영 (recordUsage 핫패스에 쓰기 추가 없음).
- `ProfileManager` 기존 14종 집계는 thin 유지 (당분간 공존, UI 이관 후 단계적 정리).
- 인사이트 규칙은 순수 함수로 분리 → 단위 테스트 용이.

## 5. 시각 언어 (팝오버 + MacTools, 확정)

- 차트 = 팝오버 레시피: `AreaMark` + `color.opacity(0.35)` + `catmullRom` + 축 hidden + `max*1.15` + 높이 64, 헤더행 소제목+현재값(mono).
- 카드 = `cardBackground` + `RoundedRectangle(medium, continuous)`, hero 숫자 + 컨텍스트 2줄.
- 숫자 전부 `monospacedDigit()`, 행 호버 하이라이트, 장식 테두리·그림자 금지.
- 라이트/다크 + Increase Contrast 대응.

## 6. 전환 전략

1. DB v11 + 대조 테스트 (rollup == 원천 집계 EXACT 일치)
2. StatsEngine + 인사이트 4종 + 단위 테스트
3. `InsightsView` 신규 (리포트 창 최상단) + 기존 화면 파일 분리 → 병행 운영 → 구 삭제

## 7. 검증

- `swift test` (기존 12개 회귀 + 신규 10개 + 신구 대조)
- `./build_and_run.sh debug macos` + 실데이터 캡처 (인사이트 카드 렌더)
- DebugPanel ERROR 0, PERF: 스냅샷 1회 ≤100ms (rollup 기반)
