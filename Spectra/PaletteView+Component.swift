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
                    harmony = scheme
                }
            }
        }
    }

    var colorWheel: some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(
                        colors: stride(from: 0.0, to: 1.0, by: 0.01).map {
                            Color(hue: $0, saturation: 1, brightness: 1)
                        }
                    ),
                    center: .center
                )
            )
    }

    var previews: some View {
        HStack(spacing: 12) {
            ForEach(harmonyColors, id: \.self) { c in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            Color(
                                hue: c.hue,
                                saturation: c.saturation,
                                brightness: c.brightness
                            )
                        )
                        .frame(height: 60)

                    Text(
                        UIColor(
                            Color(
                                hue: c.hue,
                                saturation: c.saturation,
                                brightness: c.brightness
                            )
                        ).toHex()
                    )
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

