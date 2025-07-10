import SwiftUI

struct PostFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var goodItems: [String] = []
    @State private var badItems: [String] = []
    @State private var newGoodItem: String = ""
    @State private var newBadItem: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Я молодец:")) {
                    ForEach(goodItems, id: \.self) { item in
                        Text(item)
                    }
                    HStack {
                        TextField("Добавить пункт...", text: $newGoodItem)
                        Button(action: addGoodItem) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newGoodItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section(header: Text("Я не молодец:")) {
                    ForEach(badItems, id: \.self) { item in
                        Text(item)
                    }
                    HStack {
                        TextField("Добавить пункт...", text: $newBadItem)
                        Button(action: addBadItem) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newBadItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Создать пост")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Сохранить") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Опубликовать") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
    
    func addGoodItem() {
        let trimmed = newGoodItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        goodItems.append(trimmed)
        newGoodItem = ""
    }
    
    func addBadItem() {
        let trimmed = newBadItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        badItems.append(trimmed)
        newBadItem = ""
    }
}

#Preview {
    PostFormView()
} 