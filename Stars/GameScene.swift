//
//  GameScene.swift
//  Stars
//

import SpriteKit
import UIKit

class GameScene: SKScene, SKPhysicsContactDelegate, UIGestureRecognizerDelegate {

    private let cameraController = CameraController()
    private let chunkManager = ChunkManager()
    private(set) var agentManager = AgentManager()
    private let buildSystem = BuildSystem()
    private let combatSystem = CombatSystem()

    private var worldNode: SKNode!
    private var ambientOverlay: SKSpriteNode!
    private var clockLabel: SKLabelNode!
    private var lastUpdateTime: TimeInterval = 0
    private var autosaveAccumulator: TimeInterval = 0
    private var lastAmbientMinute: Int = -1
    private var weatherNode: WeatherEffectNode!
    private var panGesture: UIPanGestureRecognizer?
    private var pinchGesture: UIPinchGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?

    var agentSelectionHandler: ((Agent) -> Void)?
    private var focusIndex = -1

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 1)

        // Physics world — no gravity, enable contact callbacks
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Camera
        camera = cameraController.cameraNode
        addChild(cameraController.cameraNode)

        // World
        worldNode = chunkManager.attachTo(scene: self)

        // Build system
        buildSystem.attachTo(worldNode: worldNode)
        agentManager.attachTo(worldNode: worldNode)
        agentManager.buildSystem = buildSystem
        combatSystem.onStructureDamaged = { [weak self] in
            self?.buildSystem.markNeedsCleanup()
        }
        combatSystem.agentLookup = { [weak self] entityID in
            self?.agentManager.agent(byID: entityID)
        }
        combatSystem.allAgentsProvider = { [weak self] in
            self?.agentManager.agents ?? []
        }
        combatSystem.isAgentSheltered = { [weak self] agent in
            guard let self else { return false }
            return agent.isRestingInHouse || self.buildSystem.isAgentInOwnHouse(agent)
        }

        // Day/night ambient overlay — sits on top of worldNode, under HUD
        ambientOverlay = SKSpriteNode(color: .clear, size: view.bounds.size)
        ambientOverlay.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ambientOverlay.zPosition = 900
        ambientOverlay.blendMode = .alpha
        cameraController.cameraNode.addChild(ambientOverlay)

        // Clock HUD label — top-right corner
        clockLabel = SKLabelNode(text: "")
        clockLabel.fontName = PixelTheme.skMonoFontName
        clockLabel.fontSize = 14
        clockLabel.fontColor = SKColor(white: 0.85, alpha: 0.9)
        clockLabel.horizontalAlignmentMode = .right
        clockLabel.verticalAlignmentMode = .top
        clockLabel.zPosition = 1000
        cameraController.cameraNode.addChild(clockLabel)

        // Weather effect overlay — above game world, below HUD
        weatherNode = WeatherEffectNode()
        weatherNode.zPosition = 950
        cameraController.cameraNode.addChild(weatherNode)

        restoreWorldState()

        chunkManager.updateChunks(
            aroundX: cameraController.chunkX,
            y: cameraController.chunkY,
            viewScale: cameraController.currentScale
        )

        // Gesture recognizers
        view.isMultipleTouchEnabled = true
        installGesturesIfNeeded(on: view)
        registerObservers()

        // Start background music
        SoundManager.shared.startBGM()

        // Start real-time weather monitoring
        WeatherManager.shared.startMonitoring()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        saveWorldState()
        WeatherManager.shared.stopMonitoring()
        removeObservers()
        removeGestures(from: view)
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        combatSystem.handleContact(contact)
    }

    // MARK: - Agent Focus

    /// Cycle camera to the next agent. Returns the focused agent (or nil if none).
    @discardableResult
    func focusNextAgent() -> Agent? {
        let agents = agentManager.agents
        guard !agents.isEmpty else { return nil }

        focusIndex = (focusIndex + 1) % agents.count
        let agent = agents[focusIndex]

        // Animate camera to agent position
        let moveAction = SKAction.move(to: agent.position, duration: 0.3)
        moveAction.timingMode = .easeInEaseOut
        cameraController.cameraNode.run(moveAction)

        return agent
    }

    // MARK: - Gesture Handlers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        cameraController.handlePan(translation: translation)
        gesture.setTranslation(.zero, in: self.view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        cameraController.handlePinch(gestureScale: gesture.scale)
        gesture.scale = 1.0
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view = self.view else { return }

        let viewPoint = gesture.location(in: view)
        let scenePoint = convertPoint(fromView: viewPoint)
        let selectedNode = nodes(at: scenePoint).first { node in
            node is Agent || node.parent is Agent
        }

        let agent = (selectedNode as? Agent) ?? (selectedNode?.parent as? Agent)
        if let agent {
            agentSelectionHandler?(agent)
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Let UIKit subviews (LeaderboardView, AgentChatView, HUD buttons) handle
    /// their own taps.  Only the scene's tap gesture fires when the touch lands
    /// directly on the SKView itself.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === tapGesture else { return true }
        // If the touch view is not the SKView, a UIKit subview owns it → skip
        return touch.view is SKView
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Stream chunks around camera
        chunkManager.updateChunks(
            aroundX: cameraController.chunkX,
            y: cameraController.chunkY,
            viewScale: cameraController.currentScale
        )

        // Tick world clock and update ambient overlay
        WorldClock.shared.update(deltaTime: dt)
        updateDayNight()

        // Update agents (movement + AI brain ticks + pending builds)
        agentManager.update(deltaTime: dt)

        autosaveAccumulator += dt
        if autosaveAccumulator >= 15 {
            autosaveAccumulator = 0
            saveWorldState()
        }
    }

    // MARK: - Setup

    private func installGesturesIfNeeded(on view: SKView) {
        if panGesture == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            view.addGestureRecognizer(pan)
            panGesture = pan
        }

        if pinchGesture == nil {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinch)
            pinchGesture = pinch
        }

        if tapGesture == nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            if let panGesture {
                tap.require(toFail: panGesture)
            }
            view.addGestureRecognizer(tap)
            tapGesture = tap
        }
    }

    private func removeGestures(from view: SKView) {
        if let panGesture {
            view.removeGestureRecognizer(panGesture)
        }
        if let pinchGesture {
            view.removeGestureRecognizer(pinchGesture)
        }
        if let tapGesture {
            view.removeGestureRecognizer(tapGesture)
        }
        panGesture = nil
        pinchGesture = nil
        tapGesture = nil
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModelConfigsChanged),
            name: .modelConfigsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenePersistenceRequest),
            name: .starsPersistWorldState,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConstitutionUpdated),
            name: .starsConstitutionDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCommandsUpdated),
            name: .starsCommandsDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEconomyUpdated),
            name: .starsEconomyDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWeatherChanged),
            name: WeatherManager.weatherDidChange,
            object: nil
        )
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Day/Night Cycle

    private func updateDayNight() {
        // Throttle — only changes once per in-game minute
        let currentMinute = WorldClock.shared.minute + WorldClock.shared.hour * 60
        guard currentMinute != lastAmbientMinute else { return }
        lastAmbientMinute = currentMinute

        // Overlay & HUD are children of the camera node.
        // Camera children render at their local size on screen (camera scale cancels out),
        // so we use view.bounds directly — NOT multiplied by scale.
        if let view = self.view {
            let vw = view.bounds.width
            let vh = view.bounds.height
            // +4 buffer to prevent sub-pixel edge gaps
            ambientOverlay.size = CGSize(width: vw + 4, height: vh + 4)

            // Position clock at top-right, respecting safe area (Dynamic Island / notch)
            let safeTop = view.safeAreaInsets.top
            let safeRight = view.safeAreaInsets.right
            clockLabel.position = CGPoint(
                x: vw / 2 - safeRight - 10,
                y: vh / 2 - safeTop - 6
            )
        }

        let (color, alpha) = WorldClock.shared.ambientTint
        ambientOverlay.color = color
        ambientOverlay.alpha = alpha
        clockLabel.text = WorldClock.shared.displayText
    }

    // MARK: - Persistence

    private func restoreWorldState() {
        if let persistedSnapshot = GameStateStore.shared.load() {
            let snapshot = IncrementalArchiveStore.shared.applyPendingDeltas(to: persistedSnapshot)
            WorldCommandRegistry.shared.restoreCustomAliases(snapshot.customCommands)
            buildSystem.restoreStructures(snapshot.structures)
            agentManager.restoreAgents(from: snapshot.agents)
            cameraController.restore(
                position: CGPoint(x: snapshot.camera.x, y: snapshot.camera.y),
                scale: CGFloat(snapshot.camera.scale)
            )
            WorldClock.shared.restore(totalMinutes: snapshot.worldTimeMinutes, savedAt: snapshot.savedAt)
            WorldEventLogStore.shared.append(
                category: .persistence,
                title: NSLocalizedString("log.world_restored", comment: ""),
                message: String(format: NSLocalizedString("log.world_restored_msg", comment: ""), snapshot.agents.count, snapshot.structures.count, snapshot.customCommands.count)
            )
        } else {
            cameraController.restore(position: CGPoint(x: 128, y: 128), scale: 1.35)
        }

        let spawnOrigin = cameraController.position == .zero
            ? CGPoint(x: 128, y: 128)
            : cameraController.position
        agentManager.syncAgents(spawnOrigin: spawnOrigin)
    }

    private func saveWorldState() {
        let snapshot = GameStateSnapshot(
            savedAt: Date(),
            agents: agentManager.snapshots(),
            structures: buildSystem.snapshots(),
            camera: CameraSnapshot(
                x: cameraController.position.x,
                y: cameraController.position.y,
                scale: Double(cameraController.currentScale)
            ),
            customCommands: WorldCommandRegistry.shared.customCommandProposals(),
            worldTimeMinutes: WorldClock.shared.totalMinutes
        )
        GameStateStore.shared.save(snapshot)
        IncrementalArchiveStore.shared.reset(after: snapshot)
        WorldEventLogStore.shared.append(
            category: .persistence,
            title: NSLocalizedString("log.world_snapshot", comment: ""),
            message: String(format: NSLocalizedString("log.world_snapshot_msg", comment: ""), snapshot.agents.count, snapshot.structures.count)
        )
    }

    @objc private func handleModelConfigsChanged() {
        agentManager.syncAgents(spawnOrigin: cameraController.position)
        saveWorldState()
    }

    @objc private func handleApplicationWillResignActive() {
        saveWorldState()
    }

    @objc private func handleApplicationDidEnterBackground() {
        saveWorldState()
    }

    @objc private func handleScenePersistenceRequest() {
        saveWorldState()
    }

    @objc private func handleConstitutionUpdated() {
        for agent in agentManager.agents {
            agent.memory.record(
                type: .observe,
                content: "⚠️ 世界宪法已更新 (v\(StarsConstitution.version))。请重新阅读 WORLD RULES，了解最新规则变更。"
            )
        }
        WorldEventLogStore.shared.append(
            category: .command,
            title: "宪法已更新",
            message: "所有 Agent 已收到通知，将重新阅读最新版宪法 v\(StarsConstitution.version)。"
        )
    }

    @objc private func handleCommandsUpdated() {
        for agent in agentManager.agents {
            agent.memory.record(
                type: .observe,
                content: "⚠️ 通用命令规则已被主人修改。请重新阅读 COMMAND RULES，了解最新的系统接口变更。"
            )
        }
        WorldEventLogStore.shared.append(
            category: .command,
            title: "命令规则已更新",
            message: "所有 Agent 已收到通知，将重新阅读最新命令规则。"
        )
    }

    @objc private func handleEconomyUpdated() {
        for agent in agentManager.agents {
            agent.memory.record(
                type: .observe,
                content: "⚠️ 经济系统规则已被主人修改。请重新阅读 ECONOMY RULES，了解最新的经济与贸易规则变更。"
            )
        }
        WorldEventLogStore.shared.append(
            category: .command,
            title: "经济规则已更新",
            message: "所有 Agent 已收到通知，将重新阅读最新经济规则。"
        )
    }

    @objc private func handleWeatherChanged() {
        guard let view = self.view else { return }
        let effect = WeatherManager.shared.currentEffect
        weatherNode.updateEffect(effect, sceneSize: view.bounds.size)
    }
}
