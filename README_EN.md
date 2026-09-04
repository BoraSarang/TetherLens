<!--
  TetherLens — Track every megabyte your Wi-Fi data plan is quietly devouring.
  Hidden in your menu bar, it exposes exactly where your hotspot data leaks.
-->

<p align="center">
  <img src="images/icon.png" alt="TetherLens" width="120">
</p>

<h1 align="center">TetherLens 🔭</h1>

<p align="center">
  <b>A macOS menu-bar surveillance camera that hunts down tethering data waste</b><br>
  From rural broadband to a Galaxy S22 hotspot — <b>not a single precious GB slips by.</b>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-F05138">
  <img alt="Native" src="https://img.shields.io/badge/Native%20App-100%25-2563eb">
  <img alt="Release" src="https://img.shields.io/badge/Release-v0.31.0-0ea5e9">
</p>

<p align="center">
  <a href="https://github.com/BoraSarang/TetherLens/releases/latest/download/TetherLens-macOS.zip">⬇️ Download for macOS</a>
  ·
  <a href="https://github.com/BoraSarang/TetherLens/releases/latest">Releases</a>
  ·
  <a href="docs/CHANGELOG.md">Changelog</a>
  ·
  <a href="README.md">한국어</a>
</p>

---

When you're on a hotspot, these questions are always a **mystery**:

> How much have I used today? Can I know before QoS throttles my speed in half?
> Which app is draining my data?

TetherLens puts the **live picture**, **exhaustion forecast**, and the **culprit (per-app usage)** in a single menu bar.

## 🚀 Key Features

| Feature | Description |
|------|------|
| ❤️ **Live menu-bar view** | `▼ 1.2 MB/s / ▲ 120 KB/s` up/down, plus **usage/remaining** or **signal strength (RSSI)/latency**, auto-switching based on your quota status. Insight colors (green→red) make state obvious |
| 📱 **Auto hotspot detection** | Distinguishes iOS Personal Hotspot ↔ Android tethering. **Composite scoring** across SSID·gateway·cost·BSSID (catches model names like `S22 HotSpot`) for automatic profile switching |
| 🎯 **QoS protection gauge** | Today's usage vs daily quota. System alerts at thresholds (50/80/95/100%) |
| 🔮 **Exhaustion forecast** | Dashboard card predicts when the quota runs out at the current pace |
| 📊 **Dashboard insights** | Total/daily average, period comparison, top days & hotspots, top apps — a report that shows the full picture |
| 📈 **Advanced graphs** | Breakdown by hour/day, cumulative lines, quota thresholds |
| 📍 **GPS/IP location tracking** | Map pin of connection location (GPS·IP) + movement history timeline |
| 🛰️ **Connection quality monitor** | Gateway + external (8.8.8.8) Ping RTT. 3-packet cross-validation flags **only real violations, no false disconnects**, with auto recovery detection |
| 🚫 **Smart saving mode** | On hotspot detection: `softwareupdate` off · `tmutil` off · blocks Apple update servers to save data |
| 🌐 **DNS presets** | Apply 1.1.1.1 / 8.8.8.8 presets, instantly updating system network settings |
| 🔌 **Per-app traffic** | Live ranking of which app uses how much (`nettop`-based) + icon toolbar to block/exclude/reset |

**Keeps your battery lean** — polling pauses on system sleep, ticks pause when the popover closes, and timer tolerance is applied.

---

## 🖥️ Preview

| Popover (summary) | QoS protection gauge | Usage report |
|--------|--------|--------|
| ![Popover summary](images/popover-summary.png) | ![QoS gauge](images/popover-qos.png) | ![Usage report](images/popover-report.png) |

---

## ⚙️ Installation

1. Download [TetherLens-macOS.zip](https://github.com/BoraSarang/TetherLens/releases/latest/download/TetherLens-macOS.zip) → unzip → move `TetherLens.app` to `Applications`
2. If you see an **unidentified developer** warning, run this once in Terminal:
   ```bash
   xattr -rd com.apple.quarantine /Applications/TetherLens.app
   ```
3. On first launch, grant Notification & Location permission — **Location is optional**, only for GPS statistics

---

## 🛠️ Development

```bash
swift build                               # build
swift test                                # run unit tests
./scripts/build-macos.sh debug            # debug app bundle + run
./scripts/build-macos.sh release          # release build + zip
./scripts/battery-profile.sh -d 60        # battery/CPU profile
```

- **Native stack**: Swift 6 + AppKit + SwiftUI, SQLite-based local storage. No cross-platform frameworks.
- **Docs**: [`PRD`](docs/PRD.md) · [`DESIGN`](docs/DESIGN.md) · [`CHANGELOG`](docs/CHANGELOG.md) · [`TODO`](docs/TODO.md)

---

<p align="center">
  <sub>
    So no precious KB of tethering has to cry over hitting the data cap — TetherLens is watching.
    <br>© 2026 <a href="https://github.com/BoraSarang">BoraSarang</a>
  </sub>
</p>
