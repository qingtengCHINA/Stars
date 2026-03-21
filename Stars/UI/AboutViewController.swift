//
//  AboutViewController.swift
//  Stars
//
//  About page — app info, open source, tip jar, legal links.
//  Stardew Valley pixel art style.
//

import UIKit
import StoreKit

final class AboutViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // StoreKit
    private var tipProduct: Product?
    private var tipButton: UIButton?

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
        loadTipProduct()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        contentStack.addArrangedSubview(makeHeroSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeInfoSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeOpenSourceSection())
        contentStack.addArrangedSubview(makeTipSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
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
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: row.topAnchor),
                button.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                button.trailingAnchor.constraint(equalTo: arrow.leadingAnchor, constant: -8),
                button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                row.heightAnchor.constraint(equalToConstant: 44),
                arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])
            stack.addArrangedSubview(row)
        }

        // Footer
        let footerStack = UIStackView()
        footerStack.axis = .horizontal
        footerStack.spacing = 0
        footerStack.alignment = .center
        footerStack.distribution = .fill

        let madeByLabel = UILabel()
        madeByLabel.text = "Made By "
        madeByLabel.font = PixelTheme.bodyFont(size: 12)
        madeByLabel.textColor = PixelTheme.textMuted

        let studioButton = UIButton(type: .system)
        studioButton.setTitle("QingTengStudio", for: .normal)
        studioButton.titleLabel?.font = PixelTheme.bodyFont(size: 12)
        studioButton.setTitleColor(PixelTheme.accentBlue, for: .normal)
        studioButton.addTarget(self, action: #selector(openStudio), for: .touchUpInside)

        let wrapperView = UIView()
        wrapperView.addSubview(footerStack)
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.addArrangedSubview(madeByLabel)
        footerStack.addArrangedSubview(studioButton)
        NSLayoutConstraint.activate([
            footerStack.centerXAnchor.constraint(equalTo: wrapperView.centerXAnchor),
            footerStack.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            footerStack.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor),
        ])
        stack.addArrangedSubview(wrapperView)

        return stack
    }

    // MARK: - StoreKit 2

    private func loadTipProduct() {
        Task {
            do {
                let products = try await Product.products(for: ["com.AIStar.buymeacoffee"])
                if let product = products.first {
                    tipProduct = product
                    tipButton?.setTitle(String(format: NSLocalizedString("about.tip_buy", comment: ""), product.displayPrice), for: .normal)
                    tipButton?.isEnabled = true
                } else {
                    tipButton?.setTitle(NSLocalizedString("about.tip_unavailable", comment: ""), for: .normal)
                }
            } catch {
                tipButton?.setTitle(NSLocalizedString("about.tip_failed", comment: ""), for: .normal)
                print("[AboutVC] StoreKit error: \(error)")
            }
        }
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
                        showThanks()
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
            tipButton?.isEnabled = true
            if let product = tipProduct {
                tipButton?.setTitle(String(format: NSLocalizedString("about.tip_buy", comment: ""), product.displayPrice), for: .normal)
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

    @objc private func openStudio() {
        UIApplication.shared.open(URL(string: "https://qingtengstudio.com/")!)
    }
}
