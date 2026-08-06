# Session — 2026-08-06 (macOS) — v0.20.0

1. 무엇을: v0.20 Big Features 5종 완성 (T-42~T-46) — 세션 IP 표시, CSV/JSON 내보내기, 메뉴바 커스텀, 앱 트래픽 차단, 프로필 자동전환 토글
2. 플랫폼: [macOS]
3. 빌드: swift build 성공, 릴리즈 대기 (turbo 없음 — SwiftPM 단일 타겟)
4. 남은 TODO: T-47 위젯은 Xcode 전환 필요로 제외 → v0.21 후보. 커밋 + 태그 + release.yml 실행
5. 전달 로그: MenuBarManager.updateMenuBarText() 중괄호 복구함. 위젯은 SwiftPM .appex 미지원 확인.
6. 문서: docs/plans/PLAN_v0.20.0_macos.md 생성, TODO.md T-41~47, CHANGELOG v0.20.0
7. 오프라인 큐: N/A (오프라인 기능 없음)
8. E2E/k6: N/A
