import SwiftUI

@main
struct PassSkinApp: App {
    @StateObject private var store = PassStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .onOpenURL { url in store.open(url) }
        }
    }
}

@MainActor
final class PassStore: ObservableObject {
    @Published var package: PassPackage?
    @Published var changes: [ImageSlot: ImageChange] = [:]
    @Published var errorMessage: String?
    @Published var builtPassData: Data?
    @Published var isBuilding = false

    func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            package = try PassPackage.load(from: url)
            changes = [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        package = nil
        changes = [:]
        builtPassData = nil
    }

    func build() {
        guard let package else { return }
        guard PassSigner.isConfigured else {
            errorMessage = PassSigner.SignError.missingCertificate.localizedDescription
            return
        }
        isBuilding = true
        let changes = self.changes
        Task.detached(priority: .userInitiated) {
            do {
                let data = try PassBuilder.build(from: package, changes: changes)
                await MainActor.run {
                    self.builtPassData = data
                    self.isBuilding = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isBuilding = false
                }
            }
        }
    }
}
