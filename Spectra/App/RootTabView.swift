//
//  RootTabView.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI

enum AppTab: Hashable {
    case generator
    case saved
    case camera
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .generator

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PaletteView()
                    .navigationTitle("Генератор")
            }
            .tabItem {
                Label("Палитра", systemImage: "paintpalette")
            }
            .tag(AppTab.generator)

            NavigationStack {
                SavedPalettesView(selectedTab: $selectedTab)
                    .navigationTitle("Сохраненные")
            }
            .tabItem {
                Label("Сохраненные", systemImage: "square.stack")
            }
            .tag(AppTab.saved)

            NavigationStack {
                CameraView()
            }
            .tabItem {
                Label("Камера", systemImage: "camera")
            }
            .tag(AppTab.camera)
        }
    }
}
