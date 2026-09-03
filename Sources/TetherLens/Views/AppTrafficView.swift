import SwiftUI

struct AppTrafficView: View {
    @ObservedObject private var monitor = TrafficMonitor.shared
    @ObservedObject private var blockManager = AppBlockManager.shared
    @AppStorage("appTraffic_show_system") private var showSystemProcesses = false
    @State private var confirmReset = false

    private var blockedApps: Set<String> { blockManager.blockedApps }

    private var isBlockingActive: Bool {
        !blockedApps.isEmpty || SavingModeManager.shared.isEnabled
    }

    var body: some View {
        VStack(spacing: TLSpace.xl) {
            if monitor.apps.isEmpty {
                emptyView
            } else {
                trafficList
            }
        }
        .padding(TLSpace.inset)
        .frame(width: TLSize.trafficWindow.w, height: TLSize.trafficWindow.h)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isBlockingActive {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(TLPalette.danger)
                        .help(Localized.activeBlockingTooltip)
                }
                Button {
                    showSystemProcesses.toggle()
                } label: {
                    Image(systemName: showSystemProcesses ? "gearshape.fill" : "gearshape")
                        .foregroundColor(showSystemProcesses ? TLPalette.danger : TLPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help(Localized.includeSystemTooltip)

                Button {
                    confirmReset = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(TLPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .help(Localized.resetTrafficTooltip)
            }
        }
        .onAppear {
            // 시트가 열려 있는 동안에만 nettop 기반 앱 트래픽을 수집 (에너지 최적화)
            TrafficMonitor.shared.acquire(reason: .sheet)
        }
        .onDisappear {
            TrafficMonitor.shared.release(reason: .sheet)
        }
        .overlay {
            if confirmReset {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: TLSpace.xxl) {
                    Text(Localized.confirm).font(TLFont.headline)
                    Text(Localized.trafficResetConfirm)
                        .font(TLFont.body)
                        .multilineTextAlignment(.center)
                    HStack(spacing: TLSpace.xl) {
                        Button(Localized.cancel) { confirmReset = false }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button(Localized.resetTraffic, role: .destructive) {
                            monitor.resetAccumulated()
                            confirmReset = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(TLSpace.xxxl)
                .background(TLPalette.windowBackground)
                .cornerRadius(TLRound.medium)
                .shadow(radius: 10)
            }
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
