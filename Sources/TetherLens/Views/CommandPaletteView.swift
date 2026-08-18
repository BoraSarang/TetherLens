import SwiftUI

// Cmd-K 커맨드 팔레트 (macos-app-design §6 — Raycast/Linear 패턴)
// SwiftUI Window scene으로 열려 내부에서 openWindow/openSettings 사용 가능.
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var searchFocused: Bool

    private struct PaletteItem {
        let title: String
        let icon: String
        let run: () -> Void
    }

    private var allItems: [PaletteItem] {
        var items: [PaletteItem] = [
            PaletteItem(title: Localized.usageReport, icon: "chart.bar.fill") {
                openWindow(id: "usageReport")
            },
            PaletteItem(title: Localized.appTrafficButton, icon: "arrow.up.arrow.down") {
                openWindow(id: "appTraffic")
            },
            PaletteItem(title: Localized.notificationList, icon: "bell") {
                openWindow(id: "notifications")
            },
            PaletteItem(title: Localized.settings, icon: "gearshape") {
                openSettings()
            },
            PaletteItem(title: Localized.about, icon: "info.circle") {
                openWindow(id: "about")
            },
            PaletteItem(title: Localized.popoverToggle, icon: "rectangle.inset.filled.and.person.filled") {
                NotificationCenter.default.post(name: .init("togglePopover"), object: nil)
            },
            PaletteItem(title: Localized.checkUpdates, icon: "arrow.down.circle") {
                UpdaterManager.shared.openDownloadPage()
            },
            PaletteItem(title: Localized.quit, icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        ]
        #if DEBUG
        items.append(
            PaletteItem(title: Localized.debugPanel, icon: "ladybug") {
                DebugPanelController.shared.toggle()
            }
        )
        #endif
        return items
    }

    private var filteredItems: [PaletteItem] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: TLSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.secondary)
                TextField(Localized.palettePlaceholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($searchFocused)
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.return) { runSelection(); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(.horizontal, TLSpace.xl)
            .padding(.vertical, TLSpace.md)

            Divider()

            if filteredItems.isEmpty {
                Spacer()
                Text(Localized.string("일치하는 명령이 없습니다", "No matching commands"))
                    .font(TLFont.caption)
                    .foregroundColor(Color.secondary)
                Spacer()
            } else {
                List {
                    ForEach(filteredItems.indices, id: \.self) { index in
                        Button {
                            select(index)
                        } label: {
                            HStack(spacing: TLSpace.md) {
                                Image(systemName: filteredItems[index].icon)
                                    .frame(width: 18)
                                    .foregroundColor(selectedIndex == index ? Color.white : Color.secondary)
                                Text(filteredItems[index].title)
                                    .foregroundColor(selectedIndex == index ? Color.white : Color.primary)
                                Spacer()
                            }
                            .padding(.horizontal, TLSpace.md)
                            .padding(.vertical, TLSpace.sm)
                            .background(selectedIndex == index ? Color.accentColor : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                .onChange(of: query) { _, _ in selectedIndex = 0 }
            }
        }
        .frame(width: 420, height: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        }
        .onAppear {
            selectedIndex = 0
            searchFocused = true
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !filteredItems.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filteredItems.count) % filteredItems.count
    }

    private func select(_ index: Int) {
        selectedIndex = index
        runSelection()
    }

    private func runSelection() {
        guard filteredItems.indices.contains(selectedIndex) else { return }
        filteredItems[selectedIndex].run()
        dismiss()
    }
}
