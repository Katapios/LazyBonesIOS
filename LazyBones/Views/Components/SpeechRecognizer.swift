import Foundation
import Speech
import AVFoundation

/// Сервис для распознавания речи
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))
    
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func startRecording() async {
        // Проверяем разрешения
        guard await requestAuthorization() else {
            errorMessage = "Нет разрешения на использование распознавания речи"
            return
        }
        
        // Проверяем доступность распознавателя
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Распознавание речи недоступно"
            return
        }
        
        // Останавливаем предыдущую запись, если есть
        stopRecording()
        
        // Настраиваем аудио сессию
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Ошибка настройки аудио: \(error.localizedDescription)"
            return
        }
        
        // Создаем запрос на распознавание
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Не удалось создать запрос на распознавание"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Настраиваем аудио движок
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            errorMessage = "Не удалось создать аудио движок"
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            recognizedText = ""
            errorMessage = nil
        } catch {
            errorMessage = "Ошибка запуска аудио движка: \(error.localizedDescription)"
            return
        }
        
        // Запускаем распознавание
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    if (error as NSError).code != 216 { // Игнорируем ошибку отмены
                        self.errorMessage = "Ошибка распознавания: \(error.localizedDescription)"
                    }
                    self.stopRecording()
                    return
                }
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
            }
        }
    }
    
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Деактивируем аудио сессию
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        isRecording = false
    }
    
    deinit {
        // В deinit очищаем ресурсы напрямую, без вызова @MainActor методов
        recognitionTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

