//
//  SavePaletteViewModel.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

import SwiftUI
import Combine
import os
internal import CoreData

@MainActor
final class SavePaletteViewModel: ObservableObject {
    
    @Published var name: String = ""
    @Published var validationError: String?
    
    private let repository: PaletteRepository
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "Kaider.Spectra", category: "SavePalette")
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.repository = PaletteRepository(context: context)
    }
    
    @discardableResult
    func save(colors: [Color]) -> Bool {
        let result = validatePaletteName(name)
        
        guard result == .valid else {
            validationError = result.message
            return false
        }
        
        validationError = nil
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = colors.map { UIColor($0).toHex() }
        
        do {
            try repository.save(
                name: trimmed,
                colors: hex
            )
            return true
        } catch {
            logger.error("Save palette failed: \(error.localizedDescription, privacy: .public)")
            validationError = "Ошибка сохранения. Попробуйте еще раз"
            return false
        }
    }
    
    enum PaletteNameValidationResult: Equatable {
        case valid
        case empty
        case tooShort
        case tooLong
        case duplicate
        
        var message: String? {
            switch self {
            case .valid:
                return nil
            case .empty:
                return "Введите название палитры"
            case .tooShort:
                return "Минимум 2 символа"
            case .tooLong:
                return "Максимум 40 символов"
            case .duplicate:
                return "Палитра с таким именем уже существует"
            }
        }
    }
    
    private func paletteExists(with name: String) -> Bool {
        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
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
}
