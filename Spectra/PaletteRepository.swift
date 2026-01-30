//
//  PaletteRepository.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

internal import CoreData

final class PaletteRepository {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() -> [Palette] {
        let request = PaletteEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        let result = (try? context.fetch(request)) ?? []
        return result.map { $0.toModel() }
    }

    func save(name: String, colors: [String]) {
        let palette = PaletteEntity(context: context)
        palette.id = UUID()
        palette.name = name
        palette.colors = colors as NSObject
        palette.createdAt = .now

        try? context.save()
    }

    func delete(_ palette: Palette) {
        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", palette.id as CVarArg)

        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            try? context.save()
        }
    }
}
