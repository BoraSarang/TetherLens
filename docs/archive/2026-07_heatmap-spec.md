# [Task] Implement macOS Hotspot Usage Heatmap View in SwiftUI

## 1. Context & Goal
Create a macOS-native SwiftUI view (`HotspotHeatmapView`) for monitoring 24-hour weekly cellular hotspot/tethering usage.
The UI should reflect a dark-mode styled card with an interactive 7x24 grid chart, legend, and peak usage badges.

---

## 2. Requirements & UI Layout

### A. Layout Structure
1. **Header Area**:
   - Title: `시간대별 핫스팟 사용량` (Font: `.headline`, Color: `.secondary`)
   - Primary Display Value: Large text showing active usage for the selected slot (Default: `00시간 00분` or `0 MB`)
   - Subtitle: `하루 핫스팟 사용 시간` (Font: `.subheadline`)
   - Badge: `피크` tag indicating high-usage periods (`.caption`, rounded background)

2. **Heatmap Grid**:
   - **Y-Axis**: 7 Days (`일`, `월`, `화`, `수`, `목`, `금`, `토`)
   - **X-Axis**: 24 Hours (`0`, `6`, `12`, `18`, `24시` labels)
   - **Grid Cells**: 7 rows × 24 columns (168 rounded rectangle blocks)
   - **Color Mapping (4 Levels)**:
     - Level 1 (0–15 min): `Color.gray.opacity(0.2)`
     - Level 2 (15–30 min): `Color.blue.opacity(0.4)`
     - Level 3 (30–45 min): `Color.blue.opacity(0.7)`
     - Level 4 (45–60 min): `Color.blue` (Bright Blue / Peak)

3. **Legend Section**:
   - Bottom row displaying color keys: `0-15`, `15-30`, `30-45`, `45-60` (in minutes)

4. **macOS Specifics**:
   - Dark mode background (`Color(NSColor.windowBackgroundColor)` or `#1E1E1E`)
   - Hover interactivity: `.onHover` support for mouse cursor interactions over grid cells to dynamically update the header display value.

---

## 3. Data Model Proposal

```swift
import SwiftUI

struct HotspotSlot: Identifiable {
    let id = UUID()
    let hour: Int // 0...23
    let durationMinutes: Int // 0...60
}

struct DayHotspotUsage: Identifiable {
    let id = UUID()
    let dayOfWeek: String // "일", "월", ...
    let slots: [HotspotSlot] // 24 slots
}