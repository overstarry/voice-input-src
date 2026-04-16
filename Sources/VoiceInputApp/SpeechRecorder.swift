import AVFoundation
import Foundation
import Speech

enum SpeechRecorderError: Error, LocalizedError {
    case speechDenied
    case microphoneDenied
    case recognizerUnavailable
    case audioInputUnavailable
    case audioEngineFailed(String)

    var errorDescription: String? {
        switch self {
        case .speechDenied:
            "Speech recognition permission is not granted."
        case .microphoneDenied:
            "Microphone permission is not granted."
        case .recognizerUnavailable:
            "Speech recognizer is unavailable for the selected language."
        case .audioInputUnavailable:
            "Audio input is unavailable."
        case let .audioEngineFailed(message):
            "Audio engine failed: \(message)"
        }
    }
}

final class SpeechRecorder {
    var onPartialText: ((String) -> Void)?
    var onRMS: ((Float) -> Void)?
    var onError: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var latestText = ""
    private var stopCompletion: ((String) -> Void)?
    private var didCompleteStop = false

    var isRecording: Bool {
        audioEngine.isRunning
    }

    func ensurePermissions(completion: @escaping (Result<Void, SpeechRecorderError>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                DispatchQueue.main.async {
                    completion(.failure(.speechDenied))
                }
                return
            }

            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted ? .success(()) : .failure(.microphoneDenied))
                }
            }
        }
    }

    func start(language: SupportedLanguage) throws {
        stopImmediately()

        latestText = ""
        didCompleteStop = false
        stopCompletion = nil

        let recognizer = SFSpeechRecognizer(locale: language.locale)
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecorderError.recognizerUnavailable
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw SpeechRecorderError.audioInputUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else {
                return
            }
            request.append(buffer)
            let rms = Self.rmsLevel(from: buffer)
            DispatchQueue.main.async {
                self.onRMS?(rms)
            }
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handle(result: result, error: error)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw SpeechRecorderError.audioEngineFailed(error.localizedDescription)
        }
    }

    func stop(completion: @escaping (String) -> Void) {
        guard audioEngine.isRunning else {
            completion(latestText)
            return
        }

        stopCompletion = completion
        didCompleteStop = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request?.endAudio()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.finishStopIfNeeded()
        }
    }

    func stopImmediately() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
        stopCompletion = nil
        didCompleteStop = true
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            latestText = result.bestTranscription.formattedString
            onPartialText?(latestText)
            if result.isFinal {
                finishStopIfNeeded()
            }
        }

        if let error {
            onError?(error.localizedDescription)
            finishStopIfNeeded()
        }
    }

    private func finishStopIfNeeded() {
        guard !didCompleteStop else {
            return
        }
        didCompleteStop = true
        let completion = stopCompletion
        stopCompletion = nil
        task?.finish()
        task = nil
        request = nil
        recognizer = nil
        completion?(latestText)
    }

    private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else {
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        let channelCount = Int(buffer.format.channelCount)
        var sum: Float = 0
        var count = 0

        for channel in 0..<channelCount {
            let samples = channels[channel]
            for index in 0..<frameLength {
                let sample = samples[index]
                sum += sample * sample
            }
            count += frameLength
        }

        guard count > 0 else {
            return 0
        }
        let rms = sqrt(sum / Float(count))
        return min(max(rms * 8.0, 0), 1)
    }
}
