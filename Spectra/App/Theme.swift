//
//  Theme.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI

enum AppTheme {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let surfaceBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    static func markerStroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.85)
    }
}

