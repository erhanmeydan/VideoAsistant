import Foundation

/// MiniMax'e transkripti gönderip YouTube için gereken metinleri üretir.
///
/// Üç ayrı çağrı yapılır:
/// 1. Altyazı düzeltme (segment grupları hâlinde),
/// 2. Bölüm başlıkları,
/// 3. Açıklama + başlıklar + etiketler.
///
/// Zaman damgaları her zaman Whisper'ın çıktısından gelir; model yalnızca metin
/// üretir, böylece zamanlama yapısal olarak korunur.
struct ContentGenerator {
    let client: MiniMaxClient

    /// Bir API çağrısında gönderilen azami segment sayısı.
    var subtitleChunkSize = 60
    /// Modele gönderilen düz metin transkriptin azami uzunluğu (karakter).
    var maximumTranscriptCharacters = 200_000

    enum GenerationError: LocalizedError {
        case allSubtitleChunksFailed(String)

        var errorDescription: String? {
            switch self {
            case .allSubtitleChunksFailed(let detail):
                return "Altyazı düzeltmesi yapılamadı. \(detail)"
            }
        }
    }

    func generate(
        segments: [TranscriptSegment],
        videoDuration: Int,
        videoName: String,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> GeneratedContent {
        var usage = TokenUsage.zero
        var content = GeneratedContent()

        // 1) Altyazı düzeltme
        let subtitleResult = await correctedSubtitles(for: segments, usage: &usage, onProgress: onProgress)
        content.subtitleSegments = subtitleResult.segments
        content.warnings.append(contentsOf: subtitleResult.warnings)

        // 2) Bölüm başlıkları
        onProgress?("Bölüm başlıkları hazırlanıyor")
        do {
            let chapters = try await requestChapters(segments: segments, videoDuration: videoDuration, usage: &usage)
            content.chapters = chapters
        } catch {
            content.warnings.append("Bölüm başlıkları üretilemedi: \(error.localizedDescription)")
            content.chapters = ChapterValidator.fallbackChapters(segments: segments, videoDuration: videoDuration)
        }

        // 3) Açıklama, başlıklar, etiketler
        onProgress?("Açıklama, başlıklar ve etiketler hazırlanıyor")
        do {
            let metadata = try await requestMetadata(
                segments: segments,
                videoName: videoName,
                videoDuration: videoDuration,
                usage: &usage
            )
            content.description = metadata.description
            content.titles = metadata.titles
            content.tags = metadata.tags
            content.warnings.append(contentsOf: metadata.warnings)
        } catch {
            content.warnings.append("Açıklama/başlık/etiket üretilemedi: \(error.localizedDescription)")
        }

        content.tokenUsage = usage
        return content
    }

    // MARK: - Altyazı

    private struct SubtitleResult {
        var segments: [TranscriptSegment]
        var warnings: [String]
    }

    private func correctedSubtitles(
        for segments: [TranscriptSegment],
        usage: inout TokenUsage,
        onProgress: (@Sendable (String) -> Void)?
    ) async -> SubtitleResult {
        var warnings: [String] = []
        var correctedTexts: [Int: String] = [:]
        var succeededChunks = 0
        var firstError: Error?

        let chunkCount = max(1, (segments.count + subtitleChunkSize - 1) / subtitleChunkSize)

        for chunkIndex in 0..<chunkCount {
            let start = chunkIndex * subtitleChunkSize
            let end = min(start + subtitleChunkSize, segments.count)
            let chunk = Array(segments[start..<end])
            let previous = start > 0 ? segments[start - 1] : nil
            let next = end < segments.count ? segments[end] : nil

            onProgress?("Altyazı düzeltiliyor (\(chunkIndex + 1)/\(chunkCount))")

            do {
                if let texts = try await requestCorrections(
                    for: chunk,
                    previous: previous,
                    next: next,
                    usage: &usage
                ) {
                    succeededChunks += 1
                    for segment in chunk {
                        if let text = texts[segment.id] {
                            correctedTexts[segment.id] = text
                        }
                    }
                } else {
                    warnings.append("Altyazı parçası \(chunkIndex + 1) düzeltilemedi, ham metin kullanıldı.")
                }
            } catch {
                if firstError == nil { firstError = error }
                warnings.append("Altyazı parçası \(chunkIndex + 1) başarısız: \(error.localizedDescription)")
            }
        }

        if succeededChunks == 0, let firstError {
            return SubtitleResult(segments: segments, warnings: warnings + [firstError.localizedDescription])
        }

        let updated = segments.map { segment -> TranscriptSegment in
            var copy = segment
            if let text = correctedTexts[segment.id] {
                copy.text = text
            }
            return copy
        }
        return SubtitleResult(segments: updated, warnings: warnings)
    }

    private struct Correction: Decodable {
        let id: Int
        let text: String
    }

    private func requestCorrections(
        for chunk: [TranscriptSegment],
        previous: TranscriptSegment?,
        next: TranscriptSegment?,
        usage: inout TokenUsage
    ) async throws -> [Int: String]? {
        let basePrompt = PromptTemplates.subtitlesUser(targets: chunk, previous: previous, next: next)
        let expectedIDs = Set(chunk.map(\.id))

        for attempt in 0..<2 {
            let prompt = attempt == 0
                ? basePrompt
                : basePrompt + "\n\nUYARI: Yanıtın yalnızca geçerli bir JSON dizisi olmalı. Kod bloğu veya açıklama yazma."

            let response = try await client.send(
                system: PromptTemplates.subtitlesSystem,
                user: prompt,
                maxTokens: 16_384,
                effort: .medium
            )
            usage = usage + response.usage

            guard let mapping = Self.parseCorrections(response.text) else { continue }
            guard Set(mapping.keys) == expectedIDs else { continue }
            return mapping
        }
        return nil
    }

    private static func parseCorrections(_ text: String) -> [Int: String]? {
        guard let json = JSONPayload.extract(from: text),
              let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([Correction].self, from: data) else {
            return nil
        }
        var mapping: [Int: String] = [:]
        for item in items {
            let cleaned = TextSanitizer.cleanSegmentText(item.text)
            guard !cleaned.isEmpty else { continue }
            mapping[item.id] = cleaned
        }
        return mapping.isEmpty ? nil : mapping
    }

    // MARK: - Bölümler

    private struct ChapterDTO: Decodable {
        struct FlexibleTime: Decodable {
            let seconds: Int

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let text = try? container.decode(String.self) {
                    seconds = Self.parse(text)
                } else if let number = try? container.decode(Double.self) {
                    seconds = Int(number)
                } else {
                    seconds = 0
                }
            }

            static func parse(_ text: String) -> Int {
                let parts = text.split(separator: ":").compactMap { Int($0) }
                switch parts.count {
                case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
                case 2: return parts[0] * 60 + parts[1]
                case 1: return parts[0]
                default: return 0
                }
            }
        }

        let start: FlexibleTime
        let title: String
    }

    private struct ChaptersPayload: Decodable {
        let chapters: [ChapterDTO]
    }

    private func requestChapters(
        segments: [TranscriptSegment],
        videoDuration: Int,
        usage: inout TokenUsage
    ) async throws -> [Chapter] {
        let prompt = PromptTemplates.chaptersUser(segments: segments, videoDuration: videoDuration)

        for attempt in 0..<2 {
            let userPrompt = attempt == 0
                ? prompt
                : prompt + "\n\nUYARI: Yanıtın yalnızca geçerli bir JSON nesnesi olmalı."
            let response = try await client.send(
                system: PromptTemplates.chaptersSystem,
                user: userPrompt,
                maxTokens: 4_096,
                effort: .high
            )
            usage = usage + response.usage

            if let chapters = Self.parseChapters(response.text) {
                return ChapterValidator.validate(chapters, videoDuration: videoDuration)
            }
        }
        return ChapterValidator.fallbackChapters(segments: segments, videoDuration: videoDuration)
    }

    private static func parseChapters(_ text: String) -> [Chapter]? {
        guard let json = JSONPayload.extract(from: text),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ChaptersPayload.self, from: data) else {
            return nil
        }
        let chapters = payload.chapters
            .map { Chapter(startSeconds: $0.start.seconds, title: TextSanitizer.removeLongDashes($0.title)) }
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return chapters.isEmpty ? nil : chapters
    }

    // MARK: - Açıklama, başlıklar, etiketler

    private struct MetadataPayload: Decodable {
        let description: String?
        let titles: [String]?
        let tags: [String]?
    }

    private struct MetadataResult {
        var description: String
        var titles: [String]
        var tags: [String]
        var warnings: [String]
    }

    private func requestMetadata(
        segments: [TranscriptSegment],
        videoName: String,
        videoDuration: Int,
        usage: inout TokenUsage
    ) async throws -> MetadataResult {
        let transcript = Self.plainTranscript(from: segments)
        let prompt = PromptTemplates.metadataUser(
            transcript: transcript,
            videoName: videoName,
            videoDuration: videoDuration
        )

        var warnings: [String] = []
        var payload: MetadataPayload?

        for attempt in 0..<2 {
            let userPrompt = attempt == 0
                ? prompt
                : prompt + "\n\nUYARI: Yanıtın yalnızca geçerli bir JSON nesnesi olmalı."
            let response = try await client.send(
                system: PromptTemplates.metadataSystem,
                user: userPrompt,
                maxTokens: 4_096,
                effort: .high
            )
            usage = usage + response.usage

            if let parsed = Self.parseMetadata(response.text) {
                payload = parsed
                break
            }
        }

        guard let payload else {
            warnings.append("Açıklama, başlık ve etiketler üretilemedi.")
            return MetadataResult(
                description: "",
                titles: [],
                tags: [],
                warnings: warnings
            )
        }

        let description = TextSanitizer.normalizeDescription(payload.description ?? "")
        var titles = TextSanitizer.normalizeTitles(payload.titles ?? [], targetCount: 5)
        var tags = TextSanitizer.normalizeTags(payload.tags ?? [], targetCount: 15)
        tags = TextSanitizer.limitTags(tags, maxTotalLength: 500)

        let droppedTags = max(0, (payload.tags ?? []).count - tags.count)
        if droppedTags > 0 {
            warnings.append("500 karakter sınırı nedeniyle \(droppedTags) etiket çıkarıldı.")
        }

        if titles.count < 5 {
            let fillers = KeywordFallback.titles(from: transcript, videoName: videoName, needed: 5 - titles.count)
            titles = TextSanitizer.normalizeTitles(titles + fillers, targetCount: 5)
            if titles.count < 5 {
                warnings.append("Başlık sayısı 5'in altında kaldı.")
            }
        }
        if tags.count < 15 {
            let fillers = KeywordFallback.tags(from: transcript, needed: 15 - tags.count)
            tags = TextSanitizer.limitTags(
                TextSanitizer.normalizeTags(tags + fillers, targetCount: 15),
                maxTotalLength: 500
            )
        }

        return MetadataResult(description: description, titles: titles, tags: tags, warnings: warnings)
    }

    private static func parseMetadata(_ text: String) -> MetadataPayload? {
        guard let json = JSONPayload.extract(from: text),
              let data = json.data(using: .utf8) else {
            return nil
        }
        // description alanı bazen string, bazen dizi olabiliyor; esnek çözümleme.
        if let payload = try? JSONDecoder().decode(MetadataPayload.self, from: data) {
            return payload
        }
        if let flexible = try? JSONDecoder().decode(FlexibleMetadataPayload.self, from: data) {
            return MetadataPayload(
                description: flexible.description?.joined(separator: "\n\n"),
                titles: flexible.titles,
                tags: flexible.tags
            )
        }
        return nil
    }

    private struct FlexibleMetadataPayload: Decodable {
        let description: [String]?
        let titles: [String]?
        let tags: [String]?
    }

    private static func plainTranscript(from segments: [TranscriptSegment]) -> String {
        segments.map(\.text).joined(separator: " ")
    }
}

/// Modelin üretmediği başlık/etiketleri tamamlamak için basit anahtar kelime çıkarımı.
enum KeywordFallback {
    private static let stopWords: Set<String> = [
        "bir", "bu", "için", "ile", "ve", "daha", "çok", "olarak", "gibi", "kadar",
        "sonra", "ben", "sen", "biz", "siz", "onlar", "ama", "ise", "ya", "her",
        "değil", "olan", "oldu", "var", "yok", "ne", "nasıl", "neden", "şey", "gibi",
        "the", "and", "you", "this", "that", "with", "for"
    ]

    static func keywords(from text: String, limit: Int) -> [String] {
        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { $0.count > 3 && !stopWords.contains($0) && !$0.allSatisfy(\.isNumber) }

        var counts: [String: Int] = [:]
        for word in words { counts[word, default: 0] += 1 }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    static func titles(from transcript: String, videoName: String, needed: Int) -> [String] {
        guard needed > 0 else { return [] }
        let base = videoName
            .replacingOccurrences(of: ".mp4", with: "")
            .replacingOccurrences(of: ".mov", with: "")
        var result: [String] = []
        if !base.isEmpty { result.append(base) }
        for keyword in keywords(from: transcript, limit: needed + 3) {
            if result.count >= needed { break }
            result.append("Yapay Zeka: \(keyword.capitalized)")
        }
        return result
    }

    static func tags(from transcript: String, needed: Int) -> [String] {
        guard needed > 0 else { return [] }
        return keywords(from: transcript, limit: needed * 2).prefix(needed).map { $0.capitalized }
    }
}
