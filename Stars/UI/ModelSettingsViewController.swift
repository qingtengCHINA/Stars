//
//  ModelSettingsViewController.swift
//  Stars
//
//  Agent management list — character roster style.
//  Each agent is a warm pixel-art card.
//

import UIKit

final class ModelSettingsViewController: UITableViewController {

    private var configs: [ModelConfig] { ModelManager.shared.configs }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.titleView = PixelTheme.makeNavTitleView(
            iconName: "机器人",
            text: NSLocalizedString("models.title", comment: "")
        )

        let summonItem = UIBarButtonItem(
            title: NSLocalizedString("models.add", comment: ""),
            style: .plain,
            target: self,
            action: #selector(addModel)
        )
        let pixelAttrs: [NSAttributedString.Key: Any] = [.font: PixelTheme.boldFont(size: 16)]
        summonItem.setTitleTextAttributes(pixelAttrs, for: .normal)
        summonItem.setTitleTextAttributes(pixelAttrs, for: .highlighted)
        navigationItem.rightBarButtonItem = summonItem

        PixelTheme.styleTableView(tableView)
        tableView.register(AgentListCell.self, forCellReuseIdentifier: "agentCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88

        // Observe config changes so the list refreshes immediately
        // (pageSheet modals don't trigger viewWillAppear on dismiss)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigsChanged),
            name: .modelConfigsDidChange, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }
        tableView.reloadData()
        updateEmptyState()
    }

    @objc private func handleConfigsChanged() {
        tableView.reloadData()
        updateEmptyState()
    }

    // MARK: - Actions

    @objc private func addModel() {
        let tier = SubscriptionStore.shared.currentTier

        // Subscribers (Plus/Pro/Max): unlimited self-added agents, skip limits
        if tier >= .plus {
            showProviderPicker()
            return
        }

        // Free tier: enforce 20-agent limit (QTC expandable)
        let store = QTCStore.shared
        let currentCount = store.currentAgentCount

        if currentCount >= QTCStore.freeAgentLimit {
            if store.balance <= 0 {
                // No QTC — show purchase prompt
                let alert = UIAlertController(
                    title: NSLocalizedString("qtc.limit_title", comment: ""),
                    message: String(format: NSLocalizedString("qtc.limit_msg", comment: ""),
                                    QTCStore.freeAgentLimit, store.balance),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(
                    title: NSLocalizedString("qtc.go_purchase", comment: ""),
                    style: .default
                ) { [weak self] _ in
                    let vc = AboutViewController()
                    self?.navigationController?.pushViewController(vc, animated: true)
                })
                alert.addAction(UIAlertAction(
                    title: NSLocalizedString("edit.cancel", comment: ""),
                    style: .cancel
                ))
                present(alert, animated: true)
                return
            }

            // Has QTC — confirm spending
            let alert = UIAlertController(
                title: NSLocalizedString("qtc.spend_title", comment: ""),
                message: String(format: NSLocalizedString("qtc.spend_msg", comment: ""),
                                store.balance),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("qtc.spend_confirm", comment: ""),
                style: .default
            ) { [weak self] _ in
                if QTCStore.shared.spendForAgentSlot() {
                    self?.showProviderPicker()
                }
            })
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("edit.cancel", comment: ""),
                style: .cancel
            ))
            present(alert, animated: true)
            return
        }

        showProviderPicker()
    }

    private func showProviderPicker() {
        let picker = ProviderPickerViewController()
        picker.onSelect = { [weak self, weak picker] provider in
            // Official provider: check per-provider agent limit
            if provider.isOfficialProvider {
                let currentOfProvider = ModelManager.shared.configs.filter { $0.provider == provider }.count
                let limit = provider.officialAgentLimit
                if currentOfProvider >= limit {
                    picker?.dismiss(animated: true) {
                        let alert = UIAlertController(
                            title: NSLocalizedString("edit.alert_title", comment: ""),
                            message: String(format: NSLocalizedString("subscription.official_limit_reached", comment: ""),
                                            provider.displayName, limit),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(
                            title: NSLocalizedString("edit.alert_confirm", comment: ""),
                            style: .default
                        ))
                        self?.present(alert, animated: true)
                    }
                    return
                }
            }

            picker?.dismiss(animated: true) {
                self?.presentEditVC(mode: .add(provider))
            }
        }

        let nav = UINavigationController(rootViewController: picker)
        nav.overrideUserInterfaceStyle = .dark
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func presentEditVC(mode: ModelEditViewController.Mode) {
        let editVC = ModelEditViewController(mode: mode)
        let nav = UINavigationController(rootViewController: editVC)
        nav.overrideUserInterfaceStyle = .dark
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func updateEmptyState() {
        if configs.isEmpty {
            let container = UIView()
            let iconLabel = UILabel()
            iconLabel.text = "🌌"
            iconLabel.font = .systemFont(ofSize: 48)
            iconLabel.textAlignment = .center
            iconLabel.translatesAutoresizingMaskIntoConstraints = false

            let textLabel = UILabel()
            textLabel.text = NSLocalizedString("models.empty_title", comment: "")
            textLabel.numberOfLines = 0
            textLabel.textAlignment = .center
            textLabel.textColor = PixelTheme.textTan
            textLabel.font = PixelTheme.headerFont(size: 16)
            textLabel.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(iconLabel)
            container.addSubview(textLabel)
            NSLayoutConstraint.activate([
                iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
                textLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
                textLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                textLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            ])
            tableView.backgroundView = container
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - DataSource

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        configs.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "agentCell", for: indexPath) as! AgentListCell
        let config = configs[indexPath.row]
        let soul = SoulStore.shared.soul(for: config.id.uuidString)
        let agent = AgentManager.current?.agent(forConfigID: config.id)
        cell.configure(config: config, soul: soul, agent: agent)
        return cell
    }

    // MARK: - Delegate

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let config = configs[indexPath.row]
        presentEditVC(mode: .edit(config))
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let config = configs[indexPath.row]
            SoulStore.shared.removeSoul(for: config.id.uuidString)
            LongTermMemory.shared.removeAll(for: config.id.uuidString)
            ModelManager.shared.deleteConfig(id: config.id)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateEmptyState()
        }
    }

    override func tableView(_ tableView: UITableView,
                            titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        NSLocalizedString("models.delete", comment: "")
    }
}

// MARK: - Agent List Cell

private final class AgentListCell: UITableViewCell {

    private let cardBg = UIView()
    private let nameLabel = UILabel()
    private let modelLabel = UILabel()
    private let soulLabel = UILabel()
    private let statusDot = UIView()
    private let contextLabel = UILabel()
    private let tokenLabel = UILabel()
    private let arrowLabel = UILabel()

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

        statusDot.layer.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(statusDot)

        nameLabel.font = PixelTheme.headerFont(size: 18)
        nameLabel.textColor = PixelTheme.textCream
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(nameLabel)

        modelLabel.font = PixelTheme.bodyFont(size: 14)
        modelLabel.textColor = PixelTheme.textTan
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(modelLabel)

        soulLabel.font = PixelTheme.bodyFont(size: 12)
        soulLabel.textColor = PixelTheme.accentAmber.withAlphaComponent(0.7)
        soulLabel.numberOfLines = 1
        soulLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(soulLabel)

        contextLabel.font = PixelTheme.boldFont(size: 12)
        contextLabel.textColor = PixelTheme.accentBlue
        contextLabel.textAlignment = .right
        contextLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(contextLabel)

        tokenLabel.font = PixelTheme.bodyFont(size: 10)
        tokenLabel.textColor = PixelTheme.textMuted
        tokenLabel.textAlignment = .right
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(tokenLabel)

        arrowLabel.text = "▸"
        arrowLabel.font = PixelTheme.boldFont(size: 18)
        arrowLabel.textColor = PixelTheme.accentAmber
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            cardBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            cardBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            cardBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),

            statusDot.leadingAnchor.constraint(equalTo: cardBg.leadingAnchor, constant: 14),
            statusDot.topAnchor.constraint(equalTo: cardBg.topAnchor, constant: 16),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            nameLabel.topAnchor.constraint(equalTo: cardBg.topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contextLabel.leadingAnchor, constant: -8),

            modelLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            modelLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            modelLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            soulLabel.topAnchor.constraint(equalTo: modelLabel.bottomAnchor, constant: 3),
            soulLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            soulLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            soulLabel.bottomAnchor.constraint(equalTo: cardBg.bottomAnchor, constant: -10),

            // Right-side stats: context + token labels stacked vertically
            contextLabel.trailingAnchor.constraint(equalTo: arrowLabel.leadingAnchor, constant: -6),
            contextLabel.bottomAnchor.constraint(equalTo: cardBg.centerYAnchor, constant: -1),

            tokenLabel.trailingAnchor.constraint(equalTo: contextLabel.trailingAnchor),
            tokenLabel.topAnchor.constraint(equalTo: cardBg.centerYAnchor, constant: 1),

            arrowLabel.trailingAnchor.constraint(equalTo: cardBg.trailingAnchor, constant: -14),
            arrowLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(config: ModelConfig, soul: SoulDocument, agent: Agent?) {
        nameLabel.text = config.alias

        // QingTeng (free tier): hide actual model name, show generic label
        if config.provider == .starsOfficial {
            modelLabel.text = "\(config.provider.displayName) · \(NSLocalizedString("models.free_model_label", comment: ""))"
        } else {
            modelLabel.text = "\(config.provider.displayName) · \(config.modelName)"
        }

        if soul.isEmpty {
            soulLabel.text = NSLocalizedString("models.soul_empty", comment: "")
        } else {
            soulLabel.text = "✨ SOUL: \(soul.personality.prefix(36))"
        }

        switch config.connectionStatus {
        case .unknown:  statusDot.backgroundColor = PixelTheme.statusUnknown
        case .success:  statusDot.backgroundColor = PixelTheme.statusOK
        case .failure:  statusDot.backgroundColor = PixelTheme.statusFail
        }

        // Context usage display
        if let agent = agent, let usage = agent.latestContextUsage {
            contextLabel.text = "🧠 \(usage.percentageText)"
            let ratio = usage.usageRatio
            contextLabel.textColor = ratio > 0.8 ? PixelTheme.hpLow
                                   : (ratio > 0.6 ? PixelTheme.hpMid
                                                  : PixelTheme.accentBlue)
        } else {
            contextLabel.text = "🧠 --"
            contextLabel.textColor = PixelTheme.textMuted
        }

        // Token consumption display
        if let agent = agent {
            let totalK = agent.totalTokensUsed > 1000
                ? String(format: "%.1fK", Double(agent.totalTokensUsed) / 1000.0)
                : "\(agent.totalTokensUsed)"
            tokenLabel.text = "🪙 \(totalK)"
        } else {
            tokenLabel.text = "🪙 --"
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let dotColor = statusDot.backgroundColor
        UIView.animate(withDuration: 0.1) {
            self.cardBg.backgroundColor = highlighted ? PixelTheme.bgLight : PixelTheme.bgMedium
            self.statusDot.backgroundColor = dotColor // preserve
        }
    }
}
