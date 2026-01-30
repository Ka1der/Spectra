//
//  Palette+Mapping.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

internal import CoreData

extension PaletteEntity {
    func toModel() -> Palette {
        Palette(
            id: id ?? UUID(),
            name: name ?? "",
            colors: colors as? [String] ?? [],
            createdAt: createdAt ?? .now
        )
    }
}
