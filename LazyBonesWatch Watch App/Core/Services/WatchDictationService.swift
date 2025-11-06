import Foundation
import WatchKit
import Combine

/// Сервис для использования системной диктовки watchOS
@MainActor
final class WatchDictationService: ObservableObject {
    @Published var isDictating = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    
    static let shared = WatchDictationService()
    
    private init() {}
    
    /// Запускает системную диктовку watchOS
    /// Возвращает распознанный текст через completion handler
    func startDictation(completion: @escaping (String?) -> Void) {
        // Получаем текущий WKInterfaceController
        // В SwiftUI приложениях нужно использовать visibleInterfaceController или rootInterfaceController
        let watchExtension = WKExtension.shared()
        guard let interfaceController = watchExtension.visibleInterfaceController ?? watchExtension.rootInterfaceController else {
            #if DEBUG
            print("[WatchDictation] Не удалось получить интерфейс контроллер")
            #endif
            errorMessage = "Не удалось получить интерфейс контроллер"
            isDictating = false
            completion(nil)
            return
        }
        
        isDictating = true
        errorMessage = nil
        recognizedText = ""
        
        #if DEBUG
        print("[WatchDictation] Запуск диктовки...")
        #endif
        
        // Используем системную диктовку watchOS
        // allowedInputMode: .allowEmoji позволяет использовать голосовой ввод и эмодзи
        // .plain - только текст, .allowEmoji - текст и эмодзи (включает голосовой ввод)
        interfaceController.presentTextInputController(
            withSuggestions: nil,
            allowedInputMode: .allowEmoji,
            completion: { [weak self] results in
                #if DEBUG
                print("[WatchDictation] Completion вызван")
                print("[WatchDictation] Results type: \(type(of: results))")
                print("[WatchDictation] Results: \(String(describing: results))")
                #endif
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        completion(nil)
                        return
                    }
                    self.isDictating = false
                    
                    // Обрабатываем результаты
                    // results может быть [String] или [Any]
                    if let stringResults = results as? [String] {
                        // Если это массив строк
                        if let firstText = stringResults.first, !firstText.isEmpty {
                            #if DEBUG
                            print("[WatchDictation] Распознанный текст (String): \(firstText)")
                            #endif
                            self.recognizedText = firstText
                            completion(firstText)
                            return
                        }
                    } else if let anyResults = results {
                        // Если это массив Any, ищем строки
                        for result in anyResults {
                            if let text = result as? String, !text.isEmpty {
                                #if DEBUG
                                print("[WatchDictation] Распознанный текст (Any->String): \(text)")
                                #endif
                                self.recognizedText = text
                                completion(text)
                                return
                            }
                        }
                    } else if results == nil {
                        #if DEBUG
                        print("[WatchDictation] Results is nil - пользователь отменил")
                        #endif
                    }
                    
                    // Если результатов нет или они пустые
                    #if DEBUG
                    print("[WatchDictation] Результаты пустые или отменено")
                    #endif
                    self.recognizedText = ""
                    completion(nil)
                }
            }
        )
    }
    
    func startDictationWithSuggestions(_ suggestions: [String]?, completion: @escaping (String?) -> Void) {
        let watchExtension = WKExtension.shared()
        guard let interfaceController = watchExtension.visibleInterfaceController ?? watchExtension.rootInterfaceController else {
            errorMessage = "Не удалось получить интерфейс контроллер"
            isDictating = false
            completion(nil)
            return
        }
        
        isDictating = true
        errorMessage = nil
        recognizedText = ""
        
        interfaceController.presentTextInputController(
            withSuggestions: suggestions,
            allowedInputMode: .allowEmoji,
            completion: { [weak self] results in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        completion(nil)
                        return
                    }
                    self.isDictating = false
                    
                    if let results = results {
                        for result in results {
                            if let text = result as? String, !text.isEmpty {
                                self.recognizedText = text
                                completion(text)
                                return
                            }
                        }
                    }
                    
                    self.recognizedText = ""
                    completion(nil)
                }
            }
        )
    }
}

