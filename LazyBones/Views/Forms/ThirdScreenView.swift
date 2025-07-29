import SwiftUI

struct ThirdScreenPlanData: Codable {
    let goodItems: [String]
    let badItems: [String]
}

struct ThirdScreenView: View {
    @EnvironmentObject var store: PostStore
    @State private var goodItems: [ChecklistItem] = [
        ChecklistItem(id: UUID(), text: "Моковый хороший пункт 1"),
        ChecklistItem(id: UUID(), text: "Моковый хороший пункт 2"),
        ChecklistItem(id: UUID(), text: "Моковый хороший пункт 3")
    ]
    @State private var badItems: [ChecklistItem] = [
        ChecklistItem(id: UUID(), text: "Моковый плохой пункт 1"),
        ChecklistItem(id: UUID(), text: "Моковый плохой пункт 2")
    ]
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
    
    enum TabType { case good, bad }
    
    var goodTags: [TagItem] {
        store.goodTags.map { TagItem(text: $0, icon: "tag", color: .green) }
    }
    
    var badTags: [TagItem] {
        store.badTags.map { TagItem(text: $0, icon: "tag", color: .red) }
    }
    
    var planTags: [TagItem] {
        selectedTab == .good ? goodTags : badTags
    }
    
    var body: some View {
        VStack {
            planSection
        }
        .hideKeyboardOnTap()
        .onAppear {
            // Загружаем моковые данные при появлении
            loadMockData()
            lastPlanDate = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { oldDay, newDay in
            if newDay != lastPlanDate {
                goodItems = []
                badItems = []
                savePlan()
                lastPlanDate = newDay
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
                
                // --- ЗОНА VOICE внутри List ---
                Section {
                    VoiceRecorderListView(voiceNotes: $voiceNotes)
                }
            }
            
            // Поле ввода с TagPicker
            VStack(spacing: 8) {
                HStack {
                    TextField("Добавить пункт плана", text: $newPlanItem)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showTagPicker.toggle() } }) {
                        Image(systemName: "tag")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    Button(action: addPlanItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
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
                                Text("\(goodTags.count)")
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
                                Text("\(badTags.count)")
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
                        .id(selectedTab) // Пересоздаем при смене вкладки
                        
                        let selectedTag = planTags[pickerIndex]
                        let isTagAdded = (selectedTab == .good ? goodItems : badItems).contains(where: { $0.text == selectedTag.text })
                        Button(action: {
                            if (!isTagAdded) {
                                if selectedTab == .good {
                                    goodItems.append(ChecklistItem(id: UUID(), text: selectedTag.text))
                                } else {
                                    badItems.append(ChecklistItem(id: UUID(), text: selectedTag.text))
                                }
                                savePlan()
                            }
                        }) {
                            Image(systemName: isTagAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(isTagAdded ? .green : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Показываем prompt для сохранения тега
                if !newPlanItem.isEmpty && !(selectedTab == .good ? store.goodTags : store.badTags).contains(newPlanItem) {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            if selectedTab == .good {
                                store.addGoodTag(newPlanItem)
                            } else {
                                store.addBadTag(newPlanItem)
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
                        action: { publishMockReportToTelegram() },
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
            Button("Сохранить", role: .none) { savePlanAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { deletePlanItem() }
            Button("Отмена", role: .cancel) { planToDeleteIndex = nil }
        }
    }
    
    // MARK: - Functions
    func loadMockData() {
        // Загружаем моковые данные
        goodItems = [
            ChecklistItem(id: UUID(), text: "Моковый хороший пункт 1"),
            ChecklistItem(id: UUID(), text: "Моковый хороший пункт 2"),
            ChecklistItem(id: UUID(), text: "Моковый хороший пункт 3")
        ]
        badItems = [
            ChecklistItem(id: UUID(), text: "Моковый плохой пункт 1"),
            ChecklistItem(id: UUID(), text: "Моковый плохой пункт 2")
        ]
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
            badItems: badItems.map { $0.text }
        )
        if let data = try? JSONEncoder().encode(planData) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func savePlanAsReport() {
        let today = Calendar.current.startOfDay(for: Date())
        let filteredGood = goodItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let filteredBad = badItems.map { $0.text }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        if let idx = store.posts.firstIndex(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: filteredGood,
                badItems: filteredBad,
                published: true,
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
                published: true,
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
        savePlan()
    }
    
    func publishMockReportToTelegram() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let regular = store.posts.first(where: { $0.type == .regular && Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
            publishStatus = "Сначала сохраните план как отчет!"
            return
        }
        guard let token = store.telegramToken, let chatId = store.telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            publishStatus = "Заполните токен и chat_id в настройках"
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: regular.date)
        let deviceName = store.getDeviceName()
        var message = "\u{1F4C5} <b>Третий экран - отчет за \(dateStr)</b>\n"
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
        
        if regular.voiceNotes.count > 0 {
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
            publishStatus = "Ошибка формирования URL"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    publishStatus = "Ошибка отправки: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    publishStatus = "План успешно опубликован!"
                } else {
                    publishStatus = "Ошибка отправки: неверный токен или chat_id"
                }
            }
        }
        task.resume()
    }
}

#Preview {
    ThirdScreenView()
        .environmentObject(PostStore())
} 