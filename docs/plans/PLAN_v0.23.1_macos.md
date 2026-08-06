# PLAN v0.23.1 — 메뉴바 할당량 기준 "오늘" 통일 (버그 수정)

- **버전**: v0.23.1 (build 24)
- **플랫폼**: [macOS]
- **작성일**: 2026-08-06
- **상태**: 승인됨 (사용자 확정: 오늘 사용량 + 오늘 잔여 / 절약모드·알림·게이지 색 전부 오늘 기준 통일)

---

## 1. 개요

### 1.1 배경
- 메뉴바 상태바에서 할당량이 설정된 프로필의 오른쪽 컬럼이 "오늘 사용량/잔여"여야 하는데 "총 누적 사용량/잔여"로 표시됨
- v0.21 커밋(40bd1f6)에서 기준이 의도적으로 `todayGB`(오늘) → `totalGB`(총 누적)로 변경됐으나, 팝오버 QoS 게이지는 여전히 `getTodayUsage`(오늘) 기준 → **동일 할당량이 표시 위치별로 다른 값/비율/색**

### 1.2 목표
1. 메뉴바 할당량 컬럼을 **오늘 기준**으로 통일 (사용자 결정)
2. 절약모드 자동활성·임계값 알림(50/80/95/100%)·게이지 색 경계도 **오늘 기준**으로 통일
3. 팝오버 QoS 게이지와 메뉴바 게이지 비율·색이 일치하도록 정렬

---

## 2. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|------|------|
| 메뉴바 상단 사용량 | **오늘 사용량** (`getTodayUsage`) |
| 메뉴바 하단 잔여 | **오늘 기준 잔여** (`quota - todayGB`) |
| 절약모드 자동활성 | **오늘 기준** (`shouldAutoActivate(used: todayGB)`) |
| 임계값 알림 | **오늘 기준** (`checkQuotaThresholds(totalGB: todayGB)`) |
| 게이지 색 경계 | **오늘 기준** (`quotaRatio = todayGB / quota`) |
| 할당량 미설정 컬럼 | **총 누적 사용량 유지** (현행 동작 보존) |
| 팝오버 QoS 게이지 | 이미 오늘 기준 → 변경 없음 |
| 함의 | 오늘 기준이므로 자정에 리셋되어 임계값 알림·절약모드가 매일 재평가됨 (선택 반영) |

---

## 3. 구현 상세

### 3.1 MenuBarManager.updateMenuBarText (`MenuBarManager.swift`)

| 라인 | 변경 전 | 변경 후 |
|------|---------|---------|
| 407 | `var totalGB: Double = 0` | `totalGB` 제거 (`todayGB`만 유지) |
| 451-452 | `let totalBytes = …; totalGB = …` | 제거 |
| 458 | `formatBytes(totalUsage…)` | `formatBytes(todayBytes)` |
| 459 | `max(quota - totalGB, 0)` | `max(quota - todayGB, 0)` |
| 468 | `shouldAutoActivate(used: totalGB…)` | `used: todayGB` |
| 471 | `sendQuotaNotification(used: totalGB…)` | `used: todayGB` |
| 475 | `checkQuotaThresholds(totalGB: totalGB…)` | `totalGB: todayGB` |
| 494 | `min(totalGB / quota, 1.0)` | `min(todayGB / quota, 1.0)` |
| 476-478 | 할당량 미설정 → 총 사용량 | **유지** |

- `cachedTotalUsage`(라인 42·368·375·381·384)는 **유지** — 할당량 미설정 컬럼(라인 477)에서 총 누적 표시에 사용

### 3.2 설정 라벨 (`Localized.swift:142`)
- `showTotalInMenuBar`: "메뉴바에 총 사용량 표시" → **"메뉴바에 사용량 표시"** (중립화 — 할당량 있으면 오늘/없으면 총 사용량이므로)

### 3.3 Info.plist
- `CFBundleShortVersionString`: `0.23.0` → `0.23.1`
- `CFBundleVersion`: `23` → `24`

---

## 4. 구현 단계 (T-번호)

- **T-85**: PLAN 작성 + TODO 등록 (본 문서, 커밋)
- **T-86**: MenuBarManager 오늘 기준 통일 + Localized 라벨 + Info.plist (커밋)
- **T-87**: 검증 (build/test) + 문서 (CHANGELOG/TODO/세션 로그) (커밋)

---

## 5. 테스트 계획

| TC | 내용 | 방법 |
|----|------|------|
| TC-1 | 메뉴바 상단 = 오늘 사용량, 하단 = 오늘 기준 잔여 | 수동: 할당량 프로필 연결 후 확인 |
| TC-2 | 메뉴바 게이지 색 = 오늘 사용량/할당량 비율 | 수동: 팝오버 게이지와 색·비율 일치 확인 |
| TC-3 | 절약모드 자동활성·임계값 알림 오늘 기준 | 수동 + 로그(`[action]`) |
| TC-4 | 할당량 미설정 시 총 사용량 유지 | 수동 |
| TC-5 | 기존 기능 회귀 없음 | `scripts/test.sh` 32개 + `swift build` + `build-macos.sh debug` |

---

## 6. 롤백 계획
- 커밋별 개별 커밋으로 유지 → `git revert`로 부분 복구 가능
- v0.23.0(이전) 기준으로 동작 복원: 오늘 기준으로 변경된 4개 지점만 revert

---

## 7. 영향도
- **성능**: 영향 없음 (`getTodayUsage` 캐시 기존 사용, `getTotalUsage` 호출 유지)
- **권한/엔트이틀먼트/에러코드**: 변경 없음
- **문서**: CHANGELOG v0.23.1, TODO T-85~87, 세션 로그
