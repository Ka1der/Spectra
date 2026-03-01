//
//  HarmonyDetector.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import UIKit

enum HarmonyDetector {

    nonisolated static func detectClosestHarmony(
        from colors: [UIColor],
        fallbackHue: Double
    ) -> (harmony: ColorHarmony, baseHue: Double) {
        let hueValues: [Double] = colors.compactMap { color in
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
                return nil
            }

            return Double(h)
        }

        guard let firstHue = hueValues.first else {
            return (.free, fallbackHue)
        }

        let hues = hueValues.map(normalizeHue)
        let dispersion = circularDispersion(hues)

        if dispersion < 0.08 {
            let base = circularMean(hues) ?? firstHue
            return (.monochrome, normalizeHue(base))
        }

        let schemes: [ColorHarmony] = [.complementary, .triad, .square]
        var bestScheme: ColorHarmony = .free
        var bestBase: Double = firstHue
        var bestScore = Double.greatestFiniteMagnitude

        for scheme in schemes {
            for base in hues {
                let expected = expectedHues(for: scheme, baseHue: base)
                let score = harmonyScore(
                    sourceHues: hues,
                    expectedHues: expected,
                    expectedCount: expected.count
                )

                if score < bestScore {
                    bestScore = score
                    bestScheme = scheme
                    bestBase = base
                }
            }
        }

        if bestScore > 0.115 {
            return (.free, firstHue)
        }

        return (bestScheme, normalizeHue(bestBase))
    }

    nonisolated private static func expectedHues(for harmony: ColorHarmony, baseHue: Double) -> [Double] {
        switch harmony {
        case .complementary:
            return [baseHue, baseHue + 0.5].map(normalizeHue)
        case .triad:
            return [baseHue, baseHue + 1.0 / 3.0, baseHue + 2.0 / 3.0].map(normalizeHue)
        case .square:
            return [baseHue, baseHue + 0.25, baseHue + 0.5, baseHue + 0.75].map(normalizeHue)
        case .monochrome, .free:
            return [normalizeHue(baseHue)]
        }
    }

    nonisolated private static func harmonyScore(
        sourceHues: [Double],
        expectedHues: [Double],
        expectedCount: Int
    ) -> Double {
        let sourceToExpected = sourceHues
            .map { hue in expectedHues.map { circularDistance(hue, $0) }.min() ?? 1 }
            .reduce(0, +) / Double(max(sourceHues.count, 1))

        let expectedToSource = expectedHues
            .map { hue in sourceHues.map { circularDistance(hue, $0) }.min() ?? 1 }
            .reduce(0, +) / Double(max(expectedHues.count, 1))

        let complexityPenalty = Double(expectedCount - 1) * 0.02
        return sourceToExpected * 0.65 + expectedToSource * 0.35 + complexityPenalty
    }

    nonisolated private static func normalizeHue(_ value: Double) -> Double {
        let normalized = value.truncatingRemainder(dividingBy: 1)
        return normalized >= 0 ? normalized : normalized + 1
    }

    nonisolated private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        let delta = abs(normalizeHue(a) - normalizeHue(b))
        return min(delta, 1 - delta)
    }

    nonisolated private static func circularDispersion(_ hues: [Double]) -> Double {
        guard !hues.isEmpty else { return 1 }
        let meanCos = hues.map { cos($0 * 2 * .pi) }.reduce(0, +) / Double(hues.count)
        let meanSin = hues.map { sin($0 * 2 * .pi) }.reduce(0, +) / Double(hues.count)
        let r = sqrt(meanCos * meanCos + meanSin * meanSin)
        return 1 - r
    }

    nonisolated private static func circularMean(_ hues: [Double]) -> Double? {
        guard !hues.isEmpty else { return nil }
        let meanCos = hues.map { cos($0 * 2 * .pi) }.reduce(0, +) / Double(hues.count)
        let meanSin = hues.map { sin($0 * 2 * .pi) }.reduce(0, +) / Double(hues.count)
        return normalizeHue(atan2(meanSin, meanCos) / (2 * .pi))
    }
}
