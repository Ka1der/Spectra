//
//  SavedPalettesViewModel.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI
import Combine
import os
internal import CoreData

@MainActor
final class SavedPalettesViewModel: ObservableObject {
    @Published var presentations: [SavedPalettePresentation] = []
    @Published var shareItem: SharedFileItem?
    @Published var exportError: String?
    @Published var tabToSelect: AppTab?

    private var context: NSManagedObjectContext?
    private weak var loadStore: PaletteLoadStore?
    private var lastSharedFileURL: URL?
    private let logger = Logger(subsystem: "Kaider.Spectra", category: "SavedPalettes")

    func configure(
        context: NSManagedObjectContext,
        loadStore: PaletteLoadStore
    ) {
        self.context = context
        self.loadStore = loadStore
    }

    func rebuildPresentations(from entities: FetchedResults<PaletteEntity>) {
        presentations = entities.map { entity in
            let palette = entity.toModel()
            let uiColors = palette.colors.compactMap(UIColor.init(hex:))
            let swatches = uiColors.map(Color.init(uiColor:))
            let scheme = HarmonyDetector.detectClosestHarmony(
                from: uiColors,
                fallbackHue: 0
            ).harmony

            return SavedPalettePresentation(
                palette: palette,
                swatches: swatches,
                scheme: scheme
            )
        }
    }

    func load(_ presentation: SavedPalettePresentation) {
        loadStore?.paletteToLoad = presentation.palette
        tabToSelect = .generator
    }

    func consumeTabSelection() {
        tabToSelect = nil
    }

    func delete(_ presentation: SavedPalettePresentation) {
        guard let context else { return }

        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@",
            presentation.palette.id as CVarArg
        )
        request.fetchLimit = 1

        do {
            guard let entity = try context.fetch(request).first else {
                return
            }

            context.delete(entity)
            try context.save()
            presentations.removeAll { $0.id == presentation.id }
        } catch {
            logger.error("Delete palette failed: \(error.localizedDescription, privacy: .public)")
            exportError = "Не удалось удалить палитру"
        }
    }

    func export(_ presentation: SavedPalettePresentation) {
        do {
            let url = try PaletteExportService.exportFileURL(
                for: presentation.palette,
                scheme: presentation.scheme
            )
            exportError = nil
            lastSharedFileURL = url
            shareItem = SharedFileItem(url: url)
        } catch {
            exportError = "Не удалось экспортировать палитру"
        }
    }

    func clearSharedFile() {
        guard let url = lastSharedFileURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Temp export cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
        lastSharedFileURL = nil
        shareItem = nil
    }
}

struct SavedPalettePresentation: Identifiable {
    let palette: Palette
    let swatches: [Color]
    let scheme: ColorHarmony

    var id: UUID { palette.id }
}

