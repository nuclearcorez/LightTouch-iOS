import SwiftUI

@main
struct LightTouchApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark) }
    }
}

private enum LTTab: String {
    case library = "Library", prepare = "Prepare", settings = "Settings"
    var symbol: String {
        switch self {
        case .library: "rectangle.stack"
        case .prepare: "plus.square.on.square"
        case .settings: "slider.horizontal.3"
        }
    }
}

private struct DeviceProfile: Identifiable {
    let id: String
    let name: String
    let board: String
    let firmware: [String]
    static let supported: [DeviceProfile] = [
        .init(id: "ipod2", name: "iPod touch (2nd generation)", board: "n72ap", firmware: ["iPhone OS 3.1.3", "iOS 4.2.1"]),
        .init(id: "ipod3", name: "iPod touch (3rd generation)", board: "n18ap", firmware: ["iOS 4.2.1"]),
        .init(id: "ipod4", name: "iPod touch (4th generation)", board: "n81ap", firmware: ["iOS 6.1.6"]),
        .init(id: "iphone3gs", name: "iPhone 3GS", board: "n88ap", firmware: ["iOS 5.1.1"]),
        .init(id: "iphone4", name: "iPhone 4", board: "n90ap / n92ap", firmware: ["iOS 4.2.1", "iOS 4.3.5", "iOS 6.1.3"]),
        .init(id: "ipad1", name: "iPad", board: "k48ap", firmware: ["iOS 5.1.1"])
    ]
}

private struct RootView: View {
    @State private var selection: LTTab = .library
    var body: some View {
        TabView(selection: $selection) {
            LibraryView().tabItem { Label("Library", systemImage: LTTab.library.symbol) }.tag(LTTab.library)
            PrepareView().tabItem { Label("Prepare", systemImage: LTTab.prepare.symbol) }.tag(LTTab.prepare)
            SettingsView().tabItem { Label("Settings", systemImage: LTTab.settings.symbol) }.tag(LTTab.settings)
        }
        .tint(Color(red: 0.48, green: 0.72, blue: 1.0))
    }
}

private struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Classic iOS, in your pocket").font(.headline)
                            Text("An experimental iOS port of LightTouch").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    EngineNotice()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR DEVICES").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        ContentUnavailableView("No devices yet", systemImage: "iphone.gen3", description: Text("Prepare a classic iPhone, iPod touch, or iPad from the Prepare tab."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK FACTS").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            FactTile(value: "6", label: "device profiles")
                            FactTile(value: "3–7", label: "iOS generations")
                            FactTile(value: "TCG", label: "CPU emulation")
                        }
                    }
                }.padding(20)
            }
            .navigationTitle("LightTouch")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct EngineNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hammer.fill").foregroundStyle(.orange).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text("iOS engine integration in progress").font(.subheadline.weight(.semibold))
                Text("This build establishes the native iPhone interface. The QEMU runtime and firmware preparation are not connected yet, so starting or importing a guest is not available in this build.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.22), lineWidth: 1))
    }
}

private struct FactTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PrepareView: View {
    @State private var selectedProfile = DeviceProfile.supported[0].id
    private var profile: DeviceProfile { DeviceProfile.supported.first(where: { $0.id == selectedProfile }) ?? DeviceProfile.supported[0] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    EngineNotice()
                    Text("Choose a classic device").font(.title2.weight(.bold))
                    ForEach(DeviceProfile.supported) { item in
                        Button { selectedProfile = item.id } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.id == "ipad1" ? "ipad" : "iphone").font(.title2).frame(width: 42).foregroundStyle(selectedProfile == item.id ? .blue : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text("Board: \(item.board)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedProfile == item.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
                            }
                            .padding(14)
                            .background(selectedProfile == item.id ? .blue.opacity(0.12) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selectedProfile == item.id ? .blue.opacity(0.5) : .white.opacity(0.06), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known firmware profiles").font(.headline)
                        Text(profile.firmware.joined(separator: "  •  ")).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                    Button {} label: { Label("Prepare device", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(true)
                    Text("Preparation is disabled until the iOS-compatible firmware pipeline and QEMU engine are built and linked.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }.navigationTitle("Prepare")
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    LabeledContent("Version", value: "iOS development build")
                    LabeledContent("Host target", value: "iPhone and iPad")
                    LabeledContent("Host SDK", value: "Current iOS SDK")
                }
                Section("Emulation") {
                    LabeledContent("Guest CPU", value: "QEMU TCG")
                    LabeledContent("Hardware virtualization", value: "Not used")
                    LabeledContent("Runtime status", value: "Not linked")
                }
                Section("About") {
                    Link(destination: URL(string: "https://github.com/nuclearcorez/LightTouch-iOS")!) {
                        Label("Source repository", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("LightTouch is free software under GPL-2.0-or-later. Preserve upstream license notices.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings")
        }
    }
}
