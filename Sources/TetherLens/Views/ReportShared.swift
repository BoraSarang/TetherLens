import SwiftUI

/// 리포트 테이블 행 호버 하이라이트 (네이티브 느낌). UsageReportView에서 분리 (v0.34.1).
struct HoverRow<Content: View>: View {
    @State private var hovering = false
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .background(hovering ? TLPalette.textBackground.opacity(0.7) : Color.clear)
            .onHover { hovering = $0 }
    }
}

/// 바이트 포맷 (GB/MB/KB/B). UsageReportView에서 분리한 공용 헬퍼 (v0.34.1).
func formatTotalBytes(_ bytes: Int64) -> String {
    let b = Double(bytes)
    if b >= 1_000_000_000 { return String(format: "%.1f GB", b / 1_000_000_000) }
    if b >= 1_000_000 { return String(format: "%.1f MB", b / 1_000_000) }
    if b >= 1_000 { return String(format: "%.1f KB", b / 1_000) }
    return "\(bytes) B"
}
