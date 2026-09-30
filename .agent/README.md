# .agent/ — 세션 인수인계

새 세션 시작 시 **반드시 먼저 읽을 파일**:

| 파일 | 용도 |
|---|---|
| **`HANDOFF-2026-09-28.md`** | ⭐ **현재 상태 인수인계** — 미커밋 변경, 남은 작업, 실측 확인된 함정 8건 |
| `session-2026-09-28-insight-macos.md` | v0.39 P2 — ⑨ 눈여거볼 점 + 심야 100% 초과 버그 |
| `session-2026-09-28-dashboard-macos.md` | 대시보드 8칸 · GUI 검증 3건 수정 |
| `session-2026-09-27-dashboard-macos.md` | v0.39 P0+P1 — 대시보드 신설 · 팝오버 상세보기 제거 |
| `session-2026-09-27-macos.md` | 전체 감사 — P0 2건 · P1 5건 · 문서 정정 20건 |
| 그 이전 `session-*.md` | v0.38 이하 이력 |

## 시작 절차 (3분)

```bash
cd /Users/lee/Documents/Apps/TetherLens
cat .agent/HANDOFF-2026-09-28.md        # ① 상태 파악
git status --short                      # ② 미커밋 변경 확인
swift build && ./scripts/test.sh         # ③ 기준선 검증 (183개/22스위트)
bd list                                 # ④ 열린 이슈
```

**커밋이 필요하면 사용자 지시를 받을 것** (Conservative 프로필 — 에이전트가 임의로 push 하지 않음).

## 날짜 규칙

- 세션 로그: `.agent/session-YYYY-MM-DD-macos.md` (8줄 요약, [workflow.md] §2 세션 관리)
- 인수인계: `.agent/HANDOFF-YYYY-MM-DD.md` (상태·남은작업·함정 — 장시간 작업 시 갱신)
