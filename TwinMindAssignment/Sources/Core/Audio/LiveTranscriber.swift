import Foundation
import AVFoundation

// MARK: - Domain Models & Protocols

public protocol TranscriptionService {
    func start() async
    func stop() async
    func enqueuePCM16(chunk: Data, sampleRate: Int) async
    var transcriptStream: AsyncStream<TranscriptEvent> { get }
}

public struct TranscriptEvent: Sendable, Equatable {
    public enum Kind: Sendable { case partial, final }
    public let kind: Kind
    public let text: String
    public let timestamp: Date
    public init(kind: Kind, text: String, timestamp: Date = .init()) {
        self.kind = kind
        self.text = text
        self.timestamp = timestamp
    }
}

// APITokenProvider protocol moved to TwinMindAssignment/Sources/Core/Protocols/APITokenProvider.swift

// MARK: - WAV Encoder (PCM16 -> WAV)

public final class WAVEncoder {
    public init() {}
    public func encodePCM16MonoToWAV(pcm16: Data, sampleRate: Int) -> Data {
        let byteRate = sampleRate * 2
        var hdr = Data()
        func s(_ t: String){ hdr.append(t.data(using: .ascii)!) }
        func u32(_ v: UInt32){ var x=v.littleEndian; hdr.append(Data(bytes:&x,count:4)) }
        func u16(_ v: UInt16){ var x=v.littleEndian; hdr.append(Data(bytes:&x,count:2)) }
        s("RIFF"); u32(UInt32(36+pcm16.count)); s("WAVE")
        s("fmt "); u32(16); u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(byteRate)); u16(2); u16(16)
        s("data"); u32(UInt32(pcm16.count))
        var out = Data(); out.append(hdr); out.append(pcm16); return out
    }
}

// MARK: - HTTPS Batching Transcriber

public final class OpenAITranscriber: TranscriptionService {
    private let sampleRate = 16_000
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let model: String
    private let language: String?
    private let session: URLSession
    private let tokenProvider: APITokenProvider
    private let wav = WAVEncoder()

    // Queue/backpressure
    private var buffer: [Data] = []
    private let maxQueueItems = 4 // ~2 minutes at 30s/chunk (reduced from 12)
    private let maxInFlight = 1 // Keep at 1 for conservative API usage
    private var inflight = 0
    private var isRunning = false
    private var lastRequestTime: Date = Date.distantPast
    private let minRequestInterval: TimeInterval = 2.0 // Increased to 2 seconds between requests for 30s chunks

    private let streamMaker = AsyncStream<TranscriptEvent>.makeStream()
    public var transcriptStream: AsyncStream<TranscriptEvent> { streamMaker.stream }

    public init(tokenProvider: APITokenProvider,
                session: URLSession = .shared,
                model: String = "gpt-4o-mini-transcribe",
                language: String? = nil) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.model = model
        self.language = language
    }

    public func start() async {
        guard !isRunning else { return }
        isRunning = true
        Task { await pump() }
    }

    public func stop() async { isRunning = false }

    public func enqueuePCM16(chunk: Data, sampleRate: Int) async {
        guard sampleRate == self.sampleRate else { 
            print("❌ [LIVE] Sample rate mismatch: got \(sampleRate), expected \(self.sampleRate)")
            return 
        }
        
        print("📥 [LIVE] Received 30s chunk: \(chunk.count) bytes")
        buffer.append(chunk)
        print("📦 [LIVE] Buffer size: \(buffer.count) chunks (30s each)")
        
        if buffer.count > maxQueueItems { 
            let removed = buffer.removeFirst()
            print("🗑️  [LIVE] Buffer overflow, removed oldest 30s chunk: \(removed.count) bytes")
        }
    }

    private func pump() async {
        print("🔄 [LIVE] Pump started")
        
        while isRunning {
            guard !buffer.isEmpty else { 
                print("⏸️  [LIVE] Buffer empty, waiting...")
                try? await Task.sleep(nanoseconds: 15_000_000); 
                continue 
            }
            
            if inflight >= maxInFlight { 
                print("🚦 [LIVE] Max in-flight (\(inflight)), waiting...")
                try? await Task.sleep(nanoseconds: 15_000_000); 
                continue 
            }
            
            // Check if enough time has passed since last request
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
            if timeSinceLastRequest < minRequestInterval {
                let waitTime = minRequestInterval - timeSinceLastRequest
                print("⏳ [LIVE] Rate limiting: waiting \(String(format: "%.1f", waitTime))s")
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                continue
            }
            
            let pcm = buffer.removeFirst()
            inflight += 1
            lastRequestTime = Date()
            print("🚀 [LIVE] Processing chunk: \(pcm.count) bytes | In-flight: \(inflight)")
            
            Task {
                defer { inflight -= 1 }
                await self.upload(pcm: pcm)
            }
        }
    }

    private func upload(pcm: Data) async {
        print("🌐 [API] Starting upload: \(pcm.count) bytes")
        
        let wavData = wav.encodePCM16MonoToWAV(pcm16: pcm, sampleRate: sampleRate)
        print("🎵 [API] Encoded WAV: \(wavData.count) bytes")
        
        await retry(times: 3, delayMs: 1000) { [self] in // Increased retry delay for rate limiting
            let token = try await tokenProvider.currentToken()
            print("🔑 [API] Using token: \(String(token.prefix(20)))...")
            
            var req = URLRequest(url: endpoint); req.httpMethod = "POST"
            let boundary = "Boundary-\(UUID().uuidString)"
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            func field(_ name: String, _ value: String) {
                body.append("--\(boundary)\r\n".data(using:.utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using:.utf8)!)
                body.append("\(value)\r\n".data(using:.utf8)!)
            }
            field("model", model); if let language { field("language", language) }
            body.append("--\(boundary)\r\n".data(using:.utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"\r\n".data(using:.utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using:.utf8)!)
            body.append(wavData)
            body.append("\r\n--\(boundary)--\r\n".data(using:.utf8)!)
            req.httpBody = body

            // Print curl command for debugging
            printCurlCommand(request: req, boundary: boundary, wavData: wavData)
            
            print("📡 [API] Sending request: \(body.count) bytes")
            let (data, resp) = try await session.data(for: req)
            
            // Log response details
            logResponse(response: resp, data: data)
            
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                if let http = resp as? HTTPURLResponse, http.statusCode == 429 {
                    print("⏳ [API] Rate limited (429) - will retry with backoff")
                    throw URLError(.badServerResponse) // This will trigger retry with backoff
                } else {
                    print("❌ [API] HTTP error: \(resp)")
                    throw URLError(.badServerResponse)
                }
            }
            
            print("✅ [API] HTTP success: \(http.statusCode)")
            
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = obj["text"] as? String {
                print("📝 [API] Transcription: '\(text)'")
                self.streamMaker.continuation.yield(.init(kind: .partial, text: text))
            } else {
                print("⚠️  [API] Failed to parse response: \(String(data: data, encoding: .utf8) ?? "unknown")")
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    private func printCurlCommand(request: URLRequest, boundary: String, wavData: Data) {
        print("🔧 [CURL] Equivalent curl command:")
        print("curl -X POST '\(endpoint.absoluteString)' \\")
        print("  -H 'Authorization: Bearer [TOKEN]' \\")
        print("  -H 'Content-Type: multipart/form-data; boundary=\(boundary)' \\")
        print("  -F 'model=\(model)' \\")
        print("  -F 'file=@chunk.wav;type=audio/wav' \\")
        print("  --data-binary '\(wavData.prefix(100).map { String(format: "%02x", $0) }.joined())...'")
        print("  # Total WAV data: \(wavData.count) bytes")
    }
    
    private func logResponse(response: URLResponse, data: Data) {
        print("📥 [RESPONSE] Received response:")
        
        if let http = response as? HTTPURLResponse {
            print("   Status: \(http.statusCode)")
            print("   Headers:")
            for (key, value) in http.allHeaderFields {
                print("     \(key): \(value)")
            }
        } else {
            print("   Response type: \(type(of: response))")
        }
        
        print("   Body size: \(data.count) bytes")
        
        // Try to parse and display response body
        if let responseText = String(data: data, encoding: .utf8) {
            if responseText.count > 500 {
                print("   Body (truncated): \(String(responseText.prefix(500)))...")
            } else {
                print("   Body: \(responseText)")
            }
        } else {
            print("   Body: <binary data>")
        }
        
        print("   ---")
    }

    private func retry(times: Int, delayMs: UInt64, _ op: @escaping () async throws -> Void) async {
        var attempt = 0
        while true {
            do { try await op(); return }
            catch {
                if attempt >= times { return }
                attempt += 1
                let backoff = delayMs * UInt64(1 << (attempt-1))
                try? await Task.sleep(nanoseconds: backoff * 1_000_000)
            }
        }
    }
}

// MARK: - Presentation ViewModel

@MainActor
final class LiveTranscriptionViewModel: ObservableObject {
    @Published private(set) var rollingCaption = ""
    private let service: TranscriptionService
    private var task: Task<Void, Never>?

    init(service: TranscriptionService) { self.service = service }

    func start() {
        task = Task {
            await service.start()
            for await evt in service.transcriptStream {
                switch evt.kind {
                case .partial: rollingCaption = merge(rollingCaption, with: evt.text)
                case .final: rollingCaption = evt.text
                }
            }
        }
    }
    func stop() { task?.cancel(); Task { await service.stop() } }

    private func merge(_ current: String, with incoming: String) -> String {
        incoming.count >= current.count ? incoming : incoming
    }
} 