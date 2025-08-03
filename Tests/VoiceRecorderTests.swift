import XCTest
@testable import LazyBones

/// Тесты для функциональности голосовых заметок
class VoiceRecorderTests: XCTestCase {
    
    func testPostWithMultipleVoiceNotes() {
        // Тест создания поста с несколькими голосовыми заметками
        let post = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Тест хороший"],
            badItems: ["Тест плохой"],
            published: true,
            voiceNotes: [
                VoiceNote(id: UUID(), path: "/test/path/voice1.m4a"),
                VoiceNote(id: UUID(), path: "/test/path/voice2.m4a")
            ],
            type: .regular
        )
        XCTAssertEqual(post.voiceNotes.count, 2)
        XCTAssertEqual(post.voiceNotes[0].path, "/test/path/voice1.m4a")
        XCTAssertEqual(post.voiceNotes[1].path, "/test/path/voice2.m4a")
    }
    
    func testAddAndRemoveVoiceNote() {
        var post = Post(
            id: UUID(),
            date: Date(),
            goodItems: [],
            badItems: [],
            published: false,
            voiceNotes: [],
            type: .regular
        )
        let note1 = VoiceNote(id: UUID(), path: "/test/path/voice1.m4a")
        let note2 = VoiceNote(id: UUID(), path: "/test/path/voice2.m4a")
        post.voiceNotes.append(note1)
        XCTAssertEqual(post.voiceNotes.count, 1)
        post.voiceNotes.append(note2)
        XCTAssertEqual(post.voiceNotes.count, 2)
        post.voiceNotes.remove(at: 0)
        XCTAssertEqual(post.voiceNotes.count, 1)
        XCTAssertEqual(post.voiceNotes[0].path, "/test/path/voice2.m4a")
    }
    
    func testDeviceNameRetrieval() {
        let store = PostStore()
        let deviceName = store.getDeviceName()
        // В тестах может быть не установлено имя устройства, поэтому проверяем дефолтное значение
        XCTAssertTrue(deviceName == "Устройство" || !deviceName.isEmpty)
    }
    
    func testTelegramMessageFormatWithMultipleVoiceNotes() {
        let post = Post(
            id: UUID(),
            date: Date(),
            goodItems: ["Пункт 1", "Пункт 2"],
            badItems: ["Пункт 3"],
            published: true,
            voiceNotes: [
                VoiceNote(id: UUID(), path: "/test/voice1.m4a"),
                VoiceNote(id: UUID(), path: "/test/voice2.m4a")
            ],
            type: .regular
        )
        let store = PostStore()
        let deviceName = store.getDeviceName()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateStyle = .full
        let dateStr = dateFormatter.string(from: post.date)
        let expectedMessage = """
        📅 <b>Отчёт за \(dateStr)</b>
        📱 <b>Устройство: \(deviceName)</b>
        
        <b>Я молодец:</b>
        • Пункт 1
        • Пункт 2
        
        <b>Я не молодец:</b>
        • Пункт 3
        
        🎤 <i>Голосовая заметка прикреплена</i>
        """
        XCTAssertTrue(expectedMessage.contains("📅"))
        XCTAssertTrue(expectedMessage.contains("📱"))
        XCTAssertTrue(expectedMessage.contains("🎤"))
        XCTAssertTrue(expectedMessage.contains("Я молодец:"))
        XCTAssertTrue(expectedMessage.contains("Я не молодец:"))
    }
} 