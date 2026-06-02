//
//  Theme.swift
//  myNetworth
//

import SwiftUI

/// Semantic color definitions for the app.
enum Theme {
    // Background gradients
    static let mainGradient1 = Color("bgMain1")
    static let mainGradient2 = Color("bgMain2")
    static let assetGradient1 = Color("bgAsset1")
    static let assetGradient2 = Color("bgAsset2")
    static let liabilityGradient1 = Color("bgLiability1")
    static let liabilityGradient2 = Color("bgLiability2")

    // Semantic
    static let positiveAmount = Color.green
    static let negativeAmount = Color.red
    static let accent = Color.accentColor
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let cardBackground = Color.white.opacity(0.1)
    static let cardBorder = Color.blue.opacity(0.3)
    static let subtleBackground = Color.white.opacity(0.05)
}

// MARK: - Item Color Environment

/// Environment colors for assets and liabilities, configurable in Settings and
/// injected at the app root so any view can read them without the view model.
extension EnvironmentValues {
    /// Color used for all assets. Defaults to green.
    @Entry var assetColor: Color = .green
    /// Color used for all liabilities. Defaults to black.
    @Entry var liabilityColor: Color = .black
}
