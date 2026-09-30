# session-2026-09-30-v039-p2-macos (P3 마감 + P2 버그 11건)

1. 착수: 미커밋 42개 변경 정리 → `feat/macos-v0.39-dashboard` 브랜치에서 **2커밋 분리**.
   감사 수정(e654a0e) / 대시보드 신설(54055b5). 각 커밋 단독 빌드·테스트를 스태시로 격리해 확인했다
   (135/20 → 183/22)
2. 이어서 `TetherLens-44t` — 설정 > **대시보드 탭** 신설(9카드 토글 + "모든 카드 표시").
   `DashboardCard.ordered` 로 표시 순서를 미러링해 순서를 두 곳에 두지 않는다
3. 카드 토글은 `settingsChanged` 로 전파 — 열려 있는 대시보드가 60초 폴링을 기다리지 않는다
4. `T-276` ② 카드 하단: 장식 금지 원칙을 지키고 **실측값**(지연 추이 스파크라인 + min/avg/max)으로 채웠다.
   `PingMonitor.recentLatencies` 를 추가했고 `jitter` 와 동일 기준(게이트웨이 우선)을 쓴다
5. 이어서 `TetherLens-axc` — P2 버그 11건 전건 해결. 정확성 4건(무한루프·RTT 위장·국기·중복 ID),
   응답성 7건(종료 블로킹·loadData N+1·renderedBody N+1·히트맵 O(168×N)·1Hz tick·UUID ID·커서 불균형)
6. **테스트가 코드의 오류를 잡았다** — `loadData` 를 백그라운드로 옮기며 인사이트를 프로필별로
   `flatMap` 했더니, `topOffender` 가 전역 집계라 결과가 달라졌다. 대상을 통째로 넘기도록 정정
7. 부수 발견 — `PopoverView` 의 1Hz 타이머가 돌리던 `tick` 을 읽는 계산 프로퍼티가
   v0.39 대시보드 도입으로 **이미 죽었는데** 타이머는 남아 있었다. 매초 body 전체 재평가의 정체
8. Sendable 9종 추가가 `loadData` 백그라운드 이동의 전제였다 (전부 순수 값 타입)
9. 신규 `scripts/tlbuild.sh` — swift build 가 컴파일러 커맨드라인을 수천 자 찍어내 읽기 힘들었음
10. 검증: `swift build` OK (신규 경고 0) + `scripts/test.sh` **197개/23스위트 통과** (183/22에서 +14)
11. 문서: CHANGELOG Part 3·Part 4 · TODO T-250 + T-280~295 · DESIGN §14.6·§14.7 · AGENTS 테스트 수
12. GUI 육안 검증은 **미수행** — Safari 가 최전위라 [HARD] 사용자 공존 규칙으로 창 활성화를 하지 않음.
    T-249에 남김
13. 미해결: `TetherLens-s13`(경고 17건 + DESIGN v0.28~v0.38 절 + `Info.plist` 죽은 키 — **[HARD] 승인 필요**)
14. 커밋·푸시 없음 (Conservative 프로필)
