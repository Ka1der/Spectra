//
//  PaletteView.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI
import UIKit
import PhotosUI
import os
internal import CoreData

@MainActor
struct PaletteView: View {
    @State var hue: Double = 0
    @State var saturation: Double = 1
    @State var harmony: ColorHarmony = .free
    @State var showHarmonyPicker = false
    @State private var showSave = false
    @State var loadedPalette: Palette?
    @State private var loadedPaletteColors: [Color] = []
    @State var importedColors: [Color] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var importTask: Task<Void, Never>?
    @State private var photoImportError: String?
    @State private var exportError: String?
    @State private var shareItem: SharedFileItem?
    @State private var lastSharedFileURL: URL?
    @EnvironmentObject private var loadStore: PaletteLoadStore
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) var colorScheme
    private let logger = Logger(subsystem: "Kaider.Spectra", category: "PaletteView")

    var generatedColors: [Color] {
        harmonyColors.map { hc in
            Color(hue: hc.hue, saturation: hc.saturation, brightness: hc.brightness)
        }
    }

    var activeColors: [Color] {
        if !importedColors.isEmpty {
            return importedColors
        }

        return loadedPaletteColors.isEmpty ? generatedColors : loadedPaletteColors
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

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Импорт фото", systemImage: "photo")
                }
                .glassActionButtonStyle()

                Button {
                    showSave = true
                } label: {
                    Label("Сохранить палитру", systemImage: "square.and.arrow.down")
                }
                .glassActionButtonStyle()

                Button {
                    exportCurrentPalette()
                } label: {
                    Label("Экспорт", systemImage: "square.and.arrow.up")
                }
                .glassActionButtonStyle()
            }

            if let photoImportError {
                Text(photoImportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if let exportError {
                Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .onChange(of: selectedPhotoItem) { _, newValue in
            startPhotoImport(from: newValue)
        }
        .onReceive(loadStore.$paletteToLoad) { palette in
            guard let palette else { return }
            loadPalette(palette)
            loadStore.paletteToLoad = nil
        }
        .navigationDestination(isPresented: $showSave) {
            SavePaletteView(
                viewModel: SavePaletteViewModel(
                    context: context
                ),
                colors: activeColors
            )
        }
        .sheet(item: $shareItem, onDismiss: clearSharedFile) { item in
            ActivityView(activityItems: [item.url])
        }
        .onDisappear {
            importTask?.cancel()
            importTask = nil
        }
    }

    func loadPalette(_ palette: Palette) {
        importedColors = []
        loadedPalette = palette

        let uiColors = palette.colors.compactMap(UIColor.init(hex:))
        loadedPaletteColors = uiColors.map(Color.init(uiColor:))

        guard let firstColor = uiColors.first else {
            loadedPaletteColors = []
            return
        }

        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        firstColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        saturation = Double(s)

        let detection = HarmonyDetector.detectClosestHarmony(
            from: uiColors,
            fallbackHue: hue
        )
        harmony = detection.harmony
        hue = detection.baseHue
    }

    private func startPhotoImport(from item: PhotosPickerItem?) {
        importTask?.cancel()
        guard let item else { return }

        importTask = Task {
            await importPhotoColors(from: item)
        }
    }

    private func importPhotoColors(from item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                photoImportError = "Не удалось загрузить изображение"
                return
            }

            let result = try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let extracted = ImagePaletteExtractor.extractColors(from: image, maxColors: 5)
                guard !extracted.isEmpty else {
                    return ImportedPhotoResult(
                        extractedColors: [],
                        fallbackHue: 0,
                        fallbackSaturation: 1,
                        harmony: .free,
                        detectedBaseHue: 0
                    )
                }

                var h: CGFloat = 0
                var s: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0
                extracted.first?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

                let fallbackHue = Double(h)
                let fallbackSaturation = Double(s)
                let detection = HarmonyDetector.detectClosestHarmony(
                    from: extracted,
                    fallbackHue: fallbackHue
                )

                return ImportedPhotoResult(
                    extractedColors: extracted,
                    fallbackHue: fallbackHue,
                    fallbackSaturation: fallbackSaturation,
                    harmony: detection.harmony,
                    detectedBaseHue: detection.baseHue
                )
            }.value

            try Task.checkCancellation()

            guard !result.extractedColors.isEmpty else {
                photoImportError = "Не удалось извлечь цвета из фото"
                return
            }

            importedColors = result.extractedColors.map { Color(uiColor: $0) }
            clearLoadedPaletteSelection()
            photoImportError = nil
            hue = result.fallbackHue
            saturation = result.fallbackSaturation
            harmony = result.harmony
            hue = result.detectedBaseHue
        } catch is CancellationError {
            logger.debug("Photo import cancelled")
        } catch {
            logger.error("Photo import failed: \(error.localizedDescription, privacy: .public)")
            photoImportError = "Ошибка импорта: \(error.localizedDescription)"
        }
    }

    private func exportCurrentPalette() {
        let hexColors = activeColors.map { UIColor($0).toHex() }
        guard !hexColors.isEmpty else {
            exportError = "Нет цветов для экспорта"
            return
        }

        let generated = Palette(
            id: UUID(),
            name: loadedPalette?.name ?? "Palette",
            colors: hexColors,
            createdAt: .now
        )

        do {
            let url = try PaletteExportService.exportFileURL(
                for: generated,
                scheme: harmony
            )
            exportError = nil
            lastSharedFileURL = url
            shareItem = SharedFileItem(url: url)
        } catch {
            exportError = "Не удалось экспортировать палитру"
        }
    }

    private func clearSharedFile() {
        guard let url = lastSharedFileURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            logger.error("Temp export cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
        lastSharedFileURL = nil
        shareItem = nil
    }

    func clearLoadedPaletteSelection() {
        loadedPalette = nil
        loadedPaletteColors = []
    }
}

private struct ImportedPhotoResult {
    let extractedColors: [UIColor]
    let fallbackHue: Double
    let fallbackSaturation: Double
    let harmony: ColorHarmony
    let detectedBaseHue: Double
}

private extension View {
    func glassActionButtonStyle() -> some View {
        modifier(GlassActionButtonModifier())
    }
}

private struct GlassActionButtonModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        colorScheme == .dark
                            ? .white.opacity(0.30)
                            : .white.opacity(0.55),
                        lineWidth: 0.9
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? .black.opacity(0.25)
                    : .black.opacity(0.12),
                radius: 10,
                y: 4
            )
    }
}

#Preview {
    PaletteView()
        .environmentObject(PaletteLoadStore())
}
