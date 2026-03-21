//
//  PixelTheme.swift
//  Stars
//
//  Stardew Valley–inspired pixel art theme.
//  Warm, earthy, cozy — this is a game, not an enterprise app.
//

import UIKit

enum PixelTheme {

    // ─────────────────────────────────────
    // MARK: - Color Palette
    // ─────────────────────────────────────

    // Backgrounds (warm browns, like wooden panels)
    static let bgDeep       = UIColor(red: 0.10, green: 0.07, blue: 0.05, alpha: 1)   // deepest
    static let bgDark       = UIColor(red: 0.15, green: 0.11, blue: 0.08, alpha: 1)   // main bg
    static let bgMedium     = UIColor(red: 0.21, green: 0.16, blue: 0.11, alpha: 1)   // card bg
    static let bgLight      = UIColor(red: 0.27, green: 0.21, blue: 0.15, alpha: 1)   // elevated
    static let bgParchment  = UIColor(red: 0.32, green: 0.26, blue: 0.18, alpha: 1)   // parchment
    static let bgInput      = UIColor(red: 0.13, green: 0.09, blue: 0.06, alpha: 1)   // text fields

    // Borders
    static let borderDark   = UIColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1)
    static let borderWarm   = UIColor(red: 0.35, green: 0.27, blue: 0.18, alpha: 1)
    static let borderGold   = UIColor(red: 0.78, green: 0.58, blue: 0.22, alpha: 1)

    // Text
    static let textCream    = UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1)   // primary
    static let textTan      = UIColor(red: 0.68, green: 0.58, blue: 0.42, alpha: 1)   // secondary
    static let textGold     = UIColor(red: 0.95, green: 0.75, blue: 0.28, alpha: 1)   // headings
    static let textMuted    = UIColor(red: 0.45, green: 0.37, blue: 0.26, alpha: 1)   // hints
    static let textWhite    = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)   // bright

    // Accents (nature-inspired)
    static let accentGreen  = UIColor(red: 0.33, green: 0.66, blue: 0.24, alpha: 1)   // forest
    static let accentRed    = UIColor(red: 0.80, green: 0.28, blue: 0.22, alpha: 1)   // berry
    static let accentBlue   = UIColor(red: 0.38, green: 0.62, blue: 0.82, alpha: 1)   // sky
    static let accentAmber  = UIColor(red: 0.91, green: 0.66, blue: 0.22, alpha: 1)   // honey
    static let accentPurple = UIColor(red: 0.58, green: 0.38, blue: 0.72, alpha: 1)   // amethyst

    // HP indicator
    static let hpHigh       = UIColor(red: 0.38, green: 0.78, blue: 0.28, alpha: 1)
    static let hpMid        = UIColor(red: 0.92, green: 0.78, blue: 0.22, alpha: 1)
    static let hpLow        = UIColor(red: 0.88, green: 0.28, blue: 0.22, alpha: 1)

    // Chat bubbles
    static let bubbleOwner  = UIColor(red: 0.18, green: 0.26, blue: 0.36, alpha: 1)
    static let bubbleAgent  = UIColor(red: 0.26, green: 0.21, blue: 0.15, alpha: 1)
    static let bubbleSystem = UIColor(red: 0.18, green: 0.15, blue: 0.10, alpha: 1)

    // Status dots
    static let statusOK     = UIColor(red: 0.35, green: 0.75, blue: 0.30, alpha: 1)
    static let statusFail   = UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 1)
    static let statusUnknown = UIColor(red: 0.50, green: 0.42, blue: 0.30, alpha: 1)

    // ─────────────────────────────────────
    // MARK: - Typography (Fusion Pixel 12px)
    // ─────────────────────────────────────

    // PostScript names — registered in Info.plist via UIAppFonts
    private static let propFontName = "Fusion-Pixel-12px-Prop-zh_hans-Regular"
    private static let monoFontName = "Fusion-Pixel-12px-Mono-zh_hans-Regular"

    /// Header / title font — proportional pixel font, used for headings & labels
    static func headerFont(size: CGFloat) -> UIFont {
        UIFont(name: propFontName, size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }

    /// Body font — proportional pixel font, for readable text
    static func bodyFont(size: CGFloat) -> UIFont {
        UIFont(name: propFontName, size: size)
            ?? .systemFont(ofSize: size, weight: .regular)
    }

    /// Bold / monospaced pixel font — for stats, code-like displays
    static func boldFont(size: CGFloat) -> UIFont {
        UIFont(name: monoFontName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }

    /// SpriteKit font name (use with SKLabelNode.fontName)
    static let skFontName = propFontName
    static let skMonoFontName = monoFontName

    // Convenient presets — bumped sizes for pixel font readability
    static let fontTitle      = headerFont(size: 24)
    static let fontSubtitle   = headerFont(size: 18)
    static let fontSection    = boldFont(size: 16)
    static let fontBody       = bodyFont(size: 16)
    static let fontSmall      = bodyFont(size: 14)
    static let fontMicro      = bodyFont(size: 12)
    static let fontStats      = boldFont(size: 12)

    // ─────────────────────────────────────
    // MARK: - Layout Constants
    // ─────────────────────────────────────

    static let borderWidth: CGFloat     = 2
    static let thickBorder: CGFloat     = 3
    static let cornerRadius: CGFloat    = 3  // sharp pixel corners
    static let cardPadding: CGFloat     = 12
    static let cardSpacing: CGFloat     = 10

    // ─────────────────────────────────────
    // MARK: - View Helpers
    // ─────────────────────────────────────

    /// Apply a warm wood-panel frame to a view.
    static func applyPanel(_ view: UIView) {
        view.backgroundColor = bgMedium
        view.layer.borderWidth = thickBorder
        view.layer.borderColor = borderWarm.cgColor
        view.layer.cornerRadius = cornerRadius
        view.clipsToBounds = true
    }

    /// Apply a card style (inner content area).
    static func applyCard(_ view: UIView) {
        view.backgroundColor = bgLight
        view.layer.borderWidth = borderWidth
        view.layer.borderColor = borderWarm.cgColor
        view.layer.cornerRadius = cornerRadius
    }

    /// Apply input field styling (dark recessed look).
    static func applyInputField(_ field: UIView) {
        field.backgroundColor = bgInput
        field.layer.borderWidth = borderWidth
        field.layer.borderColor = borderDark.cgColor
        field.layer.cornerRadius = cornerRadius
    }

    /// Style a UIButton as a chunky game button.
    static func applyButton(_ button: UIButton, color: UIColor = accentGreen) {
        button.backgroundColor = color
        button.layer.borderWidth = borderWidth
        button.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        button.layer.cornerRadius = cornerRadius
        button.titleLabel?.font = boldFont(size: 16)
        button.setTitleColor(textWhite, for: .normal)
    }

    /// Style a UIButton as a secondary (outlined) button.
    static func applyOutlineButton(_ button: UIButton, color: UIColor = borderWarm) {
        button.backgroundColor = bgMedium
        button.layer.borderWidth = borderWidth
        button.layer.borderColor = color.cgColor
        button.layer.cornerRadius = cornerRadius
        button.titleLabel?.font = boldFont(size: 16)
        button.setTitleColor(textCream, for: .normal)
    }

    /// Style a navigation bar with warm pixel theme.
    static func styleNavBar(_ navBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgMedium
        appearance.titleTextAttributes = [
            .foregroundColor: textGold,
            .font: headerFont(size: 20)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: textGold,
            .font: headerFont(size: 26)
        ]
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = accentAmber
    }

    /// Style a table view with warm background.
    static func styleTableView(_ tv: UITableView) {
        tv.backgroundColor = bgDark
        tv.separatorColor = borderWarm.withAlphaComponent(0.3)
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }

    // ─────────────────────────────────────
    // MARK: - Decorative Elements
    // ─────────────────────────────────────

    /// Create a horizontal pixel-style divider.
    static func makeDivider(color: UIColor = borderWarm) -> UIView {
        let line = UIView()
        line.backgroundColor = color
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 2).isActive = true
        return line
    }

    /// Create a section header label with icon.
    static func makeSectionHeader(_ text: String, icon: String = "") -> UILabel {
        let label = UILabel()
        label.text = icon.isEmpty ? text : "\(icon) \(text)"
        label.font = fontSection
        label.textColor = textGold
        return label
    }

    /// Create a warm-styled text view (journal/parchment feel).
    static func makeTextView() -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = bgInput
        tv.textColor = textCream
        tv.font = bodyFont(size: 16)
        tv.tintColor = accentAmber
        tv.layer.borderWidth = borderWidth
        tv.layer.borderColor = borderDark.cgColor
        tv.layer.cornerRadius = cornerRadius
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        return tv
    }

}
