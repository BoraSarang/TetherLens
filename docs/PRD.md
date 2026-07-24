# TetherLens — Product Requirements Document

**Version**: 0.1.0-draft  
**Last Updated**: 2026-07-24  
**Author**: TetherLens Team

---

## 1. Overview

TetherLens는 macOS에서 핫스팟(테더링) 및 일반 WiFi/Ethernet 연결의 데이터 사용량을 실시간으로 모니터링하고 관리하는 앱입니다.

### Problem Statement

시골 환경에서 갤럭시 S22 핫스팟으로 인터넷을 사용할 때, 일별 데이터 제한 초과 시 QoS로 인해 속도가 급격히 저하됩니다. 사용자는:
- 현재까지 사용한 데이터 양을 실시간으로 알 수 없음
- QoS 임박 시점을 예측할 수 없음
- 어떤 앱이 데이터를 소비하는지 파악할 수 없음
- 연결 품질(Ping, 속도)을 확인할 수 없음

### Solution

macOS 메뉴바에서 실시간 속도와 사용량을 표시하고, 연결 상세 정보, 할당량 관리, 품질 모니터링, 앱별 트래픽 제어 기능을 제공합니다.

---

## 2. Target Audience

- **1차**: 시골/캠핑 등에서 스마트폰 테더링으로 인터넷을 사용하는 Mac 사용자
- **2차**: 데이터 제한이 있는 핫스팟(MiFi, 도시락와이파이 등)을 사용하는 사용자
- **3차**: 네트워크 사용량을 체계적으로 관리하려는 일반 Mac 사용자

---

## 3. Minimum System Requirements

- **macOS**: 14.0 Sonoma 이상
- **Hardware**: Apple Silicon (M1 이상) 또는 Intel
- **Storage**: ~50MB
- **Memory**: ~100MB (활성 사용 시)

---

## 4. Functional Requirements

### P0 — MVP (Phase 0-1)

| ID | Feature | Description |
|----|---------|-------------|
| FR-01 | **메뉴바 실시간 속도** | 업로드/다운로드 속도를 메뉴바에 2줄로 표시 |
| FR-02 | **오늘 사용량 표시** | 금일 업+다운 합계를 메뉴바에 표시 |
| FR-03 | **인터페이스 감지** | WiFi / Ethernet / Hotspot 자동 구분 |
| FR-04 | **연결 상세 정보** | SSID, BSSID, MAC, 채널, 링크 속도, 로컬IP, 외부IP, DNS 표시 |
| FR-05 | **핫스팟 OS 구분** | iOS / Android 핫스팟 구분하여 표시 |
| FR-06 | **DNS 정보/변경** | 현재 DNS 조회, 프리셋 DNS(1.1.1.1, 8.8.8.8 등)로 변경 |
| FR-07 | **외부 IP + GeoIP** | 외부 IP 조회 및 국가 플래그 표시 |
| FR-08 | **Ping 품질 모니터링** | 8.8.8.8 + 게이트웨이 Ping RTT 실시간 표시 |
| FR-09 | **QoS 방지 게이지** | 일별 할당량 대비 사용량 시각화 (초록/노랑/빨강) |
| FR-10 | **할당량 설정 + 알림** | 프로필별 일일/월간 할당량, 임박 시 시스템 알림 |
| FR-11 | **프로필 관리** | SSID 기반 네트워크 프로필 자동 전환 |
| FR-12 | **데이터 사용량 저장** | SQLite에 샘플링 데이터 저장 |

### P1 — Advanced (Phase 2)

| ID | Feature | Description |
|----|---------|-------------|
| FR-13 | **앱별 트래픽 모니터링** | NEFilterDataProvider로 프로세스별 트래픽 추적 |
| FR-14 | **앱별 차단/허용** | 특정 앱의 인터넷 접속 차단 (절약 모드) |
| FR-15 | **스마트 절약 모드** | 핫스팟 감지 시 iCloud/업데이트/백그라운드 동기화 차단 |
| FR-16 | **통계 리포트** | 일/주/월별 그래프, 디바이스별 리포트 |
| FR-17 | **연결 이력 로그** | 디바이스별/기간별 상세 사용 리포트 |
| FR-18 | **연결 시간 추적** | 세션별/일별 연결 시간 통계 |

### P2 — Future

| ID | Feature | Description |
|----|---------|-------------|
| FR-19 | **VPN 감지** | VPN 연결 감지 및 분리 모니터링 |
| FR-20 | **발열/거리 경고** | Ping 200ms 이상 지속 시 알림 |
| FR-21 | **앱별 대역폭 제한** | 특정 앙의 속도 제한 (throttle) |

---

## 5. Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-01 | **성능 — CPU** | idle 시 <1%, 모니터링 시 <5% |
| NFR-02 | **성능 — Memory** | <100MB |
| NFR-03 | **응답성** | 속도 갱신 1초 이내, 팝오버 열림 100ms 이내 |
| NFR-04 | **보안** | 모든 네트워크 통신은 HTTPS, API 키 암호화 저장 |
| NFR-05 | **프라이버시** | 텔레메트리 없음 (외부 IP 조회 외 네트워크 요청 금지) |
| NFR-06 | **안정성** | 24/7 실행 시 크래시 0, 메모리 누수 0 |
| NFR-07 | **배터리** | 어두운 모드 지원, 불필요한 폴링 최소화 |

---

## 6. User Interface Requirements

### 6.1 메뉴바 (Menu Bar)

```
[ ↑ 1.2Mbps  ↓ 3.5Mbps | 4.7GB ]
```

- 가독성 좋은 폰트, 컴팩트한 2줄 레이아웃
- 클릭 시 팝오버 열림

### 6.2 팝오버 (Popover)

- 연결 타입 아이콘 + 네트워크명 (상단)
- 연결 상세 정보 리스트
- QoS 게이지 바
- 하단: 설정 / 통계 / 절약모드 버튼

### 6.3 설정 창 (Settings Window)

- 프로필 관리 (SSID 기반 추가/삭제/편집)
- 할당량 설정 (일별/월별, 단위: MB/GB)
- DNS 프리셋 관리
- 알림 설정
- 일반 설정 (시작프로그램 등록, 업데이트 채널 등)

### 6.4 통계 창 (Statistics Window)

- Swift Charts 기반 그래프
- 기간 선택 (일/주/월/연)
- 네트워크별 필터
- 앱별 상세 (Phase 2)

---

## 7. Technical Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6 |
| UI (Menu Bar) | AppKit (NSStatusItem) |
| UI (Popover/Settings/Stats) | SwiftUI |
| Charts | Swift Charts |
| Data Storage | SQLite (GRDB.swift) |
| Net Monitoring | getifaddrs(), Network.framework |
| WiFi Info | CoreWLAN + CoreLocation |
| Hotspot Detection | NWPathMonitor + CoreWLAN |
| Per-App Tracking (P2) | NEFilterDataProvider |
| Auto Update | Sparkle 2 |
| CI/CD | GitHub Actions |
| Distribution | GitHub Releases |
| Donation | Buy Me a Coffee |

---

## 8. Milestones

| Milestone | Timeline | Features |
|-----------|----------|----------|
| **M0 — PoC** | 1-2주 | SSID 획득, 속도 측정, 핫스팟 감지, 기본 메뉴바 |
| **M1 — Alpha** | 4-6주 | P0 전체 기능 (FR-01 ~ FR-12) |
| **M2 — Beta** | 4-6주 | P1 고급 기능 (FR-13 ~ FR-18) |
| **M3 — Release** | 2-4주 | Sparkle, Notarization, 배포 |
