# PLAN v0.22.2 — MenuBarView 속성 캐싱 재적용 (성능 P0)

> 작성일: 2026-08-06
> 플랫폼: [macOS]
> 목표: `PERFORMANCE_OPTIMIZATION.md`에 "적용 완료"로 기록됐으나 실제 코드에 미반영된 P3(속성 캐싱)를 실제로 적용해 CPU/전력 개선 + 문서 신뢰성 복구

## 배경

- 조사(`ses_02a042790ffeZJ5ra5mNfu0Lgs`) 결과 `MenuBarView.update()`가 **매초** `NSFont` 2개 + `NSMutableParagraphStyle` + 속성 딕셔너리 4개를 새로 생성
- `PERFORMANCE_OPTIMIZATION.md` P3 항목에는 "static let 캐싱 완료"로 기록돼 있으나 실제 커밋은 `setText()` 문자열 비교(skip)만 반영됨
- `col2FixedW`/`col3FixedW`도 매초 폰트 생성 + width 측정 2회

## 결정 사항

1. `fontSize`는 설정(`SettingsManager.menuBarFontSize`)에서 가변 → **static let 불가** → 인스턴스 프로퍼티에 `cachedFontSize` 기준으로 재생성 최소화
2. `fontSize` 변경 시에만 폰트/스타일/속성 재생성, 동일 fontSize면 재사용
3. `totalAttr`의 `totalColor`는 `colorForRatio(totalRatio)`로 매초 가변 → 매번 생성 필요, 단 `boldFont`만 재사용
4. `upArrow`/`downArrow`는 문자열 고정("▲"/"▼") → `sizeToFit()` 매초 호출 불필요, attr 재생성 시에만 갱신
5. `col2FixedW`/`col3FixedW`도 fontSize 캐시에 포함

## 구현 단계

| T# | 작업 | 설명 |
|----|------|------|
| T-77 | MenuBarView fontSize 캐싱 | `cachedFontSize` + 캐시 프로퍼티 도입, `update()`에서 재사용 |
| T-78 | 검증 | swift test 32개 유지 + build-macos.sh debug + 수동 확인 |

## 테스트 계획

- 자동화: 기존 32개 테스트 회귀 없음 (뷰 코드는 테스트 대상 아님)
- 수동: 메뉴바 속도 텍스트/잔여 표시 정상, fontSize 설정 변경 시 즉시 반영, 크래시 없음
- 성능: Instruments 계측은 선택 (CPU 변화가 미미해 육안/활동 모니터 참고)

## 롤백 계획

- git revert 또는 속성 캐싱 블록만 제거 → 기존 매초 생성 코드 복원

## 에러코드

- 해당 없음
