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
    static let summaryGradient1 = Color(red: 0.05, green: 0.15, blue: 0.35)
    static let summaryGradient2 = Color(red: 0.1, green: 0.25, blue: 0.45)

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
