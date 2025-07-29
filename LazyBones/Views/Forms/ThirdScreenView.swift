import SwiftUI

struct ThirdScreenView: View {
    @EnvironmentObject var store: PostStore
    @State private var planItems: [String] = [
        "Моковый пункт 1",
        "Моковый пункт 2", 
        "Моковый пункт 3",
        "Еще один моковый пункт",
        "И еще один для полноты"
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
        [
            TagItem(text: "Моковый хороший тег 1", icon: "tag", color: .green),
            TagItem(text: "Моковый хороший тег 2", icon: "tag", color: .green),
            TagItem(text: "Моковый хороший тег 3", icon: "tag", color: .green)
        ]
    }
    
    var badTags: [TagItem] {
        [
            TagItem(text: "Моковый плохой тег 1", icon: "tag", color: .red),
            TagItem(text: "Моковый плохой тег 2", icon: "tag", color: .red),
            TagItem(text: "Моковый плохой тег 3", icon: "tag", color: .red)
        ]
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
                planItems = []
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
                ForEach(planItems.indices, id: \.self) { idx in
                    HStack {
                        if editingPlanIndex == idx {
                            TextField("Пункт", text: $editingPlanText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") { finishEditPlanItem() }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(planItems[idx])
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
                        let isTagAdded = planItems.contains(where: { $0 == selectedTag.text })
                        Button(action: {
                            if (!isTagAdded) {
                                planItems.append(selectedTag.text)
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
                if !newPlanItem.isEmpty && !planTags.contains(where: { $0.text == newPlanItem }) {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            // В моковом экране просто добавляем в локальный массив
                            planItems.append(newPlanItem)
                            savePlan()
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
            if !planItems.isEmpty {
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
        planItems = [
            "Моковый пункт 1",
            "Моковый пункт 2", 
            "Моковый пункт 3",
            "Еще один моковый пункт",
            "И еще один для полноты"
        ]
    }
    
    func addPlanItem() {
        let trimmed = newPlanItem.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems.append(trimmed)
        newPlanItem = ""
        savePlan()
    }
    
    func startEditPlanItem(_ idx: Int) {
        editingPlanIndex = idx
        editingPlanText = planItems[idx]
    }
    
    func finishEditPlanItem() {
        guard let idx = editingPlanIndex else { return }
        let trimmed = editingPlanText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        planItems[idx] = trimmed
        editingPlanIndex = nil
        editingPlanText = ""
        savePlan()
    }
    
    func deletePlanItem() {
        guard let idx = planToDeleteIndex else { return }
        planItems.remove(at: idx)
        planToDeleteIndex = nil
        savePlan()
    }
    
    func savePlan() {
        let key = "third_screen_plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = try? JSONEncoder().encode(planItems) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func savePlanAsReport() {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = store.posts.firstIndex(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            let updated = Post(
                id: store.posts[idx].id,
                date: Date(),
                goodItems: planItems,
                badItems: [],
                published: true,
                voiceNotes: voiceNotes,
                type: .custom,
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
                goodItems: planItems,
                badItems: [],
                published: true,
                voiceNotes: voiceNotes,
                type: .custom,
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
        guard let custom = store.posts.first(where: { $0.type == .custom && Calendar.current.isDate($0.date, inSameDayAs: today) }) else {
            publishStatus = "Сначала сохраните план как отчет!"
            return
        }
        if custom.isEvaluated != true {
            publishStatus = "Сначала оцените план!"
            return
        }
        guard let token = store.telegramToken, let chatId = store.telegramChatId, !token.isEmpty, !chatId.isEmpty else {
            publishStatus = "Заполните токен и chat_id в настройках"
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: custom.date)
        let deviceName = store.getDeviceName()
        var message = "\u{1F4C5} <b>Третий экран - план на день за \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !custom.goodItems.isEmpty {
            message += "<b>✅ План:</b>\n"
            for (index, item) in custom.goodItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
        }
        
        if custom.voiceNotes.count > 0 {
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