import Foundation

struct VoiceNoteAttachment: Codable {
    enum Status: String, Codable {
        case transcribing
        case ready
        case failed
    }

    let id: UUID
    var localFilePath: String
    var duration: TimeInterval
    var waveform: [Double]
    var status: Status
    var transcript: String?
    var errorMessage: String?
    var mimeType: String

    var localFileURL: URL {
        URL(fileURLWithPath: localFilePath)
    }
}

struct RecordedVoiceNoteDraft {
    let fileURL: URL
    let duration: TimeInterval
    let waveform: [Double]
    let mimeType: String
}
