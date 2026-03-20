//
//  ConstitutionViewController.swift
//  Stars
//
//  View/edit the AGENTS file (world constitution).
//  Styled as an old parchment scroll for that Stardew feel.
//

import UIKit

final class ConstitutionViewController: UIViewController {

    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "📜 世界宪法"
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = PixelTheme.bgDark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        // Nav bar buttons styled as game actions
        let saveItem = UIBarButtonItem(title: "💾 保存", style: .done, target: self, action: #selector(saveContent))
        let resetItem = UIBarButtonItem(title: "🔄 重置", style: .plain, target: self, action: #selector(resetContent))
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

        // Parchment text area
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = PixelTheme.bgInput
        textView.textColor = PixelTheme.textCream
        textView.font = PixelTheme.bodyFont(size: 13)
        textView.tintColor = PixelTheme.accentAmber
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.layer.borderWidth = PixelTheme.borderWidth
        textView.layer.borderColor = PixelTheme.borderDark.cgColor
        textView.layer.cornerRadius = PixelTheme.cornerRadius
        textView.text = AgentsFile.shared.content
        frameView.addSubview(textView)

        // Title decoration inside frame
        let headerLabel = UILabel()
        headerLabel.text = "── The Constitution of the Stars ──"
        headerLabel.font = PixelTheme.headerFont(size: 12)
        headerLabel.textColor = PixelTheme.textGold
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            frameView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            frameView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            frameView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),

            headerLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -12),

            textView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            textView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 6),
            textView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -6),
            textView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: -6),
        ])
    }

    @objc private func saveContent() {
        AgentsFile.shared.update(textView.text ?? "")
        navigationController?.popViewController(animated: true)
    }

    @objc private func resetContent() {
        let alert = UIAlertController(
            title: "⚠️ 重置宪法",
            message: "恢复为默认的群星宪法？\n当前的自定义修改将丢失。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            AgentsFile.shared.reset()
            self?.textView.text = AgentsFile.shared.content
        })
        present(alert, animated: true)
    }
}
