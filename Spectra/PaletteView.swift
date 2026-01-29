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

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var harmony: ColorHarmony = .free
    @State private var showHarmonyPicker = false

    // MARK: - Colors

    private var selectedColor: Color {
        Color(hue: hue, saturation: saturation, brightness: 1)
    }

    private var complementaryColor: Color {
        Color(
            hue: (hue + 0.5).truncatingRemainder(dividingBy: 1),
            saturation: saturation,
            brightness: 1
        )
    }
    
    private var triadColors: [Color] {
        [
            Color(hue: hue, saturation: saturation, brightness: 1),
            Color(hue: (hue + 1.0 / 3.0).truncatingRemainder(dividingBy: 1),
                  saturation: saturation,
                  brightness: 1),
            Color(hue: (hue + 2.0 / 3.0).truncatingRemainder(dividingBy: 1),
                  saturation: saturation,
                  brightness: 1)
        ]
    }

    private var triadHues: [Double] {
        [
            hue,
            (hue + 1.0 / 3.0).truncatingRemainder(dividingBy: 1),
            (hue + 2.0 / 3.0).truncatingRemainder(dividingBy: 1)
        ]
    }

    private var hexColor: String {
        UIColor(selectedColor).toHex()
    }

    private var complementaryHex: String {
        UIColor(complementaryColor).toHex()
    }
    
    private var squareHues: [Double] {
        [
            hue,
            (hue + 0.25).truncatingRemainder(dividingBy: 1),
            (hue + 0.50).truncatingRemainder(dividingBy: 1),
            (hue + 0.75).truncatingRemainder(dividingBy: 1)
        ]
    }

    private var squareColors: [Color] {
        squareHues.map {
            Color(hue: $0, saturation: saturation, brightness: 1)
        }
    }

    // MARK: - Harmony

    enum ColorHarmony: String, CaseIterable {
        case free = "Свободный выбор"
        case complementary = "Complementary"
        case triad = "Triad"
        case square = "Square"
    }

    // MARK: - UI

    var body: some View {
        VStack(spacing: 16) {

            // Picker
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

            // Color wheel
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let radius = size / 2
                let center = CGPoint(x: radius, y: radius)

                ZStack {
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

                    // Main marker
                    marker(
                        color: selectedColor,
                        hue: hue,
                        saturation: saturation,
                        radius: radius,
                        center: center,
                        size: 18
                    )

                    // Complementary marker
                    if harmony == .complementary {
                        let hues = [
                            hue,
                            (hue + 0.5).truncatingRemainder(dividingBy: 1)
                        ]

                        polygon(
                            hues: hues,
                            saturation: saturation,
                            radius: radius,
                            center: center
                        )

                        ForEach(hues, id: \.self) { h in
                            marker(
                                color: Color(hue: h, saturation: saturation, brightness: 1),
                                hue: h,
                                saturation: saturation,
                                radius: radius,
                                center: center,
                                size: h == hue ? 18 : 16
                            )
                        }
                    }
                    
                    // Triad marker
                    if harmony == .triad {
                        polygon(
                            hues: triadHues,
                            saturation: saturation,
                            radius: radius,
                            center: center
                        )

                        ForEach(triadHues, id: \.self) { h in
                            marker(
                                color: Color(hue: h, saturation: saturation, brightness: 1),
                                hue: h,
                                saturation: saturation,
                                radius: radius,
                                center: center,
                                size: h == hue ? 18 : 16
                            )
                        }
                    }

                    // Square marker
                    if harmony == .square {
                        polygon(
                            hues: squareHues,
                            saturation: saturation,
                            radius: radius,
                            center: center
                        )

                        ForEach(squareHues, id: \.self) { h in
                            marker(
                                color: Color(hue: h, saturation: saturation, brightness: 1),
                                hue: h,
                                saturation: saturation,
                                radius: radius,
                                center: center,
                                size: h == hue ? 18 : 16
                            )
                        }
                    }
                }
                .contentShape(Circle())
                .gesture(
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
                )
            }
            .frame(width: 270, height: 270)

            // Preview + HEX
            HStack(spacing: 12) {

                switch harmony {

                case .free:
                    preview(color: selectedColor, hex: hexColor)

                case .complementary:
                    preview(color: selectedColor, hex: hexColor)
                    preview(color: complementaryColor, hex: complementaryHex)

                case .triad:
                    ForEach(triadColors, id: \.self) { color in
                        preview(
                            color: color,
                            hex: UIColor(color).toHex()
                        )
                    }

                case .square:
                    ForEach(squareColors, id: \.self) { color in
                        preview(
                            color: color,
                            hex: UIColor(color).toHex()
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func marker(
        color: Color,
        hue: Double,
        saturation: Double,
        radius: CGFloat,
        center: CGPoint,
        size: CGFloat
    ) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .frame(width: size, height: size)
            .position(
                point(
                    hue: hue,
                    saturation: saturation,
                    radius: radius,
                    center: center
                )
            )
    }
    
    private func polygon(
        hues: [Double],
        saturation: Double,
        radius: CGFloat,
        center: CGPoint
    ) -> some View {
        Path { path in
            guard let first = hues.first else { return }

            let firstPoint = point(
                hue: first,
                saturation: saturation,
                radius: radius,
                center: center
            )

            path.move(to: firstPoint)

            for h in hues.dropFirst() {
                path.addLine(
                    to: point(
                        hue: h,
                        saturation: saturation,
                        radius: radius,
                        center: center
                    )
                )
            }

            path.closeSubpath()
        }
        .stroke(.white.opacity(0.6), lineWidth: 1)
    }

    private func preview(color: Color, hex: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(height: 60)

            Text(hex)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func point(
        hue: Double,
        saturation: Double,
        radius: CGFloat,
        center: CGPoint
    ) -> CGPoint {
        let angle = CGFloat(hue * 2 * Double.pi)
        let r = radius * CGFloat(saturation)

        return CGPoint(
            x: center.x + cos(angle) * r,
            y: center.y + sin(angle) * r
        )
    }
}

// MARK: - HEX

extension UIColor {
    func toHex() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}

#Preview {
    PaletteView(colors: [])
}
