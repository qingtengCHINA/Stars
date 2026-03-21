//
//  SettingsViewController.swift
//  Stars
//
//  Main settings menu — warm pixel-art game menu style.
//

import UIKit

final class SettingsViewController: UITableViewController {

    private struct MenuItem {
        let title: String
        let iconName: String?  // Asset catalog image name (nil = no icon)
    }

    private var items: [MenuItem] {
        [
            MenuItem(title: NSLocalizedString("settings.agent_management", comment: ""), iconName: "机器人"),
            MenuItem(title: NSLocalizedString("settings.constitution", comment: ""),     iconName: "宪法"),
            MenuItem(title: NSLocalizedString("settings.about", comment: ""),            iconName: "咖啡"),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("settings.title", comment: "")
        overrideUserInterfaceStyle = .dark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("settings.done", comment: ""),
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
        let item = items[indexPath.row]
        cell.configure(title: item.title, iconName: item.iconName)
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = .clear
        let label = UILabel()
        label.text = NSLocalizedString("settings.header", comment: "")
        label.font = PixelTheme.headerFont(size: 16)
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
            let vc = AboutViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - Pixel Menu Cell

private final class PixelMenuCell: UITableViewCell {

    private let iconView = UIImageView()
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

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(iconView)

        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textCream
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(titleLabel)

        arrowLabel.text = "▸"
        arrowLabel.font = PixelTheme.boldFont(size: 18)
        arrowLabel.textColor = PixelTheme.accentAmber
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            cardBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            cardBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            cardBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),

            iconView.leadingAnchor.constraint(equalTo: cardBg.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),

            arrowLabel.trailingAnchor.constraint(equalTo: cardBg.trailingAnchor, constant: -16),
            arrowLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, iconName: String?) {
        titleLabel.text = title
        if let iconName, let image = UIImage(named: iconName)?.withRenderingMode(.alwaysOriginal) {
            iconView.image = image
            iconView.isHidden = false
        } else {
            iconView.image = nil
            iconView.isHidden = true
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.1) {
            self.cardBg.backgroundColor = highlighted ? PixelTheme.bgLight : PixelTheme.bgMedium
        }
    }
}
