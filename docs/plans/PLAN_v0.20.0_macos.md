# PLAN v0.20.0 — Big Features

**버전**: 0.20.0
**마지막 수정**: 2026-08-06
**상태**: 완료

---

## 1. 개요

v0.12~0.19 이후 세션/리포트/메뉴바를 대폭 개선하는 대규모 기능 릴리즈.

## 2. 결정 사항

| 항목 | 선택 | 비고 |
|------|------|------|
| 세션 타임라인 IP 표시 | `getIPForSession(_:)` + SessionRow 텍스트 | 완료 |
| 데이터 내보내기 | CSV/JSON (NSSavePanel + UTType) | 완료 |
| 메뉴바 커스텀 | MenuBarMode 3종 + SSID 토글 | 완료 |
| 앱 트래픽 차단 | AppBlockManager + 감지 알림 | 실제 pf 차단은 sudo 필요로 알림 방식 채택 |
| 프로필 자동전환 학습 | autoSwitchProfile 토글 | 완료 |
| 위젯 (WidgetKit) | **제외** | SwiftPM이 .appex 미지원 → Xcode 프로젝트 전환 필요 (다음 버전) |

## 3. 구현 단계

- T-41 버전 v0.20.0 (build 20) Info.plist 동기화 ✅
- T-42 세션 타임라인 IP 표시 ✅
- T-43 CSV/JSON 내보내기 ✅
- T-44 메뉴바 커스텀 모드 ✅
- T-45 앱 트래픽 차단/허용 ✅
- T-46 프로필 자동전환 학습 ✅
- T-47 위젯 → 제외 (Xcode 전환 필요)

## 4. 테스트 계획

- `swift build` 컴파일 통과 ✅
- DebugPanel + 스크린샷 (텍스트 전용 모델 대응: a11y-dump)

## 5. 롤백 계획

- git revert + 이전 태그(v0.19.0) 재배포

## 6. 에러 코드

- 신규 에러코드 없음 (알림/토글 기반 기능)

## 7. 성능 영향

- AppBlockManager 체크는 nettop 순회 시 O(n), 알림 1회당 1개만 발송 (notified Set)
- 자동 등록 중단 옵션으로 프로필 자동 생성 최소화 가능
