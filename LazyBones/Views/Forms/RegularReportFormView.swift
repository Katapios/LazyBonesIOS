import SwiftUI

/// Форма создания/редактирования обычного отчета с полной функциональностью
@available(*, deprecated, message: "Legacy form. Use CA-based flows (DailyPlanCAView/DailyReportCAView) instead")
struct RegularReportFormView: View {
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
    @State private var tagsVersion: Int = 0
    // Локальные массивы тегов
    @State private var currentGoodRawTags: [String] = []
    @State private var currentBadRawTags: [String] = []

    // MARK: - Теги из локального состояния (фоллбэк на store только при первичной загрузке)
    private var goodTags: [TagItem] {
        currentGoodRawTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    private var badTags: [TagItem] {
        currentBadRawTags.map { TagItem(text: $0, icon: "tag", color: .red) }
    }

    init(
        title: String = "Создать отчёт",
        post: Post? = nil,
        onSave: (() -> Void)? = nil,
        onPublish: (() -> Void)? = nil
    ) {
        self.title = title
        self.post = post
        self.onSave = onSave
        self.onPublish = onPublish
        if let post = post {
            _goodItems = State(
                initialValue: post.goodItems.map {
                    ChecklistItem(id: UUID(), text: $0)
                }
            )
            _badItems = State(
                initialValue: post.badItems.map {
                    ChecklistItem(id: UUID(), text: $0)
                }
            )
            _voiceNotes = State(initialValue: post.voiceNotes)
            self.title = "Редактирование отчёта"
        } else {
            _goodItems = State(initialValue: [
                ChecklistItem(id: UUID(), text: "")
            ])
            _badItems = State(initialValue: [
                ChecklistItem(id: UUID(), text: "")
            ])
            _voiceNotes = State(initialValue: [])
            self.title = "Создание отчёта"
        }
    }

    var body: some View {
        // Заглушка отображается только если блокирующий статус И нет форс-разблокировки
        if (store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent) && !store.forceUnlock {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                Text("Время создания локального отчета на сегодня подошло к концу.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Text("Ждите наступления следующего дня — тогда снова появится возможность создать или редактировать отчет.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        } else {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // --- ЗОНА ЛОБ/БОЛ ---
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                HStack(spacing: 0) {
                                    Button(action: {
                                        selectedTab = .good
                                        pickerIndexGood = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👍 молодец")
                                                .font(.system(size: 14.3, weight: .bold))
                                                .foregroundColor(selectedTab == .good ? .green : .primary)
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text("\(goodNonEmptyCount)")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTab == .good ? Color.green.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    Button(action: {
                                        selectedTab = .bad
                                        pickerIndexBad = 0
                                    }) {
                                        HStack(spacing: 2) {
                                            Text("👎 лаботряс")
                                                .font(.system(size: 14.3, weight: .bold))
                                                .foregroundColor(selectedTab == .bad ? .red : .primary)
                                            Text("(")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text("\(badNonEmptyCount)")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                            Text(")")
                                                .font(.system(size: 14.3))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedTab == .bad ? Color.red.opacity(0.12) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.bottom, 32)

                        // --- ЗОНА WHEEL + КНОПКА + ТЕГИ ---
                        VStack(spacing: 0) {
                            let allTags: [TagItem] = selectedTab == .good ? goodTags : badTags
                            let pickerIndex: Binding<Int> = selectedTab == .good ? $pickerIndexGood : $pickerIndexBad
                            if !allTags.isEmpty {
                                VStack(spacing: 0) {
                                    HStack(alignment: .center, spacing: 6) {
                                        TagPickerUIKitWheel(
                                            tags: allTags,
                                            selectedIndex: pickerIndex
                                        ) { _ in }
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: 120,
                                            maxHeight: 120
                                        )
                                        .id("\(selectedTab)-\(tagsVersion)")
                                        .clipped()
                                        if let tag = currentSelectedTag(allTags: allTags, isGood: selectedTab == .good) {
                                            let added = isTagAlreadyAdded(tag: tag, isGood: selectedTab == .good)
                                            Button(action: {
                                                if selectedTab == .good {
                                                    if !added { addGoodTag(tag) }
                                                } else {
                                                    if !added { addBadTag(tag) }
                                                }
                                            }) {
                                                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                                    .resizable()
                                                    .frame(width: 28, height: 28)
                                                    .foregroundColor(added ? .green : .blue)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    .contentShape(Rectangle())
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.vertical, 6)

                        // --- ЗОНА ЧЕКЛИСТА ---
                        VStack(spacing: 0) {
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
                            
                            // --- Логика предложения сохранить тег ---
                            if let newText = (selectedTab == .good ? goodItems.last?.text : badItems.last?.text),
                               shouldSuggestSaveTag(newText, isGood: selectedTab == .good) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("Сохранить тег?")
                                            .font(.headline)
                                        Text("\"\(newText)\"")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Button("Отмена") {
                                            if selectedTab == .good {
                                                goodItems[goodItems.count-1].text = ""
                                            } else {
                                                badItems[badItems.count-1].text = ""
                                            }
                                        }
                                        Button("Сохранить") {
                                            let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
                                            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if selectedTab == .good {
                                                Task {
                                                    print("[RegularReportFormView] willAddTag good=\(trimmed)")
                                                    try? await repo?.addGoodTag(trimmed)
                                                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                                    await provider?.refresh()
                                                    let afterGood = provider?.goodTags.count ?? -1
                                                    let afterBad = provider?.badTags.count ?? -1
                                                    print("[RegularReportFormView] providerAfterRefresh good=\(afterGood) bad=\(afterBad)")
                                                    await MainActor.run {
                                                        reloadTagsFromProvider()
                                                        print("[RegularReportFormView] afterReload good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) firstGood=\(currentGoodRawTags.first ?? "-") firstBad=\(currentBadRawTags.first ?? "-")")
                                                        tagsVersion &+= 1
                                                        if !goodItems.isEmpty {
                                                            goodItems[goodItems.count-1].text = ""
                                                        }
                                                    }
                                                }
                                            } else {
                                                Task {
                                                    print("[RegularReportFormView] willAddTag bad=\(trimmed)")
                                                    try? await repo?.addBadTag(trimmed)
                                                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                                    await provider?.refresh()
                                                    let afterGood = provider?.goodTags.count ?? -1
                                                    let afterBad = provider?.badTags.count ?? -1
                                                    print("[RegularReportFormView] providerAfterRefresh good=\(afterGood) bad=\(afterBad)")
                                                    await MainActor.run {
                                                        reloadTagsFromProvider()
                                                        print("[RegularReportFormView] afterReload good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) firstGood=\(currentGoodRawTags.first ?? "-") firstBad=\(currentBadRawTags.first ?? "-")")
                                                        tagsVersion &+= 1
                                                        if !badItems.isEmpty {
                                                            badItems[badItems.count-1].text = ""
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 6)

                        // --- ЗОНА VOICE ---
                        VStack(spacing: 8) {
                            if !voiceNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(voiceNotes) { note in
                                        VoiceRecorderRowClean(
                                            initialPath: note.path,
                                            onVoiceNoteChanged: { newPath in
                                                if let newPath = newPath {
                                                    if let idx = voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                                        voiceNotes[idx].path = newPath
                                                    }
                                                } else {
                                                    if let idx = voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                                        voiceNotes.remove(at: idx)
                                                    }
                                                }
                                            },
                                            isFirst: voiceNotes.first?.id == note.id
                                        )
                                    }
                                }
                            } else {
                                HStack {
                                    Image(systemName: "mic.slash").foregroundColor(.gray)
                                    Text("Создайте первую голосовую заметку")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 8)
                            }
                            Button(action: {
                                voiceNotes.append(VoiceNote(id: UUID(), path: ""))
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Добавить голосовую заметку")
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 6)

                        // --- ЗОНА СТАТУСА/КНОПОК ---
                        VStack(spacing: 0) {
                            if isSending {
                                ProgressView("Отправка в Telegram...")
                            }
                            if let status = sendStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundColor(status == "Успешно отправлено!" ? .green : .red)
                            }
                        }
                        .padding(.vertical, 6)
                        Spacer()
                    }
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .hideKeyboardOnTap()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        HStack() {
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
                                isEnabled: canPublish && !isSending,
                                compact: true
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                }
            }
            .onAppear {
                // Гарантируем инициализацию тегов при открытии формы
                // Первичная загрузка локальных массивов + refresh провайдера
                reloadTagsFromProvider()
                Task {
                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                    await provider?.refresh()
                    await MainActor.run {
                        reloadTagsFromProvider()
                        tagsVersion &+= 1
                    }
                }
            }
            .onChange(of: selectedTab, initial: false) { _, _ in
                // При переключении good/bad пересоздаем колесо
                tagsVersion &+= 1
            }
        }
    }
    
    // MARK: - Tags Loading
    func reloadTagsFromProvider() {
        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
        let good = provider?.goodTags ?? store.goodTags
        let bad = provider?.badTags ?? store.badTags
        currentGoodRawTags = good
        currentBadRawTags = bad
        // Безопасно корректируем индексы пикеров
        if currentGoodRawTags.isEmpty { pickerIndexGood = 0 }
        else if pickerIndexGood >= currentGoodRawTags.count { pickerIndexGood = 0 }
        if currentBadRawTags.isEmpty { pickerIndexBad = 0 }
        else if pickerIndexBad >= currentBadRawTags.count { pickerIndexBad = 0 }
        // DEBUG
        print("[RegularReportFormView] reloadTagsFromProvider: good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) sel=\(selectedTab) idxG=\(pickerIndexGood) idxB=\(pickerIndexBad) ver=\(tagsVersion)")
    }

    // MARK: - Actions
    func addGoodItem() {
        let new = ChecklistItem(id: UUID(), text: "")
        goodItems.append(new)
        print("[DEBUG] goodItems после добавления:", goodItems.map { $0.text })
        goodFocus = new.id
    }

    func addGoodTag(_ tag: TagItem) {
        if !goodItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            goodItems.append(new)
        }
    }

    func addBadTag(_ tag: TagItem) {
        if !badItems.contains(where: { $0.text == tag.text }) {
            let new = ChecklistItem(id: UUID(), text: tag.text)
            badItems.append(new)
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
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) ||
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    var canPublish: Bool {
        goodItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }) &&
        badItems.contains(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    // MARK: - Simple counters to reduce inline complexity
    private var goodNonEmptyCount: Int {
        TagHelpers.nonEmptyCount(in: goodItems.map { $0.text })
    }

    private var badNonEmptyCount: Int {
        TagHelpers.nonEmptyCount(in: badItems.map { $0.text })
    }

    // MARK: - TagPicker helpers
    private func currentSelectedTag(allTags: [TagItem], isGood: Bool) -> TagItem? {
        guard !allTags.isEmpty else { return nil }
        let idx = isGood ? pickerIndexGood : pickerIndexBad
        let safeIdx = TagHelpers.clampedIndex(idx, arrayCount: allTags.count)
        return allTags[safeIdx]
    }

    private func isTagAlreadyAdded(tag: TagItem, isGood: Bool) -> Bool {
        if isGood {
            return TagHelpers.isTagTextAdded(tag, in: goodItems.map { $0.text })
        } else {
            return TagHelpers.isTagTextAdded(tag, in: badItems.map { $0.text })
        }
    }

    private func shouldSuggestSaveTag(_ rawText: String, isGood: Bool) -> Bool {
        let currentRaw = isGood ? currentGoodRawTags : currentBadRawTags
        return TagHelpers.shouldSuggestSave(rawText: rawText, existingRaw: currentRaw)
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

    // MARK: - Save and Publish
    func saveAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let filteredBad = badItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let today = Calendar.current.startOfDay(for: Date())
        
        // Удалить все обычные отчёты за сегодня
        store.posts.removeAll {
            $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today)
        }
        
        // Добавить новый отчёт
        let newPost = Post(
            id: UUID(),
            date: Date(),
            goodItems: filteredGood,
            badItems: filteredBad,
            published: false,
            voiceNotes: voiceNotes,
            type: .regular
        )
        store.add(post: newPost)
        onSave?()
        dismiss()
    }

    func publishAndNotify() {
        let filteredGood = goodItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let filteredBad = badItems.map { $0.text }.filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let draftPost = Post(
            id: post?.id ?? UUID(),
            date: Date(),
            goodItems: filteredGood,
            badItems: filteredBad,
            published: false,
            voiceNotes: voiceNotes,
            type: .regular
        )
        
        if post != nil {
            store.update(post: draftPost)
        } else {
            store.add(post: draftPost)
        }
        
        // Загружаем настройки Telegram и отправляем через сервис (chatId берётся внутри сервиса)
        store.loadTelegramSettings()
        sendToTelegram(post: draftPost)
    }

    // MARK: - Telegram Integration
    func sendToTelegram(post: Post) {
        isSending = true
        sendStatus = nil

        // Формируем текст сообщения (дублируем логику из sendTextMessage, чтобы использовать единый publish)
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
        let validVoicePaths = post.voiceNotes
            .map { $0.path }
            .filter { FileManager.default.fileExists(atPath: $0) }
        if !validVoicePaths.isEmpty {
            message += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
        }

        store.publish(text: message, voicePaths: validVoicePaths) { success in
            DispatchQueue.main.async {
                self.isSending = false
                if success {
                    self.finalizePublish(post: post)
                } else {
                    // Если голосовых не было — вероятно проблема с токеном/chatId, иначе считаем ошибкой голосовых
                    self.sendStatus = validVoicePaths.isEmpty ? "Ошибка отправки: неверный токен или chat_id" : "Ошибка отправки голосовых заметок"
                }
            }
        }
    }

    private func finalizePublish(post: Post) {
        // Обновляем пост как опубликованный только если отправка успешна
        let publishedPost = Post(
            id: post.id,
            date: post.date,
            goodItems: post.goodItems,
            badItems: post.badItems,
            published: true,
            voiceNotes: post.voiceNotes,
            type: .regular
        )
        store.update(post: publishedPost)
        self.sendStatus = "Успешно отправлено!"
        self.onPublish?()
        self.dismiss()
    }

    private func sendTextMessage(
        post: Post,
        completion: @escaping (Bool) -> Void
    ) {
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

        // Показываем метку о голосовой заметке только если файл(ы) существуют
        let hasExistingVoices = post.voiceNotes
            .map { $0.path }
            .contains { FileManager.default.fileExists(atPath: $0) }
        if hasExistingVoices {
            message += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
        }

        // Отправляем через PostStore, который использует PostTelegramService и актуальные настройки из UserDefaults
        store.sendToTelegram(text: message) { success in
            completion(success)
        }
    }

    private func sendAllVoiceNotes(
        voiceNotes: [String],
        completion: @escaping (Bool) -> Void
    ) {
        var index = 0
        func sendNext(successSoFar: Bool) {
            if index >= voiceNotes.count {
                completion(successSoFar)
                return
            }
            let path = voiceNotes[index]
            let url = URL(fileURLWithPath: path)
            sendSingleVoice(voiceURL: url) { success in
                index += 1
                sendNext(successSoFar: successSoFar && success)
            }
        }
        sendNext(successSoFar: true)
    }

    private func sendSingleVoice(
        voiceURL: URL,
        completion: @escaping (Bool) -> Void
    ) {
        // Получаем актуальный chat_id из UserDefaults и сервис из DI
        guard let chatId = UserDefaultsManager.shared.string(forKey: "telegramChatId"), !chatId.isEmpty else {
            completion(false)
            return
        }
        guard let telegramService = DependencyContainer.shared.resolve(TelegramServiceProtocol.self) else {
            completion(false)
            return
        }
        Task {
            do {
                try await telegramService.sendVoice(voiceURL, caption: nil, to: chatId)
                await MainActor.run { completion(true) }
            } catch {
                await MainActor.run { completion(false) }
            }
        }
    }
}

#Preview {
    DailyPlanCAView()
}

#Preview("DailyReportCAView - Status Done") {
    DailyReportCAView()
}

private func createStoreWithDoneStatus() -> PostStore {
    let store = PostStore()
    store.reportStatus = .sent
    return store
} 