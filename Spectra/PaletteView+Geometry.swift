//
//  PaletteView+Geometry.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI

// MARK: - Geometry & Gestures
extension PaletteView {

    func marker(
        color: HarmonyColor,
        radius: CGFloat,
        center: CGPoint,
        isMain: Bool
    ) -> some View {
        Circle()
            .fill(
                Color(
                    hue: color.hue,
                    saturation: color.saturation,
                    brightness: color.brightness
                )
            )
            .overlay(Circle().stroke(.black, lineWidth: 2))
            .frame(width: isMain ? 18 : 16, height: isMain ? 18 : 16)
            .position(
                PaletteGeometry.point(
                    hue: color.hue,
                    saturation: color.saturation,
                    radius: radius,
                    center: center
                )
            )
    }

    func polygon(
        colors: [HarmonyColor],
        radius: CGFloat,
        center: CGPoint
    ) -> some View {
        Path { path in
            guard let first = colors.first else { return }

            path.move(
                to: PaletteGeometry.point(
                    hue: first.hue,
                    saturation: first.saturation,
                    radius: radius,
                    center: center
                )
            )

            for c in colors.dropFirst() {
                path.addLine(
                    to: PaletteGeometry.point(
                        hue: c.hue,
                        saturation: c.saturation,
                        radius: radius,
                        center: center
                    )
                )
            }

            path.closeSubpath()
        }
        .stroke(.black.opacity(0.6), lineWidth: 1)
    }

    func dragGesture(
        center: CGPoint,
        radius: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - center.x
                let dy = value.location.y - center.y
                let distance = sqrt(dx * dx + dy * dy)

                guard distance <= radius else { return }

                let angle = atan2(dy, dx)
                hue = angle < 0
                    ? (angle + 2 * Double.pi) / (2 * Double.pi)
                    : angle / (2 * Double.pi)

                saturation = min(distance / radius, 1)
            }
    }
}

