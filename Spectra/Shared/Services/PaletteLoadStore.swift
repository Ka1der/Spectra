//
//  PaletteLoadStore.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import Foundation
import Combine

@MainActor
final class PaletteLoadStore: ObservableObject {
    @Published var paletteToLoad: Palette?
}
