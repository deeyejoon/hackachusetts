//  SageFonts.swift
//  Typography helpers for Sage.
//
//  Headings/logo use a serif (Fraunces if bundled, else the system serif).
//  Body uses a sans-serif (Inter if bundled, else the system default).
//
//  To use custom fonts, add Fraunces / Inter .ttf files to the app target and
//  register them in Info.plist under "Fonts provided by application". The
//  helpers fall back to system faces automatically if the custom fonts are
//  not present.

import SwiftUI

enum SageFont {
    /// Serif display face for headings and the logo.
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if UIFont(name: "Fraunces", size: size) != nil {
            return .custom("Fraunces", size: size).weight(weight)
        }
        // System serif fallback.
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Sans-serif body face.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if UIFont(name: "Inter", size: size) != nil {
            return .custom("Inter", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }
}
