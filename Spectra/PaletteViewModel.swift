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

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func savePalette(name: String) {
        let hexColors = colors.map {
            UIColor($0).toHex()
        }

        let entity = PaletteEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.colors = hexColors as NSObject
        entity.createdAt = .now

        try? context.save()
    }
}
