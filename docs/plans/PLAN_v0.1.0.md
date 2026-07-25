# TetherLens — 구현 계획 v0.1.0

**버전**: 0.1.0
**마지막 수정**: 2026-07-24
**상태**: 초안

---

## 1. 개요

TetherLens는 macOS 메뉴바에서 핫스팟/테더링 데이터 사용량을 모니터링하고 관리하는 앱입니다.

**Phase 0 (PoC)** 은 본격 개발 전에 핵심 기술 가정을 검증하는 단계입니다.

---

## 2. 아키텍처 결정 사항

| 결정 | 선택 | 이유 |
|------|------|------|
| **최소 macOS** | 14.0 Sonoma | API 가용성과 사용자 기반의 균형 |
| **메뉴바** | NSStatusItem (AppKit) | 전체 레이아웃 제어, SwiftUI MenuBarExtra는 제약이 큼 |
| **팝오버/설정** | SwiftUI | 빠른 개발, 선언형 UI |
| **데이터 저장** | SQLite via GRDB.swift | 가벼움, Swift 네이티브, 서버 불필요 |
| **네트워크 모니터링** | getifaddrs() + poll | 샌드박스 호환, 저오버헤드, Net Bar에서 검증됨 |
| **WiFi 정보** | CoreWLAN + CoreLocation | macOS 14+에서 SSID/BSSID를 위한 유일한 공식 API |
| **핫스팟 탐지** | CoreWLAN.isPersonalHotspot + NWPathMonitor.isExpensive + 게이트웨이 IP | iOS/Android 다중 레이어 휴리스틱 |
| **배포** | GitHub Releases + Sparkle | 2026년 직접 배포 시 notarization 불필요 |
| **라이선스** | 클로즈드 소스 | 개발자 선호도 |

### 주요 리스크: SSID/BSSID 접근

Apple은 macOS 14.5부터 SSID/BSSID 접근을 점진적으로 Location Services 뒤로 잠궜습니다. Tahoe (26.5.2)에서 유일하게 보장된 방법:

```
CoreWLAN.CWWiFiClient.shared().interface()?.ssid()
  + CLLocationManager.requestWhenInUseAuthorization()
  + com.apple.security.personal-information.location entitlement
```

**대체 방법** (CoreWLAN 실패 시):
1. `ipconfig getsummary` 파싱 (Tahoe 26.0.1 기준 비관리 Mac에서 동작)
2. DHCP 게이트웨이 IP + known-networks.plist 상관 분석 (추론 방식, 정확도 낮음)

---

## 3. 구현 단계

### Phase 0 — 개념 검증 (1-2주)

**목표**: 핵심 기술 가정 검증

| 작업 ID | 설명 | 의존성 | 상태 |
|---------|------|--------|------|
| T-001 | Xcode 프로젝트 생성 + 기본 구조 | 없음 | ✅ |
| T-002 | CoreWLAN SSID/BSSID 테스트 (Location Services) | T-001 | ✅ |
| T-003 | getifaddrs() 네트워크 속도 측정 | T-001 | ✅ |
| T-004 | NWPathMonitor 핫스팟 탐지 + 게이트웨이 IP | T-001 | ✅ |
| T-005 | 기본 NSStatusItem + SwiftUI Popover | T-001 | ✅ |
| T-006 | 검증: S22 핫스팟, iPad mini 6 핫스팟 | T-002~T-005 | ✅ |

**산출물**: 메뉴바에 SSID, 속도, 핫스팟 유형을 표시하는 최소 앱

### Phase 1 — 핵심 앱 (4-6주)

**목표**: PoC 기능 완성

| 작업 ID | 설명 | 의존성 | 상태 |
|---------|------|--------|------|
| T-101 | 전체 메뉴바 UI (2줄 속도 + 일일 사용량) | T-005 | ✅ |
| T-102 | 연결 상세 팝오버 (SSID, BSSID, 채널, 링크 속도, IP, DNS) | T-002 | ✅ |
| T-103 | 핫스팟 OS 탐지 (iOS/Android) | T-004 | ✅ |
| T-104 | 외부 IP + GeoIP 조회 | T-001 | ✅ |
| T-105 | Ping 모니터 (8.8.8.8 + 게이트웨이, SimplePing) | T-001 | ✅ |
| T-106 | QoS 게이지 + 색상 상태 | T-001 | ✅ |
| T-107 | 데이터 할당량 설정 + 알림 | T-001 | ✅ (T-108에 포함) |
| T-108 | SSID 기반 프로필 관리 | T-002 | ✅ |
| T-109 | SQLite 사용 기록 저장 | T-001 | ✅ |
| T-110 | DNS 표시 + 프리셋 변경 | T-001 | ✅ |

### DNS 표시 ↔ 변경기 연결

팝오버 "연결 주소" 섹션의 DNS 표시는 T-110 DNS 프리셋 변경기와 연결됨:
- PopoverView `connectionAddressView`에 `detailRow(label: "DNS", value: dnsString)` 추가
- DNS 라벨 탭 → 프리셋 선택 UI로 연결
- 프리셋 변경 시 `ConnectionInfo.dnsServers` 업데이트 + 시스템 DNS 설정 반영 (`networksetup` via `osascript`, 관리자 권한 필요)

| T-111 | **설정 메뉴** (UserDefaults): col3 표시 토글, 할당량 GB 입력, 단위 리셋 | T-106 | ✅ |
| T-112 | **SettingsView** SwiftUI 팝오버/윈도우 (토글, 숫자 입력) | T-111 | ✅ |

### 설정 기능 상세 (T-111, T-112)

- **저장소**: `UserDefaults` (설정용, DB 불필요)
  - `bool("showTotalColumn")` → col3 숨김/표시, 기본 `true`
  - `double("quotaGB")` → 할당량 GB, 기본 `3.0`
  - `bool("quotaEnabled")` → QoS 색상 사용 여부, 기본 `false`
- **col3 숨김 동작**:
  1. `update()`에서 `showTotalColumn`이 false면 col3 텍스트만 빈 문자열로 설정, 전체 프레임 폭은 유지 (디자인 흔들림 방지)
  2. `totalRatio < 0`이면 텍스트 숨김
- **SettingsView 위치**: PopoverView 하단 설정 버튼 → sheet 또는 별도 Preferences 윈도우

### Phase 2 — 고급 기능 (4-6주)

**목표**: 앱별 모니터링 + 스마트 데이터 절약

| 작업 ID | 설명 |
|---------|------|
| T-201 | NEFilterDataProvider System Extension |
| T-202 | 앱별 트래픽 목록 (상위 N개 앱) |
| T-203 | 스마트 절약 모드 (iCloud/업데이트/백업 차단) |
| T-204 | Swift Charts 통계 화면 |
| T-205 | 연결 기록 로그 + 기기 보고서 |
| T-206 | 세션/연결 시간 추적 |

### Phase 3 — 릴리즈 (2-4주)

**목표**: 프로덕션 빌드 + 배포

| 작업 ID | 설명 |
|---------|------|
| T-301 | Sparkle 자동 업데이트 |
| T-302 | 코드 서명 + Notarization |
| T-303 | GitHub Actions CI/CD |
| T-304 | Buy Me a Coffee 후원 링크 |
| T-305 | 로그인 시 실행 (Launch Agent) |
| T-306 | 크래시 리포팅 (선택) |

---

## 4. 파일 구조

```
TetherLens/
├── TetherLens.xcodeproj/
├── Sources/
│   ├── App/
│   │   ├── App.swift                    # @main App 진입점
│   │   ├── AppDelegate.swift            # NSApplicationDelegate
│   │   └── MenuBarManager.swift         # NSStatusItem 관리
│   ├── Networking/
│   │   ├── NetworkMonitor.swift         # getifaddrs() 폴링
│   │   ├── HotspotDetector.swift        # NWPathMonitor + CoreWLAN
│   │   ├── PingMonitor.swift            # SimplePing 래퍼
│   │   └── IPResolver.swift             # 외부 IP + GeoIP
│   ├── Models/
│   │   ├── NetworkInfo.swift            # 연결 정보 모델
│   │   ├── DataUsage.swift              # 사용량 데이터 모델
│   │   ├── Profile.swift                # 네트워크 프로필 모델
│   │   └── Quota.swift                  # 할당량 설정 모델
│   ├── Services/
│   │   ├── DataStore.swift              # SQLite (GRDB) 계층
│   │   ├── ProfileManager.swift         # SSID 기반 프로필
│   │   └── QuotaMonitor.swift           # 할당량 확인 + 알림
│   ├── Views/
│   │   ├── PopoverView.swift            # 메인 팝오버 내용
│   │   ├── QoSGauge.swift               # 할당량 시각화
│   │   ├── ConnectionDetailView.swift   # 연결 정보 행 (미사용)
│   │   ├── SettingsView.swift           # 설정 창
│   │   └── StatisticsView.swift         # 차트 + 리포트
│   └── Extensions/
│       ├── Formatters.swift
│       └── Color+Status.swift
├── Resources/
│   ├── Assets.xcassets/
│   └── Info.plist
├── TetherLensExtension/                 # Phase 2
│   └── FilterProvider.swift
├── docs/
│   ├── PRD.md
│   ├── PLAN.md (symlink → plans/PLAN_v0.1.0.md)
│   ├── plans/
│   │   └── PLAN_v0.1.0.md
│   └── tests/
│       └── v0.1.0.md
├── AGENTS.md
└── README.md
```

---

## 5. 테스트 계획

### Phase 0 검증

| 테스트 ID | 설명 | 통과 기준 |
|-----------|------|-----------|
| TC-001 | Tahoe에서 CoreWLAN SSID (본인 Mac) | SSID가 nil이 아님 |
| TC-002 | macOS 14에서 CoreWLAN SSID (테스트 Mac) | SSID가 nil이 아님 |
| TC-003 | Galaxy S22 핫스팟 탐지 | isExpensive=true, 게이트웨이 192.168.43.x |
| TC-004 | iPad mini 6 핫스팟 탐지 | isPersonalHotspot=true, 게이트웨이 172.20.10.x |
| TC-005 | 속도 측정 정확도 | 시스템 환경설정 네트워크 통계 대비 ±5% 이내 |
| TC-006 | 인터페이스 유형 탐지 | WiFi/이더넷/핫스팟 올바르게 식별 |

---

## 6. 롤백 계획

Phase 0 PoC가 SSID 획득에 실패할 경우:
1. `ipconfig getsummary` 대체 시도
2. known-networks.plist 상관 분석 시도 (정확도 낮음)
3. 모든 SSID 방법 실패 시 → **수동 네트워크 이름 지정**으로 전환, 사용자가 직접 네트워크 이름 입력
4. 자동 SSID 탐지 없이도 앱 작동 가능하지만, 프로필 자동 전환은 제한됨

---

## 7. 미해결 질문

- Q1: Galaxy S22 MAC 주소 — 핫스팟 모드에서 랜덤인가 고정인가?
- Q2: `ipconfig getsummary`가 이 Mac에서 동작하는가? (비관리, Tahoe 26.5.2)
- Q3: `NWPath.isExpensive`가 Android 16 핫스팟에서 안정적으로 true를 반환하는가?
