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
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
    @State private var selectedTab: TabType = .good
    enum TabType { case good, bad }
    @State private var pickerIndexGood: Int = 0
    @State private var pickerIndexBad: Int = 0
    
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
            self.title = "Редактирование отчёта"
        } else {
            _goodItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
            _badItems = State(initialValue: [ChecklistItem(id: UUID(), text: "")])
            _voiceNotes = State(initialValue: [])
            self.title = "Создание отчёта"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Компактный свитчер ЛОБ/БОЛ над контентом
                    HStack(spacing: 0) {
                        Button(action: { 
                            selectedTab = .good
                            pickerIndexGood = 0 // сбросить индекс
                        }) {
                            HStack(spacing: 2) {
                                Text("ЛОБ")
                                    .font(.system(size: 14.3, weight: .bold)) // 13 * 1.1
                                    .foregroundColor(selectedTab == .good ? .green : .primary)
                                Text("(")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                                Text("\(goodItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                                Text(")")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6.6) // 6 * 1.1
                            .padding(.vertical, 2.2)  // 2 * 1.1
                            .background(selectedTab == .good ? Color.green.opacity(0.12) : Color.clear)
                            .cornerRadius(6.6) // 6 * 1.1
                        }
                        Button(action: { 
                            selectedTab = .bad
                            pickerIndexBad = 0 // сбросить индекс
                        }) {
                            HStack(spacing: 2) {
                                Text("БОЛ")
                                    .font(.system(size: 14.3, weight: .bold))
                                    .foregroundColor(selectedTab == .bad ? .red : .primary)
                                Text("(")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                                Text("\(badItems.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count)")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                                Text(")")
                                    .font(.system(size: 14.3))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6.6)
                            .padding(.vertical, 2.2)
                            .background(selectedTab == .bad ? Color.red.opacity(0.12) : Color.clear)
                            .cornerRadius(6.6)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8.8) // 8 * 1.1
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Всегда вычислять теги для колеса и горизонтального списка реактивно
                    let allTags: [TagItem] = selectedTab == .good ? goodTags : badTags
                    let selectedItems: [ChecklistItem] = selectedTab == .good ? goodItems : badItems
                    let selectedTexts: Set<String> = Set(selectedItems.map { $0.text })
                    let availableTags: [TagItem] = allTags.filter { !selectedTexts.contains($0.text) }
                    let pickerIndex: Binding<Int> = selectedTab == .good ? $pickerIndexGood : $pickerIndexBad
                    if !availableTags.isEmpty {
                        TagPickerUIKitWheel(tags: availableTags, selectedIndex: pickerIndex) { tag in
                            let prevIndex = pickerIndex.wrappedValue
                            let prevCount = availableTags.count
                            if selectedTab == .good {
                                addGoodTag(tag)
                            } else {
                                addBadTag(tag)
                            }
                            DispatchQueue.main.async {
                                let newCount = (selectedTab == .good ? goodTags : badTags).filter { !Set((selectedTab == .good ? goodItems : badItems).map { $0.text }).contains($0.text) }.count
                                if prevIndex < newCount {
                                    pickerIndex.wrappedValue = prevIndex
                                } else {
                                    pickerIndex.wrappedValue = max(0, newCount - 1)
                                }
                            }
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .id(selectedTab) // <--- добавлено для корректного обновления
                    }
                    // Список выбранных тегов (тоже с TagBrickView, тап — удалить)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedItems) { item in
                                // Для ЛОБ искать только в goodTags, для БОЛ — только в badTags
                                let tag = (selectedTab == .good ? goodTags : badTags).first(where: { $0.text == item.text }) ?? TagItem(text: item.text, icon: "tag", color: .gray)
                                TagBrickView(tag: tag) {
                                    // Удалить тег из списка и вернуть в picker
                                    if selectedTab == .good {
                                        removeGoodItem(item)
                                    } else {
                                        removeBadItem(item)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    // --- остальной контент формы ниже ---
                    if selectedTab == .good {
                        ChecklistSectionView(
                            title: "Я молодец:",
                            items: $goodItems,
                            focusPrefix: "good",
                            focusField: _goodFocus,
                            onAdd: addGoodItem,
                            onRemove: removeGoodItem
                        )
                    } else {
                        ChecklistSectionView(
                            title: "Я не молодец:",
                            items: $badItems,
                            focusPrefix: "bad",
                            focusField: _badFocus,
                            onAdd: addBadItem,
                            onRemove: removeBadItem
                        )
                    }
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
            .hideKeyboardOnTap()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 10) {
                        LargeButtonView(
                            title: "Сохранить",
                            icon: "tray.and.arrow.down.fill",
                            color: .blue,
                            action: saveAndNotify,
                            isEnabled: canSave && !isSending,
                            compact: true
                        )
                        LargeButtonView(
                            title: "Опубликовать",
                            icon: "paperplane.fill",
                            color: .green,
                            action: publishAndNotify,
                            isEnabled: canSave && !isSending,
                            compact: true
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
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
            // goodFocus = new.id // убрано, чтобы не вызывать клавиатуру
        }
    }
    
    func addBadTag(_ tag: TagItem) {
        // Проверяем, нет ли уже такого тега
        if !badItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            badItems.append(new)
            // badFocus = new.id // убрано, чтобы не вызывать клавиатуру
        }
    }
    
    // MARK: - Icon Mapping
    private func getIconForItem(_ item: String, isGood: Bool) -> String {
        let lowercasedItem = item.lowercased()
        
        // Маппинг для "Я молодец"
        if isGood {
            if lowercasedItem.contains("не хлебил") { return "🚫" }
            if lowercasedItem.contains("не новостил") { return "📰" }
            if lowercasedItem.contains("не ел вредное") { return "🍴" }
            if lowercasedItem.contains("гулял") { return "🚶" }
            if lowercasedItem.contains("кодил") { return "💻" }
            if lowercasedItem.contains("рисовал") { return "🎨" }
            if lowercasedItem.contains("читал") { return "📚" }
            if lowercasedItem.contains("смотрел туториалы") { return "▶️" }
        }
        // Маппинг для "Я не молодец"
        else {
            if lowercasedItem.contains("хлебил") { return "❌" }
            if lowercasedItem.contains("новостил") { return "📰" }
            if lowercasedItem.contains("ел вредное") { return "🍴" }
            if lowercasedItem.contains("не гулял") { return "🚶" }
            if lowercasedItem.contains("не кодил") { return "💻" }
            if lowercasedItem.contains("не рисовал") { return "🎨" }
            if lowercasedItem.contains("не читал") { return "📚" }
            if lowercasedItem.contains("не смотрел туториалы") { return "▶️" }
        }
        
        // Дефолтные иконки для нераспознанных пунктов
        return isGood ? "✅" : "❌"
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
        let draftPost = Post(id: post?.id ?? UUID(), date: Date(), goodItems: filteredGood, badItems: filteredBad, published: false, voiceNotes: voiceNotes)
        if let _ = post {
            store.update(post: draftPost)
        } else {
            store.add(post: draftPost)
        }
        if let token = store.telegramToken, let chatId = store.telegramChatId, !token.isEmpty, !chatId.isEmpty {
            sendToTelegram(token: token, chatId: chatId, post: draftPost)
        } else {
            self.sendStatus = "Ошибка: заполните токен и chat_id в настройках"
            // Не меняем статус, не вызываем onPublish
        }
    }
    
    func sendToTelegram(token: String, chatId: String, post: Post) {
        isSending = true
        sendStatus = nil
        sendTextMessage(token: token, chatId: chatId, post: post) { success in
            if success && post.voiceNotes.count > 0 {
                self.sendAllVoiceNotes(token: token, chatId: chatId, voiceNotes: post.voiceNotes.map { $0.path }) { allSuccess in
                    DispatchQueue.main.async {
                        self.isSending = false
                        if allSuccess {
                            self.finalizePublish(post: post)
                        } else {
                            self.sendStatus = "Ошибка отправки голосовых заметок"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSending = false
                    if success {
                        self.finalizePublish(post: post)
                    } else {
                        self.sendStatus = "Ошибка отправки: неверный токен или chat_id"
                    }
                }
            }
        }
    }

    private func finalizePublish(post: Post) {
        // Обновляем пост как опубликованный только если отправка успешна
        let publishedPost = Post(id: post.id, date: post.date, goodItems: post.goodItems, badItems: post.badItems, published: true, voiceNotes: post.voiceNotes)
        store.update(post: publishedPost)
        self.sendStatus = "Успешно отправлено!"
        self.onPublish?()
        self.dismiss()
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
            message += "<b>✅ Я молодец:</b>\n"
            for (index, item) in post.goodItems.enumerated() {
                let icon = getIconForItem(item, isGood: true)
                message += "\(index + 1). \(icon) \(item)\n"
            }
            message += "\n"
        }
        if !post.badItems.isEmpty {
            message += "<b>❌ Я не молодец:</b>\n"
            for (index, item) in post.badItems.enumerated() {
                let icon = getIconForItem(item, isGood: false)
                message += "\(index + 1). \(icon) \(item)\n"
            }
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

