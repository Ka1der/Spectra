//
//  PaletteView+Component.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI

// MARK: - UI Components
extension PaletteView {

    var harmonyPicker: some View {
        Button {
            showHarmonyPicker = true
        } label: {
            HStack {
                Text(harmony.rawValue)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
            }
        }
        .buttonStyle(.bordered)
        .confirmationDialog(
            "Цветовая схема",
            isPresented: $showHarmonyPicker
        ) {
            ForEach(ColorHarmony.allCases, id: \.self) { scheme in
                Button(scheme.rawValue) {
                    importedColors = []
                    clearLoadedPaletteSelection()
                    harmony = scheme
                }
            }
        }
    }

    var colorWheel: some View {
        Circle()
            .fill(ColorWheelCache.gradient)
    }

    var previews: some View {
        HStack(spacing: 12) {
            ForEach(activeColors.indices, id: \.self) { index in
                let color = activeColors[index]

                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(height: 60)

                    Text(UIColor(color).toHex())
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.surfaceBackground)
        )
    }

}

private enum ColorWheelCache {
    static let gradient = AngularGradient(
        gradient: Gradient(
            colors: stride(from: 0.0, to: 1.0, by: 0.01).map {
                Color(hue: $0, saturation: 1, brightness: 1)
            }
        ),
        center: .center
    )
}
