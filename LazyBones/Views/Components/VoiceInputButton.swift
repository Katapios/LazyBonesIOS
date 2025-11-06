import SwiftUI
import Speech

/// Кнопка для голосового ввода с распознаванием речи
struct VoiceInputButton: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @Binding var text: String
    let isGood: Bool
    
    @State private var showPermissionAlert = false
    
    var body: some View {
        Button(action: {
            if speechRecognizer.isRecording {
                Task { @MainActor in
                    speechRecognizer.stopRecording()
                    // Обновляем текст, если есть распознанный текст
                    if !speechRecognizer.recognizedText.isEmpty {
                        text = speechRecognizer.recognizedText
                    }
                }
            } else {
                Task { @MainActor in
                    await speechRecognizer.startRecording()
                    if speechRecognizer.errorMessage != nil {
                        showPermissionAlert = true
                    }
                }
            }
        }) {
            Image(systemName: speechRecognizer.isRecording ? "mic.circle.fill" : "mic.circle")
                .font(.system(size: 32))
                .foregroundColor(speechRecognizer.isRecording ? .red : (isGood ? .green : .accentColor))
                .overlay(
                    // Индикатор записи
                    Group {
                        if speechRecognizer.isRecording {
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .scaleEffect(1.2)
                                .opacity(0.6)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true),
                                    value: speechRecognizer.isRecording
                                )
                        }
                    }
                )
        }
        .alert("Ошибка", isPresented: $showPermissionAlert) {
            Button("Настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(speechRecognizer.errorMessage ?? "Не удалось начать распознавание речи")
        }
        .onChange(of: speechRecognizer.recognizedText) { newValue in
            // Обновляем текст в реальном времени во время распознавания
            if speechRecognizer.isRecording && !newValue.isEmpty {
                text = newValue
            }
        }
    }
}

