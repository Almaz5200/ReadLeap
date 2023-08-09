import AVFoundation
import Dependencies
import Speech

extension AudioRecorderClient: DependencyKey {
    static var liveValue: Self {
        let audioRecorder = AudioRecorder()
        return Self(
            currentTime: { await audioRecorder.currentTime },
            requestRecordPermission: { await AudioRecorder.requestPermission() },
            startRecording: { url in try await audioRecorder.start(url: url) },
            stopRecording: { await audioRecorder.stop() }
        )
    }
}

private actor AudioRecorder {
    var delegate: Delegate?
    var recorder: AVAudioRecorder?
    var speechRecognizer: SFSpeechRecognizer?
    var audioEngine: AVAudioEngine?
    var currentBestTranscription: String?

    var currentTime: TimeInterval? {
        guard
            let recorder = self.recorder,
            recorder.isRecording
        else { return nil }
        return recorder.currentTime
    }

    static func requestPermission() async -> Bool {
        await withUnsafeContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
            SFSpeechRecognizer.requestAuthorization { _ in
            }
        }
    }

    @discardableResult
    func stop() -> String? {
        let bestGuess = currentBestTranscription
        currentBestTranscription = nil
        self.recorder?.stop()
        self.audioEngine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        return bestGuess
    }

    func start(url: URL) async throws -> Bool {
        self.stop()

        let stream = AsyncThrowingStream<String?, Error> { continuation in
            do {
                let audioEngine = AVAudioEngine()
                self.audioEngine = audioEngine
                let delegate = Delegate(
                    didUpdateTranscription: { transcription in
                        continuation.yield(transcription)
                    },
                    didFinishRecording: { flag in
                        continuation.finish()
                        try? AVAudioSession.sharedInstance().setActive(false)
                    },
                    encodeErrorDidOccur: { error in
                        continuation.finish(throwing: error)
                        try? AVAudioSession.sharedInstance().setActive(false)
                    }
                )
                self.delegate = delegate
                let recorder = try AVAudioRecorder(
                    url: url,
                    settings: [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    ])
                self.recorder = recorder
                let speechRecognizer = SFSpeechRecognizer(locale: .current)
                self.speechRecognizer = speechRecognizer
                recorder.delegate = self.delegate

                continuation.onTermination = { [recorder = UncheckedSendable(recorder)] _ in
                    recorder.wrappedValue.stop()
                }
                try AVAudioSession.sharedInstance().setCategory(
                    .playAndRecord, mode: .default, options: .defaultToSpeaker)
                try AVAudioSession.sharedInstance().setActive(true)
                self.recorder?.record()

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
                    request.append(buffer)
                }
                audioEngine.prepare()
                try audioEngine.start()

                speechRecognizer?.recognitionTask(with: request, delegate: delegate)

            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await guess in stream {
            self.currentBestTranscription = guess
        }
        return true
    }
}

private final class Delegate: NSObject, AVAudioRecorderDelegate, SFSpeechRecognitionTaskDelegate, Sendable {
    let didUpdateTranscription: @Sendable (String?) -> Void
    let didFinishRecording: @Sendable (Bool) -> Void
    let encodeErrorDidOccur: @Sendable (Error?) -> Void

    init(
        didUpdateTranscription: @escaping @Sendable (String?) -> Void,
        didFinishRecording: @escaping @Sendable (Bool) -> Void,
        encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
    ) {
        self.didUpdateTranscription = didUpdateTranscription
        self.didFinishRecording = didFinishRecording
        self.encodeErrorDidOccur = encodeErrorDidOccur
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.didFinishRecording(flag)
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        self.encodeErrorDidOccur(error)
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        self.didUpdateTranscription(transcription.formattedString.lowercased())
    }
}
