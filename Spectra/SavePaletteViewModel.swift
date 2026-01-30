//
//  SavePaletteViewModel.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

import SwiftUI
import Combine
internal import CoreData

final class SavePaletteViewModel: ObservableObject {

    @Published var name: String = ""

    private let repository: PaletteRepository

    init(context: NSManagedObjectContext) {
        repository = PaletteRepository(context: context)
    }

    func save(colors: [Color]) {
        let hex = colors.map { UIColor($0).toHex() }
        repository.save(
            name: name.isEmpty ? "Untitled" : name,
            colors: hex
        )
    }
}
