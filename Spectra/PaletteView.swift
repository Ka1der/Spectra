//
//  PaletteView.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI
import UIKit
internal import CoreData

@MainActor
struct PaletteView: View {
    let colors: [Color]

    @State var hue: Double = 0
    @State var saturation: Double = 1
    @State var harmony: ColorHarmony = .free
    @State var showHarmonyPicker = false
    @State private var showSave = false
    @State var loadedPalette: Palette?
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .default
    )
    private var savedPalettes: FetchedResults<PaletteEntity>

    var generatedColors: [Color] {
        harmonyColors.map { hc in
            Color(hue: hc.hue, saturation: hc.saturation, brightness: hc.brightness)
        }
    }

    var activeColors: [Color] {
        guard let loadedPalette else { return generatedColors }

        let loaded = loadedPalette.colors.compactMap(Color.init(hex:))
        return loaded.isEmpty ? generatedColors : loaded
    }

    var savedPaletteModels: [Palette] {
        savedPalettes.map { $0.toModel() }
    }

    var harmonyColors: [HarmonyColor] {
        harmony.colors(
            baseHue: hue,
            baseSaturation: saturation
        )
    }

    var body: some View {
        VStack(spacing: 16) {

            harmonyPicker

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2
                let center = CGPoint(x: radius, y: radius)

                ZStack {
                    colorWheel

                    // polygon — только если больше 1 точки и не монохром
                    if harmonyColors.count > 1,
                       harmony != .monochrome {
                        polygon(
                            colors: harmonyColors,
                            radius: radius,
                            center: center
                        )
                    }

                    ForEach(harmonyColors, id: \.self) { c in
                        marker(
                            color: c,
                            radius: radius,
                            center: center,
                            isMain: c.hue == hue
                        )
                    }
                }
                .contentShape(Circle())
                .gesture(dragGesture(center: center, radius: radius))
            }
            .frame(width: 270, height: 270)

            previews

            Button {
                showSave = true
            } label: {
                Label("Сохранить палитру", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            savedPalettesSection
        }
        .padding()
        .sheet(isPresented: $showSave) {
            NavigationStack {
                SavePaletteView(
                    viewModel: SavePaletteViewModel(
                        context: context
                    ),
                    colors: activeColors
                )
            }
        }
    }

    func loadPalette(_ palette: Palette) {
        loadedPalette = palette

        guard
            let firstColor = palette.colors.compactMap(Color.init(hex:)).first
        else {
            return
        }

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        UIColor(firstColor).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        saturation = Double(s)
    }

    func deletePalette(_ palette: Palette) {
        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", palette.id as CVarArg)
        request.fetchLimit = 1

        guard let entity = try? context.fetch(request).first else {
            return
        }

        context.delete(entity)
        try? context.save()

        if loadedPalette?.id == palette.id {
            loadedPalette = nil
        }
    }
}

#Preview {
    PaletteView(colors: [])
}
