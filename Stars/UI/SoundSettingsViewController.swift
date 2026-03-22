//
//  SoundSettingsViewController.swift
//  Stars
//
//  Sound settings page — BGM volume slider + SFX volume slider + Apple Music integration.
//  Pixel-art style consistent with other settings pages.
//

import UIKit
import MusicKit

final class SoundSettingsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var bgmSlider: UISlider!
    private var sfxSlider: UISlider!
    private var bgmLabel: UILabel!
    private var sfxLabel: UILabel!

    // Apple Music section
    private var appleMusicSongTable: UITableView!
    private var appleMusicAuthButton: UIButton!
    private var appleMusicPlayButton: UIButton!
    private var appleMusicStatusLabel: UILabel!
    private var appleMusicSelectedLabel: UILabel!
    private var appleMusicContainer: UIView!
    private var bgmSourceSegment: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = PixelTheme.bgDark

        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        navigationItem.titleView = PixelTheme.makeNavTitleView(
            iconName: "声音",
            text: NSLocalizedString("sound.title", comment: "")
        )

        setupLayout()
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

        contentStack.addArrangedSubview(makeBGMSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeSFXSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeBGMSourceSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeBGMListSection())
        contentStack.addArrangedSubview(PixelTheme.makeDivider(color: PixelTheme.borderWarm))
        contentStack.addArrangedSubview(makeAppleMusicSection())
    }

    // MARK: - BGM Section

    private func makeBGMSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let title = UILabel()
        title.text = NSLocalizedString("sound.bgm_title", comment: "")
        title.font = PixelTheme.headerFont(size: 18)
        title.textColor = PixelTheme.textGold

        bgmLabel = UILabel()
        bgmLabel.font = PixelTheme.bodyFont(size: 14)
        bgmLabel.textColor = PixelTheme.textTan
        updateBGMLabel()

        bgmSlider = makeSlider()
        bgmSlider.value = SoundManager.shared.bgmVolume
        bgmSlider.addTarget(self, action: #selector(bgmSliderChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [title, bgmLabel, bgmSlider])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - SFX Section

    private func makeSFXSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let title = UILabel()
        title.text = NSLocalizedString("sound.sfx_title", comment: "")
        title.font = PixelTheme.headerFont(size: 18)
        title.textColor = PixelTheme.textGold

        sfxLabel = UILabel()
        sfxLabel.font = PixelTheme.bodyFont(size: 14)
        sfxLabel.textColor = PixelTheme.textTan
        updateSFXLabel()

        sfxSlider = makeSlider()
        sfxSlider.value = SoundManager.shared.sfxVolume
        sfxSlider.addTarget(self, action: #selector(sfxSliderChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [title, sfxLabel, sfxSlider])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - BGM Track List

    private func makeBGMListSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let title = UILabel()
        title.text = NSLocalizedString("sound.tracklist", comment: "")
        title.font = PixelTheme.headerFont(size: 16)
        title.textColor = PixelTheme.textGold

        let tracks = UILabel()
        tracks.numberOfLines = 0
        tracks.font = PixelTheme.bodyFont(size: 14)
        tracks.textColor = PixelTheme.textTan
        tracks.text = """
        🎵 Moon and Sun
        🎵 Everything Moves
        🎵 Litae

        \(NSLocalizedString("sound.credit", comment: ""))
        """

        let stack = UIStackView(arrangedSubviews: [title, tracks])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - BGM Source Section

    private func makeBGMSourceSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius

        let title = UILabel()
        title.text = NSLocalizedString("sound.bgm_source", comment: "BGM Source")
        title.font = PixelTheme.headerFont(size: 16)
        title.textColor = PixelTheme.textGold

        bgmSourceSegment = UISegmentedControl(items: [
            NSLocalizedString("sound.bgm_builtin", comment: "Built-in Tracks"),
            NSLocalizedString("sound.bgm_apple_music", comment: "Apple Music"),
        ])
        bgmSourceSegment.selectedSegmentIndex = SoundManager.shared.bgmSource == .builtIn ? 0 : 1
        bgmSourceSegment.setTitleTextAttributes([
            .font: PixelTheme.bodyFont(size: 14),
            .foregroundColor: PixelTheme.textTan,
        ], for: .normal)
        bgmSourceSegment.setTitleTextAttributes([
            .font: PixelTheme.boldFont(size: 14),
            .foregroundColor: PixelTheme.textWhite,
        ], for: .selected)
        bgmSourceSegment.backgroundColor = PixelTheme.bgInput
        bgmSourceSegment.selectedSegmentTintColor = PixelTheme.accentAmber
        bgmSourceSegment.addTarget(self, action: #selector(bgmSourceChanged), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [title, bgmSourceSegment])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    @objc private func bgmSourceChanged() {
        let source: SoundManager.BGMSource = bgmSourceSegment.selectedSegmentIndex == 0 ? .builtIn : .appleMusic
        SoundManager.shared.switchBGMSource(source)
        updateAppleMusicPlayButton()
    }

    // MARK: - Apple Music Section

    private func makeAppleMusicSection() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.layer.cornerRadius = PixelTheme.cornerRadius
        appleMusicContainer = card

        let title = UILabel()
        title.text = NSLocalizedString("sound.apple_music_title", comment: "Apple Music")
        title.font = PixelTheme.headerFont(size: 18)
        title.textColor = PixelTheme.textGold

        // Auth button
        appleMusicAuthButton = UIButton(type: .system)
        appleMusicAuthButton.setTitle(NSLocalizedString("sound.apple_music_auth", comment: "Authorize Apple Music"), for: .normal)
        PixelTheme.applyButton(appleMusicAuthButton, color: PixelTheme.accentAmber)
        appleMusicAuthButton.addTarget(self, action: #selector(appleMusicAuthTapped), for: .touchUpInside)

        // Status label
        appleMusicStatusLabel = UILabel()
        appleMusicStatusLabel.font = PixelTheme.bodyFont(size: 14)
        appleMusicStatusLabel.textColor = PixelTheme.textTan
        appleMusicStatusLabel.numberOfLines = 0
        appleMusicStatusLabel.text = ""

        // Selected count label
        appleMusicSelectedLabel = UILabel()
        appleMusicSelectedLabel.font = PixelTheme.bodyFont(size: 14)
        appleMusicSelectedLabel.textColor = PixelTheme.accentGreen
        appleMusicSelectedLabel.text = ""

        // Song table
        appleMusicSongTable = UITableView(frame: .zero, style: .plain)
        appleMusicSongTable.backgroundColor = PixelTheme.bgInput
        appleMusicSongTable.separatorColor = PixelTheme.borderWarm.withAlphaComponent(0.3)
        appleMusicSongTable.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        appleMusicSongTable.layer.borderWidth = PixelTheme.borderWidth
        appleMusicSongTable.layer.borderColor = PixelTheme.borderDark.cgColor
        appleMusicSongTable.layer.cornerRadius = PixelTheme.cornerRadius
        appleMusicSongTable.dataSource = self
        appleMusicSongTable.delegate = self
        appleMusicSongTable.register(UITableViewCell.self, forCellReuseIdentifier: "AppleMusicSongCell")
        appleMusicSongTable.translatesAutoresizingMaskIntoConstraints = false
        appleMusicSongTable.heightAnchor.constraint(equalToConstant: 300).isActive = true
        appleMusicSongTable.isHidden = true

        // Play button
        appleMusicPlayButton = UIButton(type: .system)
        PixelTheme.applyButton(appleMusicPlayButton, color: PixelTheme.accentGreen)
        appleMusicPlayButton.addTarget(self, action: #selector(appleMusicPlayTapped), for: .touchUpInside)
        appleMusicPlayButton.isHidden = true
        updateAppleMusicPlayButton()

        let stack = UIStackView(arrangedSubviews: [
            title,
            appleMusicStatusLabel,
            appleMusicAuthButton,
            appleMusicSelectedLabel,
            appleMusicSongTable,
            appleMusicPlayButton,
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        // Refresh UI based on current auth state
        refreshAppleMusicUI()

        return card
    }

    private func refreshAppleMusicUI() {
        let mgr = AppleMusicManager.shared
        switch mgr.authStatus {
        case .authorized:
            appleMusicAuthButton.isHidden = true
            appleMusicStatusLabel.text = ""
            appleMusicSongTable.isHidden = false
            appleMusicPlayButton.isHidden = false
            updateAppleMusicSelectedLabel()
            // Load library if empty
            if mgr.librarySongs.isEmpty {
                Task { [weak self] in
                    await mgr.loadLibrary()
                    guard let self else { return }
                    self.appleMusicSongTable.reloadData()
                    if mgr.librarySongs.isEmpty {
                        self.appleMusicStatusLabel.text = NSLocalizedString("sound.apple_music_empty", comment: "No Music Found")
                    }
                }
            }
        case .denied:
            appleMusicAuthButton.isHidden = true
            appleMusicSongTable.isHidden = true
            appleMusicPlayButton.isHidden = true
            appleMusicSelectedLabel.text = ""
            appleMusicStatusLabel.text = NSLocalizedString("sound.apple_music_denied", comment: "Apple Music Not Authorized")
        case .notDetermined:
            appleMusicAuthButton.isHidden = false
            appleMusicSongTable.isHidden = true
            appleMusicPlayButton.isHidden = true
            appleMusicSelectedLabel.text = ""
            appleMusicStatusLabel.text = ""
        }
    }

    private func updateAppleMusicSelectedLabel() {
        let count = AppleMusicManager.shared.selectedSongIDs.count
        if count > 0 {
            appleMusicSelectedLabel.text = String(format: NSLocalizedString("sound.apple_music_selected", comment: "%d Selected"), count)
        } else {
            appleMusicSelectedLabel.text = ""
        }
    }

    private func updateAppleMusicPlayButton() {
        let mgr = AppleMusicManager.shared
        if mgr.isPlaying {
            appleMusicPlayButton.setTitle(NSLocalizedString("sound.apple_music_stop", comment: "Stop Playing"), for: .normal)
            PixelTheme.applyButton(appleMusicPlayButton, color: PixelTheme.accentRed)
        } else {
            appleMusicPlayButton.setTitle(NSLocalizedString("sound.apple_music_play", comment: "Play Playlist"), for: .normal)
            PixelTheme.applyButton(appleMusicPlayButton, color: PixelTheme.accentGreen)
        }
    }

    @objc private func appleMusicAuthTapped() {
        Task {
            await AppleMusicManager.shared.requestAuthorization()
            refreshAppleMusicUI()
        }
    }

    @objc private func appleMusicPlayTapped() {
        let mgr = AppleMusicManager.shared
        if mgr.isPlaying {
            mgr.stopPlayback()
            // If source is Apple Music, resume built-in BGM? No — just stop.
            updateAppleMusicPlayButton()
        } else {
            Task {
                await mgr.startPlayback()
                updateAppleMusicPlayButton()
            }
        }
    }

    // MARK: - Helpers

    private func makeSlider() -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = PixelTheme.accentAmber
        slider.maximumTrackTintColor = PixelTheme.bgLight
        slider.thumbTintColor = PixelTheme.textGold
        return slider
    }

    @objc private func bgmSliderChanged() {
        SoundManager.shared.bgmVolume = bgmSlider.value
        updateBGMLabel()
    }

    @objc private func sfxSliderChanged() {
        SoundManager.shared.sfxVolume = sfxSlider.value
        updateSFXLabel()
    }

    private func updateBGMLabel() {
        let pct = Int(SoundManager.shared.bgmVolume * 100)
        bgmLabel.text = String(format: NSLocalizedString("sound.bgm_volume", comment: ""), pct)
    }

    private func updateSFXLabel() {
        let pct = Int(SoundManager.shared.sfxVolume * 100)
        sfxLabel.text = String(format: NSLocalizedString("sound.sfx_volume", comment: ""), pct)
    }
}

// MARK: - Apple Music Song Table

extension SoundSettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AppleMusicManager.shared.librarySongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppleMusicSongCell", for: indexPath)
        let song = AppleMusicManager.shared.librarySongs[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = song.title
        config.secondaryText = song.artistName
        config.textProperties.font = PixelTheme.bodyFont(size: 14)
        config.textProperties.color = PixelTheme.textCream
        config.secondaryTextProperties.font = PixelTheme.bodyFont(size: 12)
        config.secondaryTextProperties.color = PixelTheme.textTan
        cell.contentConfiguration = config

        cell.backgroundColor = PixelTheme.bgInput
        let bgView = UIView()
        bgView.backgroundColor = PixelTheme.bgLight
        cell.selectedBackgroundView = bgView

        if AppleMusicManager.shared.isSelected(song) {
            cell.accessoryType = .checkmark
            cell.tintColor = PixelTheme.accentGreen
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let song = AppleMusicManager.shared.librarySongs[indexPath.row]
        AppleMusicManager.shared.toggleSong(song)
        tableView.reloadRows(at: [indexPath], with: .none)
        updateAppleMusicSelectedLabel()
    }
}
