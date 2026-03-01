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
                    loadedPalette = nil
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
    }

    var savedPalettesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Сохраненные палитры")
                .font(.headline)

            if savedPaletteModels.isEmpty {
                Text("Пока нет сохраненных палитр")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(savedPaletteModels) { palette in
                            savedPaletteCard(palette)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func savedPaletteCard(_ palette: Palette) -> some View {
        let paletteColors = palette.colors.compactMap(Color.init(hex:))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(palette.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    deletePalette(palette)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }

            HStack(spacing: 4) {
                ForEach(Array(paletteColors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 20, height: 20)
                }
            }

            Button("Загрузить") {
                loadPalette(palette)
            }
            .buttonStyle(.bordered)
            .disabled(paletteColors.isEmpty)
        }
        .padding(10)
        .frame(width: 180, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
