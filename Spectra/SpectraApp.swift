//
//  SpectraApp.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI

@main
struct SpectraApp: App {
    var body: some Scene {
        WindowGroup {
            PaletteView(colors: [
                .blue,
                .cyan,
                .mint,
                .green,
                .yellow
            ]
            )
        }
    }
}
