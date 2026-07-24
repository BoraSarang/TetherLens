# Changelog

## [0.2.0] — 2026-07-24 — Phase 0 PoC ✅

### Added
- 메뉴바 커스텀 NSView (2줄: ▲ 업로드 / ▼ 다운로드)
- 메뉴바 실시간 속도 표시 (KB/s / MB/s / GB/s)
- 메뉴바 오늘 사용량 (ByteCountFormatter)
- 메뉴바 total 텍스트 QoS 색상 적용 (green/orange/red)
- SwiftUI 팝오버 (연결 정보, 속도, QoS 게이지, 버튼)
- CoreWLAN SSID/BSSID 획득 (Location 권한)
- getifaddrs() 네트워크 속도 측정 (NetworkMonitor)
- NWPathMonitor 핫스팟 감지 + 게이트웨이 IP 분석
- iOS/Android 핫스팟 OS 구분
- 외부 IP + GeoIP 조회 (ip-api.com)
- Ping 모니터링 (8.8.8.8 + 게이트웨이)
- QoS 방지 게이지 (3단계 색상 바 + 남은 용량)
- 프로젝트 구조: AppKit + SwiftUI 하이브리드
- scripts/package.sh 번들 패키징

### Changed
- 메뉴바 레이아웃: frame 기반 6셀 → 고정폭 col2/col3 + 우측정렬
- 팝오버 속도 포맷: Kbps/Mbps → KB/s/MB/s (메뉴바와 통일)
- 연결 정보 라벨 bold + 값 우측 정렬
- Location 권한 요청 타이밍 개선 (activationPolicy보다 먼저)
