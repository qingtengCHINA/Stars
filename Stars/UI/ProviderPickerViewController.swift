//
//  ProviderPickerViewController.swift
//  Stars
//
//  Searchable provider list — pixel-art character select screen style.
//

import UIKit

final class ProviderPickerViewController: UITableViewController, UISearchResultsUpdating {

    var onSelect: ((APIProvider) -> Void)?

    private let searchController = UISearchController(searchResultsController: nil)

    /// Build the full provider list: official providers (filtered by tier) + third-party.
    private var allVisibleProviders: [APIProvider] {
        let tier = SubscriptionStore.shared.currentTier

        // Official providers: show only those the user's tier can access
        let official = ProviderCatalog.officialProviders.filter { provider in
            tier >= provider.requiredSubscriptionTier
        }

        return official + ProviderCatalog.orderedProviders
    }

    private var filteredProviders: [APIProvider] {
        let all = allVisibleProviders
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else { return all }

        let needle = query.lowercased()
        return all.filter { provider in
            let definition = provider.definition
            let haystack = [
                definition.displayName,
                definition.selectionTitle,
                definition.selectionSubtitle,
                definition.protocolLabel,
            ]
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(needle)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("provider.title", comment: "")
        overrideUserInterfaceStyle = .dark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("provider.cancel", comment: ""),
            style: .plain,
            target: self,
            action: #selector(closeSelf)
        )

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString("provider.search", comment: "")
        searchController.searchBar.tintColor = PixelTheme.accentAmber
        searchController.searchBar.barTintColor = PixelTheme.bgMedium
        navigationItem.searchController = searchController
        definesPresentationContext = true

        PixelTheme.styleTableView(tableView)
        tableView.register(ProviderCell.self, forCellReuseIdentifier: "providerCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredProviders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "providerCell", for: indexPath) as! ProviderCell
        let provider = filteredProviders[indexPath.row]
        cell.configure(with: provider.definition)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(filteredProviders[indexPath.row])
    }

    func updateSearchResults(for searchController: UISearchController) {
        tableView.reloadData()
    }

    @objc private func closeSelf() {
        dismiss(animated: true)
    }
}

// MARK: - Provider Cell

private final class ProviderCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let protocolBadge = UILabel()
    private let cardBg = UIView()
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

        titleLabel.font = PixelTheme.boldFont(size: 16)
        titleLabel.textColor = PixelTheme.textCream
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(titleLabel)

        subtitleLabel.font = PixelTheme.bodyFont(size: 14)
        subtitleLabel.textColor = PixelTheme.textTan
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(subtitleLabel)

        protocolBadge.font = PixelTheme.boldFont(size: 12)
        protocolBadge.textColor = PixelTheme.bgDark
        protocolBadge.backgroundColor = PixelTheme.accentAmber
        protocolBadge.layer.cornerRadius = 2
        protocolBadge.clipsToBounds = true
        protocolBadge.textAlignment = .center
        protocolBadge.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(protocolBadge)

        arrowLabel.text = "▸"
        arrowLabel.font = PixelTheme.boldFont(size: 16)
        arrowLabel.textColor = PixelTheme.accentAmber
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        cardBg.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            cardBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            cardBg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            cardBg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),

            protocolBadge.topAnchor.constraint(equalTo: cardBg.topAnchor, constant: 10),
            protocolBadge.leadingAnchor.constraint(equalTo: cardBg.leadingAnchor, constant: 12),
            protocolBadge.heightAnchor.constraint(equalToConstant: 16),
            protocolBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: cardBg.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: protocolBadge.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: arrowLabel.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardBg.leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: arrowLabel.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardBg.bottomAnchor, constant: -10),

            arrowLabel.trailingAnchor.constraint(equalTo: cardBg.trailingAnchor, constant: -12),
            arrowLabel.centerYAnchor.constraint(equalTo: cardBg.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with definition: ProviderDefinition) {
        titleLabel.text = definition.selectionTitle
        subtitleLabel.text = definition.selectionSubtitle
        protocolBadge.text = " \(definition.protocolLabel) "
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let badgeColor = PixelTheme.accentAmber
        UIView.animate(withDuration: 0.1) {
            self.cardBg.backgroundColor = highlighted ? PixelTheme.bgLight : PixelTheme.bgMedium
            self.protocolBadge.backgroundColor = badgeColor // preserve badge color
        }
    }
}
