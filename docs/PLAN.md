# TetherLens — 구현 로드맵

- **작성일**: 2026-08-06 (v0.23.1 구조 정리 시점 — 이전에는 `plans/PLAN_v0.1.0.md` symlink였음)
- 버전별 상세 계획: `docs/plans/PLAN_v{버전}_{platform}.md`
- 작업 추적: `docs/TODO.md` (bd 우선, 보조 참조)

---

## 진행 중 / 최신

### v0.23.1 — 메뉴바 할당량 기준 "오늘" 통일 + 에이전트 규칙 정리 ✅
- 메뉴바 사용량/잔여·절약모드·임계값 알림·게이지 색 전부 `getTodayUsage`(오늘) 기준으로 통일 (팝오버 게이지와 일치)
- 에이전트 규칙 문서 완성: `AGENTS.macos.md`, `docs/DESIGN.md` 신설
- Info.plist 단일화 (루트 `Resources/Info.plist` 기준, 배포 버전 0.13.0→0.23.1 정상화)
- 상세: `docs/plans/PLAN_v0.23.1_macos.md`

### v0.23.0 — 디자인 시스템 + 팝오버 재설계 ✅
- `DesignSystem/Theme.swift` 토큰 도입, 전 뷰 하드코딩 값 치환
- 팝오버 요약/상세 2단 재설계, 배너 상단 고정
- 상세: `docs/plans/PLAN_v0.23.0_uiux.md`

---

## 버전 이력

| 버전 | 날짜 | 핵심 |
|------|------|------|
| v0.1.0 | 2026-07-24 | PoC 구현 계획 (최초) |
| v0.20.0 | 2026-08-02 | session IP, export, 메뉴바 커스텀, traffic block, auto-switch |
| v0.21.0 | 2026-08-06 | 데이터 유실·크래시 회귀 제거, Low 6건 개선 |
| v0.21.1 | 2026-08-06 | QoS 임계값 단일화, AppTraffic 토글, 폴링 간격 즉시 저장 |
| v0.22.0 | 2026-08-06 | 자동화 테스트 도입 (Swift Testing, 32개/7스위트) |
| v0.22.1 | 2026-08-06 | Android 핫스팟 감지 보강 |
| v0.22.2 | 2026-08-06 | MenuBarView 속성 캐싱 재적용 (성능) |
| v0.23.0 | 2026-08-06 | 디자인 시스템 + 팝오버 재설계 |
| v0.23.1 | 2026-08-06 | 메뉴바 할당량 오늘 기준 통일 + 에이전트 규칙 정리 |

---

## 참고

- 이전 상세 계획 파일: `docs/plans/` (PLAN_v0.1.0.md ~ PLAN_v0.23.1_macos.md)
- 테스트 계획: `docs/tests/v{버전}_macos.md`
- 기술 설계: `docs/DESIGN.md`
- 에이전트 규칙: `AGENTS.local.md` → `AGENTS.macos.md`
