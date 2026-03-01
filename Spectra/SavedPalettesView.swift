//
//  SavedPalettesView.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI
internal import CoreData

struct SavedPalettesView: View {
    @Binding var selectedTab: AppTab
    @StateObject private var viewModel = SavedPalettesViewModel()
    @EnvironmentObject private var loadStore: PaletteLoadStore
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
        animation: .default
    )
    private var savedPalettes: FetchedResults<PaletteEntity>

    var body: some View {
        Group {
            if viewModel.presentations.isEmpty {
                ContentUnavailableView(
                    "Нет сохраненных палитр",
                    systemImage: "square.stack",
                    description: Text("Сохраните палитру на вкладке генератора")
                )
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.presentations) { presentation in
                            paletteCard(presentation)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let exportError = viewModel.exportError {
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
        .sheet(item: $viewModel.shareItem, onDismiss: viewModel.clearSharedFile) { item in
            ActivityView(activityItems: [item.url])
        }
        .onAppear {
            viewModel.configure(context: context, loadStore: loadStore)
            viewModel.rebuildPresentations(from: savedPalettes)
        }
        .onChange(of: savedPalettes.count) { _, _ in
            viewModel.rebuildPresentations(from: savedPalettes)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSManagedObjectContextObjectsDidChange,
                object: context
            )
        ) { _ in
            viewModel.rebuildPresentations(from: savedPalettes)
        }
        .onChange(of: viewModel.tabToSelect) { _, tab in
            guard let tab else { return }
            selectedTab = tab
            viewModel.consumeTabSelection()
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
                    viewModel.load(presentation)
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .disabled(presentation.swatches.isEmpty)

                Button {
                    viewModel.export(presentation)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .disabled(presentation.swatches.isEmpty)

                Button {
                    viewModel.delete(presentation)
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
}
