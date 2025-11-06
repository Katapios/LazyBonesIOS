import SwiftUI
import AVFoundation

struct ThirdScreenPlanData: Codable {
    let goodItems: [String]
    let badItems: [String]
    let voiceNotes: [VoiceNote]
}

@available(*, deprecated, message: "Use DailyReportCAView instead")
struct DailyReportView: View {
    @EnvironmentObject var store: PostStore
    @State private var goodItems: [ChecklistItem] = []
    @State private var badItems: [ChecklistItem] = []
    @State private var newPlanItem: String = ""
    @State private var editingPlanIndex: Int? = nil
    @State private var editingPlanText: String = ""
    @State private var showSaveAlert = false
    @State private var showDeletePlanAlert = false
    @State private var planToDeleteIndex: Int? = nil
    @State private var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var publishStatus: String? = nil
    @State private var pickerIndex: Int = 0
    @State private var showTagPicker: Bool = false
    @State private var tagPickerOffset: CGFloat = 0
    @State private var selectedTab: TabType = .good
    @State private var voiceNotes: [VoiceNote] = []
    @State private var showVoiceRecorder: Bool = false
    // Локальные теги и версия для форс-перерисовки колеса
    @State private var currentGoodRawTags: [String] = []
    @State private var currentBadRawTags: [String] = []
    @State private var tagsVersion: Int = 0
    
    // Источник тегов: резолвим провайдера на каждый вызов (избегаем устаревшего инстанса)
    
    enum TabType { case good, bad }
    
    var goodTags: [TagItem] {
        currentGoodRawTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    var badTags: [TagItem] {
        currentBadRawTags.map { TagItem(text: $0, icon: "tag", color: .red) }
    }
    
    var planTags: [TagItem] {
        selectedTab == .good ? goodTags : badTags
    }
    
    var body: some View {
        if store.reportStatus == .sent || store.reportStatus == .notCreated || store.reportStatus == .notSent {
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
            VStack {
                planSection
            }
            .hideKeyboardOnTap()
            .onAppear {
                // Загружаем сохраненные данные при появлении
                // Теги берём через TagProvider; убираем прямую загрузку из стора
                loadSavedData()
                lastPlanDate = Calendar.current.startOfDay(for: Date())
                // Инициализируем локальные теги и обновляем провайдер (единый источник)
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
            .onChange(of: showTagPicker, initial: false) { oldVal, newVal in
                if newVal {
                    // При открытии пикера теги должны быть актуальны
                    reloadTagsFromProvider()
                    tagsVersion &+= 1
                }
            }
            .onChange(of: selectedTab, initial: false) { _, _ in
                // Переключение вкладок — обновляем теги и пересоздаём колесо
                reloadTagsFromProvider()
                tagsVersion &+= 1
                pickerIndex = 0
            }
            .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { oldDay, newDay in
                if newDay != lastPlanDate {
                    goodItems = []
                    badItems = []
                    voiceNotes = []
                    savePlan()
                    lastPlanDate = newDay
                }
            }
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(spacing: 16) {
            // --- Список пунктов плана ---
            List {
                if selectedTab == .good {
                    ForEach(goodItems.indices, id: \.self) { idx in
                        HStack {
                            if editingPlanIndex == idx {
                                TextField("Пункт", text: $editingPlanText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button("OK") { finishEditPlanItem() }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text(goodItems[idx].text)
                                Spacer()
                                Button(action: { startEditPlanItem(idx) }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Button(action: { planToDeleteIndex = idx; showDeletePlanAlert = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                } else {
                    ForEach(badItems.indices, id: \.self) { idx in
                        HStack {
                            if editingPlanIndex == idx {
                                TextField("Пункт", text: $editingPlanText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button("OK") { finishEditPlanItem() }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text(badItems[idx].text)
                                Spacer()
                                Button(action: { startEditPlanItem(idx) }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Button(action: { planToDeleteIndex = idx; showDeletePlanAlert = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            

            
            // Поле ввода с TagPicker
            VStack(spacing: 8) {
                HStack {
                    TextField("Добавить пункт плана", text: $newPlanItem)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // Иконки микрофона и тега рядом
                    HStack(spacing: 8) {
                        // Голосовой ввод (распознавание речи)
                        VoiceInputButton(
                            text: $newPlanItem,
                            isGood: selectedTab == .good
                        )
                        
                        // Запись аудио (старая кнопка)
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) { 
                                showVoiceRecorder.toggle()
                                if showVoiceRecorder {
                                    showTagPicker = false
                                }
                            } 
                        }) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(showVoiceRecorder ? .red : .accentColor)
                        }
                        
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) { 
                                showTagPicker.toggle()
                                if showTagPicker {
                                    showVoiceRecorder = false
                                }
                            } 
                        }) {
                            Image(systemName: "tag.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(showTagPicker ? .blue : .accentColor)
                        }
                    }
                    
                    Button(action: addPlanItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                    }.disabled(newPlanItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // --- Переключатель good/bad тегов ---
                HStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Button(action: {
                            selectedTab = .good
                            pickerIndex = 0
                        }) {
                            HStack(spacing: 2) {
                                Text("👍 молодец")
                                    .font(.system(size: 14.3, weight: .bold))
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTab == .good ? Color.green.opacity(0.12) : Color.clear)
                            .cornerRadius(8)
                        }
                        Button(action: {
                            selectedTab = .bad
                            pickerIndex = 0
                        }) {
                            HStack(spacing: 2) {
                                Text("👎 лаботряс")
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
                .padding(.vertical, 6)
                
                // TagPicker выезжает справа
                if showTagPicker, !planTags.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        TagPickerUIKitWheel(
                            tags: planTags,
                            selectedIndex: $pickerIndex
                        ) { _ in }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            maxHeight: 160
                        )
                        .clipped()
                        .id("\(selectedTab)-\(tagsVersion)") // Пересоздаем при смене вкладки/версии тегов
                        
                        // Кнопка добавления/подтверждения для выбранного тега
                        if let tag = currentSelectedTag() {
                            let added = isTagAlreadyAdded(tag)
                            Button(action: {
                                if !added {
                                    if selectedTab == .good {
                                        goodItems.append(ChecklistItem(id: UUID(), text: tag.text))
                                    } else {
                                        badItems.append(ChecklistItem(id: UUID(), text: tag.text))
                                    }
                                    savePlan()
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // VoiceRecorder выезжает вместо TagPicker
                if showVoiceRecorder {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Голосовые заметки")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showVoiceRecorder = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Существующие голосовые заметки
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
                                            savePlan()
                                        },
                                        isFirst: voiceNotes.first?.id == note.id
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            // Сообщение когда нет голосовых заметок
                            HStack {
                                Image(systemName: "mic.slash")
                                    .foregroundColor(.gray)
                                Text("Создайте первую голосовую заметку на сегодня")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Кнопка добавления новой заметки
                        Button(action: {
                            voiceNotes.append(VoiceNote(id: UUID(), path: ""))
                            savePlan()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Добавить голосовую заметку")
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Показываем prompt для сохранения тега (через репозиторий + refresh провайдера)
                if !newPlanItem.isEmpty && !(selectedTab == .good ? currentGoodRawTags : currentBadRawTags).contains(newPlanItem) {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
                            let tagToSave = newPlanItem // важно зафиксировать до addPlanItem()
                            if selectedTab == .good {
                                Task {
                                    print("[DailyReportView] willAddTag good=\(tagToSave)")
                                    try? await repo?.addGoodTag(tagToSave)
                                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                    await provider?.refresh()
                                    let afterGood = provider?.goodTags.count ?? -1
                                    let afterBad = provider?.badTags.count ?? -1
                                    print("[DailyReportView] providerAfterRefresh good=\(afterGood) bad=\(afterBad)")
                                    await MainActor.run {
                                        reloadTagsFromProvider()
                                        print("[DailyReportView] afterReload good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) firstGood=\(currentGoodRawTags.first ?? "-") firstBad=\(currentBadRawTags.first ?? "-")")
                                        tagsVersion &+= 1
                                    }
                                }
                            } else {
                                Task {
                                    print("[DailyReportView] willAddTag bad=\(tagToSave)")
                                    try? await repo?.addBadTag(tagToSave)
                                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                    await provider?.refresh()
                                    let afterGood = provider?.goodTags.count ?? -1
                                    let afterBad = provider?.badTags.count ?? -1
                                    print("[DailyReportView] providerAfterRefresh good=\(afterGood) bad=\(afterBad)")
                                    await MainActor.run {
                                        reloadTagsFromProvider()
                                        print("[DailyReportView] afterReload good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) firstGood=\(currentGoodRawTags.first ?? "-") firstBad=\(currentBadRawTags.first ?? "-")")
                                        tagsVersion &+= 1
                                    }
                                }
                            }
                            addPlanItem()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            
            // Кнопки действий
            if !goodItems.isEmpty || !badItems.isEmpty {
                HStack(spacing: 12) {
                    LargeButtonView(
                        title: "Сохранить",
                        icon: "tray.and.arrow.down.fill",
                        color: .blue,
                        action: { showSaveAlert = true },
                        isEnabled: true,
                        compact: true
                    )
                    LargeButtonView(
                        title: "Отправить",
                        icon: "paperplane.fill",
                        color: .green,
                        action: { publishReportToTelegram() },
                        isEnabled: true,
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                if let status = publishStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("успешно") ? .green : .red)
                }
            }
        }
        .padding()
        .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
                                    Button("Сохранить", role: .none) { saveAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { deletePlanItem() }
            Button("Отмена", role: .cancel) { planToDeleteIndex = nil }
        }
    }
    
    // MARK: - Functions
    func reloadTagsFromProvider() {
        let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
        let good = provider?.goodTags ?? store.goodTags
        let bad = provider?.badTags ?? store.badTags
        currentGoodRawTags = good
        currentBadRawTags = bad
        // Безопасно корректируем индекс после обновления источника
        let count = (selectedTab == .good ? currentGoodRawTags.count : currentBadRawTags.count)
        if count == 0 {
            pickerIndex = 0
        } else if pickerIndex >= count {
            pickerIndex = 0
        }
        // DEBUG
        print("[DailyReportView] reloadTagsFromProvider: good=\(currentGoodRawTags.count) bad=\(currentBadRawTags.count) sel=\(selectedTab) idx=\(pickerIndex) ver=\(tagsVersion)")
    }

    // MARK: - TagPicker helpers (вынесены из body для облегчения тип-чекинга)
    func safePickerIndex() -> Int {
        let count = planTags.count
        guard count > 0 else { return 0 }
        return min(max(0, pickerIndex), max(count - 1, 0))
    }
    func currentSelectedTag() -> TagItem? {
        let count = planTags.count
        guard count > 0 else { return nil }
        let idx = safePickerIndex()
        return planTags[idx]
    }
    func isTagAlreadyAdded(_ tag: TagItem) -> Bool {
        if selectedTab == .good {
            return goodItems.contains(where: { $0.text == tag.text })
        } else {
            return badItems.contains(where: { $0.text == tag.text })
        }
    }
    func loadSavedData() {
        let key = "third_screen_plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        
        // Пытаемся загрузить сохраненные данные
        if let data = UserDefaults.standard.data(forKey: key),
           let planData = try? JSONDecoder().decode(ThirdScreenPlanData.self, from: data) {
            // Загружаем сохраненные данные
            goodItems = planData.goodItems.map { ChecklistItem(id: UUID(), text: $0) }
            badItems = planData.badItems.map { ChecklistItem(id: UUID(), text: $0) }
            voiceNotes = planData.voiceNotes
        } else {
            // Инициализируем пустые данные
            goodItems = []
            badItems = []
            voiceNotes = []
        }
    }
    
    func addPlanItem() {
        let trimmed = newPlanItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if selectedTab == .good {
            goodItems.append(ChecklistItem(id: UUID(), text: trimmed))
        } else {
            badItems.append(ChecklistItem(id: UUID(), text: trimmed))
        }
        newPlanItem = ""
        savePlan()
    }
    
    func startEditPlanItem(_ idx: Int) {
        editingPlanIndex = idx
        if selectedTab == .good {
            editingPlanText = goodItems[idx].text
        } else {
            editingPlanText = badItems[idx].text
        }
    }
    
    func finishEditPlanItem() {
        guard let idx = editingPlanIndex else { return }
        let trimmed = editingPlanText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        if selectedTab == .good {
            goodItems[idx].text = trimmed
        } else {
            badItems[idx].text = trimmed
        }
        editingPlanIndex = nil
        editingPlanText = ""
        savePlan()
    }
    
    func deletePlanItem() {
        guard let idx = planToDeleteIndex else { return }
        if selectedTab == .good {
            goodItems.remove(at: idx)
        } else {
            badItems.remove(at: idx)
        }
        planToDeleteIndex = nil
        savePlan()
    }
    
    func savePlan() {
        let key = "third_screen_plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let planData = ThirdScreenPlanData(
            goodItems: goodItems.map { $0.text },
            badItems: badItems.map { $0.text },
            voiceNotes: voiceNotes
        )
        if let data = try? JSONEncoder().encode(planData) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func saveAsReport() {
        let today = Calendar.current.startOfDay(for: Date())
        let filteredGood = goodItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let filteredBad = badItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        

        
        if let idx = store.posts.firstIndex(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: filteredGood,
                badItems: filteredBad,
                published: false,
                voiceNotes: voiceNotes,
                type: .regular,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.posts[idx] = updated
            store.save()
        } else {
            let post = Post(
                id: UUID(),
                date: Date(),
                goodItems: filteredGood,
                badItems: filteredBad,
                published: false,
                voiceNotes: voiceNotes,
                type: .regular,
                authorUsername: nil,
                authorFirstName: nil,
                authorLastName: nil,
                isExternal: false,
                externalVoiceNoteURLs: nil,
                externalText: nil,
                externalMessageId: nil,
                authorId: nil
            )
            store.add(post: post)
        }
        // Очищаем статус публикации при сохранении
        publishStatus = nil
        savePlan()
    }
    
    func publishReportToTelegram() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let regular = store.posts.first(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
            publishStatus = "Сначала сохраните план как отчет!"
            return
        }
        
        // Загружаем настройки Telegram и отправляем текст через сервис
        store.loadTelegramSettings()
        // Формируем текст сообщения локально
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: regular.date)
        let deviceName = store.getDeviceName()
        var message = "\u{1F4C5} <b>Отчет за день - \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !regular.goodItems.isEmpty {
            message += "<b>✅ Я молодец:</b>\n"
            for (index, item) in regular.goodItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
            message += "\n"
        }
        if !regular.badItems.isEmpty {
            message += "<b>❌ Я не молодец:</b>\n"
            for (index, item) in regular.badItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
        }
        let validVoicePaths = regular.voiceNotes
            .map { $0.path }
            .filter { FileManager.default.fileExists(atPath: $0) }
        if !validVoicePaths.isEmpty {
            message += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
        }

        store.publish(text: message, voicePaths: validVoicePaths) { success in
            DispatchQueue.main.async {
                if success {
                    if let idx = self.store.posts.firstIndex(where: { $0.id == regular.id }) {
                        var updated = self.store.posts[idx]
                        updated.published = true
                        self.store.posts[idx] = updated
                        self.store.save()
                        self.store.updateReportStatus()
                    }
                    self.publishStatus = validVoicePaths.isEmpty ? "Отчет успешно опубликован!" : "Отчет успешно опубликован с голосовыми заметками!"
                } else {
                    self.publishStatus = validVoicePaths.isEmpty ? "Ошибка отправки" : "Ошибка отправки голосовых заметок"
                }
            }
        }
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
        var message = "\u{1F4C5} <b>Отчет за день - \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !post.goodItems.isEmpty {
            message += "<b>✅ Я молодец:</b>\n"
            for (index, item) in post.goodItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
            message += "\n"
        }
        if !post.badItems.isEmpty {
            message += "<b>❌ Я не молодец:</b>\n"
            for (index, item) in post.badItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
        }
        
        // Показываем метку о голосовой заметке только если файл(ы) существуют
        let hasExistingVoices = post.voiceNotes
            .map { $0.path }
            .contains { FileManager.default.fileExists(atPath: $0) }
        if hasExistingVoices {
            message += "\n\u{1F3A4} <i>Голосовая заметка прикреплена</i>"
        }
        
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
    DailyReportCAView()
} 