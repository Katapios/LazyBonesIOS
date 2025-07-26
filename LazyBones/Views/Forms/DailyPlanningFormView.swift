// DailyPlanningFormView.swift
// LazyBones
//
// Created by Денис Рюмин on 2025-07-10.

import SwiftUI

struct DailyPlanningFormView: View {
    @EnvironmentObject var store: PostStore
    @State private var selectedTab = 0 // По умолчанию открывается первый экран (локальный отчет)
    
    var postForToday: Post? {
        store.posts.first(where: { Calendar.current.isDateInToday($0.date) && !$0.published })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Кастомный заголовок ---
            HStack {
                Text(selectedTab == 0 ? "Отчёт за день" : "План на день")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 4)
            // --- Индикаторы свайпа ---
            HStack(spacing: 8) {
                Circle()
                    .fill(selectedTab == 0 ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedTab == 1 ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 4)
            // --- TabView ---
            TabView(selection: $selectedTab) {
                // Первый экран — форма создания/редактирования отчета
                PostFormView(post: postForToday)
                    .tag(0)
                // Второй экран — весь старый функционал
                PlanningContentView()
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

// Весь старый функционал вынесен во вложенную вью
struct PlanningContentView: View {
    @EnvironmentObject var store: PostStore
    @State private var planItems: [String] = []
    @State private var newPlanItem: String = ""
    @State private var editingPlanIndex: Int? = nil
    @State private var editingPlanText: String = ""
    @State private var showSaveAlert = false
    @State private var showDeletePlanAlert = false
    @State private var planToDeleteIndex: Int? = nil
    @State private var lastPlanDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var publishStatus: String? = nil
    
    var body: some View {
        VStack {
            planSection
        }
        .hideKeyboardOnTap()
        .onAppear {
            loadPlan()
            lastPlanDate = Calendar.current.startOfDay(for: Date())
        }
        .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { oldDay, newDay in
            if newDay != lastPlanDate {
                planItems = []
                savePlan()
                lastPlanDate = newDay
            }
        }
        .alert("Сохранить план как отчет?", isPresented: $showSaveAlert) {
            Button("Сохранить", role: .none) { savePlanAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { deletePlanItem() }
            Button("Отмена", role: .cancel) { planToDeleteIndex = nil }
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Добавить пункт плана", text: $newPlanItem)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addPlanItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }.disabled(newPlanItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
            }
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
                        action: { publishCustomReportToTelegram() },
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
    }
    
    // MARK: - Functions
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
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = try? JSONEncoder().encode(planItems) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    func loadPlan() {
        let key = "plan_" + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            planItems = decoded
        } else {
            planItems = []
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
                voiceNotes: [],
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
                voiceNotes: [],
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
    func publishCustomReportToTelegram() {
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
        var message = "\u{1F4C5} <b>План на день за \(dateStr)</b>\n"
        message += "\u{1F4F1} <b>Устройство: \(deviceName)</b>\n\n"
        if !custom.goodItems.isEmpty {
            message += "<b>✅ План:</b>\n"
            for (index, item) in custom.goodItems.enumerated() {
                message += "\(index + 1). \(item)\n"
            }
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
    DailyPlanningFormView()
        .environmentObject(PostStore())
}
