//
//  SavedPalettesView.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI
import os
internal import CoreData

struct SavedPalettesView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var loadStore: PaletteLoadStore
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .default
    )
    private var savedPalettes: FetchedResults<PaletteEntity>
    @State private var presentations: [SavedPalettePresentation] = []
    @State private var shareItem: SharedFileItem?
    @State private var exportError: String?
    @State private var lastSharedFileURL: URL?
    private let logger = Logger(subsystem: "Kaider.Spectra", category: "SavedPalettes")

    var body: some View {
        Group {
            if presentations.isEmpty {
                ContentUnavailableView(
                    "Нет сохраненных палитр",
                    systemImage: "square.stack",
                    description: Text("Сохраните палитру на вкладке генератора")
                )
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(presentations) { presentation in
                            paletteCard(presentation)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let exportError {
                Text(exportError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .sheet(item: $shareItem, onDismiss: clearSharedFile) { item in
            ActivityView(activityItems: [item.url])
        }
        .onAppear(perform: rebuildPresentations)
        .onChange(of: savedPalettes.count) { _, _ in
            rebuildPresentations()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSManagedObjectContextObjectsDidChange,
                object: context
            )
        ) { _ in
            rebuildPresentations()
        }
    }

    private func paletteCard(_ presentation: SavedPalettePresentation) -> some View {
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.palette.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(presentation.scheme.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(Array(presentation.swatches.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.separator.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Button {
                    loadStore.paletteToLoad = presentation.palette
                    selectedTab = .generator
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .disabled(presentation.swatches.isEmpty)

                Button {
                    exportPalette(presentation.palette, scheme: presentation.scheme)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .disabled(presentation.swatches.isEmpty)

                Button {
                    deletePalette(presentation.palette)
                } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func deletePalette(_ palette: Palette) {
        let request = PaletteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", palette.id as CVarArg)
        request.fetchLimit = 1

        do {
            guard let entity = try context.fetch(request).first else {
                return
            }

            context.delete(entity)
            try context.save()
        } catch {
            logger.error("Delete palette failed: \(error.localizedDescription, privacy: .public)")
            exportError = "Не удалось удалить палитру"
        }
    }

    private func exportPalette(_ palette: Palette, scheme: ColorHarmony) {
        do {
            let url = try PaletteExportService.exportFileURL(for: palette, scheme: scheme)
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

    private func rebuildPresentations() {
        presentations = savedPalettes.map { entity in
            let palette = entity.toModel()
            let uiColors = palette.colors.compactMap(UIColor.init(hex:))
            let swatches = uiColors.map(Color.init(uiColor:))
            let scheme = HarmonyDetector.detectClosestHarmony(
                from: uiColors,
                fallbackHue: 0
            ).harmony

            return SavedPalettePresentation(
                palette: palette,
                swatches: swatches,
                scheme: scheme
            )
        }
    }
}

private struct SavedPalettePresentation: Identifiable {
    let palette: Palette
    let swatches: [Color]
    let scheme: ColorHarmony

    var id: UUID { palette.id }
}
