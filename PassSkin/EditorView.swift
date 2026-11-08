import SwiftUI
import PhotosUI
import PassKit

struct EditorView: View {
    @EnvironmentObject private var store: PassStore

    var body: some View {
        if let package = store.package {
            List {
                Section {
                    PassPreview(package: package, changes: store.changes)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(ImageSlot.slots(for: package.style)) { slot in
                        SlotRow(slot: slot, package: package)
                    }
                } header: {
                    Text("الصور — \(package.style.arabicName)")
                } footer: {
                    if package.style == .eventTicket {
                        Text("في التذاكر: لو اخترت خلفية أو صورة جانبية، البانر ينشال تلقائياً لأن Wallet ما يعرضهم مع بعض.")
                    }
                }

                Section {
                    Button {
                        store.build()
                    } label: {
                        HStack {
                            Spacer()
                            if store.isBuilding {
                                ProgressView()
                            } else {
                                Label("أضف إلى Wallet", systemImage: "plus.rectangle.on.rectangle")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(store.changes.isEmpty || store.isBuilding)
                } footer: {
                    Text("تنضاف نسخة جديدة بشكلك الجديد. تقدر تحذف القديمة من Wallet بعدها.")
                }
            }
            .navigationTitle(package.organizationName.isEmpty ? "البطاقة" : package.organizationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { store.reset() }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.builtPassData != nil },
                set: { if !$0 { store.builtPassData = nil } }
            )) {
                if let data = store.builtPassData {
                    AddPassSheet(data: data) { error in
                        store.builtPassData = nil
                        if let error { store.errorMessage = error }
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }
}

// MARK: - صف صورة

private struct SlotRow: View {
    @EnvironmentObject private var store: PassStore
    let slot: ImageSlot
    let package: PassPackage

    @State private var pickerItem: PhotosPickerItem?

    private var currentImage: UIImage? {
        switch store.changes[slot] {
        case .replace(let img)?: return img
        case .remove?: return nil
        case nil: return package.existingImage(named: slot.rawValue)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill))
                if let img = currentImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.arabicName).font(.body)
                Text(slot.hint).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("اختر صورة", systemImage: "photo.on.rectangle")
                }
                if currentImage != nil {
                    Button(role: .destructive) {
                        store.changes[slot] = .remove
                    } label: {
                        Label("إزالة الصورة", systemImage: "trash")
                    }
                }
                if store.changes[slot] != nil {
                    Button {
                        store.changes[slot] = nil
                    } label: {
                        Label("رجّع الأصلية", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
            }
        }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    store.changes[slot] = .replace(img)
                }
                pickerItem = nil
            }
        }
    }
}

// MARK: - معاينة تقريبية للبطاقة

private struct PassPreview: View {
    let package: PassPackage
    let changes: [ImageSlot: ImageChange]

    private func image(_ slot: ImageSlot) -> UIImage? {
        switch changes[slot] {
        case .replace(let img)?: return img
        case .remove?: return nil
        case nil:
            // في التذاكر: تغيير الخلفية/الجانبية يشيل البانر
            if slot == .strip, package.style == .eventTicket,
               changes[.background] != nil || changes[.thumbnail] != nil {
                return nil
            }
            return package.existingImage(named: slot.rawValue)
        }
    }

    var body: some View {
        let bg = Color(package.backgroundColor ?? .systemGray5)
        let fg = Color(package.foregroundColor ?? .label)
        let lbl = Color(package.labelColor ?? package.foregroundColor ?? .secondaryLabel)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let logo = image(.logo) {
                    Image(uiImage: logo).resizable().scaledToFit().frame(maxWidth: 110, maxHeight: 34)
                }
                if let text = package.logoText {
                    Text(text).font(.headline).foregroundStyle(fg)
                }
                Spacer()
            }
            .padding(12)

            if let strip = image(.strip) {
                Image(uiImage: strip)
                    .resizable()
                    .scaledToFill()
                    .frame(height: package.style == .eventTicket ? 84 : 120)
                    .clipped()
            }

            HStack(alignment: .top) {
                if let field = package.primaryField {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.label).font(.caption).foregroundStyle(lbl)
                        Text(field.value).font(.title3.bold()).foregroundStyle(fg)
                    }
                }
                Spacer()
                if let thumb = image(.thumbnail) {
                    Image(uiImage: thumb).resizable().scaledToFill()
                        .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)

            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 6)
                .fill(.white)
                .frame(width: 110, height: 110)
                .overlay(Image(systemName: "qrcode").font(.system(size: 70)).foregroundStyle(.black))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        }
        .frame(height: 380)
        .background {
            ZStack {
                bg
                if let back = image(.background) {
                    Image(uiImage: back).resizable().scaledToFill().blur(radius: 18)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6, y: 3)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - شاشة الإضافة لـ Wallet

struct AddPassSheet: UIViewControllerRepresentable {
    let data: Data
    let onFinish: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            let pass = try PKPass(data: data)
            guard PKAddPassesViewController.canAddPasses(),
                  let vc = PKAddPassesViewController(pass: pass) else {
                throw PassError.unreadable
            }
            vc.delegate = context.coordinator
            return vc
        } catch {
            let vc = UIViewController()
            DispatchQueue.main.async {
                onFinish("Wallet رفض البطاقة — غالباً الشهادة أو Team ID في Config.swift غير صحيحة.")
            }
            return vc
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onFinish: (String?) -> Void
        init(onFinish: @escaping (String?) -> Void) { self.onFinish = onFinish }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            onFinish(nil)
        }
    }
}
