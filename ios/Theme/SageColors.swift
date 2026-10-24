//  SageColors.swift
//  Sage design-system palette.
//
//  Warm, non-clinical tones. Expose every brand color as a static `Color` so
//  views reference `Color.sageMoss` rather than scattering hex literals.

import SwiftUI

extension Color {
    /// App background — warm off-white.  #F6F3EC
    static let sageBackground = Color(hex: 0xF6F3EC)

    /// Card / bubble surfaces.  #FFFFFF
    static let sageSurface = Color(hex: 0xFFFFFF)

    /// Primary text — near-black warm.  #2A2A24
    static let sageText = Color(hex: 0x2A2A24)

    /// Muted / secondary text.  #767468
    static let sageMuted = Color(hex: 0x767468)

    /// Primary accent — moss green.  #5F7A5A
    static let sageMoss = Color(hex: 0x5F7A5A)

    /// Secondary accent — terracotta.  #C97B5B
    static let sageTerracotta = Color(hex: 0xC97B5B)

    /// Hairline borders.  #E4E0D4
    static let sageBorder = Color(hex: 0xE4E0D4)

    /// Dark surface for "insight" / crisis bubbles.
    static let sageDark = Color(hex: 0x2A2A24)
}

extension Color {
    /// Build a Color from a 0xRRGGBB integer.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
