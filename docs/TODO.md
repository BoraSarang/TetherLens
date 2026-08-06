# TetherLens — TODO

> 작업 추적: pending | in_progress | completed | cancelled
> 버그는 `bd`로 관리 (절대 TODO.md에 기록 금지)

---

## ✅ Phase 0 — PoC (2026-07-24)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 1 | Xcode 프로젝트 생성 + 기본 구조 설정 | P0 | ✅ |
| 2 | CoreWLAN SSID/BSSID 획득 (CoreLocation 권한) | P0 | ✅ |
| 3 | getifaddrs() 네트워크 속도 측정 | P0 | ✅ |
| 4 | NWPathMonitor 핫스팟 감지 + 게이트웨이 IP 분석 | P0 | ✅ |
| 5 | 기본 NSStatusItem + SwiftUI Popover | P0 | ✅ |
| 6 | iPhone/iPad 핫스팟, Android 핫스팟 실기기 검증 | P0 | ✅ |

## ✅ Phase 1 — Core App (2026-07-25)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 7 | 메뉴바 UI 완성 (2줄 속도 + 오늘 사용량) | P0 | ✅ |
| 8 | 연결 상세 정보 팝오버 | P0 | ✅ |
| 9 | 핫스팟 iOS/Android OS 구분 | P0 | ✅ |
| 10 | 외부 IP + GeoIP 조회 | P0 | ✅ |
| 11 | Ping 품질 모니터링 (8.8.8.8 + 게이트웨이) | P0 | ✅ |
| 12 | QoS 방지 게이지 (초록/노랑/빨강) | P0 | ✅ |
| 13 | SSID 기반 프로필 관리 + SQLite 저장소 | P0 | ✅ |
| 14 | 데이터 할당량 설정 + 경고 알림 | P0 | ✅ |
| 15 | DNS 표시 + 프리셋 변경 | P1 | ✅ |
| 16 | 설정 UI (col3 표시 토글) | P1 | ✅ |
| 17 | 프로필 편집기 + ZStack 오버레이 | P1 | ✅ |
| 18 | 프로필 삭제 시 SSID 자동 재등록 | P1 | ✅ |
| 19 | UUID DB BLOB 타입 매칭 수정 | P1 | ✅ |
| 20 | col3 데이터 usage_log 기준 변경 | P1 | ✅ |
| 21 | col3 total/잔여 2줄 표시 | P1 | ✅ |
| 22 | 잔여 용량 MB/GB 자동 단위 | P2 | ✅ |

## ✅ Phase 2 — Advanced (2026-07-25)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 23 | 스마트 절약 모드 | P1 | ✅ |
| 24 | 통계 그래프 (Swift Charts) | P1 | ✅ |
| 25 | 연결 이력 리포트 | P1 | ✅ |
| 26 | 세션 시간 추적 | P2 | ✅ |

## ✅ Phase 3 — Release (Completed)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 27 | Sparkle 자동 업데이트 | P0 | ✅ |
| 28 | 코드 서명 + Notarization | P0 | ✅ (로컬 서명 완료, Notarization은 유료 계정 필요 시 추후) |
| 29 | GitHub Actions CI/CD | P0 | ✅ |
| 30 | Buy Me a Coffee 후원 링크 | P1 | ✅ |
| 31 | 로그인 시 자동 실행 | P1 | ✅ |

## ⬜ Future (Backlog)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 32 | NEFilterDataProvider System Extension | P1 | ⬜ |
| 33 | 앱별 트래픽 per-app 누적 total 초기화 버튼 | P2 | ⬜ |
| 34 | 다크 모드 대응 | P3 | ⬜ |
| 35 | IP 변경 이력 추적 (ip_log 테이블 + onIPChange 콜백) | P2 | ✅ |
| 36 | 영문 현지화 (Localized.swift ~150개 키) | P1 | ✅ |
| 37 | 세션 타임라인 뷰 (SessionTimelineView) | P2 | ✅ |
| 38 | 핫스팟 히트맵 뷰 (HeatmapView/Grid/Map) | P2 | ✅ |
| 39 | OnboardingView (첫 실행 권한 안내) | P2 | ✅ |
| 40 | SettingsView 권한 섹션 + 용어 통일 | P2 | ✅ |

## ✅ v0.20 — Big Features (2026-08-06)

| # | Task | Priority | Status |
|---|------|----------|--------|
| 41 | 버전 v0.20.0 (build 20) Info.plist 동기화 | P0 | ✅ |
| 42 | 세션 타임라인 IP 표시 (getIPForSession) | P1 | ✅ |
| 43 | CSV/JSON 데이터 내보내기 (UsageReportView) | P1 | ✅ |
| 44 | 메뉴바 커스텀 모드 (속도/사용량/SSID 조합) | P1 | ✅ |
| 45 | 앱 트래픽 차단/허용 (AppBlockManager + 감지 알림) | P2 | ✅ |
| 46 | 프로필 자동전환 학습 (autoSwitchProfile 토글) | P2 | ✅ |
| 47 | 위젯 (WidgetKit) — SwiftPM이 .appex 미지원, Xcode 전환 필요로 제외 | P3 | ❌ |
