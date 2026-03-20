//
//  SettingsViewController.swift
//  Stars
//
//  Main settings menu — warm pixel-art game menu style.
//

import UIKit

final class SettingsViewController: UITableViewController {

    private let items: [(title: String, icon: String)] = [
        ("🏰  Agent 管理", ""),
        ("📜  世界宪法", ""),
        ("🌟  关于群星", ""),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "⚙️ 设置"
        overrideUserInterfaceStyle = .dark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        tableView.backgroundColor = PixelTheme.bgDark
        tableView.separatorColor = PixelTheme.borderWarm.withAlphaComponent(0.3)
        tableView.register(PixelMenuCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 56
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }
    }

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    // MARK: - DataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! PixelMenuCell
        cell.configure(title: items[indexPath.row].title)
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .clear
        let label = UILabel()
        label.text = "─── 群星控制面板 ───"
        label.font = PixelTheme.headerFont(size: 13)
        label.textColor = PixelTheme.textTan
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4),
        ])
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        36
    }

    // MARK: - Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            let vc = ModelSettingsViewController(style: .insetGrouped)
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let vc = ConstitutionViewController()
            navigationController?.pushViewController(vc, animated: true)
        default:
            let alert = UIAlertController(
                title: "🌟 群星 · Stars",
                message: "AI的群星闪耀时 v1.0\n\n一个像素风AI沙盒世界\n让AI Agent在这里自由生活",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好的！", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - Pixel Menu Cell

private final class PixelMenuCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let arrowLabel = UILabel()
    private let cardBg = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        cardBg.backgroundColor = PixelTheme.bgMedium
        cardBg.layer.borderWidth = PixelTheme.borderWidth
        cardBg.layer.borderColor = PixelTheme.borderWarm.cgColor
        cardBg.layer.cornerRadius = PixelTheme.cornerRadius
        cardBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardBg)

        titleLabel.font = PixelTheme.headerFont(size: 16)
        titleLabel.textColor = PixelTheme.textCream
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(titleLabel)

        arrowLabel.text = "▸"
        arrowLabel.font = PixelTheme.boldFont(size: 16)
        arrowLabel.textColor = PixelTheme.accentAmber
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            cardBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            cardBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            cardBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),

            titleLabel.leadingAnchor.constraint(equalTo: cardBg.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),

            arrowLabel.trailingAnchor.constraint(equalTo: cardBg.trailingAnchor, constant: -16),
            arrowLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) {
        titleLabel.text = title
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            self.cardBg.backgroundColor = highlighted ? PixelTheme.bgLight : PixelTheme.bgMedium
        }
    }
}
