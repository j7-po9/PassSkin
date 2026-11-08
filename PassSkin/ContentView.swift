import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PassStore
    @State private var showImporter = false

    private var passTypes: [UTType] {
        [UTType("com.apple.pkpass"), UTType("com.apple.pkpasses"), UTType(filenameExtension: "pkpass")]
            .compactMap { $0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.package != nil {
                    EditorView()
                } else {
                    welcome
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: passTypes) { result in
                if case .success(let url) = result { store.open(url) }
            }
            .alert("تنبيه", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("غيّر شكل بطاقتك")
                        .font(.largeTitle.bold())
                    Text("بدون تسجيل وبدون ما تكتب أي معلومة — بس اختر الصور.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    step(1, "افتح Wallet واضغط على البطاقة")
                    step(2, "اضغط ••• ثم «مشاركة البطاقة»")
                    step(3, "اختر تطبيق «بطاقتي»")
                    step(4, "غيّر الصور واضغط «أضف إلى Wallet»")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    showImporter = true
                } label: {
                    Label("أو اختر ملف البطاقة (pkpass)", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("بطاقات البنك (Apple Pay) ما يمكن تغيير شكلها.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}
