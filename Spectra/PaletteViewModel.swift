//
//  PaletteViewModel.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

import SwiftUI
internal import CoreData
import Combine

final class PaletteViewModel: ObservableObject {

    @Published var colors: [Color] = []
    @Published var name: String = ""
    @Published var validationError: String?

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Save

    func savePalette() {

        let result = validatePaletteName(name)

        guard result == .valid else {
            validationError = result.message
            return
        }

        validationError = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let palette = PaletteEntity(context: context)
        palette.id = UUID()
        palette.name = trimmed
        palette.createdAt = Date()

        let hexColors = colors.map { UIColor($0).toHex() }
        palette.colors = hexColors as NSObject

        do {
            try context.save()
        } catch {
            print("Save error:", error)
        }
    }
}

// MARK: - Validation

extension PaletteViewModel {

    enum PaletteNameValidationResult: Equatable {
        case valid
        case empty
        case tooShort
        case tooLong
        case duplicate

        var message: String? {
            switch self {
            case .valid: return nil
            case .empty: return "Введите название палитры"
            case .tooShort: return "Минимум 2 символа"
            case .tooLong: return "Максимум 40 символов"
            case .duplicate: return "Палитра с таким именем уже существует"
            }
        }
    }

    private func validatePaletteName(_ name: String) -> PaletteNameValidationResult {

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count >= 2 else { return .tooShort }
        guard trimmed.count <= 40 else { return .tooLong }

        if paletteExists(with: trimmed) {
            return .duplicate
        }

        return .valid
    }

    private func paletteExists(with name: String) -> Bool {

        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1

        do {
            return try context.count(for: request) > 0
        } catch {
            return false
        }
    }
}
