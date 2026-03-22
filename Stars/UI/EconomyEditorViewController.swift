//
//  EconomyEditorViewController.swift
//  Stars
//
//  View/edit the economy system rules for all agents.
//  Players can modify trade rules, bounty mechanics, pricing, rewards,
//  and more — giving maximum freedom to reshape the world's economy.
//

import UIKit

final class EconomyEditorViewController: UIViewController {

    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = PixelTheme.bgDark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.titleView = PixelTheme.makeNavTitleView(
            iconName: "经济",
            text: NSLocalizedString("economy_editor.title", comment: "")
        )

        // Nav bar buttons
        let saveItem = UIBarButtonItem(
            title: NSLocalizedString("economy_editor.save", comment: ""),
            style: .done, target: self, action: #selector(saveContent)
        )
        let resetItem = UIBarButtonItem(
            title: NSLocalizedString("economy_editor.reset", comment: ""),
            style: .plain, target: self, action: #selector(resetContent)
        )
        navigationItem.rightBarButtonItems = [saveItem, resetItem]

        // Outer frame (wood panel border)
        let frameView = UIView()
        frameView.backgroundColor = PixelTheme.bgMedium
        frameView.layer.borderWidth = PixelTheme.thickBorder
        frameView.layer.borderColor = PixelTheme.borderWarm.cgColor
        frameView.layer.cornerRadius = PixelTheme.cornerRadius
        frameView.clipsToBounds = true
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)

        // Text area
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = PixelTheme.bgInput
        textView.textColor = PixelTheme.textCream
        textView.font = PixelTheme.bodyFont(size: 16)
        textView.tintColor = PixelTheme.accentAmber
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.layer.borderWidth = PixelTheme.borderWidth
        textView.layer.borderColor = PixelTheme.borderDark.cgColor
        textView.layer.cornerRadius = PixelTheme.cornerRadius
        textView.text = EconomyFile.shared.content
        frameView.addSubview(textView)

        // Title decoration
        let headerLabel = UILabel()
        headerLabel.text = "── Economy & Trade Rules ──"
        headerLabel.font = PixelTheme.headerFont(size: 14)
        headerLabel.textColor = PixelTheme.textGold
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(headerLabel)

        // Hint label
        let hintLabel = UILabel()
        hintLabel.text = NSLocalizedString("economy_editor.hint", comment: "")
        hintLabel.font = PixelTheme.fontMicro
        hintLabel.textColor = PixelTheme.textMuted
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            frameView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            frameView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            frameView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),

            headerLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -12),

            hintLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            hintLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -12),

            textView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            textView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 6),
            textView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -6),
            textView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: -6),
        ])
    }

    @objc private func saveContent() {
        EconomyFile.shared.update(textView.text ?? "")
        navigationController?.popViewController(animated: true)
    }

    @objc private func resetContent() {
        let alert = UIAlertController(
            title: NSLocalizedString("economy_editor.reset_alert_title", comment: ""),
            message: NSLocalizedString("economy_editor.reset_alert_message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("economy_editor.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("economy_editor.reset_confirm", comment: ""), style: .destructive) { [weak self] _ in
            EconomyFile.shared.reset()
            self?.textView.text = EconomyFile.shared.content
        })
        present(alert, animated: true)
    }
}
