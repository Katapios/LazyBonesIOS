import SwiftUI

struct AddReportItemView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    @Environment(\.dismiss) var dismiss
    
    let isGood: Bool
    @State private var text: String = ""
    @StateObject private var dictationService = WatchDictationService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(isGood ? "Добавить хорошее" : "Добавить плохое")
                    .font(.headline)
                    .padding(.top)
                
                // Голосовой ввод через системную диктовку watchOS
                Button(action: {
                    requestVoiceInput()
                }) {
                    HStack {
                        Image(systemName: dictationService.isDictating ? "mic.fill" : "mic")
                        Text(dictationService.isDictating ? "Диктовка..." : "Голосовой ввод")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(dictationService.isDictating ? .red : (isGood ? .green : .red))
                .disabled(dictationService.isDictating)
                
                // Индикатор диктовки
                if dictationService.isDictating {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Говорите...")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Текстовый ввод
                TextField("Введите текст", text: $text, axis: .vertical)
                    .textFieldStyle(.automatic)
                    .lineLimit(3...6)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                // Кнопка сохранения
                Button(action: {
                    saveItem()
                }) {
                    Label("Сохранить", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle(isGood ? "Хорошее" : "Плохое")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: dictationService.recognizedText) { newValue in
            if !newValue.isEmpty {
                text = newValue
            }
        }
    }
    
    private func requestVoiceInput() {
        // Используем системную диктовку watchOS
        dictationService.startDictation { recognizedText in
            Task { @MainActor in
                if let text = recognizedText, !text.isEmpty {
                    self.text = text
                } else {
                    // Если распознавание не удалось, показываем сообщение
                    if let error = dictationService.errorMessage {
                        print("[WatchApp] Ошибка диктовки: \(error)")
                    }
                }
            }
        }
    }
    
    private func saveItem() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        viewModel.sendReportItem(trimmedText, isGood: isGood)
        dismiss()
    }
}

