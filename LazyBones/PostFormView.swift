import SwiftUI

struct ChecklistItem: Identifiable, Equatable {
    let id: UUID
    var text: String
}

struct PostFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PostStore
    @State private var goodItems: [ChecklistItem] = [ChecklistItem(id: UUID(), text: "")]
    @State private var badItems: [ChecklistItem] = [ChecklistItem(id: UUID(), text: "")]
    @FocusState private var focusField: Field?
    var title: String = "Создать отчёт"
    
    enum Field: Hashable {
        case good(UUID)
        case bad(UUID)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Я молодец:").font(.headline)
                    ForEach(goodItems) { item in
                        HStack {
                            TextField("Пункт...", text: binding(for: item, in: $goodItems))
                                .focused($focusField, equals: .good(item.id))
                                .textFieldStyle(.roundedBorder)
                            Button(action: { removeGoodItem(item) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(goodItems.count > 1 ? .red : .gray)
                            }
                            .disabled(goodItems.count == 1)
                        }
                    }
                    Button(action: addGoodItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить пункт")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Я не молодец:").font(.headline)
                    ForEach(badItems) { item in
                        HStack {
                            TextField("Пункт...", text: binding(for: item, in: $badItems))
                                .focused($focusField, equals: .bad(item.id))
                                .textFieldStyle(.roundedBorder)
                            Button(action: { removeBadItem(item) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(badItems.count > 1 ? .red : .gray)
                            }
                            .disabled(badItems.count == 1)
                        }
                    }
                    Button(action: addBadItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить пункт")
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Сохранить") {
                            savePost(published: false)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                        Spacer()
                        Button("Опубликовать") {
                            savePost(published: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .hideKeyboardOnTap()
    }
    
    // MARK: - Actions
    func addGoodItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        goodItems.append(new)
        print("[DEBUG] goodItems после добавления:", goodItems.map { $0.text })
        focusField = .good(new.id)
    }
    func removeGoodItem(_ item: ChecklistItem) {
        guard goodItems.count > 1 else { return }
        if let idx = goodItems.firstIndex(of: item) {
            goodItems.remove(at: idx)
            // Сдвигаем фокус, если нужно
            if let current = focusField, case .good(let id) = current, id == item.id {
                let newIdx = min(idx, goodItems.count - 1)
                focusField = .good(goodItems[newIdx].id)
            }
        }
    }
    func addBadItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        badItems.append(new)
        print("[DEBUG] badItems после добавления:", badItems.map { $0.text })
        focusField = .bad(new.id)
    }
    func removeBadItem(_ item: ChecklistItem) {
        guard badItems.count > 1 else { return }
        if let idx = badItems.firstIndex(of: item) {
            badItems.remove(at: idx)
            if let current = focusField, case .bad(let id) = current, id == item.id {
                let newIdx = min(idx, badItems.count - 1)
                focusField = .bad(badItems[newIdx].id)
            }
        }
    }
    
    func binding(for item: ChecklistItem, in array: Binding<[ChecklistItem]>) -> Binding<String> {
        guard let idx = array.wrappedValue.firstIndex(of: item) else {
            return .constant("")
        }
        return Binding(
            get: { array.wrappedValue[idx].text },
            set: { array.wrappedValue[idx].text = $0 }
        )
    }
    
    var canSave: Bool {
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }
    
    func savePost(published: Bool) {
        let filteredGood = goodItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let filteredBad = badItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let post = Post(id: UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: published)
        store.add(post: post)
        dismiss()
    }
}

#Preview {
    PostFormView(title: "Создать отчёт").environmentObject(PostStore())
} 