//
//  ColorHarmony.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import Foundation

struct HarmonyColor: Hashable {
    let hue: Double
    let saturation: Double
    let brightness: Double
}

enum ColorHarmony: String, CaseIterable {
    case free = "Свободный выбор"
    case monochrome = "Монохромная"
    case complementary = "Комплиментарная"
    case triad = "Треугольная"
    case square = "Квадратная"

    func colors(
        baseHue: Double,
        baseSaturation: Double
    ) -> [HarmonyColor] {

        switch self {

        case .free:
            return [
                HarmonyColor(
                    hue: baseHue,
                    saturation: baseSaturation,
                    brightness: 1
                )
            ]

        case .monochrome:
            // Adobe-подобный веер по радиусу
            let steps: [Double] = [0.25, 0.45, 0.65, 0.85, 1.0]

            return steps.map {
                HarmonyColor(
                    hue: baseHue,
                    saturation: $0,
                    brightness: 1 - ($0 * 0.15)
                )
            }

        case .complementary:
            return [
                baseHue,
                baseHue + 0.5
            ].map {
                HarmonyColor(
                    hue: $0.truncatingRemainder(dividingBy: 1),
                    saturation: baseSaturation,
                    brightness: 1
                )
            }

        case .triad:
            return [
                baseHue,
                baseHue + 1.0 / 3.0,
                baseHue + 2.0 / 3.0
            ].map {
                HarmonyColor(
                    hue: $0.truncatingRemainder(dividingBy: 1),
                    saturation: baseSaturation,
                    brightness: 1
                )
            }

        case .square:
            return [
                baseHue,
                baseHue + 0.25,
                baseHue + 0.5,
                baseHue + 0.75
            ].map {
                HarmonyColor(
                    hue: $0.truncatingRemainder(dividingBy: 1),
                    saturation: baseSaturation,
                    brightness: 1
                )
            }
        }
    }
}
