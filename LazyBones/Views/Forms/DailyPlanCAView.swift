import SwiftUI

struct DailyPlanCAView: View {
    @EnvironmentObject var store: PostStore
    @StateObject private var viewModel = DailyPlanCAViewModel()
    @State private var tagsVersion: Int = 0

    // Нормализация тега как в легаси
    private func normalizeTag(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("✅ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        if trimmed.hasPrefix("❌ ") { return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
        return trimmed
    }

    var body: some View {
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

            // Поле ввода + TagPicker
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

                if viewModel.showTagPicker, !viewModel.planTags.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        TagPickerUIKitWheel(
                            tags: viewModel.planTags,
                            selectedIndex: $viewModel.pickerIndex
                        ) { _ in }
                        .id("plan-ca-wheel-\(tagsVersion)")
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 120,
                            maxHeight: 160
                        )
                        .clipped()

                        let safeIndex = min(max(0, viewModel.pickerIndex), max(viewModel.planTags.count - 1, 0))
                        if viewModel.planTags.indices.contains(safeIndex) {
                            let selectedTag = viewModel.planTags[safeIndex]
                            let isTagAdded = viewModel.planItems.contains(where: { $0 == selectedTag.text })
                            Button(action: {
                                if !isTagAdded {
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
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // Prompt на сохранение нового тега (через TagRepository + TagProvider)
                let newText = normalizeTag(viewModel.newPlanItem)
                // Временно определяем существование тега по локальному списку, позже заменим на провайдер
                let existsInProvider = viewModel.planTags.contains(where: { $0.text == newText })
                if !newText.isEmpty && !existsInProvider {
                    HStack {
                        Text("Сохранить тег?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Сохранить") {
                            viewModel.saveNewTag(newText)
                            tagsVersion += 1 // форсим перерисовку колесика
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
        .hideKeyboardOnTap()
        .onAppear { viewModel.onAppear() }
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
    DailyPlanCAView()
        .environmentObject(PostStore())
}
