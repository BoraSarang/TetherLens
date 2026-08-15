# Session — 2026-08-12-macos

## v0.28 에너지 최적화 (T-137~141)

1. **무엇**: 배터리 이슈 조사 → 실측으로 TrafficMonitor 상시 nettop 가동(CPU 130%) 확인. 방전 직접 원인은 시스템 충전 인식 실패(하드웨어)로 분리하고, 앱 측 낭비를 최적화.
2. **플랫폼**: macOS (SwiftPM). 영향 파일: SettingsManager, TrafficMonitor, MenuBarManager, PingMonitor, AppBlockManager, PopoverView, AppTrafficView + docs.
3. **빌드 결과**: `./scripts/test.sh` 전체 통과 (build 포함). `build-macos.sh debug` 재설치·실행 성공, 실행 중 nettop 프로세스 0개 확인 (에너지 절감 실증). 신규 에러코드 없음.
4. **남은 TODO**: 수동 검증 1건 — (b) 저전력 토글 시 ping/메뉴바 주기 변화. 필요 시 사용자 확인. (a)는 완료.
5. **다음 에이전트 전달**: TrafficMonitor는 더 이상 상시 구동하지 않음. `acquire(reason:)`/`release(reason:)`로 활성 참조 관리, `MenuBarManager`가 `blockedAppsChanged`/`powerStateChanged` 노티에서 참조·저전력을 조정. 차단 감지 보존 확인 필요.
6. **문서 업데이트**: docs/plans/PLAN_v0.28_macos.md 신설, docs/TODO.md v0.28 섹션 ✅, docs/CHANGELOG.md v0.28 기록.
7. **오프라인 큐**: 해당 없음 (단일 macOS 앱).
8. **E2E/k6**: 해당 없음. 단위 테스트만 (test.sh 전체 통과).

## v0.28.1 세션 (21:07 종료)
1. T-142~144: 팝오버 acquire 누수 수정 — NSPopoverDelegate로 제어 이전(popoverDidShow/DidClose), PopoverView acquire/release 제거, nettop -l 2 고정 + balance 로그
2. 플랫폼: macOS
3. 빌드 결과: test.sh 43개 통과, debug 재설치 성공. DebugPanel balance=0 유지, 팝오버 여닫기 후 nettop 0개 (30초 관찰)
4. 남은 TODO: 없음 (v0.28.1 완료)
5. 다음 전달: 이전 커밋들에도 유사 패턴(PopoverView 등 SwiftUI 수명주기 의존) 확인 필요시 bd
6. 문서: TODO v0.28.1 등록, CHANGELOG v0.28.1 작성
7. 오프라인 큐: 해당 없음 (macOS 네이티브)
8. 커밋 45b432b → main 푸시 + v0.28.1 태그 + GitHub Release 생성 완료
