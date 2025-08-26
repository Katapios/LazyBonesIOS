import SwiftUI
import AVFoundation

/// Чистый компонент записи одной голосовой заметки (совместим по API)
struct VoiceRecorderRowClean: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var recordingURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""

    let initialPath: String?
    let onVoiceNoteChanged: (String?) -> Void
    let isFirst: Bool

    private var hasValidRecording: Bool {
        guard let url = recordingURL, !url.path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: url.path) && fileSize(url) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                // Запись/стоп
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                }
                .disabled(isPlaying)

                // Воспроизведение/стоп
                if hasValidRecording {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(isPlaying ? .red : .green)
                    }
                    .disabled(isRecording)
                }

                // Удаление
                if hasValidRecording {
                    Button(role: .destructive, action: deleteRecording) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    }
                    .disabled(isRecording || isPlaying)
                }
            }

            statusView
        }
        .padding(.vertical, 4)
        .alert("Ошибка", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            setupAudioSession()
            loadInitialFile()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if isRecording {
            Text("Запись...").foregroundColor(.red).font(.caption)
        } else if isPlaying {
            Text("Воспроизведение...").foregroundColor(.green).font(.caption)
        } else if !hasValidRecording {
            Text("Нет записи").foregroundColor(.gray).font(.caption)
        }
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            showError("Ошибка настройки аудио: \(error.localizedDescription)")
        }
    }

    private func loadInitialFile() {
        guard let path = initialPath, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path), fileSize(url) > 0 {
            recordingURL = url
        }
    }

    // MARK: - Recording
    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("voice_note_\(UUID().uuidString)_\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
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
        guard let url = recordingURL else { return }
        if fileSize(url) > 0 {
            DispatchQueue.main.async { onVoiceNoteChanged(url.path) }
        } else {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
            DispatchQueue.main.async { onVoiceNoteChanged(nil) }
        }
    }

    // MARK: - Playback
    private func togglePlayback() {
        isPlaying ? stopPlayback() : startPlayback()
    }

    private func startPlayback() {
        guard let url = recordingURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
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
        guard let url = recordingURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            recordingURL = nil
            DispatchQueue.main.async { onVoiceNoteChanged(nil) }
        } catch {
            showError("Ошибка удаления: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    private func fileSize(_ url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    VoiceRecorderRowClean(initialPath: nil, onVoiceNoteChanged: { _ in }, isFirst: true)
        .padding()
}
