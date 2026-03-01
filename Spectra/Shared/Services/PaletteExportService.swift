//
//  PaletteExportService.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import Foundation

enum PaletteExportService {
    struct Payload: Codable {
        let version: Int
        let id: UUID
        let name: String
        let scheme: String
        let colors: [String]
        let createdAt: Date
    }

    static func exportFileURL(for palette: Palette, scheme: ColorHarmony) throws -> URL {
        let payload = Payload(
            version: 1,
            id: palette.id,
            name: palette.name,
            scheme: scheme.rawValue,
            colors: palette.colors,
            createdAt: palette.createdAt
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let filename = sanitizedFilename(from: palette.name) + ".spectra.json"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-" + filename)

        try data.write(to: url, options: .atomic)
        return url
    }

    private static func sanitizedFilename(from value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Palette" : cleaned
    }
}

