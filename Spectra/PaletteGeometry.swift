//
//  PaletteGeometry.swift
//  Spectra
//
//  Created by Kaider on 29.01.2026.
//

import SwiftUI

struct PaletteGeometry {

    static func point(
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
