import SwiftUI

struct AppTrafficView: View {
    @ObservedObject private var monitor = TrafficMonitor.shared
    @ObservedObject private var blockManager = AppBlockManager.shared
    let onClose: () -> Void
    @AppStorage("appTraffic_show_system") private var showSystemProcesses = false

    private var blockedApps: Set<String> { blockManager.blockedApps }

    private var isBlockingActive: Bool {
        !blockedApps.isEmpty || SavingModeManager.shared.isEnabled
    }

    var body: some View {
        VStack(spacing: TLSpace.xl) {
            headerView
            if monitor.apps.isEmpty {
                emptyView
            } else {
                trafficList
            }
            Button(Localized.close) { onClose() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.bottom, TLSpace.md)
        }
        .padding(TLSpace.inset)
        .frame(width: TLSize.sheetStandard, height: 380)
    }

    private var headerView: some View {
        HStack {
            Text(Localized.appTraffic)
                .font(TLFont.headline)
            Spacer()
            if isBlockingActive {
                Label(Localized.blockingOn, systemImage: "hand.raised.fill")
                    .font(TLFont.caption.bold())
                    .foregroundColor(TLPalette.danger)
            }
            Toggle(Localized.excludeSystem, isOn: $showSystemProcesses)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(TLFont.caption)
            Button(Localized.resetTraffic) { monitor.resetAccumulated() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var emptyView: some View {
        VStack {
            Spacer()
            Text(Localized.trafficCollecting)
                .font(TLFont.caption)
                .foregroundColor(TLPalette.textSecondary)
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
            Text(Localized.process)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Localized.block)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.danger)
                .frame(width: 36, alignment: .center)
            Text(Localized.upload)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.upload)
                .frame(width: 64, alignment: .trailing)
            Text(Localized.download)
                .font(TLFont.smallBold)
                .foregroundColor(TLPalette.download)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private func appRow(_ app: TrafficMonitor.AppTraffic) -> some View {
        let isBlocked = blockedApps.contains(app.processName)
        return HStack(spacing: 0) {
            Text(app.processName)
                .font(TLFont.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                toggleBlock(app.processName)
            } label: {
                Image(systemName: isBlocked ? "hand.raised.fill" : "hand.raised")
                    .foregroundColor(isBlocked ? TLPalette.danger : TLPalette.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 36, alignment: .center)
            Text(formatByteRate(app.bytesIn))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.upload)
                .frame(width: 64, alignment: .trailing)
            Text(formatByteRate(app.bytesOut))
                .font(TLFont.mediumMono)
                .foregroundColor(TLPalette.download)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .opacity(isBlocked ? 0.5 : 1)
    }

    private func toggleBlock(_ name: String) {
        let isBlocked = blockedApps.contains(name)
        AppBlockManager.shared.setBlocked(name, blocked: !isBlocked)
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
