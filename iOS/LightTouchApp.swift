import SwiftUI
import UniformTypeIdentifiers

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

private struct DeviceProfileRow: View {
    let profile: DeviceProfile
    let isSelected: Bool
    let onSelect: () -> Void

    private var iconColor: Color { isSelected ? .blue : .gray }
    private var fillColor: Color { isSelected ? Color.blue.opacity(0.12) : Color.white.opacity(0.04) }
    private var borderColor: Color { isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.06) }

    var body: some View {
        Button(action: onSelect) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            deviceIcon
            deviceDescription
            Spacer(minLength: 8)
            selectionIcon
        }
        .padding(14)
        .background(fillColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
    }

    private var deviceIcon: some View {
        Image(systemName: profile.id == "ipad1" ? "ipad" : "iphone")
            .font(.title2)
            .frame(width: 42)
            .foregroundStyle(iconColor)
    }

    private var deviceDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text("Board: \(profile.board)").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectionIcon: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
        }
    }
}

private struct PrepareView: View {
    @State private var selectedProfile = DeviceProfile.supported[0].id
    @State private var showImporter = false
    @State private var showImportAlert = false
    @State private var importedIPSW: String?
    @State private var importMessage = ""

    private var profile: DeviceProfile {
        DeviceProfile.supported.first(where: { $0.id == selectedProfile }) ?? DeviceProfile.supported[0]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    EngineNotice()
                    Text("Choose a classic device").font(.title2.weight(.bold))
                    ForEach(DeviceProfile.supported) { item in
                        DeviceProfileRow(
                            profile: item,
                            isSelected: selectedProfile == item.id
                        ) {
                            selectedProfile = item.id
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known firmware profiles").font(.headline)
                        Text(profile.firmware.joined(separator: "  •  ")).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(15).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

                    Button { showImporter = true } label: {
                        Label("Choose IPSW file", systemImage: "doc.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    if let importedIPSW {
                        Label("Imported: \(importedIPSW)", systemImage: "checkmark.circle.fill")
                            .font(.footnote).foregroundStyle(.green)
                            .lineLimit(2)
                    }

                    Button {} label: {
                        Label("Prepare device", systemImage: "arrow.down.to.line").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    Text("IPSW files can be copied into the app now. Firmware extraction, validation, and guest creation will be enabled after the iOS firmware engine is integrated.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Prepare")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "ipsw") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("ImportedIPSWs", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = folder.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                    importedIPSW = url.lastPathComponent
                    importMessage = "Copied \(url.lastPathComponent) into LightTouch. Firmware preparation is not connected yet."
                } catch {
                    importMessage = "Could not import IPSW: \(error.localizedDescription)"
                }
                showImportAlert = true
            }
            .alert("IPSW import", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
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
