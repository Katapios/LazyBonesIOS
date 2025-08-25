// DailyPlanningFormView.swift
// LazyBones
//
// Created by Денис Рюмин on 2025-07-10.

import SwiftUI

struct DailyPlanningFormView: View {
    @EnvironmentObject var store: PostStore
    @State private var selectedTab = 0 // По умолчанию открывается первый экран (третий экран)
    
    var postForToday: Post? {
        store.posts.first(where: { Calendar.current.isDateInToday($0.date) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Кастомный заголовок ---
            HStack {
                Text(getTitleForTab(selectedTab))
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
                Circle()
                    .fill(selectedTab == 2 ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 4)
            // --- TabView ---
            TabView(selection: $selectedTab) {
                // Первый экран — отчет за день (с голосовыми заметками)
                DailyReportView()
                    .tag(0)
                // Второй экран — план на день
                PlanningContentView()
                    .tag(1)
                // Третий экран — План за день (CA)
                DailyPlanCAView()
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onAppear {
                // Гарантируем инициализацию тегов при показе формы через TagProvider
                Task {
                    let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                    await provider?.refresh()
                }
            }
        }
    }
    
    private func getTitleForTab(_ tab: Int) -> String {
        switch tab {
        case 0: return "Отчет за день"
        case 1: return "План на день"
        case 2: return "План за день"
        default: return "Отчет за день"
        }
    }
}

// Весь старый функционал вынесен во вложенную вью
struct PlanningContentView: View {
    @EnvironmentObject var store: PostStore
    @StateObject private var viewModel: PlanningViewModel
    @State private var tagsVersion: Int = 0

    // Нормализация тега: убираем возможные префиксы эмодзи и пробелы
    private func normalizeTag(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("✅ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        if trimmed.hasPrefix("❌ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        return trimmed
    }

    init() {
        // PostStore берется из Environment в onAppear, поэтому инициализируем временно
        // и переинициализируем в onAppear, когда store доступен
        _viewModel = StateObject(wrappedValue: PlanningViewModel(store: PostStore.shared))
    }
    
    var body: some View {
        VStack {
            planSection
        }
        .hideKeyboardOnTap()
        .onAppear {
            // Синхронизируем VM со store из окружения и запускаем lifecycle
            if viewModel.store !== store { viewModel.store = store }
            viewModel.onAppear()
        }
        .onChange(of: Calendar.current.startOfDay(for: Date()), initial: false) { _, _ in
            viewModel.handleDayChangeIfNeeded()
        }
    }
    
    // MARK: - План
    var planSection: some View {
        VStack(spacing: 16) {
            // --- Список пунктов плана ---
            List {
                ForEach(viewModel.planItems.indices, id: \.self) { idx in
                    HStack {
                        if viewModel.editingPlanIndex == idx {
                            TextField("Пункт", text: $viewModel.editingPlanText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("OK") { viewModel.finishEditPlanItem() }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Text(viewModel.planItems[idx])
                            Spacer()
                            Button(action: { viewModel.startEditPlanItem(idx) }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Button(action: { viewModel.planToDeleteIndex = idx; viewModel.showDeletePlanAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Поле ввода с TagPicker
            VStack(spacing: 8) {
                HStack {
                    TextField("Добавить пункт плана", text: $viewModel.newPlanItem)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: { withAnimation(.easeInOut(duration: 0.3)) { viewModel.showTagPicker.toggle() } }) {
                        Image(systemName: "tag")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    Button(action: viewModel.addPlanItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }.disabled(viewModel.newPlanItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // TagPicker выезжает справа
                if viewModel.showTagPicker, !viewModel.planTags.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        TagPickerUIKitWheel(
                            tags: viewModel.planTags,
                            selectedIndex: $viewModel.pickerIndex
                        ) { _ in }
                        .id("plan-wheel-\(tagsVersion)")
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            maxHeight: 160
                        )
                        .clipped()
                        
                        // Безопасная коррекция индекса, чтобы избежать падения при изменении списка тегов
                        let safeIndex = min(max(0, viewModel.pickerIndex), max(viewModel.planTags.count - 1, 0))
                        let selectedTag = viewModel.planTags[safeIndex]
                        let isTagAdded = viewModel.planItems.contains(where: { $0 == selectedTag.text })
                        Button(action: {
                            if (!isTagAdded) {
                                viewModel.planItems.append(selectedTag.text)
                                viewModel.savePlan()
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
                
                // Показываем prompt для сохранения тега (через TagProvider)
                let newText = normalizeTag(viewModel.newPlanItem)
                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                let existsInProvider = provider?.goodTags.contains(newText) ?? false
                if !newText.isEmpty && !existsInProvider {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            let trimmed = newText.trimmingCharacters(in: .whitespaces)
                            Task {
                                let repo = DependencyContainer.shared.resolve(TagRepositoryProtocol.self)
                                let provider = DependencyContainer.shared.resolve(TagProviderProtocol.self)
                                try? await repo?.addGoodTag(trimmed)
                                await provider?.refresh()
                                await MainActor.run {
                                    // Форс перерисовку колеса и выставление индекса на сохранённый тег
                                    tagsVersion += 1
                                    if let arr = provider?.goodTags, let idx = arr.firstIndex(of: trimmed) {
                                        viewModel.pickerIndex = idx
                                    } else {
                                        viewModel.pickerIndex = 0
                                    }
                                }
                            }
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
            if !viewModel.planItems.isEmpty {
                HStack(spacing: 12) {
                    LargeButtonView(
                        title: "Сохранить",
                        icon: "tray.and.arrow.down.fill",
                        color: .blue,
                        action: { viewModel.showSaveAlert = true },
                        isEnabled: true,
                        compact: true
                    )
                    LargeButtonView(
                        title: "Отправить",
                        icon: "paperplane.fill",
                        color: .green,
                        action: { viewModel.publishCustomReportToTelegram() },
                        isEnabled: true,
                        compact: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                if let status = viewModel.publishStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(status.contains("успешно") ? .green : .red)
                }
            }
        }
        .padding()
        .alert("Сохранить план как отчет?", isPresented: $viewModel.showSaveAlert) {
            Button("Сохранить", role: .none) { viewModel.savePlanAsReport() }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Удалить пункт плана?", isPresented: $viewModel.showDeletePlanAlert) {
            Button("Удалить", role: .destructive) { viewModel.deletePlanItem() }
            Button("Отмена", role: .cancel) { viewModel.planToDeleteIndex = nil }
        }
    }
}

#Preview {
    DailyPlanningFormView()
        .environmentObject(PostStore())
}
