//
//  SavePaletteView.swift
//  Spectra
//
//  Created by Kaider on 30.01.2026.
//

import SwiftUI
internal import CoreData

struct SavePaletteView: View {
    @ObservedObject var viewModel: SavePaletteViewModel
    let colors: [Color]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {

            // Preview
            HStack(spacing: 8) {
                ForEach(colors.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors[i])
                        .frame(height: 48)
                }
            }

            // Name input
            TextField("Название палитры", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
            
            if let error = viewModel.validationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Save
            Button("Сохранить") {
                if viewModel.save(colors: colors) {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(colors.isEmpty)

            Spacer()
        }
        .padding()
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Сохранение")
    }
}

#Preview("SavePaletteView") {
    let persistence = PersistenceController(inMemory: true)
    let context = persistence.container.viewContext
    let vm = SavePaletteViewModel(context: context)

    NavigationStack {
        SavePaletteView(
            viewModel: vm,
            colors: [.red, .green, .blue, .orange, .purple]
        )
    }
}
