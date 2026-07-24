# TetherLens — Implementation Plan v0.1.0

**Version**: 0.1.0  
**Last Updated**: 2026-07-24  
**Status**: Draft

---

## 1. Overview

TetherLens is a macOS menu bar app for monitoring and managing hotspot/tethering data usage.

**Phase 0 (PoC)** focuses on validating critical technical assumptions before full-scale development.

---

## 2. Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Minimum macOS** | 14.0 Sonoma | Balance between API availability and user base |
| **Menu Bar** | NSStatusItem (AppKit) | Full control over layout, SwiftUI MenuBarExtra too limiting |
| **Popover/Settings** | SwiftUI | Faster development, declarative UI |
| **Data Storage** | SQLite via GRDB.swift | Lightweight, Swift-native, no server needed |
| **Network Monitoring** | getifaddrs() + poll | Sandbox-compatible, low overhead, proven in Net Bar |
| **WiFi Info** | CoreWLAN + CoreLocation | Only official API for SSID/BSSID on macOS 14+ |
| **Hotspot Detection** | CoreWLAN.isPersonalHotspot + NWPathMonitor.isExpensive + Gateway IP | Multi-layer heuristic for iOS/Android |
| **Distribution** | GitHub Releases + Sparkle | Notarization not required for direct distribution in 2026 |
| **License** | Closed source | Per developer preference |

### Key Risk: SSID/BSSID Access

Apple has progressively locked SSID/BSSID access behind Location Services since macOS 14.5. On Tahoe (26.5.2), the only guaranteed method is:

```
CoreWLAN.CWWiFiClient.shared().interface()?.ssid()
  + CLLocationManager.requestWhenInUseAuthorization()
  + com.apple.security.personal-information.location entitlement
```

**Fallback methods** (if CoreWLAN fails):
1. `ipconfig getsummary` parsing (works on unmanaged Macs as of Tahoe 26.0.1)
2. DHCP gateway IP + known-networks.plist correlation (inference, lower accuracy)

---

## 3. Implementation Phases

### Phase 0 — Proof of Concept (1-2 weeks)

**Goal**: Validate critical technical assumptions

| Task ID | Description | Dependencies | Status |
|---------|-------------|--------------|--------|
| T-001 | Create Xcode project + basic structure | None | Pending |
| T-002 | CoreWLAN SSID/BSSID test with Location Services | T-001 | Pending |
| T-003 | getifaddrs() network speed measurement | T-001 | Pending |
| T-004 | NWPathMonitor hotspot detection + gateway IP | T-001 | Pending |
| T-005 | Basic NSStatusItem + SwiftUI Popover | T-001 | Pending |
| T-006 | Verification: S22 hotspot, iPad mini 6 hotspot | T-002~T-005 | Pending |

**Deliverable**: A minimal app that shows SSID, speed, hotspot type in menu bar.

### Phase 1 — Core App (4-6 weeks)

**Goal**: P0 features complete

| Task ID | Description | Dependencies |
|---------|-------------|--------------|
| T-101 | Full menu bar UI (2-line speed + daily usage) | T-005 |
| T-102 | Connection detail popover (SSID, BSSID, channel, link rate, IPs, DNS) | T-002 |
| T-103 | Hotspot OS detection (iOS/Android) | T-004 |
| T-104 | External IP + GeoIP lookup | T-001 |
| T-105 | Ping monitor (8.8.8.8 + gateway, SimplePing) | T-001 |
| T-106 | QoS gauge with color states | T-001 |
| T-107 | Data quota settings + alerts | T-001 |
| T-108 | SSID-based profile management | T-002 |
| T-109 | SQLite storage for usage history | T-001 |
| T-110 | DNS display + preset changer | T-001 | ✅ |

### DNS Display ↔ Changer Connection

팝오버 "연결 주소" 섹션의 DNS 표시는 T-110 DNS 프리셋 변경기와 연결됨:
- PopoverView `connectionAddressView`에 `detailRow(label: "DNS", value: dnsString)` 추가
- DNS 표시 탭 → 프리셋 선택 UI로 연결 (Phase 1 T-110에서 구현)
- 프리셋 변경 시 `ConnectionInfo.dnsServers` 업데이트 + 시스템 DNS 설정 반영 (`networksetup` via `osascript`, 관리자 권한 필요)

| T-111 | **Settings menu** (UserDefaults): col3 total column show/hide toggle, quota GB input, quota unit reset | T-106 |
| T-112 | **SettingsView** SwiftUI popover/window with toggles and number fields | T-111 |

### Settings Feature Details (T-111, T-112)

- **Storage**: `UserDefaults` (simple, no DB needed for settings)
  - `bool("showTotalColumn")` → col3 숨김/표시, default `true`
  - `double("quotaGB")` → 사용자 할당량 GB, default `3.0`
  - `bool("quotaEnabled")` → QoS 색상 사용 여부, default `false`
- **col3 total data**: 현재 `totalUpload`/`totalDownload`는 실제 시스템 getifaddrs() 누적값. QoS quota 비율(`totalUsedGB = 2.7`, `totalQuotaGB = 3.0`)은 **하드코딩된 임시 데이터** — T-107에서 SettingsView로 대체
- **col3 hide 동작**:
  1. `update()`에서 `showTotalColumn`이 false면 col3 서브뷰 숨김, `statusItem.length` 재계산
  2. `totalRatio < 0`이면 col3 숨김 (toggle off 시 `totalRatio = -1` 전달)
- **SettingsView 위치**: PopoverView 하단 설정 버튼 → sheet 또는 별도 Preferences 윈도우

### Phase 2 — Advanced (4-6 weeks)

**Goal**: Per-app monitoring + smart data saving

| Task ID | Description |
|---------|-------------|
| T-201 | NEFilterDataProvider System Extension |
| T-202 | Per-app traffic list (top N apps) |
| T-203 | Smart saving mode (iCloud/update/backup blocker) |
| T-204 | Statistics view with Swift Charts |
| T-205 | Connection history log + device reports |
| T-206 | Session/connection time tracking |

### Phase 3 — Release (2-4 weeks)

**Goal**: Production-ready build + distribution

| Task ID | Description |
|---------|-------------|
| T-301 | Sparkle auto-update integration |
| T-302 | Code signing + Notarization |
| T-303 | GitHub Actions CI/CD |
| T-304 | Buy Me a Coffee donation link |
| T-305 | Pref pane: launch at login |
| T-306 | Crash reporting (optional) |

---

## 4. File Structure

```
TetherLens/
├── TetherLens.xcodeproj/
├── Sources/
│   ├── App/
│   │   ├── App.swift                    # @main App entry
│   │   ├── AppDelegate.swift            # NSApplicationDelegate
│   │   └── MenuBarManager.swift         # NSStatusItem management
│   ├── Networking/
│   │   ├── NetworkMonitor.swift         # getifaddrs() polling
│   │   ├── HotspotDetector.swift        # NWPathMonitor + CoreWLAN
│   │   ├── PingMonitor.swift            # SimplePing wrapper
│   │   └── IPResolver.swift             # External IP + GeoIP
│   ├── Models/
│   │   ├── NetworkInfo.swift            # Connection info model
│   │   ├── DataUsage.swift              # Usage data model
│   │   ├── Profile.swift                # Network profile model
│   │   └── Quota.swift                  # Quota settings model
│   ├── Services/
│   │   ├── DataStore.swift              # SQLite (GRDB) layer
│   │   ├── ProfileManager.swift         # SSID-based profiles
│   │   └── QuotaMonitor.swift           # Quota checking + alerts
│   ├── Views/
│   │   ├── PopoverView.swift            # Main popover content
│   │   ├── QoSGauge.swift               # Quota visualization
│   │   ├── ConnectionDetailView.swift   # Connection info rows
│   │   ├── SettingsView.swift           # Preferences window
│   │   └── StatisticsView.swift         # Charts & reports
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
│   ├── PLAN.md (symlink -> plans/PLAN_v0.1.0.md)
│   ├── plans/
│   │   └── PLAN_v0.1.0.md
│   └── tests/
│       └── v0.1.0.md
├── AGENTS.md
└── README.md
```

---

## 5. Testing Plan

### Phase 0 Verification

| Test Case | Description | Pass Criteria |
|-----------|-------------|---------------|
| TC-001 | CoreWLAN SSID on Tahoe (own Mac) | Non-nil SSID returned |
| TC-002 | CoreWLAN SSID on macOS 14 (test Mac) | Non-nil SSID returned |
| TC-003 | Galaxy S22 hotspot detection | isExpensive=true, gateway 192.168.43.x |
| TC-004 | iPad mini 6 hotspot detection | isPersonalHotspot=true, gateway 172.20.10.x |
| TC-005 | Speed measurement accuracy | Within ±5% of System Preferences network stats |
| TC-006 | Interface type detection | Correctly identifies WiFi/Ethernet/Hotspot |

---

## 6. Rollback Plan

If Phase 0 PoC fails on SSID acquisition:
1. Try `ipconfig getsummary` fallback
2. Try known-networks.plist correlation (lower accuracy)
3. If all SSID methods fail: pivot to **manual network naming** — let user name their networks
4. The app can still function without automatic SSID detection, but profile auto-switching is degraded

---

## 7. Open Questions

- Q1: Galaxy S22 MAC address — random or fixed in hotspot mode?
- Q2: Does `ipconfig getsummary` work on this specific Mac (non-managed, Tahoe 26.5.2)?
- Q3: Does `NWPath.isExpensive` reliably return true for Android 16 hotspot?
