# 세션 로그 — 2026-09-03 (macOS)

## 무엇을
- 메뉴바 col3 자동 전환(할당량 유무): RSSI/지연 ↔ 사용량/잔여 + 색상 + 오른쪽 정렬, 지연/RSSI 토글
- 안드로이드 핫스팟 판별 개선: SSID/게이트웨이low등급/isExpensive/BSSID 종합 득점(임계 4), `S22 HotSpot` 감지
- 거짓 "연결 끊김" 알림 수정(ReachabilityPolicy + PingMonitor 3패킷)
- 프로필 편집 창 높이 동적(할당량 ON 286) + 프로세스 툴바 아이콘화 + 사용량 토글 라벨/부연

## 플랫폼
- macOS (SwiftUI/AppKit, 메뉴바+플로팅+핫스팟)

## 빌드 + PERF + CACHE
- swift test 63개 / 9스위트 통과, build_and_run debug macos 성공
- PERF/CACHE 영향 없음(감지 로직·UI만)

## 남은 TODO
- 사용자 수동 확인: 할당량 설정/미설정 메뉴바 col3, Android 핫스팟 '유형', 프로필 창 높이, 툴바 아이콘
- HOTSPOT 로그로 게이트웨이 대역 지속 보정

## 전달 로그
- uncommitted 변경 일괄을 v0.31.0 커밋으로 정리 + push 예정

## 문서 갱신
- docs/CHANGELOG.md v0.31.0 항목 추가, 본 세션 로그

## 큐 상태
- 없음(브랜치 main, origin/main 동기화 전)

## E2E
- 해당 없음(UI/감지 → 수동 체크 위주)
