# session-2026-09-20-macos

1. GitHub Releases 기반 업데이트 시스템 구현 (UpdaterManager·설정 탭·UpdateSheet·MenuBarManager NSWindow) — bd 60h
2. `.github/workflows/release.yml` 신규: v태그 → 버전 검증 → 테스트 → 빌드 → ad-hoc 서명 → Release 자동 발행
3. 팝오버 사용 기록 단일 차트 + 고정 영역 확장(연결성까지), 스크롤 높이 통일 180 — bd sac
4. Info.plist 0.36.0/36, README 배지, CHANGELOG [0.36.0], release-notes/v0.36.0.md
5. release.yml YAML 오류(⸺ 무들여쓰기) 수정 후 태그 강제 이동 → CI 성공
6. v0.36.0 릴리즈 발행 완료 (zip 포함), 커밋 a2eee41 + 77d38ed 푸시
7. 검증: swift build 통과, test.sh 99개 통과, 앱 실행 확인
8. 잔여: bd 9a5(v0.31 플로팅) 미처리 — 별도 건
