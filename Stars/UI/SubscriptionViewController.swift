//
//  SubscriptionViewController.swift
//  Stars
//
//  Subscription management page — Plus / Pro / Max tiers.
//  Bottom: restore purchases, privacy, terms of service.
//

import UIKit
import StoreKit

final class SubscriptionViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private var plusButton: UIButton?
    private var proButton: UIButton?
    private var maxButton: UIButton?

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
            text: NSLocalizedString("subscription.title", comment: "")
        )

        setupLayout()
        loadProducts()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshUI),
            name: SubscriptionStore.tierDidChange, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }
        refreshUI()
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

        contentStack.addArrangedSubview(makeCurrentTierSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeTierComparisonSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeSubscriptionButtonsSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeFooterSection())
    }

    // MARK: - Current Tier

    private var tierLabel: UILabel?

    private func makeCurrentTierSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = "👑"
        icon.font = .systemFont(ofSize: 36)
        icon.textAlignment = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.font = PixelTheme.headerFont(size: 20)
        label.textColor = PixelTheme.textCream
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        self.tierLabel = label

        card.addSubview(icon)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        updateTierLabel()
        return card
    }

    private func updateTierLabel() {
        let tier = SubscriptionStore.shared.currentTier
        tierLabel?.text = String(format: NSLocalizedString("subscription.current_tier", comment: ""), tier.displayName)
    }

    // MARK: - Tier Comparison

    private func makeTierComparisonSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        let header = UILabel()
        header.text = NSLocalizedString("subscription.benefits_title", comment: "")
        header.font = PixelTheme.headerFont(size: 16)
        header.textColor = PixelTheme.textGold
        header.textAlignment = .center
        stack.addArrangedSubview(header)

        let rows: [(String, String)] = [
            (NSLocalizedString("subscription.benefit_free", comment: ""),
             NSLocalizedString("subscription.benefit_free_desc", comment: "")),
            (NSLocalizedString("subscription.benefit_plus", comment: ""),
             NSLocalizedString("subscription.benefit_plus_desc", comment: "")),
            (NSLocalizedString("subscription.benefit_pro", comment: ""),
             NSLocalizedString("subscription.benefit_pro_desc", comment: "")),
            (NSLocalizedString("subscription.benefit_max", comment: ""),
             NSLocalizedString("subscription.benefit_max_desc", comment: "")),
        ]

        for (title, desc) in rows {
            stack.addArrangedSubview(makeBenefitRow(title: title, desc: desc))
        }

        return stack
    }

    private func makeBenefitRow(title: String, desc: String) -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = PixelTheme.boldFont(size: 15)
        titleLabel.textColor = PixelTheme.textCream
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = PixelTheme.bodyFont(size: 13)
        descLabel.textColor = PixelTheme.textTan
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(titleLabel)
        card.addSubview(descLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        return card
    }

    // MARK: - Subscription Buttons

    private func makeSubscriptionButtonsSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10

        let header = UILabel()
        header.text = NSLocalizedString("subscription.choose_plan", comment: "")
        header.font = PixelTheme.headerFont(size: 16)
        header.textColor = PixelTheme.textGold
        header.textAlignment = .center
        stack.addArrangedSubview(header)

        let plus = makeSubscriptionButton(tier: .plus)
        self.plusButton = plus
        stack.addArrangedSubview(plus)

        let pro = makeSubscriptionButton(tier: .pro)
        self.proButton = pro
        stack.addArrangedSubview(pro)

        let max = makeSubscriptionButton(tier: .max)
        self.maxButton = max
        stack.addArrangedSubview(max)

        return stack
    }

    private func makeSubscriptionButton(tier: SubscriptionTier) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = tier.rawValue
        button.titleLabel?.font = PixelTheme.boldFont(size: 16)
        button.setTitleColor(PixelTheme.textCream, for: .normal)
        button.backgroundColor = PixelTheme.bgMedium
        button.layer.cornerRadius = PixelTheme.cornerRadius
        button.layer.borderWidth = PixelTheme.borderWidth
        button.layer.borderColor = PixelTheme.borderWarm.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(subscriptionButtonTapped(_:)), for: .touchUpInside)

        // Initial title (loading)
        let loadingKey: String
        switch tier {
        case .plus: loadingKey = "subscription.plus_loading"
        case .pro:  loadingKey = "subscription.pro_loading"
        case .max:  loadingKey = "subscription.max_loading"
        default:    loadingKey = ""
        }
        button.setTitle(NSLocalizedString(loadingKey, comment: ""), for: .normal)
        return button
    }

    @objc private func subscriptionButtonTapped(_ sender: UIButton) {
        guard let tier = SubscriptionTier(rawValue: sender.tag) else { return }
        guard let product = SubscriptionStore.shared.product(for: tier) else { return }

        let current = SubscriptionStore.shared.currentTier
        if current == tier {
            // Already subscribed to this tier — manage subscription
            openManageSubscriptions()
            return
        }

        sender.setTitle(NSLocalizedString("subscription.processing", comment: ""), for: .normal)
        sender.isEnabled = false

        Task {
            do {
                let success = try await SubscriptionStore.shared.purchase(product)
                if success {
                    await MainActor.run { self.refreshUI() }
                }
            } catch {
                print("[SubscriptionVC] Purchase error: \(error)")
            }
            await MainActor.run {
                sender.isEnabled = true
                self.refreshButtonTitles()
            }
        }
    }

    private func openManageSubscriptions() {
        if let scene = view.window?.windowScene {
            Task {
                try? await AppStore.showManageSubscriptions(in: scene)
            }
        }
    }

    // MARK: - Footer (Restore + Privacy + Terms)

    private func makeFooterSection() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center

        // Auto-renewable subscription notice
        let notice = UILabel()
        notice.text = NSLocalizedString("subscription.auto_renew_notice", comment: "")
        notice.font = PixelTheme.bodyFont(size: 11)
        notice.textColor = PixelTheme.textMuted
        notice.numberOfLines = 0
        notice.textAlignment = .center
        stack.addArrangedSubview(notice)

        // Links row: Restore | Privacy | Terms
        let linksStack = UIStackView()
        linksStack.axis = .horizontal
        linksStack.spacing = 4
        linksStack.alignment = .center

        let restoreBtn = makeLinkButton(NSLocalizedString("subscription.restore", comment: ""), action: #selector(restoreTapped))
        let sep1 = makeSepLabel()
        let privacyBtn = makeLinkButton(NSLocalizedString("subscription.privacy", comment: ""), action: #selector(privacyTapped))
        let sep2 = makeSepLabel()
        let termsBtn = makeLinkButton(NSLocalizedString("subscription.terms", comment: ""), action: #selector(termsTapped))

        linksStack.addArrangedSubview(restoreBtn)
        linksStack.addArrangedSubview(sep1)
        linksStack.addArrangedSubview(privacyBtn)
        linksStack.addArrangedSubview(sep2)
        linksStack.addArrangedSubview(termsBtn)

        stack.addArrangedSubview(linksStack)
        return stack
    }

    private func makeLinkButton(_ title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = PixelTheme.bodyFont(size: 13)
        btn.setTitleColor(PixelTheme.accentAmber, for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func makeSepLabel() -> UILabel {
        let sep = UILabel()
        sep.text = "|"
        sep.font = PixelTheme.bodyFont(size: 13)
        sep.textColor = PixelTheme.textMuted
        return sep
    }

    @objc private func restoreTapped() {
        Task {
            await SubscriptionStore.shared.restorePurchases()
            let tier = SubscriptionStore.shared.currentTier
            let alert = UIAlertController(
                title: NSLocalizedString("subscription.restore_title", comment: ""),
                message: String(format: NSLocalizedString("subscription.restore_msg", comment: ""), tier.displayName),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("edit.alert_confirm", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func privacyTapped() {
        guard let url = URL(string: "https://sites.google.com/view/stars-privacy-policy") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func termsTapped() {
        guard let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Product Loading

    private func loadProducts() {
        Task {
            await SubscriptionStore.shared.loadProducts()
            refreshButtonTitles()
        }
    }

    private func refreshButtonTitles() {
        let current = SubscriptionStore.shared.currentTier
        let store = SubscriptionStore.shared

        for (tier, button) in [(SubscriptionTier.plus, plusButton),
                               (SubscriptionTier.pro, proButton),
                               (SubscriptionTier.max, maxButton)] {
            guard let button else { continue }
            if let product = store.product(for: tier) {
                if current == tier {
                    button.setTitle("✓ \(tier.displayName) — " + NSLocalizedString("subscription.current", comment: ""), for: .normal)
                    button.layer.borderColor = PixelTheme.accentGreen.cgColor
                } else if current > tier {
                    button.setTitle("✓ \(tier.displayName) — " + NSLocalizedString("subscription.included", comment: ""), for: .normal)
                    button.layer.borderColor = PixelTheme.accentGreen.withAlphaComponent(0.5).cgColor
                } else {
                    button.setTitle("\(tier.displayName) — \(product.displayPrice)/\(NSLocalizedString("subscription.monthly", comment: ""))", for: .normal)
                    button.layer.borderColor = PixelTheme.borderWarm.cgColor
                }
            } else {
                button.setTitle("\(tier.displayName) — " + NSLocalizedString("subscription.unavailable", comment: ""), for: .normal)
            }
        }
    }

    @objc private func refreshUI() {
        updateTierLabel()
        refreshButtonTitles()
    }
}
