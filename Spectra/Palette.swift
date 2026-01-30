//
//  Palette.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

import Foundation

struct Palette: Identifiable {
    let id: UUID
    let name: String
    let colors: [String]   // HEX
    let createdAt: Date
}
