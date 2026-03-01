//
//  ImagePaletteExtractor.swift
//  Spectra
//
//  Created by Codex on 01.03.2026.
//

import UIKit

enum ImagePaletteExtractor {
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
            let pixels = rgbaPixels(from: resized)
        else {
            return []
        }

        let channels = 4
        let pixelCount = pixels.count / channels
        let sampleStep = max(1, pixelCount / targetSamplePixels)

        var histogram = [Int](repeating: 0, count: binsCount)
        for pixelIndex in stride(from: 0, to: pixelCount, by: sampleStep) {
            let base = pixelIndex * channels
            let r = pixels[base]
            let g = pixels[base + 1]
            let b = pixels[base + 2]
            let a = pixels[base + 3]

            guard a > 20 else { continue }

            let key = quantizedKey(r: r, g: g, b: b)
            histogram[key] += 1
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

    nonisolated private static func rgbaPixels(from image: UIImage) -> [UInt8]? {
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
        return pixels
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
        from histogram: [Int],
        limit: Int
    ) -> [(key: Int, count: Int)] {
        guard limit > 0 else { return [] }

        var top: [(key: Int, count: Int)] = []
        top.reserveCapacity(limit)

        for (key, count) in histogram.enumerated() where count > 0 {
            if top.count < limit {
                top.append((key, count))
                if top.count == limit {
                    top.sort { $0.count < $1.count }
                }
                continue
            }

            guard count > top[0].count else { continue }
            top[0] = (key, count)

            var index = 0
            while index + 1 < top.count, top[index].count > top[index + 1].count {
                top.swapAt(index, index + 1)
                index += 1
            }
        }

        return top.sorted { $0.count > $1.count }
    }
}
