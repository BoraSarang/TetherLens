import SwiftUI

struct AppTrafficView: View {
    @ObservedObject private var monitor = TrafficMonitor.shared
    let onClose: () -> Void
    @State private var showSystemProcesses = false

    var body: some View {
        VStack(spacing: 12) {
            headerView
            if monitor.apps.isEmpty {
                emptyView
            } else {
                trafficList
            }
            Button("닫기") { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, 8)
        }
        .padding(16)
        .frame(width: 320, height: 380)
    }

    private var headerView: some View {
        HStack {
            Text("프로세스별 트래픽")
                .font(.headline)
            Spacer()
            Toggle("시스템 프로세스 제외", isOn: $showSystemProcesses)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.caption)
            Button("초기화") { monitor.resetAccumulated() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text("트래픽 데이터를 수집 중입니다...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var trafficList: some View {
        List {
            headerRow
            ForEach(filteredApps.prefix(15)) { app in
                appRow(app)
            }
        }
        .listStyle(.plain)
    }

    private var filteredApps: [TrafficMonitor.AppTraffic] {
        let sorted = monitor.apps.sorted {
            $0.bytesIn + $0.bytesOut > $1.bytesIn + $1.bytesOut
        }
        if showSystemProcesses { return sorted }
        return sorted.filter { !SystemProcesses.set.contains($0.processName) }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("프로세스")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("▲ 업로드")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.orange)
                .frame(width: 74, alignment: .trailing)
            Text("▼ 다운로드")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 74, alignment: .trailing)
        }
    }

    private func appRow(_ app: TrafficMonitor.AppTraffic) -> some View {
        HStack(spacing: 0) {
            Text(app.processName)
                .font(.system(size: 10))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatByteRate(app.bytesIn))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 74, alignment: .trailing)
            Text(formatByteRate(app.bytesOut))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func formatByteRate(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond)
        if bps >= 1_000_000_000 {
            return String(format: "%.1f GB/s", bps / 1_000_000_000)
        } else if bps >= 1_000_000 {
            return String(format: "%.1f MB/s", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.1f KB/s", bps / 1_000)
        } else {
            return String(format: "%.0f B/s", bps)
        }
    }
}
