//
//  PaletteView.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI
import UIKit

struct PaletteView: View {
    let colors: [Color]

    @State var hue: Double = 0
    @State var saturation: Double = 1
    @State var harmony: ColorHarmony = .free
    @State var showHarmonyPicker = false
    @State private var showSave = false
    @Environment(\.managedObjectContext) private var context

    // Computed colors for the current harmony selection to be saved
    private var currentColors: [Color] {
        // Map HarmonyColor to SwiftUI Color. Assuming HarmonyColor exposes hue and saturation in 0...1 space,
        // and full brightness/value for display.
        harmonyColors.map { hc in
            Color(hue: hc.hue, saturation: hc.saturation, brightness: 1.0)
        }
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
        }
        .padding()
        .sheet(isPresented: $showSave) {
            NavigationStack {
                SavePaletteView(
                    viewModel: SavePaletteViewModel(
                        context: context
                    ),
                    colors: currentColors
                )
            }
        }
    }
}

#Preview {
    PaletteView(colors: [])
}
