//
//  AboutViewController.swift
//  Stars
//
//  About page — app info, open source, QTC store, tip jar, legal links.
//  Stardew Valley pixel art style.
//

import UIKit
import StoreKit

final class AboutViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // StoreKit products
    private var tipProduct: Product?
    private var tipButton: UIButton?
    private var qtc10Product: Product?
    private var qtc50Product: Product?
    private var qtc10Button: UIButton?
    private var qtc50Button: UIButton?

    // QTC Dashboard (live-updated)
    private var qtcBalanceLabel: UILabel?
    private var qtcDetailView: UITextView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = PixelTheme.bgDark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.titleView = PixelTheme.makeNavTitleView(
            iconName: "Stars icon",
            text: NSLocalizedString("about.title", comment: "")
        )

        setupLayout()
        loadAllProducts()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshQTCDashboard),
            name: QTCStore.balanceDidChange, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }
        refreshQTCDashboard()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
        ])
        let fillW = contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -16)
        fillW.priority = .defaultHigh
        fillW.isActive = true
        contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 600).isActive = true

        contentStack.addArrangedSubview(makeHeroSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeInfoSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeOpenSourceSection())
        contentStack.addArrangedSubview(makeMusicCreditsSection())
        contentStack.addArrangedSubview(makeQTCPurchaseSection())     // QTC purchase — above tip
        contentStack.addArrangedSubview(makeTipSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeQTCDashboardSection())    // QTC dashboard — above legal
        contentStack.addArrangedSubview(makeLegalSection())
    }

    // MARK: - Hero Section

    private func makeHeroSection() -> UIView {
        let container = UIView()
        container.backgroundColor = PixelTheme.bgMedium
        container.layer.borderWidth = PixelTheme.thickBorder
        container.layer.borderColor = PixelTheme.borderWarm.cgColor
        container.layer.cornerRadius = PixelTheme.cornerRadius

        let icon = UIImageView()
        icon.image = .pixelIcon(named: "Stars icon")
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let title = UILabel()
        title.text = NSLocalizedString("about.app_title", comment: "")
        title.font = PixelTheme.headerFont(size: 28)
        title.textColor = PixelTheme.textGold
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = NSLocalizedString("about.subtitle", comment: "")
        subtitle.font = PixelTheme.headerFont(size: 16)
        subtitle.textColor = PixelTheme.textTan
        subtitle.textAlignment = .center

        let version = UILabel()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        version.text = "v\(appVersion) (\(buildNumber))"
        version.font = PixelTheme.bodyFont(size: 14)
        version.textColor = PixelTheme.textMuted
        version.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle, version])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
        ])
        return container
    }

    // MARK: - Info Section

    private func makeInfoSection() -> UIView {
        let label = UILabel()
        label.text = NSLocalizedString("about.description", comment: "")
        label.font = PixelTheme.bodyFont(size: 14)
        label.textColor = PixelTheme.textCream
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }

    // MARK: - Open Source Section

    private func makeOpenSourceSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("about.opensource", comment: "")
        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold

        let descLabel = UILabel()
        descLabel.text = NSLocalizedString("about.opensource_desc", comment: "")
        descLabel.font = PixelTheme.bodyFont(size: 14)
        descLabel.textColor = PixelTheme.textTan
        descLabel.numberOfLines = 0

        let ghButton = UIButton(type: .system)
        ghButton.setTitle(NSLocalizedString("about.github", comment: ""), for: .normal)
        PixelTheme.applyButton(ghButton, color: PixelTheme.bgLight)
        ghButton.layer.borderColor = PixelTheme.accentAmber.cgColor
        ghButton.setTitleColor(PixelTheme.accentAmber, for: .normal)
        ghButton.addTarget(self, action: #selector(openGitHub), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, ghButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            ghButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        return card
    }

    // MARK: - Music Credits Section

    private func makeMusicCreditsSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("about.music_title", comment: "")
        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold

        let creditsLabel = UILabel()
        creditsLabel.numberOfLines = 0
        creditsLabel.font = PixelTheme.bodyFont(size: 14)
        creditsLabel.textColor = PixelTheme.textTan
        creditsLabel.text = """
        🎵 Moon and Sun
        \(NSLocalizedString("about.music_from", comment: ""))

        🎵 Everything Moves
        \(NSLocalizedString("about.music_from", comment: ""))

        🎵 Litae
        \(NSLocalizedString("about.music_from", comment: ""))
        """

        let linkButton = UIButton(type: .system)
        linkButton.setTitle("🔗 fiftysounds.com", for: .normal)
        PixelTheme.applyButton(linkButton, color: PixelTheme.bgLight)
        linkButton.layer.borderColor = PixelTheme.accentAmber.cgColor
        linkButton.setTitleColor(PixelTheme.accentAmber, for: .normal)
        linkButton.addTarget(self, action: #selector(openFiftySounds), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, creditsLabel, linkButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            linkButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        return card
    }

    // MARK: - QTC Purchase Section

    private func makeQTCPurchaseSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.thickBorder
        card.layer.borderColor = PixelTheme.accentAmber.withAlphaComponent(0.6).cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("qtc.purchase_title", comment: "")
        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold

        let descLabel = UILabel()
        descLabel.text = NSLocalizedString("qtc.purchase_desc", comment: "")
        descLabel.font = PixelTheme.bodyFont(size: 14)
        descLabel.textColor = PixelTheme.textTan
        descLabel.numberOfLines = 0

        // QTC ×10 button
        let btn10 = UIButton(type: .system)
        btn10.setTitle(NSLocalizedString("qtc.loading", comment: ""), for: .normal)
        PixelTheme.applyButton(btn10, color: PixelTheme.accentAmber)
        btn10.setTitleColor(PixelTheme.bgDark, for: .normal)
        btn10.addTarget(self, action: #selector(buyQTC10), for: .touchUpInside)
        btn10.isEnabled = false
        self.qtc10Button = btn10

        // QTC ×50 button
        let btn50 = UIButton(type: .system)
        btn50.setTitle(NSLocalizedString("qtc.loading", comment: ""), for: .normal)
        PixelTheme.applyButton(btn50, color: PixelTheme.accentAmber)
        btn50.setTitleColor(PixelTheme.bgDark, for: .normal)
        btn50.addTarget(self, action: #selector(buyQTC50), for: .touchUpInside)
        btn50.isEnabled = false
        self.qtc50Button = btn50

        let buttonsRow = UIStackView(arrangedSubviews: [btn10, btn50])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10
        buttonsRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, buttonsRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            buttonsRow.heightAnchor.constraint(equalToConstant: 44),
        ])
        return card
    }

    // MARK: - Tip Section

    private func makeTipSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let tipIcon = UIImageView()
        tipIcon.image = .pixelIcon(named: "咖啡")
        tipIcon.contentMode = .scaleAspectFit
        tipIcon.translatesAutoresizingMaskIntoConstraints = false
        tipIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        tipIcon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleText = UILabel()
        titleText.text = NSLocalizedString("about.tip_title", comment: "")
        titleText.font = PixelTheme.headerFont(size: 18)
        titleText.textColor = PixelTheme.textGold

        let titleLabel = UIStackView(arrangedSubviews: [tipIcon, titleText])
        titleLabel.axis = .horizontal
        titleLabel.spacing = 6
        titleLabel.alignment = .center

        let descLabel = UILabel()
        descLabel.text = NSLocalizedString("about.tip_desc", comment: "")
        descLabel.font = PixelTheme.bodyFont(size: 14)
        descLabel.textColor = PixelTheme.textTan
        descLabel.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("about.tip_loading", comment: ""), for: .normal)
        PixelTheme.applyButton(button, color: PixelTheme.accentAmber)
        button.setTitleColor(PixelTheme.bgDark, for: .normal)
        button.addTarget(self, action: #selector(buyTip), for: .touchUpInside)
        button.isEnabled = false
        self.tipButton = button

        let stack = UIStackView(arrangedSubviews: [titleLabel, descLabel, button])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return card
    }

    // MARK: - QTC Dashboard Section

    private func makeQTCDashboardSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("qtc.dashboard_title", comment: "")
        titleLabel.font = PixelTheme.headerFont(size: 16)
        titleLabel.textColor = PixelTheme.textGold

        let balLabel = UILabel()
        balLabel.font = PixelTheme.headerFont(size: 22)
        balLabel.textColor = PixelTheme.accentAmber
        balLabel.textAlignment = .center
        self.qtcBalanceLabel = balLabel

        let detailTV = UITextView()
        detailTV.backgroundColor = PixelTheme.bgInput
        detailTV.textColor = PixelTheme.textTan
        detailTV.font = PixelTheme.bodyFont(size: 12)
        detailTV.layer.cornerRadius = PixelTheme.cornerRadius
        detailTV.layer.borderWidth = PixelTheme.borderWidth
        detailTV.layer.borderColor = PixelTheme.borderDark.cgColor
        detailTV.isEditable = false
        detailTV.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        detailTV.translatesAutoresizingMaskIntoConstraints = false
        self.qtcDetailView = detailTV

        let stack = UIStackView(arrangedSubviews: [titleLabel, balLabel, detailTV])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            detailTV.heightAnchor.constraint(equalToConstant: 120),
        ])

        refreshQTCDashboard()

        return card
    }

    @objc private func refreshQTCDashboard() {
        let store = QTCStore.shared
        let agentCount = store.currentAgentCount
        let maxAgents = store.maxAgents
        qtcBalanceLabel?.text = String(
            format: NSLocalizedString("qtc.balance_display", comment: ""),
            store.balance, agentCount, maxAgents
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        var lines = [String]()
        let freeRemain = store.freeSlotRemaining
        if freeRemain > 0 {
            lines.append(String(format: NSLocalizedString("qtc.free_slots", comment: ""), freeRemain))
        } else {
            lines.append(NSLocalizedString("qtc.no_free_slots", comment: ""))
        }
        lines.append("")

        let txs = store.transactions
        if txs.isEmpty {
            lines.append(NSLocalizedString("qtc.no_transactions", comment: ""))
        } else {
            lines.append(NSLocalizedString("qtc.recent_transactions", comment: ""))
            for tx in txs.suffix(15).reversed() {
                let time = formatter.string(from: Date(timeIntervalSince1970: tx.timestamp))
                let sign = tx.amount >= 0 ? "+" : ""
                lines.append("  [\(time)] \(sign)\(tx.amount) QTC  \(tx.reason) → \(tx.balance)")
            }
        }

        qtcDetailView?.text = lines.joined(separator: "\n")
    }

    // MARK: - Legal Section

    private func makeLegalSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let items: [(String, Selector)] = [
            (NSLocalizedString("about.terms", comment: ""), #selector(openTerms)),
            (NSLocalizedString("about.privacy", comment: ""), #selector(openPrivacy)),
            (NSLocalizedString("about.recommended", comment: ""), #selector(openRecommended)),
        ]

        for (title, action) in items {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = PixelTheme.bodyFont(size: 16)
            button.setTitleColor(PixelTheme.accentBlue, for: .normal)
            button.addTarget(self, action: action, for: .touchUpInside)

            let row = UIView()
            row.backgroundColor = PixelTheme.bgMedium
            row.layer.borderWidth = 1
            row.layer.borderColor = PixelTheme.borderWarm.cgColor
            row.layer.cornerRadius = PixelTheme.cornerRadius

            let arrow = UILabel()
            arrow.text = "▸"
            arrow.font = PixelTheme.boldFont(size: 16)
            arrow.textColor = PixelTheme.accentAmber
            arrow.translatesAutoresizingMaskIntoConstraints = false

            button.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(button)
            row.addSubview(arrow)
            arrow.setContentHuggingPriority(.required, for: .horizontal)
            arrow.setContentCompressionResistancePriority(.required, for: .horizontal)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: row.topAnchor),
                button.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                row.heightAnchor.constraint(equalToConstant: 44),
                arrow.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 4),
                arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
            stack.addArrangedSubview(row)
        }

        // Footer: Restore Purchases | Made By QingTengStudio
        let footerStack = UIStackView()
        footerStack.axis = .horizontal
        footerStack.spacing = 8
        footerStack.alignment = .center

        let restoreButton = UIButton(type: .system)
        restoreButton.setTitle(NSLocalizedString("qtc.restore", comment: ""), for: .normal)
        restoreButton.titleLabel?.font = PixelTheme.bodyFont(size: 12)
        restoreButton.setTitleColor(PixelTheme.accentBlue, for: .normal)
        restoreButton.addTarget(self, action: #selector(restorePurchases), for: .touchUpInside)

        let separator = UILabel()
        separator.text = " | "
        separator.font = PixelTheme.bodyFont(size: 12)
        separator.textColor = PixelTheme.textMuted

        let madeByLabel = UILabel()
        madeByLabel.text = "Made By "
        madeByLabel.font = PixelTheme.bodyFont(size: 12)
        madeByLabel.textColor = PixelTheme.textMuted

        let studioButton = UIButton(type: .system)
        studioButton.setTitle("QingTengStudio", for: .normal)
        studioButton.titleLabel?.font = PixelTheme.bodyFont(size: 12)
        studioButton.setTitleColor(PixelTheme.accentBlue, for: .normal)
        studioButton.addTarget(self, action: #selector(openStudio), for: .touchUpInside)

        footerStack.addArrangedSubview(restoreButton)
        footerStack.addArrangedSubview(separator)
        footerStack.addArrangedSubview(madeByLabel)
        footerStack.addArrangedSubview(studioButton)

        let wrapperView = UIView()
        wrapperView.addSubview(footerStack)
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            footerStack.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor),
            footerStack.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            footerStack.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
        ])
        stack.addArrangedSubview(wrapperView)

        return stack
    }

    // MARK: - StoreKit 2

    private func loadAllProducts() {
        Task {
            do {
                let products = try await Product.products(for: [
                    "com.AIStar.buymeacoffee",
                    "com.AIStar.QTC",
                    "com.AIStar.QTC50",
                ])
                for product in products {
                    switch product.id {
                    case "com.AIStar.buymeacoffee":
                        tipProduct = product
                        tipButton?.setTitle(String(format: NSLocalizedString("about.tip_buy", comment: ""), product.displayPrice), for: .normal)
                        tipButton?.isEnabled = true
                    case "com.AIStar.QTC":
                        qtc10Product = product
                        qtc10Button?.setTitle(String(format: NSLocalizedString("qtc.buy_10", comment: ""), product.displayPrice), for: .normal)
                        qtc10Button?.isEnabled = true
                    case "com.AIStar.QTC50":
                        qtc50Product = product
                        qtc50Button?.setTitle(String(format: NSLocalizedString("qtc.buy_50", comment: ""), product.displayPrice), for: .normal)
                        qtc50Button?.isEnabled = true
                    default:
                        break
                    }
                }
                // Mark unavailable if not loaded
                if tipProduct == nil {
                    tipButton?.setTitle(NSLocalizedString("about.tip_unavailable", comment: ""), for: .normal)
                }
                if qtc10Product == nil {
                    qtc10Button?.setTitle(NSLocalizedString("qtc.unavailable", comment: ""), for: .normal)
                }
                if qtc50Product == nil {
                    qtc50Button?.setTitle(NSLocalizedString("qtc.unavailable", comment: ""), for: .normal)
                }
            } catch {
                tipButton?.setTitle(NSLocalizedString("about.tip_failed", comment: ""), for: .normal)
                qtc10Button?.setTitle(NSLocalizedString("qtc.unavailable", comment: ""), for: .normal)
                qtc50Button?.setTitle(NSLocalizedString("qtc.unavailable", comment: ""), for: .normal)
                print("[AboutVC] StoreKit error: \(error)")
            }
        }
    }

    // MARK: - Purchase Actions

    @objc private func buyQTC10() {
        purchaseQTC(product: qtc10Product, amount: 10, button: qtc10Button)
    }

    @objc private func buyQTC50() {
        purchaseQTC(product: qtc50Product, amount: 50, button: qtc50Button)
    }

    private func purchaseQTC(product: Product?, amount: Int, button: UIButton?) {
        guard let product else { return }
        button?.isEnabled = false
        button?.setTitle(NSLocalizedString("qtc.processing", comment: ""), for: .normal)

        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        QTCStore.shared.addCredits(amount, reason: String(
                            format: NSLocalizedString("qtc.purchased_reason", comment: ""),
                            amount
                        ))
                        showQTCPurchaseSuccess(amount: amount)
                    case .unverified:
                        // Unverified transactions are not granted — potential tampering.
                        print("[AboutVC] QTC purchase unverified — not granting credits.")
                    }
                case .userCancelled:
                    break
                case .pending:
                    break
                @unknown default:
                    break
                }
            } catch {
                print("[AboutVC] QTC purchase error: \(error)")
            }
            // Reset button — ensure UIKit updates are on the main thread
            await MainActor.run {
                button?.isEnabled = true
                if let product = (amount == 10 ? self.qtc10Product : self.qtc50Product) {
                    let key = amount == 10 ? "qtc.buy_10" : "qtc.buy_50"
                    button?.setTitle(String(format: NSLocalizedString(key, comment: ""), product.displayPrice), for: .normal)
                }
            }
        }
    }

    private func showQTCPurchaseSuccess(amount: Int) {
        let alert = UIAlertController(
            title: NSLocalizedString("qtc.success_title", comment: ""),
            message: String(format: NSLocalizedString("qtc.success_msg", comment: ""), amount, QTCStore.shared.balance),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("about.tip_thanks_ok", comment: ""), style: .default))
        present(alert, animated: true)
        refreshQTCDashboard()
    }

    @objc private func buyTip() {
        guard let product = tipProduct else { return }
        tipButton?.isEnabled = false
        tipButton?.setTitle(NSLocalizedString("about.tip_processing", comment: ""), for: .normal)

        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        showThanks()
                    case .unverified:
                        print("[AboutVC] Tip purchase unverified — skipping.")
                    }
                case .userCancelled:
                    break
                case .pending:
                    break
                @unknown default:
                    break
                }
            } catch {
                print("[AboutVC] Purchase error: \(error)")
            }
            await MainActor.run {
                self.tipButton?.isEnabled = true
                if let product = self.tipProduct {
                    self.tipButton?.setTitle(String(format: NSLocalizedString("about.tip_buy", comment: ""), product.displayPrice), for: .normal)
                }
            }
        }
    }

    private func showThanks() {
        let alert = UIAlertController(
            title: NSLocalizedString("about.tip_thanks_title", comment: ""),
            message: NSLocalizedString("about.tip_thanks_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("about.tip_thanks_ok", comment: ""), style: .default))
        present(alert, animated: true)
    }

    // MARK: - Restore Purchases

    @objc private func restorePurchases() {
        Task {
            // StoreKit 2: iterate through all past transactions
            // For consumables, finished transactions are gone, but we reconcile iCloud
            QTCStore.shared.reconcileFromICloud()

            await MainActor.run {
                let alert = UIAlertController(
                    title: NSLocalizedString("qtc.restore_title", comment: ""),
                    message: NSLocalizedString("qtc.restore_msg", comment: ""),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: NSLocalizedString("about.tip_thanks_ok", comment: ""), style: .default))
                self.present(alert, animated: true)
                self.refreshQTCDashboard()
            }
        }
    }

    // MARK: - Actions

    @objc private func openGitHub() {
        UIApplication.shared.open(URL(string: "https://github.com/qingtengCHINA/Stars")!)
    }

    @objc private func openTerms() {
        UIApplication.shared.open(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
    }

    @objc private func openPrivacy() {
        UIApplication.shared.open(URL(string: "https://www.freeprivacypolicy.com/live/6c84fe52-c36d-4ea3-8961-09018a2ad58a")!)
    }

    @objc private func openRecommended() {
        UIApplication.shared.open(URL(string: "https://apps.apple.com/hk/developer/%E7%92%9E-%E8%8F%85/id1805856047")!)
    }

    @objc private func openFiftySounds() {
        UIApplication.shared.open(URL(string: "https://www.fiftysounds.com/zh/")!)
    }

    @objc private func openStudio() {
        UIApplication.shared.open(URL(string: "https://qingtengstudio.com/")!)
    }
}
