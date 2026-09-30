# session-2026-09-27-macos

1. 신규 세션 — 공통 에이전트 규칙 부트스트랩(4단계) + TetherLens 전체 감사 시작. 소스 83파일/15,923줄, 문서 13종, 테스트 13파일 대조
2. 실측 기반선: `swift build` OK(경고 25건) / `scripts/test.sh` 131개·19스위트 통과 / git clean(main) / bd 열린 이슈 0건
3. 감사 결과: P0 2건 · P1 5건 · P2 11건 코드 결함 + 문서 정합 20건 (FR-24·Sparkle이 5개 문서에서 "✅"이나 코드에 없음)
4. P0-1 절약모드 `/etc/hosts` 영구 오염 수정 — 마커 1줄 → `### TetherLens SavingMode BEGIN/END ###` 블록 + `activate()` 선행 제거로 멱등화. 임시 파일로 완전 제거·중복 블록 정리 실증 (bd TetherLens-fif)
5. P0-2 프록시 진단 100% 무효 수정 — `scutil --proxy`는 따옴표 0개인데 `line.contains("\"")`로 전부 탈락. `nonisolated static parseProxyOutput`으로 분리해 키-값 파싱 + 비활성 프로토콜 서버 제외 (bd TetherLens-4px)
6. P1 앱별 트래픽 10배 과소 수정 — `nettop -l 2`(1초)를 10초 주기에 그대로 쓰던 문제. `samples`를 재조회 주기 따라 하되 상한 30으로 설정, 워치독 비례 확장 (bd TetherLens-4e6)
7. P1 추가 발견: `parse()`가 `parts[1]`만 이름으로 써 `OpenCode Helper.56898` → `OpenCode`로 잘리던 버그. 시간 컬럼과 마지막 2바이트 컬럼 사이를 이름으로 묶고 끝 PID만 제거. 업/다운 슬롯 대응 유지
8. P1 `parse()` 마지막 블록만 반환 → 전 블록 합산 변경(`-d` 델타 모드 첫 블록은 0인 기준점)
9. P1 핀 고정 후 팝오버 재오픈 불가 수정 — `popoverDidClose`에서 `popoverPinned` 리셋 + `.transient` 복원 (bd TetherLens-uwk)
10. P1 진단 센터 "닫기" 무동작 수정 — Raw NSWindow라 `@Environment(\.dismiss)`가 no-op. `onClose` 콜백으로 `DiagnosticsWindowController.hide()` 위임 (bd TetherLens-uwk)
11. P1 DB 폴백 in-memory 마이그레이션 누락 수정 — 테이블 0개 DB로의 폴백 방지 (bd TetherLens-u23)
12. P1 메뉴바 단축키 8개 동작 불가 수정 — `AppShortcuts` 신규(NSEvent 로컬 모니터 + `MainActor.assumeIsolated`, 미등록 키 통과로 ⌘Q·⌘W 보존). `App.body`는 `@SceneBuilder var scenes`로 분리해 result builder 유지 (bd TetherLens-zvo)
13. 테스트 11개 추가 — `ProxyParseTests`(4) + `TrafficParseTests`(7). 총 **142개/21스위트 통과** (기존 131/19)
14. nettop 실제 출력 형식을 로컬 실행으로 확인 — `time process.pid bytes_in bytes_out`, 델타 모드 첫 블록은 전부 0. 이 확인으로 파서 가정을 바로잡음
15. 문서 정정: PRD(FR-24 미구현·FR-20 부분·FR-21 미구현·§7 스택 3건) / DESIGN(§5·§10·헤더 경고) / TODO(T-27·30·129 정정, T-142/143 stale ✅, T-144 부분 되돌림 명시) / AGENTS.local·macos(테스트 수 142/21) / COMPETITOR_ANALYSIS(§0 정정표 12항목)
16. CHANGELOG `[Unreleased]` 중복 1건 병합 + v0.31~v0.32 사이 미기재 섹션은 「버전 미기재」로 표시(임의 버전 부여 금지). PLAN.md 진행중·버전표 갱신
17. 검증: `swift build` OK + `scripts/test.sh` 142개/21스위트 통과
18. 남은 TODO: T-249 GUI 육안 검증(수동) · T-250 P2 11건 · T-251 Info.plist 죽은 키(승인 필요) · T-252 DESIGN/PLAN 보충 · T-253 경고 25건 · T-254 error_message_ko.json
19. 큐: bd 6건 전부 close. **커밋·푸시 없음** (Conservative 프로필 — 사용자 지시 시에만)
20. E2E: 해당 없음(macOS 메뉴바 앱). DebugPanel 육안 검증은 T-249로 위임
