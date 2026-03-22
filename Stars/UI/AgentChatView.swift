//
//  AgentChatView.swift
//  Stars
//
//  Slide-in chat panel — Stardew Valley pixel-art style.
//  Warm wood panel with parchment chat area,
//  real-time stats, and collapsible journal detail.
//

import UIKit

final class AgentChatView: UIView {

    private weak var agent: Agent?
    private var refreshTimer: Timer?

    var onDismiss: (() -> Void)?

    // Header
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // Stats bar
    private let hpLabel = UILabel()
    private let posLabel = UILabel()
    private let ctxLabel = UILabel()
    private let tokenLabel = UILabel()
    private let actionLabel = UILabel()

    // Chat
    private let chatTableView = UITableView(frame: .zero, style: .plain)
    private var chatEntries: [(role: String, text: String)] = []

    // Input
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)

    // Detail toggle
    private let detailToggle = UIButton(type: .system)
    private let detailSegment = UISegmentedControl(items: [
        NSLocalizedString("chat.tab_log", comment: ""),
        NSLocalizedString("chat.tab_stars", comment: ""),
    ])
    private let detailView = UITextView()
    private var isDetailExpanded = false
    private var detailHeightConstraint: NSLayoutConstraint!

    init(agent: Agent) {
        self.agent = agent
        super.init(frame: .zero)
        setupUI()
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Outer wood-panel frame
        backgroundColor = PixelTheme.bgDark
        layer.cornerRadius = PixelTheme.cornerRadius
        layer.borderWidth = PixelTheme.thickBorder
        layer.borderColor = PixelTheme.borderWarm.cgColor
        clipsToBounds = true

        // -- Header (wooden banner) --
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = PixelTheme.bgMedium
        addSubview(headerView)

        // Inner border effect for header
        let headerInnerBorder = UIView()
        headerInnerBorder.backgroundColor = PixelTheme.borderDark
        headerInnerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerInnerBorder)

        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = PixelTheme.boldFont(size: 18)
        closeButton.tintColor = PixelTheme.textTan
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)

        // -- Stats bar (parchment info strip) --
        let statsView = UIView()
        statsView.translatesAutoresizingMaskIntoConstraints = false
        statsView.backgroundColor = PixelTheme.bgParchment.withAlphaComponent(0.4)
        addSubview(statsView)

        let statsFont = PixelTheme.fontStats

        hpLabel.font = statsFont
        hpLabel.textColor = PixelTheme.hpHigh
        hpLabel.translatesAutoresizingMaskIntoConstraints = false

        posLabel.font = statsFont
        posLabel.textColor = PixelTheme.textTan
        posLabel.translatesAutoresizingMaskIntoConstraints = false

        ctxLabel.font = statsFont
        ctxLabel.textColor = PixelTheme.accentBlue
        ctxLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenLabel.font = statsFont
        tokenLabel.textColor = PixelTheme.accentAmber
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false

        actionLabel.font = statsFont
        actionLabel.textColor = PixelTheme.textTan
        actionLabel.translatesAutoresizingMaskIntoConstraints = false

        let statsRow1 = UIStackView(arrangedSubviews: [hpLabel, posLabel, actionLabel])
        statsRow1.axis = .horizontal
        statsRow1.spacing = 8
        statsRow1.translatesAutoresizingMaskIntoConstraints = false

        let statsRow2 = UIStackView(arrangedSubviews: [ctxLabel, tokenLabel])
        statsRow2.axis = .horizontal
        statsRow2.spacing = 8
        statsRow2.translatesAutoresizingMaskIntoConstraints = false

        let statsStack = UIStackView(arrangedSubviews: [statsRow1, statsRow2])
        statsStack.axis = .vertical
        statsStack.spacing = 2
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsView.addSubview(statsStack)

        // Stats border
        let statsBorder = UIView()
        statsBorder.backgroundColor = PixelTheme.borderWarm.withAlphaComponent(0.5)
        statsBorder.translatesAutoresizingMaskIntoConstraints = false
        statsView.addSubview(statsBorder)

        // -- Chat table --
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.backgroundColor = PixelTheme.bgInput.withAlphaComponent(0.5)
        chatTableView.separatorStyle = .none
        chatTableView.dataSource = self
        chatTableView.delegate = self
        chatTableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "chat")
        chatTableView.rowHeight = UITableView.automaticDimension
        chatTableView.estimatedRowHeight = 44
        chatTableView.keyboardDismissMode = .onDrag
        addSubview(chatTableView)

        // -- Detail toggle --
        detailToggle.setTitle(NSLocalizedString("chat.detail_collapsed", comment: ""), for: .normal)
        detailToggle.titleLabel?.font = PixelTheme.boldFont(size: 12)
        detailToggle.tintColor = PixelTheme.textTan
        detailToggle.contentHorizontalAlignment = .left
        detailToggle.addTarget(self, action: #selector(toggleDetail), for: .touchUpInside)
        detailToggle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(detailToggle)

        // -- Detail segment (tab switcher) --
        detailSegment.selectedSegmentIndex = 0
        detailSegment.translatesAutoresizingMaskIntoConstraints = false
        detailSegment.backgroundColor = PixelTheme.bgInput
        detailSegment.selectedSegmentTintColor = PixelTheme.bgLight
        detailSegment.setTitleTextAttributes([
            .foregroundColor: PixelTheme.textMuted,
            .font: PixelTheme.boldFont(size: 11),
        ], for: .normal)
        detailSegment.setTitleTextAttributes([
            .foregroundColor: PixelTheme.textGold,
            .font: PixelTheme.boldFont(size: 11),
        ], for: .selected)
        detailSegment.addTarget(self, action: #selector(detailSegmentChanged), for: .valueChanged)
        detailSegment.isHidden = true
        addSubview(detailSegment)

        // -- Detail view (old journal style) --
        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.backgroundColor = PixelTheme.bgInput
        detailView.textColor = PixelTheme.textTan
        detailView.font = PixelTheme.bodyFont(size: 12)
        detailView.layer.cornerRadius = PixelTheme.cornerRadius
        detailView.layer.borderWidth = PixelTheme.borderWidth
        detailView.layer.borderColor = PixelTheme.borderDark.cgColor
        detailView.isEditable = false
        detailView.textContainerInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        detailView.isHidden = true
        addSubview(detailView)

        // -- Input area (wooden input bar) --
        let inputContainer = UIView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = PixelTheme.bgMedium
        addSubview(inputContainer)

        // Input top border
        let inputBorder = UIView()
        inputBorder.backgroundColor = PixelTheme.borderWarm
        inputBorder.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputBorder)

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.font = PixelTheme.bodyFont(size: 16)
        inputField.textColor = PixelTheme.textCream
        inputField.backgroundColor = PixelTheme.bgInput
        inputField.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("chat.input_placeholder", comment: ""),
            attributes: [.foregroundColor: PixelTheme.textMuted]
        )
        inputField.layer.cornerRadius = PixelTheme.cornerRadius
        inputField.layer.borderWidth = PixelTheme.borderWidth
        inputField.layer.borderColor = PixelTheme.borderDark.cgColor
        inputField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        inputField.leftViewMode = .always
        inputField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 0))
        inputField.rightViewMode = .always
        inputField.returnKeyType = .send
        inputField.autocapitalizationType = .none
        inputField.autocorrectionType = .no
        inputField.tintColor = PixelTheme.accentAmber
        inputField.delegate = self
        inputContainer.addSubview(inputField)

        sendButton.setTitle("📨", for: .normal)
        sendButton.titleLabel?.font = PixelTheme.headerFont(size: 20)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(sendButton)

        detailHeightConstraint = detailView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            headerInnerBorder.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerInnerBorder.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerInnerBorder.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerInnerBorder.heightAnchor.constraint(equalToConstant: 2),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10),

            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 6),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            // Stats
            statsView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            statsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            statsView.trailingAnchor.constraint(equalTo: trailingAnchor),

            statsBorder.leadingAnchor.constraint(equalTo: statsView.leadingAnchor),
            statsBorder.trailingAnchor.constraint(equalTo: statsView.trailingAnchor),
            statsBorder.bottomAnchor.constraint(equalTo: statsView.bottomAnchor),
            statsBorder.heightAnchor.constraint(equalToConstant: 1),

            statsStack.topAnchor.constraint(equalTo: statsView.topAnchor, constant: 5),
            statsStack.leadingAnchor.constraint(equalTo: statsView.leadingAnchor, constant: 12),
            statsStack.trailingAnchor.constraint(equalTo: statsView.trailingAnchor, constant: -12),
            statsStack.bottomAnchor.constraint(equalTo: statsView.bottomAnchor, constant: -5),

            // Chat table
            chatTableView.topAnchor.constraint(equalTo: statsView.bottomAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Detail toggle
            detailToggle.topAnchor.constraint(equalTo: chatTableView.bottomAnchor, constant: 2),
            detailToggle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            detailToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            detailToggle.heightAnchor.constraint(equalToConstant: 22),

            // Detail segment
            detailSegment.topAnchor.constraint(equalTo: detailToggle.bottomAnchor, constant: 2),
            detailSegment.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            detailSegment.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            detailSegment.heightAnchor.constraint(equalToConstant: 24),

            // Detail view
            detailView.topAnchor.constraint(equalTo: detailSegment.bottomAnchor, constant: 2),
            detailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            detailView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            detailHeightConstraint,

            // Input
            inputContainer.topAnchor.constraint(equalTo: detailView.bottomAnchor, constant: 4),
            inputContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            inputBorder.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            inputBorder.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
            inputBorder.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor),
            inputBorder.heightAnchor.constraint(equalToConstant: 2),

            inputField.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 10),
            inputField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 10),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -6),
            inputField.heightAnchor.constraint(equalToConstant: 34),
            inputField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 38),
        ])
    }

    // MARK: - Actions

    @objc private func dismissSelf() {
        endEditing(true)
        refreshTimer?.invalidate()
        onDismiss?()
    }

    @objc private func sendMessage() {
        guard let agent else { return }
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        agent.receiveOwnerMessage(text)
        inputField.text = nil
        refresh()
    }

    @objc private func toggleDetail() {
        isDetailExpanded.toggle()
        detailView.isHidden = !isDetailExpanded
        detailSegment.isHidden = !isDetailExpanded
        detailHeightConstraint.constant = isDetailExpanded ? 140 : 0
        detailToggle.setTitle(isDetailExpanded ? NSLocalizedString("chat.detail_expanded", comment: "") : NSLocalizedString("chat.detail_collapsed", comment: ""), for: .normal)
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }

    @objc private func detailSegmentChanged() {
        refreshDetail()
    }

    // MARK: - Refresh

    private func refresh() {
        guard let agent else {
            titleLabel.text = NSLocalizedString("chat.agent_missing", comment: "")
            return
        }

        // -- Real-time Stats --
        let hpRatio = Double(agent.hp) / Double(agent.maxHP)
        hpLabel.text = "❤️ \(agent.hp)/\(agent.maxHP) ⭐\(agent.stars)"
        hpLabel.textColor = hpRatio > 0.5 ? PixelTheme.hpHigh : (hpRatio > 0.25 ? PixelTheme.hpMid : PixelTheme.hpLow)

        posLabel.text = "📍(\(agent.tileX),\(agent.tileY))"
        actionLabel.text = agent.isDead ? NSLocalizedString("chat.dead", comment: "") : "⚡ \(agent.currentAction.rawValue)"

        if let usage = agent.latestContextUsage {
            let ratio = usage.usageRatio
            ctxLabel.text = "🧠 \(usage.usedTokens)/\(usage.limitTokens) (\(usage.percentageText))"
            ctxLabel.textColor = ratio > 0.8 ? PixelTheme.hpLow : (ratio > 0.6 ? PixelTheme.hpMid : PixelTheme.accentBlue)
        } else {
            ctxLabel.text = NSLocalizedString("chat.waiting", comment: "")
            ctxLabel.textColor = PixelTheme.textMuted
        }

        let totalK = agent.totalTokensUsed > 1000
            ? String(format: "%.1fK", Double(agent.totalTokensUsed) / 1000.0)
            : "\(agent.totalTokensUsed)"
        tokenLabel.text = "🪙 \(totalK) · 💭×\(agent.thinkCycleCount)"

        let modelName = ModelManager.shared.config(for: agent.representedModelConfigID)?.modelName ?? "?"
        let thinkingStatus = (agent.brain?.isThinking == true) ? " 🧠✨" : ""
        titleLabel.text = "\(agent.displayName) · \(modelName)\(thinkingStatus)"

        // -- Chat entries --
        var newEntries: [(role: String, text: String)] = []
        for msg in agent.chatMessages.suffix(30) {
            switch msg.speaker {
            case .owner:
                newEntries.append((NSLocalizedString("chat.owner", comment: ""), msg.text))
            case .agent:
                newEntries.append((agent.displayName, msg.text))
            case .system:
                continue
            }
        }

        if agent.pendingOwnerReplies > 0 {
            newEntries.append(("···", String(format: NSLocalizedString("chat.thinking", comment: ""), agent.displayName)))
        }

        let needsReload = newEntries.count != chatEntries.count
        chatEntries = newEntries
        if needsReload {
            chatTableView.reloadData()
            scrollToBottom()
        }

        refreshDetail()
    }

    private func refreshDetail() {
        guard let agent, isDetailExpanded else { return }

        if detailSegment.selectedSegmentIndex == 1 {
            refreshStarTransactions()
            return
        }

        var lines = [String]()

        if let thought = agent.currentThought, !thought.isEmpty {
            lines.append(String(format: NSLocalizedString("chat.thought", comment: ""), thought))
            lines.append("")
        }

        let memories = agent.memory.recentEntries(count: 6)
        if !memories.isEmpty {
            lines.append(String(format: NSLocalizedString("chat.short_memory", comment: ""), memories.count))
            for m in memories {
                lines.append("  [\(m.type.rawValue)] \(m.content)")
            }
        }

        let ltmCount = LongTermMemory.shared.entries(for: agent.entityID).count
        if ltmCount > 0 {
            lines.append("")
            lines.append(String(format: NSLocalizedString("chat.long_memory", comment: ""), ltmCount))
            let topEntries = LongTermMemory.shared.topEntries(for: agent.entityID, count: 3)
            for e in topEntries {
                lines.append("  [\(e.category.rawValue)] \(e.content)")
            }
        }

        let events = WorldEventLogStore.shared.recentEvents(limit: 4, entityID: agent.entityID)
        if !events.isEmpty {
            lines.append("")
            lines.append(NSLocalizedString("chat.system_log", comment: ""))
            for e in events {
                lines.append("  [\(e.category.rawValue)] \(e.title): \(e.message)")
            }
        }

        detailView.text = lines.joined(separator: "\n")
    }

    private func refreshStarTransactions() {
        guard let agent else { return }

        let transactions = agent.starTransactions
        if transactions.isEmpty {
            detailView.text = NSLocalizedString("chat.no_transactions", comment: "")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        var lines = [String]()
        lines.append("⭐ \(NSLocalizedString("chat.star_balance", comment: "")): \(agent.stars)")
        lines.append("")

        // Show most recent transactions (newest first)
        for tx in transactions.suffix(20).reversed() {
            let time = formatter.string(from: Date(timeIntervalSince1970: tx.timestamp))
            let sign = tx.amount >= 0 ? "+" : ""
            let amountStr = "\(sign)\(tx.amount)⭐"
            lines.append("  [\(time)] \(amountStr) \(tx.reason) → \(tx.balance)⭐")
        }

        detailView.text = lines.joined(separator: "\n")
    }

    private func scrollToBottom() {
        guard !chatEntries.isEmpty else { return }
        let lastRow = chatEntries.count - 1
        chatTableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: false)
    }
}

// MARK: - Table DataSource

extension AgentChatView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        chatEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "chat", for: indexPath) as! ChatBubbleCell
        let entry = chatEntries[indexPath.row]
        let isOwner = entry.role == NSLocalizedString("chat.owner", comment: "")
        cell.configure(role: entry.role, text: entry.text, isOwner: isOwner)
        return cell
    }
}

// MARK: - Table Delegate (long-press context menu to copy)

extension AgentChatView: UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let entry = chatEntries[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copyText = UIAction(
                title: NSLocalizedString("chat.copy", comment: ""),
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                UIPasteboard.general.string = entry.text
            }
            let copyAll = UIAction(
                title: NSLocalizedString("chat.copy_all", comment: ""),
                image: UIImage(systemName: "doc.on.doc.fill")
            ) { [weak self] _ in
                guard let self else { return }
                let allText = self.chatEntries.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
                UIPasteboard.general.string = allText
            }
            return UIMenu(title: "", children: [copyText, copyAll])
        }
    }
}

// MARK: - Text Field Delegate

extension AgentChatView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}

// MARK: - Chat Bubble Cell

private final class ChatBubbleCell: UITableViewCell {
    private let roleLabel = UILabel()
    private let bubbleLabel = UILabel()
    private let bubbleBg = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        roleLabel.font = PixelTheme.boldFont(size: 12)
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(roleLabel)

        bubbleBg.layer.cornerRadius = PixelTheme.cornerRadius
        bubbleBg.layer.borderWidth = 1
        bubbleBg.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleBg)

        bubbleLabel.font = PixelTheme.bodyFont(size: 14)
        bubbleLabel.numberOfLines = 0
        bubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleBg.addSubview(bubbleLabel)

        NSLayoutConstraint.activate([
            roleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            roleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            roleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            bubbleBg.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 2),
            bubbleBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            bubbleBg.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -30),
            bubbleBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            bubbleLabel.topAnchor.constraint(equalTo: bubbleBg.topAnchor, constant: 6),
            bubbleLabel.leadingAnchor.constraint(equalTo: bubbleBg.leadingAnchor, constant: 8),
            bubbleLabel.trailingAnchor.constraint(equalTo: bubbleBg.trailingAnchor, constant: -8),
            bubbleLabel.bottomAnchor.constraint(equalTo: bubbleBg.bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(role: String, text: String, isOwner: Bool) {
        roleLabel.text = role
        bubbleLabel.text = text

        if role == "···" {
            // Thinking state
            roleLabel.textColor = PixelTheme.textMuted
            bubbleBg.backgroundColor = PixelTheme.bgMedium
            bubbleBg.layer.borderColor = PixelTheme.borderWarm.withAlphaComponent(0.3).cgColor
            bubbleLabel.textColor = PixelTheme.textMuted
        } else if isOwner {
            // Owner (player) message
            roleLabel.textColor = PixelTheme.accentBlue
            bubbleBg.backgroundColor = PixelTheme.bubbleOwner
            bubbleBg.layer.borderColor = PixelTheme.accentBlue.withAlphaComponent(0.3).cgColor
            bubbleLabel.textColor = PixelTheme.textWhite
        } else {
            // Agent message
            roleLabel.textColor = PixelTheme.textGold
            bubbleBg.backgroundColor = PixelTheme.bubbleAgent
            bubbleBg.layer.borderColor = PixelTheme.borderWarm.withAlphaComponent(0.5).cgColor
            bubbleLabel.textColor = PixelTheme.textCream
        }
    }
}
