//
//  GameViewController.swift
//  Stars
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private var chatView: AgentChatView?
    private var chatWidthConstraint: NSLayoutConstraint?
    private var chatTrailingConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = self.view as? SKView else { return }

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        scene.agentSelectionHandler = { [weak self] agent in
            self?.showChat(for: agent)
        }

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif

        setupSettingsButton()
    }

    // MARK: - UI

    private func setupSettingsButton() {
        let button = UIButton(type: .system)
        button.setTitle("⚙️", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.backgroundColor = PixelTheme.bgMedium.withAlphaComponent(0.9)
        button.layer.cornerRadius = PixelTheme.cornerRadius
        button.layer.borderWidth = PixelTheme.borderWidth
        button.layer.borderColor = PixelTheme.borderWarm.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 38),
            button.heightAnchor.constraint(equalToConstant: 38),
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
        ])
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController(style: .insetGrouped)
        let nav = UINavigationController(rootViewController: settingsVC)
        nav.overrideUserInterfaceStyle = .dark
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // MARK: - Agent Chat

    private func showChat(for agent: Agent) {
        chatView?.removeFromSuperview()

        let chat = AgentChatView(agent: agent)
        chat.translatesAutoresizingMaskIntoConstraints = false
        chat.onDismiss = { [weak self] in
            UIView.animate(withDuration: 0.2, animations: {
                self?.chatView?.alpha = 0
                self?.chatView?.transform = CGAffineTransform(translationX: 60, y: 0)
            }) { _ in
                self?.chatView?.removeFromSuperview()
                self?.chatView = nil
            }
        }
        view.addSubview(chat)

        let trailing = chat.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -4)
        let width = chat.widthAnchor.constraint(equalToConstant: preferredChatWidth())

        NSLayoutConstraint.activate([
            chat.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            chat.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            trailing,
            width,
        ])
        chatTrailingConstraint = trailing
        chatWidthConstraint = width
        chatView = chat

        // Animate in
        chat.alpha = 0
        chat.transform = CGAffineTransform(translationX: preferredChatWidth(), y: 0)
        UIView.animate(withDuration: 0.2) {
            chat.alpha = 1
            chat.transform = .identity
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        chatWidthConstraint?.constant = preferredChatWidth()
    }

    private func preferredChatWidth() -> CGFloat {
        // Half screen width, clamped to reasonable bounds
        min(view.bounds.width * 0.52, max(340, view.bounds.width * 0.5))
    }

    // MARK: - Orientation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool { true }
}
