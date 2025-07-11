import SwiftUI
import AVFoundation

/// Компонент для работы с одной голосовой заметкой
struct VoiceRecorderRowView: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var recordingURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteConfirm = false
    
    let initialPath: String?
    let onVoiceNoteChanged: (String?) -> Void
    let isFirst: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Кнопка записи/перезаписи
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(isRecording ? .red : .red)
                }
                .disabled(isPlaying)
                
                // Кнопка воспроизведения
                if recordingURL != nil {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(isPlaying ? .red : .green)
                    }
                    .disabled(isRecording)
                }
                // Кнопка удаления
                if recordingURL != nil {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    }
                    .disabled(isRecording || isPlaying)
                }
            }
            if isRecording {
                Text("Запись...")
                    .foregroundColor(.red)
                    .font(.caption)
            } else if isPlaying {
                Text("Воспроизведение...")
                    .foregroundColor(.green)
                    .font(.caption)
            } else if recordingURL != nil {
                Text("Голосовая заметка готова")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Text("Нет записи")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .alert("Ошибка", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Удалить заметку?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) { deleteRecording() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Голосовая заметка будет удалена безвозвратно.")
        }
        .onAppear {
            setupAudioSession()
            if let path = initialPath {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    recordingURL = url
                }
            }
        }
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            showError("Ошибка настройки аудио: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recording
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("voice_note_\(UUID().uuidString)_\(Date().timeIntervalSince1970).m4a")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = nil
            audioRecorder?.record()
            isRecording = true
            recordingURL = audioFilename
        } catch {
            showError("Ошибка записи: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        onVoiceNoteChanged(recordingURL?.path)
    }
    
    // MARK: - Playback
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard let url = recordingURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = nil
            audioPlayer?.play()
            isPlaying = true
        } catch {
            showError("Ошибка воспроизведения: \(error.localizedDescription)")
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // MARK: - Delete
    private func deleteRecording() {
        if let url = recordingURL {
            do {
                try FileManager.default.removeItem(at: url)
                recordingURL = nil
                onVoiceNoteChanged(nil)
            } catch {
                showError("Ошибка удаления: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Error Handling
    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

/// Список голосовых заметок с возможностью добавления
struct VoiceRecorderListView: View {
    @Binding var voiceNotes: [VoiceNote]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Голосовые заметки").font(.headline)
            ForEach(voiceNotes) { note in
                VoiceRecorderRowView(
                    initialPath: note.path,
                    onVoiceNoteChanged: { newPath in
                        if let newPath = newPath {
                            if let idx = voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                voiceNotes[idx].path = newPath
                            }
                        } else {
                            if let idx = voiceNotes.firstIndex(where: { $0.id == note.id }) {
                                voiceNotes.remove(at: idx)
                            }
                        }
                    },
                    isFirst: voiceNotes.first?.id == note.id
                )
            }
            Button(action: {
                voiceNotes.append(VoiceNote(id: UUID(), path: ""))
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить голосовую заметку")
                }
            }
            .padding(.top, 4)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VoiceRecorderListView_Preview: View {
    @State var notes: [VoiceNote] = []
    var body: some View {
        VoiceRecorderListView(voiceNotes: $notes)
    }
}

#Preview {
    VoiceRecorderListView_Preview()
} 
