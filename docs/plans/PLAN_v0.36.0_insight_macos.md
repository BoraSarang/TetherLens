# PLAN v0.36.0 — 인사이트 재설계 (macOS)

> bd: TetherLens-r60 / 상태: 진행 중 / 작성: 2026-09-11
> 배경: v0.34 인사이트(T-194~198)를 T-202~203에서 삭제. 복원이 아닌 신규 설계.

## 1. 항목 6종 (임계값 초안, 사용자 조정 없음)

| # | 항목 | 발동 조건 |
|---|---|---|
| 1 | 한도 소진 예측 | 할당량 프로필 + 오늘 페이스로 자정 전 소진 예상 (15분 미만 경과 제외) |
| 2 | 주범 앱 | 오늘 전체 50MB+ 이면서 1위 앱 점유 40%+ |
| 3 | 급증 감지 | 오늘 ≥ 최근 7일 평균 × 2 (baseline 10MB 미만 제외) |
| 4 | 야간 소모 | 00–06시 합계가 오늘의 30%+ (오늘 50MB+일 때만) |
| 5 | 업로드 편중 | 오늘 업로드 비중 40%+ (오늘 50MB+일 때만) |
| 6 | IP 변경 잦음 | 최근 7일 distinct IP 5개+ |

제외: 구 sessionEff (액션 불분명).

## 2. 설계 원칙

- **DB 마이그레이션 없음**: `ProfileManager` 기존 조회(`getTodayUsage`·`getDailyUsage`·`getHourlyUsage`·`getAppTrafficLogs`·`getIPLogs`) 조합으로 계산. 엔진은 순수 함수 + 입력 구조체 (테스트 용이, 롤백 안전).
- **조용하면 숨김**: 0개면 녹색 도트 + "특이사항 없음" 한 줄.
- **섹션 제목**: "눈여겨볼 점" ("지금 알면 좋은 것" 폐기).
- **배치**: 차트 탭 최상단 고정.
- **액션**: 주범 앱→앱 트래픽 탭 전환, IP 잦음→진단 센터 열기.

## 3. 파일

- 신규 `Services/InsightEngine.swift` (Foundation only, SwiftUI 미의존)
- 신규 `Views/InsightSectionView.swift` (고정 섹션 + 카드 + empty 상태)
- 신규 `Tests/TetherLensTests/InsightEngineTests.swift` (임계값 경계 10개 내외)
- 수정 `Views/UsageReportView.swift` (차트 탭 상단 배선 + loadData 계산)
- 수정 `Utils/Localized.swift` (문구 10개 내외 한/영)

## 4. 검증

- `./scripts/test.sh` 통과 (신규 테스트 포함 90개+)
- `./build_and_run.sh debug macos` + 실DB 6종 발동 여부 수동 확인 + DebugPanel ERROR 0
