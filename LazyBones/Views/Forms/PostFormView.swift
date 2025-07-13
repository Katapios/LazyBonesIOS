import SwiftUI

// MARK: - Tag Models
struct TagItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let icon: String
    let color: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TagItem, rhs: TagItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tag Brick Component
struct TagBrickView: View {
    let tag: TagItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tag.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tag.text)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tag.color)
            .cornerRadius(20)
            .shadow(color: tag.color.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tag Section Component
struct TagSectionView: View {
    let title: String
    let tags: [TagItem]
    let onTagTap: (TagItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
            ], spacing: 8) {
                ForEach(tags) { tag in
                    TagBrickView(tag: tag) {
                        onTagTap(tag)
                    }
                }
            }
        }
    }
}

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
    @State private var voiceNotes: [VoiceNote]
    @FocusState private var goodFocus: UUID?
    @FocusState private var badFocus: UUID?
    var title: String = "Создать отчёт"
    var post: Post? = nil
    var onSave: (() -> Void)? = nil
    var onPublish: (() -> Void)? = nil
    @State private var isSending: Bool = false
    @State private var sendStatus: String? = nil
    
    // MARK: - Predefined Tags
    private let goodTags: [TagItem] = [
        TagItem(text: "не хлебил", icon: "xmark.circle.fill", color: .green),
        TagItem(text: "не новостил", icon: "newspaper.fill", color: .blue),
        TagItem(text: "не ел вредное", icon: "fork.knife", color: .orange),
        TagItem(text: "гулял", icon: "figure.walk", color: .mint),
        TagItem(text: "кодил", icon: "laptopcomputer", color: .purple),
        TagItem(text: "рисовал", icon: "paintbrush.fill", color: .pink),
        TagItem(text: "читал", icon: "book.fill", color: .indigo),
        TagItem(text: "смотрел туториалы", icon: "play.rectangle.fill", color: .red)
    ]
    
    private let badTags: [TagItem] = [
        TagItem(text: "хлебил", icon: "xmark.circle.fill", color: .red),
        TagItem(text: "новостил", icon: "newspaper.fill", color: .orange),
        TagItem(text: "ел вредное", icon: "fork.knife", color: .pink),
        TagItem(text: "не гулял", icon: "figure.walk", color: .gray),
        TagItem(text: "не кодил", icon: "laptopcomputer", color: .brown),
        TagItem(text: "не рисовал", icon: "paintbrush.fill", color: .secondary),
        TagItem(text: "не читал", icon: "book.fill", color: .mint),
        TagItem(text: "не смотрел туториалы", icon: "play.rectangle.fill", color: .cyan)
    ]
    
    init(title: String = "Создать отчёт", post: Post? = nil, onSave: (() -> Void)? = nil, onPublish: (() -> Void)? = nil) {
        self.title = title
        self.post = post
        self.onSave = onSave
        self.onPublish = onPublish
        if let post = post {
            _goodItems = State(initialValue: post.goodItems.map { ChecklistItem(id: UUID(), text: $0) })
            _badItems = State(initialValue: post.badItems.map { ChecklistItem(id: UUID(), text: $0) })
            _voiceNotes = State(initialValue: post.voiceNotes)
        } else {
            _goodItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
            _badItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
            _voiceNotes = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Секция тегов для "Я молодец"
                    TagSectionView(
                        title: "Быстрые теги для 'Я молодец':",
                        tags: goodTags,
                        onTagTap: addGoodTag
                    )
                    
                    ChecklistSectionView(
                        title: "Я молодец:",
                        items: $goodItems,
                        focusPrefix: "good",
                        focusField: _goodFocus,
                        onAdd: addGoodItem,
                        onRemove: removeGoodItem
                    )
                    
                    // Секция тегов для "Я не молодец"
                    TagSectionView(
                        title: "Быстрые теги для 'Я не молодец':",
                        tags: badTags,
                        onTagTap: addBadTag
                    )
                    
                    ChecklistSectionView(
                        title: "Я не молодец:",
                        items: $badItems,
                        focusPrefix: "bad",
                        focusField: _badFocus,
                        onAdd: addBadItem,
                        onRemove: removeBadItem
                    )
                    
                    VoiceRecorderListView(voiceNotes: $voiceNotes)
                    
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
    
    func addGoodTag(_ tag: TagItem) {
        // Проверяем, нет ли уже такого тега
        if !goodItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            goodItems.append(new)
            goodFocus = new.id
        }
    }
    
    func addBadTag(_ tag: TagItem) {
        // Проверяем, нет ли уже такого тега
        if !badItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            badItems.append(new)
            badFocus = new.id
        }
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
        let newPost = Post(id: post?.id ?? UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: false, voiceNotes: voiceNotes)
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
        let newPost = Post(id: post?.id ?? UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: true, voiceNotes: voiceNotes)
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
        // Сначала отправляем текстовое сообщение
        sendTextMessage(token: token, chatId: chatId, post: post) { success in
            if success && post.voiceNotes.count > 0 {
                self.sendAllVoiceNotes(token: token, chatId: chatId, voiceNotes: post.voiceNotes.map { $0.path }) { allSuccess in
                    DispatchQueue.main.async {
                        self.isSending = false
                        if allSuccess {
                            self.sendStatus = "Успешно отправлено!"
                            self.onPublish?()
                            self.dismiss()
                        } else {
                            self.sendStatus = "Ошибка отправки голосовых заметок"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSending = false
                    if success {
                        self.sendStatus = "Успешно отправлено!"
                        self.onPublish?()
                        self.dismiss()
                    } else {
                        self.sendStatus = "Ошибка отправки: неверный токен или chat_id"
                    }
                }
            }
        }
    }
    
    private func sendTextMessage(token: String, chatId: String, post: Post, completion: @escaping (Bool) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: post.date)
        let deviceName = store.getDeviceName()
        
        var message = "\u{1F4C5} <b>Отчёт за \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        
        if !post.goodItems.isEmpty {
            message += "<b>Я молодец:</b>\n"
            for item in post.goodItems { message += "• \(item)\n" }
            message += "\n"
        }
        if !post.badItems.isEmpty {
            message += "<b>Я не молодец:</b>\n"
            for item in post.badItems { message += "• \(item)\n" }
        }
        
        if post.voiceNotes.count > 0 {
            message += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
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
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.sendStatus = "Ошибка: \(error.localizedDescription)"
                    completion(false)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    self.sendStatus = "Ошибка отправки: неверный токен или chat_id"
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    private func sendAllVoiceNotes(token: String, chatId: String, voiceNotes: [String], completion: @escaping (Bool) -> Void) {
        var index = 0
        func sendNext(successSoFar: Bool) {
            if index >= voiceNotes.count {
                completion(successSoFar)
                return
            }
            let path = voiceNotes[index]
            let url = URL(fileURLWithPath: path)
            sendSingleVoice(token: token, chatId: chatId, voiceURL: url) { success in
                index += 1
                sendNext(successSoFar: successSoFar && success)
            }
        }
        sendNext(successSoFar: true)
    }

    private func sendSingleVoice(token: String, chatId: String, voiceURL: URL, completion: @escaping (Bool) -> Void) {
        let urlString = "https://api.telegram.org/bot\(token)/sendVoice"
        guard let tgURL = URL(string: urlString) else {
            completion(false)
            return
        }
        var request = URLRequest(url: tgURL)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        // Добавляем chat_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatId)\r\n".data(using: .utf8)!)
        // Добавляем аудиофайл
        do {
            let audioData = try Data(contentsOf: voiceURL)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voice\"; filename=\"voice_note.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        } catch {
            completion(false)
            return
        }
        request.httpBody = body
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Ошибка отправки аудио: \(error.localizedDescription)")
                    completion(false)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
        task.resume()
    }
}

#Preview {
    PostFormView(title: "Создать отчёт").environmentObject(PostStore())
} 

