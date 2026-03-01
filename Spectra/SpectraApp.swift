//
//  SpectraApp.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI
internal import CoreData

@main
struct SpectraApp: App {
    @StateObject private var loadStore = PaletteLoadStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(loadStore)
        }
        .environment(\.managedObjectContext,
                     PersistenceController.shared.container.viewContext)
    }
}
