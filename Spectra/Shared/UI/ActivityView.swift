//
//  ActivityView.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

