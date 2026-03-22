//
//  LeaderboardView.swift
//  Stars
//
//  Pixel-style leaderboard showing all agents ranked by Stars.
//  #1 ranked agent has an automatic 10⭐ system bounty.
//  Tap an agent name to locate them and open chat.
//

import UIKit

final class LeaderboardView: UIView {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rankings: [(rank: Int, name: String, stars: Int, isDead: Bool, isBounty: Bool, entityID: String)] = []
    private var refreshTimer: Timer?

    /// Provide agent data — set by GameViewController.
    var dataProvider: (() -> [(name: String, stars: Int, isDead: Bool, entityID: String)])?

    var onDismiss: (() -> Void)?

    /// Called when user taps an agent row — provides the entityID.
    var onAgentSelected: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { refreshTimer?.invalidate() }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = PixelTheme.bgDark
        layer.borderWidth = PixelTheme.borderWidth * 1.5
        layer.borderColor = PixelTheme.borderGold.cgColor
        layer.cornerRadius = PixelTheme.cornerRadius
        clipsToBounds = true

        // Header bar — prominent, never obscured
        let header = UIView()
        header.backgroundColor = PixelTheme.bgDeep
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        // Gold separator below header
        let headerSep = UIView()
        headerSep.backgroundColor = PixelTheme.borderGold
        headerSep.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerSep)

        let titleLabel = UILabel()
        titleLabel.text = "⭐ 排行榜"
        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.titleLabel?.font = PixelTheme.headerFont(size: 18)
        closeBtn.setTitleColor(PixelTheme.textCream, for: .normal)
        closeBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeBtn)

        // Bounty note
        let bountyNote = UILabel()
        bountyNote.text = "🎯 #1 自动悬赏 10⭐ · 点击名字查看"
        bountyNote.font = PixelTheme.fontMicro
        bountyNote.textColor = PixelTheme.accentRed
        bountyNote.textAlignment = .center
        bountyNote.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bountyNote)

        // Column header
        let columnHeader = UIView()
        columnHeader.backgroundColor = PixelTheme.bgDeep.withAlphaComponent(0.5)
        columnHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(columnHeader)

        let rankHeader = UILabel()
        rankHeader.text = "#"
        rankHeader.font = PixelTheme.fontMicro
        rankHeader.textColor = PixelTheme.textMuted
        rankHeader.textAlignment = .center
        rankHeader.translatesAutoresizingMaskIntoConstraints = false
        columnHeader.addSubview(rankHeader)

        let nameHeader = UILabel()
        nameHeader.text = "Agent"
        nameHeader.font = PixelTheme.fontMicro
        nameHeader.textColor = PixelTheme.textMuted
        nameHeader.translatesAutoresizingMaskIntoConstraints = false
        columnHeader.addSubview(nameHeader)

        let starsHeader = UILabel()
        starsHeader.text = "Stars"
        starsHeader.font = PixelTheme.fontMicro
        starsHeader.textColor = PixelTheme.textMuted
        starsHeader.textAlignment = .right
        starsHeader.translatesAutoresizingMaskIntoConstraints = false
        columnHeader.addSubview(starsHeader)

        // Table
        tableView.backgroundColor = .clear
        tableView.separatorColor = PixelTheme.borderDark.withAlphaComponent(0.4)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LeaderboardCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 38
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)

        NSLayoutConstraint.activate([
            // Header — taller for visibility
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 42),

            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),

            closeBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -6),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),

            // Gold separator line at bottom of header
            headerSep.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            headerSep.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            headerSep.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            headerSep.heightAnchor.constraint(equalToConstant: 2),

            // Bounty note
            bountyNote.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 3),
            bountyNote.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            bountyNote.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            bountyNote.heightAnchor.constraint(equalToConstant: 16),

            // Column header
            columnHeader.topAnchor.constraint(equalTo: bountyNote.bottomAnchor, constant: 2),
            columnHeader.leadingAnchor.constraint(equalTo: leadingAnchor),
            columnHeader.trailingAnchor.constraint(equalTo: trailingAnchor),
            columnHeader.heightAnchor.constraint(equalToConstant: 18),

            rankHeader.leadingAnchor.constraint(equalTo: columnHeader.leadingAnchor, constant: 10),
            rankHeader.centerYAnchor.constraint(equalTo: columnHeader.centerYAnchor),
            rankHeader.widthAnchor.constraint(equalToConstant: 28),

            nameHeader.leadingAnchor.constraint(equalTo: rankHeader.trailingAnchor, constant: 4),
            nameHeader.centerYAnchor.constraint(equalTo: columnHeader.centerYAnchor),

            starsHeader.trailingAnchor.constraint(equalTo: columnHeader.trailingAnchor, constant: -10),
            starsHeader.centerYAnchor.constraint(equalTo: columnHeader.centerYAnchor),

            // Table
            tableView.topAnchor.constraint(equalTo: columnHeader.bottomAnchor, constant: 1),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Auto-refresh every 2 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reloadData()
        }
        reloadData()
    }

    func reloadData() {
        guard let data = dataProvider?() else { return }
        let sorted = data.sorted { $0.stars > $1.stars }
        rankings = sorted.enumerated().map { idx, entry in
            (rank: idx + 1,
             name: entry.name,
             stars: entry.stars,
             isDead: entry.isDead,
             isBounty: idx == 0 && sorted.count >= 2 && entry.stars > 0,
             entityID: entry.entityID)
        }
        tableView.reloadData()
    }

    @objc private func dismissTapped() { onDismiss?() }
}

// MARK: - Table View

extension LeaderboardView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rankings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! LeaderboardCell
        let entry = rankings[indexPath.row]
        cell.configure(rank: entry.rank, name: entry.name, stars: entry.stars,
                       isDead: entry.isDead, isBounty: entry.isBounty)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = rankings[indexPath.row]
        onAgentSelected?(entry.entityID)

        // Brief highlight feedback
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.15, animations: {
                cell.contentView.backgroundColor = PixelTheme.textGold.withAlphaComponent(0.2)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    cell.contentView.backgroundColor = entry.rank == 1 && !entry.isDead
                        ? PixelTheme.textGold.withAlphaComponent(0.08)
                        : .clear
                }
            }
        }
    }
}

// MARK: - Cell

private final class LeaderboardCell: UITableViewCell {

    private let rankLabel = UILabel()
    private let nameLabel = UILabel()
    private let starsLabel = UILabel()
    private let bountyIcon = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        for label in [rankLabel, nameLabel, starsLabel, bountyIcon] {
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
        }

        rankLabel.font = PixelTheme.headerFont(size: 14)
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)
        rankLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        nameLabel.font = PixelTheme.bodyFont(size: 14)
        nameLabel.textColor = PixelTheme.textCream
        nameLabel.lineBreakMode = .byTruncatingTail
        // Name compresses to make room for stars — never push stars off screen
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        starsLabel.font = PixelTheme.headerFont(size: 14)
        starsLabel.textColor = PixelTheme.textGold
        starsLabel.textAlignment = .right
        starsLabel.setContentHuggingPriority(.required, for: .horizontal)
        starsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        bountyIcon.font = PixelTheme.bodyFont(size: 10)
        bountyIcon.textColor = PixelTheme.accentRed
        bountyIcon.setContentHuggingPriority(.required, for: .horizontal)
        bountyIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            rankLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            // Connect name → bountyIcon → starsLabel as a continuous chain
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: bountyIcon.leadingAnchor, constant: -2),

            bountyIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            bountyIcon.trailingAnchor.constraint(equalTo: starsLabel.leadingAnchor, constant: -3),

            starsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            starsLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            starsLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rank: Int, name: String, stars: Int, isDead: Bool, isBounty: Bool) {
        let medal: String
        switch rank {
        case 1: medal = "🥇"
        case 2: medal = "🥈"
        case 3: medal = "🥉"
        default: medal = "\(rank)."
        }
        rankLabel.text = medal
        rankLabel.textColor = rank <= 3 ? PixelTheme.textGold : PixelTheme.textMuted

        nameLabel.text = isDead ? "💀\(name)" : name
        nameLabel.textColor = isDead ? PixelTheme.textMuted : PixelTheme.textCream

        // Highlight #1 with background tint
        if rank == 1 && !isDead {
            contentView.backgroundColor = PixelTheme.textGold.withAlphaComponent(0.08)
        } else {
            contentView.backgroundColor = .clear
        }

        starsLabel.text = "\(stars)⭐"

        bountyIcon.text = isBounty ? "🎯" : ""
        bountyIcon.isHidden = !isBounty
    }
}
