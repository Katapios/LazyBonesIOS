import SwiftUI

struct ChecklistItem: Identifiable, Equatable {
    let id: UUID
    var text: String
}

struct ChecklistSectionView: View {
    let title: String
    @Binding var items: [ChecklistItem]
    let focusPrefix: String
    @FocusState var focusField: UUID?
    let onAdd: () -> Void
    let onRemove: (ChecklistItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(items) { item in
                HStack {
                    TextField("Пункт...", text: binding(for: item))
                        .focused($focusField, equals: item.id)
                        .textFieldStyle(.roundedBorder)
                    Button(action: { onRemove(item) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(items.count > 1 ? .red : .gray)
                    }
                    .disabled(items.count == 1)
                }
            }
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить пункт")
                }
            }
        }
    }
    
    private func binding(for item: ChecklistItem) -> Binding<String> {
        guard let idx = items.firstIndex(of: item) else {
            return .constant("")
        }
        return Binding(
            get: { items[idx].text },
            set: { items[idx].text = $0 }
        )
    }
}

struct PostFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PostStore
    @State private var goodItems: [ChecklistItem]
    @State private var badItems: [ChecklistItem]
    @FocusState private var goodFocus: UUID?
    @FocusState private var badFocus: UUID?
    var title: String = "Создать отчёт"
    var post: Post? = nil
    var onSave: (() -> Void)? = nil
    var onPublish: (() -> Void)? = nil
    @State private var isSending: Bool = false
    @State private var sendStatus: String? = nil
    
    init(title: String = "Создать отчёт", post: Post? = nil, onSave: (() -> Void)? = nil, onPublish: (() -> Void)? = nil) {
        self.title = title
        self.post = post
        self.onSave = onSave
        self.onPublish = onPublish
        if let post = post {
            _goodItems = State(initialValue: post.goodItems.map { ChecklistItem(id: UUID(), text: $0) })
            _badItems = State(initialValue: post.badItems.map { ChecklistItem(id: UUID(), text: $0) })
        } else {
            _goodItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
            _badItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChecklistSectionView(
                        title: "Я молодец:",
                        items: $goodItems,
                        focusPrefix: "good",
                        focusField: _goodFocus,
                        onAdd: addGoodItem,
                        onRemove: removeGoodItem
                    )
                    ChecklistSectionView(
                        title: "Я не молодец:",
                        items: $badItems,
                        focusPrefix: "bad",
                        focusField: _badFocus,
                        onAdd: addBadItem,
                        onRemove: removeBadItem
                    )
                    if isSending {
                        ProgressView("Отправка в Telegram...")
                    }
                    if let status = sendStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status == "Успешно отправлено!" ? .green : .red)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Сохранить") {
                            saveAndNotify()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isSending)
                        Spacer()
                        Button("Опубликовать") {
                            publishAndNotify()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave || isSending)
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
        goodFocus = new.id
    }
    func removeGoodItem(_ item: ChecklistItem) {
        guard goodItems.count > 1 else { return }
        if let idx = goodItems.firstIndex(of: item) {
            goodItems.remove(at: idx)
            if let current = goodFocus, current == item.id {
                let newIdx = min(idx, goodItems.count - 1)
                goodFocus = goodItems[newIdx].id
            }
        }
    }
    func addBadItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        badItems.append(new)
        print("[DEBUG] badItems после добавления:", badItems.map { $0.text })
        badFocus = new.id
    }
    func removeBadItem(_ item: ChecklistItem) {
        guard badItems.count > 1 else { return }
        if let idx = badItems.firstIndex(of: item) {
            badItems.remove(at: idx)
            if let current = badFocus, current == item.id {
                let newIdx = min(idx, badItems.count - 1)
                badFocus = badItems[newIdx].id
            }
        }
    }
    
    var canSave: Bool {
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }
    
    func saveAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let filteredBad = badItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let newPost = Post(id: post?.id ?? UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: false)
        if let _ = post {
            store.update(post: newPost)
        } else {
            store.add(post: newPost)
        }
        onSave?()
        dismiss()
    }
    func publishAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let filteredBad = badItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let newPost = Post(id: post?.id ?? UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: true)
        if let _ = post {
            store.update(post: newPost)
        } else {
            store.add(post: newPost)
        }
        if let token = store.telegramToken, let chatId = store.telegramChatId, !token.isEmpty, !chatId.isEmpty {
            sendToTelegram(token: token, chatId: chatId, post: newPost)
        } else {
            onPublish?()
            dismiss()
        }
    }
    func sendToTelegram(token: String, chatId: String, post: Post) {
        isSending = true
        sendStatus = nil
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: post.date)
        var message = "\u{1F4C5} <b>Отчёт за \(dateStr)</b>\n\n"
        if !post.goodItems.isEmpty {
            message += "<b>Я молодец:</b>\n"
            for item in post.goodItems { message += "• \(item)\n" }
            message += "\n"
        }
        if !post.badItems.isEmpty {
            message += "<b>Я не молодец:</b>\n"
            for item in post.badItems { message += "• \(item)\n" }
        }
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        let params = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "HTML"
        ]
        var urlComponents = URLComponents(string: urlString)!
        urlComponents.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = urlComponents.url else {
            sendStatus = "Ошибка URL"
            isSending = false
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isSending = false
                if let error = error {
                    sendStatus = "Ошибка: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    sendStatus = "Успешно отправлено!"
                    onPublish?()
                    dismiss()
                } else {
                    sendStatus = "Ошибка отправки: неверный токен или chat_id"
                }
            }
        }
        task.resume()
    }
}

#Preview {
    PostFormView(title: "Создать отчёт").environmentObject(PostStore())
} 

