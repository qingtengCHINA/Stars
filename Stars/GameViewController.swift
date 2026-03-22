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
    private var leaderboardView: LeaderboardView?
    private weak var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = self.view as? SKView else { return }

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        scene.agentSelectionHandler = { [weak self] agent in
            guard let self, let scene = self.gameScene else { return }
            self.showChat(for: agent)
            self.focusCameraOnAgent(agent, in: scene)
        }
        self.gameScene = scene

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif

        setupHUDButtons()
    }

    // MARK: - UI

    private func setupHUDButtons() {
        let settingsBtn = makeHUDButton(iconName: "设置")
        settingsBtn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        let findBtn = makeHUDButton(iconName: "查找")
        findBtn.addTarget(self, action: #selector(findNextAgent), for: .touchUpInside)

        let leaderboardBtn = makeHUDButton(iconName: "排行榜")
        leaderboardBtn.addTarget(self, action: #selector(toggleLeaderboard), for: .touchUpInside)

        view.addSubview(settingsBtn)
        view.addSubview(findBtn)
        view.addSubview(leaderboardBtn)
        NSLayoutConstraint.activate([
            settingsBtn.widthAnchor.constraint(equalToConstant: 48),
            settingsBtn.heightAnchor.constraint(equalToConstant: 48),
            settingsBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            settingsBtn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),

            findBtn.widthAnchor.constraint(equalToConstant: 48),
            findBtn.heightAnchor.constraint(equalToConstant: 48),
            findBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            findBtn.leadingAnchor.constraint(equalTo: settingsBtn.trailingAnchor, constant: 6),

            leaderboardBtn.widthAnchor.constraint(equalToConstant: 48),
            leaderboardBtn.heightAnchor.constraint(equalToConstant: 48),
            leaderboardBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            leaderboardBtn.leadingAnchor.constraint(equalTo: findBtn.trailingAnchor, constant: 6),
        ])
    }

    private func makeHUDButton(iconName: String) -> UIButton {
        let button = UIButton(type: .custom)
        if let image = UIImage.pixelIcon(named: iconName) {
            button.setImage(image, for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
            let inset: CGFloat = 6
            button.contentEdgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        } else {
            button.setTitle(iconName, for: .normal)
            button.titleLabel?.font = PixelTheme.headerFont(size: 20)
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    @objc private func findNextAgent() {
        guard let scene = gameScene else { return }
        guard let agent = scene.focusNextAgent() else { return }
        // Open chat and offset camera so the agent is visible on the left
        showChat(for: agent)
        focusCameraOnAgent(agent, in: scene)
    }

    @objc private func toggleLeaderboard() {
        if let existing = leaderboardView {
            UIView.animate(withDuration: 0.2, animations: {
                existing.alpha = 0
                existing.transform = CGAffineTransform(translationX: -60, y: 0)
            }) { _ in
                existing.removeFromSuperview()
                self.leaderboardView = nil
            }
            return
        }

        let lb = LeaderboardView()
        lb.translatesAutoresizingMaskIntoConstraints = false
        lb.dataProvider = { [weak self] in
            self?.gameScene?.agentManager.agents.map {
                (name: $0.displayName, stars: $0.stars, isDead: $0.isDead, entityID: $0.entityID)
            } ?? []
        }
        lb.onDismiss = { [weak self] in
            UIView.animate(withDuration: 0.2, animations: {
                self?.leaderboardView?.alpha = 0
                self?.leaderboardView?.transform = CGAffineTransform(translationX: -60, y: 0)
            }) { _ in
                self?.leaderboardView?.removeFromSuperview()
                self?.leaderboardView = nil
            }
        }
        lb.onAgentSelected = { [weak self] entityID in
            self?.focusAndChatAgent(entityID: entityID)
        }
        view.addSubview(lb)

        NSLayoutConstraint.activate([
            lb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            lb.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            lb.widthAnchor.constraint(equalToConstant: 280),
            lb.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
        leaderboardView = lb

        lb.alpha = 0
        lb.transform = CGAffineTransform(translationX: -60, y: 0)
        UIView.animate(withDuration: 0.2) {
            lb.alpha = 1
            lb.transform = .identity
        }
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

    // MARK: - Leaderboard → Agent Focus

    private func focusAndChatAgent(entityID: String) {
        guard let scene = gameScene else { return }
        guard let agent = scene.agentManager.agent(byID: entityID) else { return }

        // Open chat for this agent
        showChat(for: agent)

        // Animate camera so the agent is on the LEFT side (not hidden behind chat panel).
        // Chat panel occupies the right portion, so offset the camera to the right
        // to keep the agent visible in the left half of the screen.
        focusCameraOnAgent(agent, in: scene)
    }

    /// Positions the camera so the agent appears on the LEFT side of the screen,
    /// leaving room for the chat panel on the right.
    private func focusCameraOnAgent(_ agent: Agent, in scene: GameScene) {
        guard let cam = scene.camera else { return }

        // Convert chat width (screen pts) → world units using camera scale
        let chatWidth = preferredChatWidth()
        let worldOffset = chatWidth / 2 * cam.xScale

        let target = CGPoint(x: agent.position.x + worldOffset,
                             y: agent.position.y)
        let moveAction = SKAction.move(to: target, duration: 0.3)
        moveAction.timingMode = .easeInEaseOut
        cam.run(moveAction)
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
