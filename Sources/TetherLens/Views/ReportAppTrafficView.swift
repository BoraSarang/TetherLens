import SwiftUI

/// 프로세스별 트래픽 (사용자/시스템 섹션 + 정렬). UsageReportView에서 분리 (v0.34.1).
struct ReportAppTrafficView: View {
    let appTrafficData: [(processName: String, uploadBytes: Int64, downloadBytes: Int64)]
    @Binding var sortOrder: UsageReportView.TrafficSortOrder
    @Binding var expandedSection: UsageReportView.AppTrafficSection

    var body: some View {
        Group {
            if appTrafficData.isEmpty {
                Spacer()
                Text(Localized.noTrafficData)
                    .foregroundColor(TLPalette.textSecondary)
                Spacer()
            } else {
                let systemSet = SystemProcesses.set
                let sorted = appTrafficData.sorted { a, b in
                    switch sortOrder {
                    case .total: return a.uploadBytes + a.downloadBytes > b.uploadBytes + b.downloadBytes
                    case .upload: return a.uploadBytes > b.uploadBytes
                    case .download: return a.downloadBytes > b.downloadBytes
                    }
                }
                let userApps = sorted.filter { !systemSet.contains($0.processName) }
                let systemApps = sorted.filter { systemSet.contains($0.processName) }
                let userMax = userApps.prefix(10).map { $0.uploadBytes + $0.downloadBytes }.max() ?? 1
                let systemMax = systemApps.prefix(10).map { $0.uploadBytes + $0.downloadBytes }.max() ?? 1
                let totalUp = appTrafficData.reduce(0) { $0 + $1.uploadBytes }
                let totalDn = appTrafficData.reduce(0) { $0 + $1.downloadBytes }
                let userUp = userApps.reduce(0) { $0 + $1.uploadBytes }
                let userDn = userApps.reduce(0) { $0 + $1.downloadBytes }
                let sysUp = systemApps.reduce(0) { $0 + $1.uploadBytes }
                let sysDn = systemApps.reduce(0) { $0 + $1.downloadBytes }

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear.frame(width: 20)
                            Text(Localized.process)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Localized.upload)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.upload)
                                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                            Text(Localized.download)
                                .font(TLFont.smallBold)
                                .foregroundColor(TLPalette.download)
                                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                        }
                        .frame(height: 20)

                        Divider()

                        summaryRow(label: Localized.totalSum, upload: totalUp, download: totalDn, isBold: true)
                        summaryRow(label: Localized.userSum, upload: userUp, download: userDn, isBold: true)
                        summaryRow(label: Localized.systemSum, upload: sysUp, download: sysDn, isBold: true)

                        Divider()
                            .padding(.vertical, TLSpace.xs)

                        HStack(spacing: 0) {
                            Spacer()
                            Picker(Localized.sortBy, selection: $sortOrder) {
                                ForEach(UsageReportView.TrafficSortOrder.allCases, id: \.self) { order in
                                    Text(order.localized).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.bottom, TLSpace.xs)
                    }
                    .padding(.horizontal, TLSpace.xl)

                    Divider()
                        .padding(.horizontal, TLSpace.xl)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Button {
                                    withAnimation {
                                        expandedSection = expandedSection == .user ? .system : .user
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: TLSpace.xs) {
                                        Image(systemName: expandedSection == .user ? "chevron.down" : "chevron.right")
                                            .font(TLFont.badge)
                                            .foregroundColor(TLPalette.textSecondary)
                                        Text(Localized.userProcesses)
                                            .font(TLFont.smallBold)
                                            .foregroundColor(TLPalette.textSecondary)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, TLSpace.sm)
                                }
                                .buttonStyle(.plain)
                                .id("top")

                                if expandedSection == .user {
                                    ForEach(Array(userApps.prefix(10).enumerated()), id: \.element.processName) { _, item in
                                        Divider()
                                        appTrafficRow(item, fraction: Double(item.uploadBytes + item.downloadBytes) / Double(userMax))
                                    }
                                }

                                Button {
                                    withAnimation {
                                        expandedSection = expandedSection == .system ? .user : .system
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                } label: {
                                    HStack(spacing: TLSpace.xs) {
                                        Image(systemName: expandedSection == .system ? "chevron.down" : "chevron.right")
                                            .font(TLFont.badge)
                                            .foregroundColor(TLPalette.textSecondary)
                                    Text(Localized.systemProcesses)
                                        .font(TLFont.smallBold)
                                        .foregroundColor(TLPalette.textSecondary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, TLSpace.sm)
                            }
                            .buttonStyle(.plain)

                            if expandedSection == .system {
                                ForEach(Array(systemApps.prefix(10).enumerated()), id: \.element.processName) { _, item in
                                        Divider()
                                        appTrafficRow(item, fraction: Double(item.uploadBytes + item.downloadBytes) / Double(systemMax))
                                    }
                                }
                            }
                            .padding(TLSpace.md)
                            .background(TLPalette.cardBackground, in: RoundedRectangle(cornerRadius: TLRound.medium, style: .continuous))
                            .padding(.horizontal, TLSpace.xl)
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(label: String, upload: Int64, download: Int64, isBold: Bool) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(TLFont.medium.weight(isBold ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatTotalBytes(upload))
                .font(TLFont.mediumMono.weight(isBold ? .bold : .regular))
                .foregroundColor(TLPalette.upload)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
            Text(formatTotalBytes(download))
                .font(TLFont.mediumMono.weight(isBold ? .bold : .regular))
                .foregroundColor(TLPalette.download)
                .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func appTrafficRow(_ item: (processName: String, uploadBytes: Int64, downloadBytes: Int64), fraction: Double = 1) -> some View {
        HoverRow {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Group {
                        if let nsImage = AppIconResolver.icon(forProcess: item.processName) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "app")
                                .foregroundColor(TLPalette.textSecondary)
                        }
                    }
                    .frame(width: 16, height: 16)
                    Text(item.processName)
                        .font(TLFont.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatTotalBytes(item.uploadBytes))
                        .font(TLFont.mediumMono)
                        .foregroundColor(TLPalette.upload)
                        .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                    Text(formatTotalBytes(item.downloadBytes))
                        .font(TLFont.mediumMono)
                        .foregroundColor(TLPalette.download)
                        .frame(width: TLSize.trafficDownloadCol, alignment: .trailing)
                }
                GeometryReader { geo in
                    Capsule()
                        .fill(TLPalette.upload.opacity(0.45))
                        .frame(width: geo.size.width * min(max(fraction, 0), 1), height: 2)
                }
                .frame(height: 2)
            }
            .padding(.vertical, 2)
        }
    }
}
