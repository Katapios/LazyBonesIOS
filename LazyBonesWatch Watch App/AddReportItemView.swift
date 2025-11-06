import SwiftUI

struct AddReportItemView: View {
    @EnvironmentObject var viewModel: WatchMainViewModel
    @Environment(\.dismiss) var dismiss
    
    let isGood: Bool
    @State private var text: String = ""
    @State private var isRecording: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(isGood ? "Добавить хорошее" : "Добавить плохое")
                    .font(.headline)
                    .padding(.top)
                
                // Голосовой ввод
                Button(action: {
                    startVoiceInput()
                }) {
                    Label("Голосовой ввод", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isGood ? .green : .red)
                .disabled(isRecording)
                
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
    }
    
    private func startVoiceInput() {
        isRecording = true
        // Здесь можно использовать Speech framework для распознавания речи
        // Для упрощения используем текстовое поле
        text = "Голосовой ввод (в разработке)"
        isRecording = false
    }
    
    private func saveItem() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        viewModel.sendReportItem(trimmedText, isGood: isGood)
        dismiss()
    }
}

