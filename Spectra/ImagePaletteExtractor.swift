//
//  ImagePaletteExtractor.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import UIKit

enum ImagePaletteExtractor {
    private struct BinStat {
        var population: Int = 0
        var weightedScore: Double = 0
    }

    private struct RGB {
        let r: Double
        let g: Double
        let b: Double
    }

    nonisolated static func extractColors(from image: UIImage, maxColors: Int = 5) -> [UIColor] {
        let binsCount = 32 * 32 * 32
        let maxHistogramCandidates = 96
        let distinctDistanceSquared = 0.16 * 0.16
        let targetSamplePixels = 12000

        guard
            maxColors > 0,
            let resized = resize(image: image, maxDimension: 140),
            let rgba = rgbaPixels(from: resized)
        else {
            return []
        }

        let pixels = rgba.pixels
        let width = rgba.width
        let height = rgba.height
        let channels = 4
        let pixelCount = pixels.count / channels
        let sampleStep = max(1, pixelCount / targetSamplePixels)

        var histogram = [BinStat](repeating: BinStat(), count: binsCount)
        let centerX = Double(width - 1) * 0.5
        let centerY = Double(height - 1) * 0.5
        let maxRadius = max(1.0, sqrt(centerX * centerX + centerY * centerY))

        for pixelIndex in stride(from: 0, to: pixelCount, by: sampleStep) {
            let base = pixelIndex * channels
            let r = pixels[base]
            let g = pixels[base + 1]
            let b = pixels[base + 2]
            let a = pixels[base + 3]

            guard a > 20 else { continue }

            let rgb = normalizedRGB(r: r, g: g, b: b)
            let hsv = rgbToHSV(rgb)
            let weight = prominenceWeight(
                hsv: hsv,
                pixelIndex: pixelIndex,
                width: width,
                centerX: centerX,
                centerY: centerY,
                maxRadius: maxRadius
            )

            let key = quantizedKey(r: r, g: g, b: b)
            histogram[key].population += 1
            histogram[key].weightedScore += weight
        }

        let topBins = topHistogramBins(from: histogram, limit: maxHistogramCandidates)
        var result: [UIColor] = []
        var selected: [RGB] = []
        selected.reserveCapacity(maxColors)

        for bin in topBins {
            let rgb = rgbFromQuantizedKey(bin.key)
            let isDistinct = selected.allSatisfy {
                colorDistanceSquared($0, rgb) > distinctDistanceSquared
            }

            if isDistinct {
                selected.append(rgb)
                result.append(
                    UIColor(
                        red: CGFloat(rgb.r),
                        green: CGFloat(rgb.g),
                        blue: CGFloat(rgb.b),
                        alpha: 1
                    )
                )
            }

            if result.count == maxColors {
                break
            }
        }

        return result
    }

    nonisolated private static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated private static func rgbaPixels(from image: UIImage) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height)
    }

    nonisolated private static func quantizedKey(r: UInt8, g: UInt8, b: UInt8) -> Int {
        let qr = Int(r >> 3)
        let qg = Int(g >> 3)
        let qb = Int(b >> 3)
        return (qr << 10) | (qg << 5) | qb
    }

    nonisolated private static func rgbFromQuantizedKey(_ key: Int) -> RGB {
        let qr = (key >> 10) & 0x1F
        let qg = (key >> 5) & 0x1F
        let qb = key & 0x1F

        return RGB(
            r: Double(qr * 8 + 4) / 255.0,
            g: Double(qg * 8 + 4) / 255.0,
            b: Double(qb * 8 + 4) / 255.0
        )
    }

    nonisolated private static func colorDistanceSquared(_ a: RGB, _ b: RGB) -> Double {
        let dr = a.r - b.r
        let dg = a.g - b.g
        let db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }

    nonisolated private static func topHistogramBins(
        from histogram: [BinStat],
        limit: Int
    ) -> [(key: Int, score: Double, population: Int)] {
        guard limit > 0 else { return [] }

        var top: [(key: Int, score: Double, population: Int)] = []
        top.reserveCapacity(limit)

        for (key, stat) in histogram.enumerated() where stat.population > 0 {
            let score = stat.weightedScore
            let population = stat.population

            if top.count < limit {
                top.append((key, score, population))
                if top.count == limit {
                    top.sort { lhs, rhs in
                        if lhs.score == rhs.score {
                            return lhs.population < rhs.population
                        }
                        return lhs.score < rhs.score
                    }
                }
                continue
            }

            if score < top[0].score {
                continue
            }
            if score == top[0].score, population <= top[0].population {
                continue
            }

            top[0] = (key, score, population)

            var index = 0
            while index + 1 < top.count {
                let shouldSwap: Bool
                if top[index].score == top[index + 1].score {
                    shouldSwap = top[index].population > top[index + 1].population
                } else {
                    shouldSwap = top[index].score > top[index + 1].score
                }
                guard shouldSwap else { break }
                top.swapAt(index, index + 1)
                index += 1
            }
        }

        return top.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.population > rhs.population
            }
            return lhs.score > rhs.score
        }
    }

    nonisolated private static func normalizedRGB(r: UInt8, g: UInt8, b: UInt8) -> RGB {
        RGB(
            r: Double(r) / 255.0,
            g: Double(g) / 255.0,
            b: Double(b) / 255.0
        )
    }

    nonisolated private static func rgbToHSV(_ rgb: RGB) -> (h: Double, s: Double, v: Double) {
        let maxValue = max(rgb.r, rgb.g, rgb.b)
        let minValue = min(rgb.r, rgb.g, rgb.b)
        let delta = maxValue - minValue
        let saturation = maxValue == 0 ? 0 : delta / maxValue

        var hue = 0.0
        if delta > 0 {
            if maxValue == rgb.r {
                hue = (rgb.g - rgb.b) / delta
            } else if maxValue == rgb.g {
                hue = 2 + (rgb.b - rgb.r) / delta
            } else {
                hue = 4 + (rgb.r - rgb.g) / delta
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }

        return (hue, saturation, maxValue)
    }

    nonisolated private static func prominenceWeight(
        hsv: (h: Double, s: Double, v: Double),
        pixelIndex: Int,
        width: Int,
        centerX: Double,
        centerY: Double,
        maxRadius: Double
    ) -> Double {
        let x = Double(pixelIndex % width)
        let y = Double(pixelIndex / width)
        let dx = x - centerX
        let dy = y - centerY
        let radial = min(1.0, sqrt(dx * dx + dy * dy) / maxRadius)

        let centerBoost = 1.0 + (1.0 - radial) * 0.25
        let saturationBoost = 0.35 + hsv.s * 1.65
        let brightnessBoost = 0.55 + min(hsv.v, 0.95) * 0.75

        let neutralPenalty = hsv.s < 0.16 ? 0.20 : 1.0
        let darkPenalty = hsv.v < 0.11 ? 0.25 : 1.0

        return saturationBoost * brightnessBoost * centerBoost * neutralPenalty * darkPenalty
    }
}
