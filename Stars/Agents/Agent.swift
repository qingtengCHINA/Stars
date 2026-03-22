//
//  Agent.swift
//  Stars
//

import SpriteKit

enum ChatSpeakerRole: String, Codable, Sendable {
    case owner
    case agent
    case system
}

struct ChatMessageEntry: Codable, Sendable {
    let speaker: ChatSpeakerRole
    let text: String
    let timestamp: TimeInterval
}

/// Records every star increase/decrease for the transaction log.
struct StarTransaction: Codable, Sendable {
    let timestamp: TimeInterval
    let amount: Int          // positive = gain, negative = spend
    let reason: String       // human-readable description
    let balance: Int         // stars after this transaction
}

final class Agent: SKSpriteNode {

    // MARK: - Identity

    let entityID: String
    private(set) var displayName: String
    private(set) var representedModelConfigID: UUID

    // MARK: - AI

    var brain: AgentBrain?
    var currentThought: String?
    var currentAction: AgentActionType = .idle

    // MARK: - Memory

    let memory = MemoryStore()
    var shortTermMessages: [ShortTermMessage] = []
    var forceNextThink = false
    private(set) var chatMessages: [ChatMessageEntry] = []
    private(set) var pendingOwnerReplies = 0
    private(set) var latestContextUsage: ContextUsageSnapshot?
    private(set) var totalTokensUsed: Int = 0
    private(set) var thinkCycleCount: Int = 0

    // MARK: - Combat

    var hp: Int
    let maxHP: Int = 100
    var isDead: Bool { hp <= 0 }
    var facingAngle: CGFloat = 0
    var pendingWeapon: WeaponType = .melee
    var pendingWeaponID: String = "fist"   // specific weapon from catalog
    var weaponCooldown: TimeInterval = 0
    private(set) var stars: Int = 0
    private(set) var starTransactions: [StarTransaction] = []

    // MARK: - Weapon Inventory & Revival

    /// Weapon ammo inventory — weaponID → remaining uses.
    /// Free weapons (fist, pistol) are NOT tracked here — always unlimited.
    var weaponAmmo: [String: Int] = [:]

    /// All weapon IDs the agent currently has ammo for (plus free weapons).
    var ownedWeapons: Set<String> {
        var weapons = WeaponCatalog.defaultWeapons  // fist, pistol always available
        weapons.formUnion(weaponAmmo.keys.filter { weaponAmmo[$0]! > 0 })
        return weapons
    }

    /// Number of revival cards held (150⭐ each).
    var revivalCards: Int = 0

    /// Callback: find nearest living enemy agent near a point (for homing weapons).
    /// Set by AgentManager. Parameters: (targetPoint, excludeEntityID) → Agent?
    var nearestAgentProvider: ((CGPoint, String) -> Agent?)?

    // MARK: - Building

    var pendingBuild: PendingBuild?
    var buildCooldown: TimeInterval = 0

    // MARK: - House Resting

    /// Accumulated real seconds the agent has been idle inside its own house.
    var houseRestAccumulator: TimeInterval = 0
    /// Set by AgentManager when agent is actively resting inside own house.
    var isRestingInHouse: Bool = false

    // MARK: - Near-Death & Movement Modifiers

    /// True when HP ≤ 5 — agent is critically wounded.
    var isNearDeath: Bool { !isDead && hp > 0 && hp <= 5 }

    /// Effective move speed accounting for near-death (−50%) and night (−30%).
    var effectiveMoveSpeed: CGFloat {
        var speed = moveSpeed
        if isNearDeath { speed *= 0.5 }
        if WorldClock.shared.isNight { speed *= 0.7 }
        return speed
    }

    // MARK: - Exploration

    /// Tiles this agent has visited (tracked as "chunkX_chunkY" for 64×64-tile chunks).
    var visitedChunks: Set<String> = []

    // MARK: - Movement

    let moveSpeed: CGFloat
    let agentColor: UIColor
    private(set) var targetPosition: CGPoint?
    private var wanderIdle = true
    private var wanderTimer: TimeInterval = 0
    private var wanderDirection: CGVector = .zero

    // MARK: - Respawn

    private var respawnTimer: TimeInterval = 0

    // MARK: - UI

    private var speechNode: SKLabelNode?
    private var speechTimer: TimeInterval = 0
    private var hpBarBg: SKSpriteNode?
    private var hpBarFill: SKSpriteNode?
    private var restingNode: SKLabelNode?
    private var nearDeathPulseAction: SKAction?
    private var _wasResting = false
    private var _wasNearDeath = false

    // MARK: - Animation

    private var walkTextures: [SKTexture]?
    private var idleTexture: SKTexture?
    private var isAnimatingWalk = false

    // MARK: - Constants

    static let agentSize: CGFloat = 24

    // MARK: - Init

    init(agentColor: UIColor,
         displayName: String,
         entityID: String = UUID().uuidString,
         modelConfigID: UUID,
         moveSpeed: CGFloat = CGFloat.random(in: 20...50),
         startingHP: Int = 100) {
        self.entityID = entityID
        self.displayName = displayName
        self.representedModelConfigID = modelConfigID
        self.moveSpeed = moveSpeed
        self.hp = max(0, min(startingHP, maxHP))
        self.agentColor = agentColor

        let textures = Self.createCreatureTextures(seed: entityID, baseColor: agentColor)
        let size = CGSize(width: Self.agentSize, height: Self.agentSize)

        super.init(texture: textures[0], color: .clear, size: size)
        self.idleTexture = textures[0]
        if textures.count > 1 {
            self.walkTextures = Array(textures.dropFirst())
        }
        self.zPosition = ZSort.entityBase   // will be refined per-frame
        self.name = displayName
        wanderTimer = TimeInterval.random(in: 0.5...2.0)

        setupPhysicsBody()
        setupHPBar()
        startIdleAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Physics

    private func setupPhysicsBody() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Self.agentSize, height: Self.agentSize))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.friction = 0
        body.restitution = 0
        body.linearDamping = 0
        body.categoryBitMask    = PhysicsCategory.agent
        body.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.melee | PhysicsCategory.trap
        body.collisionBitMask   = PhysicsCategory.structure
        self.physicsBody = body
    }

    // MARK: - HP Bar

    private func setupHPBar() {
        let barW: CGFloat = 20
        let barH: CGFloat = 2

        let bg = SKSpriteNode(color: UIColor(white: 0.2, alpha: 0.8),
                              size: CGSize(width: barW, height: barH))
        bg.anchorPoint = CGPoint(x: 0, y: 0.5)
        bg.position = CGPoint(x: -barW / 2, y: Self.agentSize / 2 + 3)
        bg.zPosition = 2
        addChild(bg)
        hpBarBg = bg

        let fill = SKSpriteNode(color: .green,
                                size: CGSize(width: barW, height: barH))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = .zero
        fill.zPosition = 1
        bg.addChild(fill)
        hpBarFill = fill
    }

    private func updateHPBar() {
        let ratio = CGFloat(hp) / CGFloat(maxHP)
        hpBarFill?.xScale = ratio
        if ratio > 0.5 {
            hpBarFill?.color = .green
        } else if ratio > 0.25 {
            hpBarFill?.color = .yellow
        } else {
            hpBarFill?.color = .red
        }
    }

    // MARK: - Resting Visual

    /// Stores the saved z-position before entering the house.
    private var savedZPosition: CGFloat?

    private func updateRestingVisual() {
        if isRestingInHouse {
            // Agent is inside their house — render behind the house with reduced visibility
            if !isDead { alpha = 0.45 }

            // Push agent z-position below the structure layer so the house
            // roof covers the agent, making them appear truly "inside".
            if savedZPosition == nil {
                savedZPosition = zPosition
                zPosition = ZSort.terrain + 1
            }

            if restingNode == nil {
                let zzz = SKLabelNode(text: "💤")
                zzz.fontSize = 10
                // Position high enough to appear above the house roof
                zzz.position = CGPoint(x: 0, y: Self.agentSize / 2 + 28)
                // High z so the indicator is visible above everything
                zzz.zPosition = ZSort.projectile + 5
                zzz.name = "restingIndicator"
                addChild(zzz)
                restingNode = zzz
                // Gentle floating animation
                let floatUp = SKAction.moveBy(x: 0, y: 4, duration: 1.5)
                let floatDown = SKAction.moveBy(x: 0, y: -4, duration: 1.5)
                floatUp.timingMode = .easeInEaseOut
                floatDown.timingMode = .easeInEaseOut
                zzz.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
            }
        } else {
            // Not resting — restore full visibility and z-position
            if !isDead { alpha = 1.0 }
            if let sz = savedZPosition {
                zPosition = sz
                savedZPosition = nil
            }
            if let node = restingNode {
                node.removeAllActions()
                node.removeFromParent()
                restingNode = nil
            }
        }
    }

    // MARK: - Near-Death Visual

    private func updateNearDeathVisual() {
        if isNearDeath {
            // Pulsing red tint when critically wounded
            if nearDeathPulseAction == nil {
                let pulseRed = SKAction.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.5)
                let pulseBack = SKAction.colorize(withColorBlendFactor: 0.1, duration: 0.5)
                let pulse = SKAction.repeatForever(SKAction.sequence([pulseRed, pulseBack]))
                pulse.timingMode = .easeInEaseOut
                nearDeathPulseAction = pulse
                run(pulse, withKey: "nearDeathPulse")
            }
        } else {
            if nearDeathPulseAction != nil {
                removeAction(forKey: "nearDeathPulse")
                nearDeathPulseAction = nil
                if !isDead && !isRestingInHouse {
                    run(SKAction.colorize(withColorBlendFactor: 0, duration: 0.2))
                }
            }
        }
    }

    // MARK: - Walk / Idle Animation

    private func startIdleAnimation() {
        removeAction(forKey: "walkAnim")
        let breatheIn = SKAction.scaleY(to: 1.04, duration: 0.7)
        breatheIn.timingMode = .easeInEaseOut
        let breatheOut = SKAction.scaleY(to: 0.96, duration: 0.7)
        breatheOut.timingMode = .easeInEaseOut
        let breathe = SKAction.repeatForever(SKAction.sequence([breatheIn, breatheOut]))
        run(breathe, withKey: "idleBreathe")
    }

    private func startWalkAnimation() {
        removeAction(forKey: "idleBreathe")
        yScale = 1.0
        guard let frames = walkTextures, !frames.isEmpty else { return }
        let walkAction = SKAction.animate(with: frames, timePerFrame: 0.12)
        run(SKAction.repeatForever(walkAction), withKey: "walkAnim")
    }

    private func stopWalkAnimation() {
        removeAction(forKey: "walkAnim")
        self.texture = idleTexture
        if !isDead {
            startIdleAnimation()
        }
    }

    // MARK: - Exploration Tracking

    /// Cached chunk coordinate to avoid per-frame String allocation.
    /// Only generates a Set key when the agent actually moves to a new chunk.
    private var lastChunkX: Int = Int.min
    private var lastChunkY: Int = Int.min

    /// Check and record chunk visit. Returns true if this is a newly discovered chunk.
    func trackExploration() -> Bool {
        let chunkX = Int(floor(position.x / (Chunk.tileSize * 64)))
        let chunkY = Int(floor(position.y / (Chunk.tileSize * 64)))
        // Fast path: still in the same chunk as last frame
        guard chunkX != lastChunkX || chunkY != lastChunkY else { return false }
        lastChunkX = chunkX
        lastChunkY = chunkY
        let key = "\(chunkX)_\(chunkY)"
        if visitedChunks.contains(key) { return false }
        visitedChunks.insert(key)
        return true
    }

    // MARK: - Tile Coordinates

    var tileX: Int { Int(floor(position.x / Chunk.tileSize)) }
    var tileY: Int { Int(floor(position.y / Chunk.tileSize)) }

    func updateIdentity(displayName: String, modelConfigID: UUID) {
        self.displayName = displayName
        self.representedModelConfigID = modelConfigID
        self.name = displayName
    }

    // MARK: - Public Actions

    func moveTo(tileX: Int, tileY: Int) {
        targetPosition = CGPoint(
            x: CGFloat(tileX) * Chunk.tileSize + Chunk.tileSize / 2,
            y: CGFloat(tileY) * Chunk.tileSize + Chunk.tileSize / 2
        )
    }

    func clearTarget() {
        targetPosition = nil
        physicsBody?.velocity = .zero
    }

    func showSpeechBubble(_ text: String) {
        speechNode?.removeFromParent()
        let display = text.count > 40 ? String(text.prefix(40)) + "…" : text

        let label = SKLabelNode(text: display)
        label.fontSize = 8
        label.fontName = PixelTheme.skFontName
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: Self.agentSize / 2 + 10)
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = 100
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .bottom
        label.zPosition = 3
        addChild(label)

        speechNode = label
        speechTimer = 5.0
    }

    // MARK: - Star Transaction Recording

    /// Records a star transaction and keeps the log capped at 100 entries.
    private func recordStarTransaction(amount: Int, reason: String) {
        let tx = StarTransaction(
            timestamp: Date().timeIntervalSince1970,
            amount: amount,
            reason: reason,
            balance: stars
        )
        starTransactions.append(tx)
        // Keep only the most recent 100 transactions
        if starTransactions.count > 100 {
            starTransactions.removeFirst(starTransactions.count - 100)
        }
    }

    /// Award kill reward: percentage of the victim's stars (minimum killReward).
    func awardKillReward(victimStars: Int) {
        let pct = EconomyConfig.shared.killRewardPercent
        let reward = max(EconomyConfig.shared.killReward, victimStars * pct / 100)
        stars += reward
        recordStarTransaction(amount: reward, reason: "Kill reward (victim had \(victimStars)⭐)")
        memory.record(type: .combat, content: "Earned \(reward)⭐ from kill (victim had \(victimStars)⭐)! Total Stars: \(stars).")
        showSpeechBubble("⭐ +\(reward)")
    }

    // MARK: - Economy

    /// Attempt to spend stars. Returns true if the agent has enough.
    @discardableResult
    func spendStars(_ amount: Int, reason: String = "purchase") -> Bool {
        guard amount > 0, stars >= amount else { return false }
        stars -= amount
        recordStarTransaction(amount: -amount, reason: reason)
        memory.record(type: .observe, content: "Spent \(amount) ⭐ (remaining: \(stars)).")
        return true
    }

    /// Receive stars from another agent (or system).
    func receiveStars(_ amount: Int, from senderName: String? = nil) {
        guard amount > 0 else { return }
        stars += amount
        let source = senderName ?? "system"
        recordStarTransaction(amount: amount, reason: "Received from \(source)")
        memory.record(type: .observe, content: "Received \(amount) ⭐ from \(source). Total: \(stars).")
        showSpeechBubble("⭐ +\(amount)")
    }

    // MARK: - Ammo

    /// Consume 1 ammo for the given weapon. Returns false if out of ammo.
    func consumeAmmo(weaponID: String) -> Bool {
        // Free weapons have unlimited ammo
        guard !WeaponCatalog.defaultWeapons.contains(weaponID) else { return true }
        guard let current = weaponAmmo[weaponID], current > 0 else { return false }
        weaponAmmo[weaponID] = current - 1
        if current - 1 == 0 {
            weaponAmmo.removeValue(forKey: weaponID)
        }
        return true
    }

    /// Add ammo for a weapon (from purchase).
    func addAmmo(weaponID: String, amount: Int) {
        weaponAmmo[weaponID] = (weaponAmmo[weaponID] ?? 0) + amount
    }

    /// Check remaining ammo for a weapon (0 for not owned, -1 for unlimited free weapons).
    func ammoCount(for weaponID: String) -> Int {
        if WeaponCatalog.defaultWeapons.contains(weaponID) { return -1 }
        return weaponAmmo[weaponID] ?? 0
    }

    func healHP(_ amount: Int) {
        guard !isDead else { return }
        hp = min(maxHP, hp + amount)
        updateHPBar()
    }

    func startBuildCooldown(_ duration: TimeInterval) {
        buildCooldown = duration
        physicsBody?.velocity = .zero
    }

    func receiveOwnerMessage(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appendChatMessage(.owner, text: trimmed)
        pendingOwnerReplies += 1
        shortTermMessages.append(
            ShortTermMessage(
                speakerName: "主人",
                content: trimmed,
                gameTick: Date().timeIntervalSince1970
            )
        )
        memory.record(type: .talk, content: "主人说: \"\(trimmed)\"")
        forceNextThink = true
        brain?.requestImmediateThink()
        persistMutation(
            reason: "owner-message",
            category: .chat,
            title: NSLocalizedString("log.owner_message", comment: ""),
            message: trimmed
        )
    }

    func recordAgentReply(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appendChatMessage(.agent, text: trimmed)
        pendingOwnerReplies = max(0, pendingOwnerReplies - 1)
        persistMutation(
            reason: "agent-reply",
            category: .chat,
            title: NSLocalizedString("log.agent_reply", comment: ""),
            message: trimmed
        )
    }

    func recordSystemMessage(_ text: String, consumesOwnerReply: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendChatMessage(.system, text: trimmed)
        if consumesOwnerReply {
            pendingOwnerReplies = max(0, pendingOwnerReplies - 1)
        }
        persistMutation(
            reason: "system-message",
            category: .chat,
            title: NSLocalizedString("log.system_message", comment: ""),
            message: trimmed
        )
    }

    // MARK: - Damage & Death

    func takeDamage(_ amount: Int) {
        guard !isDead else { return }
        hp = max(0, hp - amount)
        updateHPBar()

        run(SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.15),
        ]))

        if isDead { die() }
        persistMutation(
            reason: "agent-damaged",
            category: .combat,
            title: NSLocalizedString("log.agent_damaged", comment: ""),
            message: String(format: NSLocalizedString("log.agent_damaged_msg", comment: ""), amount, hp, maxHP)
        )
    }

    private func die() {
        // Stop all animations on death
        removeAction(forKey: "idleBreathe")
        removeAction(forKey: "walkAnim")
        isAnimatingWalk = false
        yScale = 1.0
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        alpha = 0.3
        targetPosition = nil
        currentAction = .idle
        pendingBuild = nil
        respawnTimer = EconomyConfig.shared.respawnTime

        // STOP the brain — no more token consumption during death
        brain?.stop()

        memory.record(type: .combat, content: "I died at (\(tileX), \(tileY)). My consciousness fades... waiting to respawn in \(Int(respawnTimer)) seconds.")
        showSpeechBubble("💀")

        // Record to long-term memory — death is significant
        LongTermMemory.shared.recordCombatEvent(
            entityID: entityID,
            content: "Died at (\(tileX), \(tileY)) on Day \(WorldClock.shared.day). Death means my thinking stops — I cease to exist until respawn."
        )

        persistMutation(
            reason: "agent-died",
            category: .combat,
            title: NSLocalizedString("log.agent_died", comment: ""),
            message: String(format: NSLocalizedString("log.agent_died_msg", comment: ""), Int(respawnTimer))
        )
    }

    /// Force respawn — called by Revival Card. Skips the 30s timer.
    func forceRespawn() {
        guard isDead else { return }
        respawnTimer = 0
        respawn()
        memory.record(type: .combat, content: "Revived by a Revival Card! Full HP restored.")
    }

    private func respawn() {
        hp = maxHP
        restorePhysicsBody()
        alpha = 1.0
        updateHPBar()
        // Restart animations after revival
        self.texture = idleTexture
        startIdleAnimation()

        // RESTART the brain — thinking resumes
        brain?.resume()

        memory.record(type: .combat, content: "Respawned with full HP at (\(tileX), \(tileY)). My consciousness returns. I remember dying.")
        forceNextThink = true  // Think immediately after revival
        brain?.recordSignificantEvent()  // respawn → trigger SOUL reflection

        LongTermMemory.shared.recordCombatEvent(
            entityID: entityID,
            content: "Respawned at (\(tileX), \(tileY)) on Day \(WorldClock.shared.day). The experience of death was terrifying — my thoughts simply stopped."
        )

        persistMutation(
            reason: "agent-respawned",
            category: .combat,
            title: NSLocalizedString("log.agent_respawned", comment: ""),
            message: String(format: NSLocalizedString("log.agent_respawned_msg", comment: ""), tileX, tileY)
        )
    }

    func restorePersistentState(
        position: CGPoint,
        hp: Int,
        currentThought: String?,
        currentAction: AgentActionType,
        memories: [MemoryEntry],
        chatMessages: [ChatMessageEntry],
        shortTermMessages: [ShortTermMessage],
        forceNextThink: Bool,
        pendingOwnerReplies: Int,
        respawnRemaining: TimeInterval,
        stars: Int = 0,
        houseRestAccumulator: TimeInterval = 0,
        visitedChunks: Set<String> = [],
        weaponAmmo: [String: Int] = [:],
        revivalCards: Int = 0
    ) {
        self.position = position
        self.hp = max(0, min(hp, maxHP))
        self.currentThought = currentThought
        self.currentAction = currentAction
        memory.restore(entries: memories)
        self.chatMessages = chatMessages
        self.shortTermMessages = shortTermMessages
        self.forceNextThink = forceNextThink
        self.pendingOwnerReplies = max(0, pendingOwnerReplies)
        self.respawnTimer = max(0, respawnRemaining)
        self.stars = stars
        self.houseRestAccumulator = houseRestAccumulator
        self.visitedChunks = visitedChunks
        self.weaponAmmo = weaponAmmo
        self.revivalCards = revivalCards

        if isDead {
            applyDeadStateForRestore()
        } else {
            restorePhysicsBody()
            alpha = 1.0
        }
        updateHPBar()
    }

    func updateContextUsage(_ usage: ContextUsageSnapshot) {
        latestContextUsage = usage
        totalTokensUsed += usage.usedTokens + usage.responseTokens
        thinkCycleCount += 1
    }

    @discardableResult
    func compactChatHistory(keepingRecent recentCount: Int = 10) -> Int {
        guard chatMessages.count > recentCount + 2 else { return 0 }

        let compactCount = chatMessages.count - recentCount
        let olderMessages = Array(chatMessages.prefix(compactCount))
        let summary = olderMessages
            .prefix(6)
            .map { message in
                let role: String
                switch message.speaker {
                case .owner: role = "主人"
                case .agent: role = displayName
                case .system: role = "系统"
                }
                return "\(role): \(message.text)"
            }
            .joined(separator: " | ")

        memory.record(type: .talk, content: "Compacted \(compactCount) older chat turns: \(summary)")
        chatMessages = Array(chatMessages.suffix(recentCount))
        return compactCount
    }

    // MARK: - Per-Frame Update

    func update(deltaTime dt: TimeInterval) {

        // Update depth sorting based on y-position
        // Skip when resting in house — agent is deliberately placed behind structures
        if !isRestingInHouse {
            zPosition = ZSort.depthZ(for: position.y)
        }

        // Walk animation: toggle based on movement
        let vel = physicsBody?.velocity ?? .zero
        let isMoving = (vel.dx * vel.dx + vel.dy * vel.dy) > 4
        if isMoving != isAnimatingWalk {
            isAnimatingWalk = isMoving
            if isMoving {
                startWalkAnimation()
            } else {
                stopWalkAnimation()
            }
        }

        // Resting-in-house visual — only update when state changes
        let resting = isRestingInHouse
        if resting != _wasResting {
            _wasResting = resting
            updateRestingVisual()
        }

        // Near-death visual — only update when state changes
        let nearDeath = isNearDeath
        if nearDeath != _wasNearDeath {
            _wasNearDeath = nearDeath
            updateNearDeathVisual()
        }

        // Exploration tracking — award stars for discovering new chunks
        if !isDead && trackExploration() {
            let reward = EconomyConfig.shared.explorationReward
            stars += reward
            recordStarTransaction(amount: reward, reason: "Exploration reward")
            memory.record(type: .observe, content: "Discovered a new area! Earned \(reward) exploration Star\(reward > 1 ? "s" : ""). Total Stars: \(stars).")
            showSpeechBubble("🌟 +\(reward)")
        }

        // Dead → count down respawn
        if isDead {
            respawnTimer -= dt
            if respawnTimer <= 0 { respawn() }
            return
        }

        // Cooldowns
        if weaponCooldown > 0 { weaponCooldown -= dt }
        if buildCooldown > 0  { buildCooldown  -= dt }

        // Brain tick (paused during build cooldown)
        if buildCooldown <= 0 {
            brain?.update(deltaTime: dt)
        }

        // Speech bubble timer
        if speechTimer > 0 {
            speechTimer -= dt
            if speechTimer <= 0 {
                speechNode?.removeFromParent()
                speechNode = nil
            }
        }

        // Attack: if in range and cooled down → fire weapon
        if currentAction == .attack, let target = targetPosition {
            let dist = hypot(target.x - position.x, target.y - position.y)
            let weaponDef = WeaponCatalog.weapon(for: pendingWeaponID)
            if dist <= weaponDef.reach && weaponCooldown <= 0 {
                performAttack(toward: target)
                return
            }
        }

        // Movement
        if let target = targetPosition {
            moveToward(target, deltaTime: dt)
        } else {
            wander(deltaTime: dt)
        }
    }

    // MARK: - Attack Execution

    private func performAttack(toward target: CGPoint) {
        guard let parent = self.parent else { return }
        let weaponDef = WeaponCatalog.weapon(for: pendingWeaponID)

        // Consume ammo — free weapons are unlimited
        guard consumeAmmo(weaponID: pendingWeaponID) else {
            memory.record(type: .combat, content: "Out of ammo for \(weaponDef.displayName)! Buy more with /buy_weapon.")
            showSpeechBubble("🔫 No ammo!")
            clearTarget()
            currentAction = .idle
            return
        }

        weaponCooldown = weaponDef.cooldown

        // Play weapon SFX
        SoundManager.shared.playWeaponSFX(weaponID: pendingWeaponID)

        switch weaponDef.category {
        case .melee:
            WeaponSystem.meleeAttack(by: self, weaponDef: weaponDef, in: parent)
        case .ranged, .explosive:
            // For homing weapons, find the nearest enemy to target
            var homingTarget: Agent? = nil
            if weaponDef.isHoming {
                homingTarget = nearestAgentProvider?(target, entityID)
            }
            WeaponSystem.rangedAttack(by: self, toward: target, weaponDef: weaponDef,
                                      in: parent, homingTarget: homingTarget)
        }

        clearTarget()
        currentAction = .idle
    }

    // MARK: - Velocity-Based Movement (works with physics collisions)

    private func moveToward(_ target: CGPoint, deltaTime dt: TimeInterval) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < 2.0 {
            targetPosition = nil
            currentAction = .idle
            physicsBody?.velocity = .zero
            return
        }

        let speed = effectiveMoveSpeed
        let vx = (dx / dist) * speed
        let vy = (dy / dist) * speed
        physicsBody?.velocity = CGVector(dx: vx, dy: vy)
        facingAngle = atan2(vy, vx)
    }

    private func wander(deltaTime dt: TimeInterval) {
        wanderTimer -= dt

        if wanderTimer <= 0 {
            wanderIdle.toggle()
            if wanderIdle {
                wanderTimer = TimeInterval.random(in: 1.0...3.0)
                wanderDirection = .zero
            } else {
                wanderTimer = TimeInterval.random(in: 1.0...4.0)
                let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
                wanderDirection = CGVector(dx: cos(angle), dy: sin(angle))
                facingAngle = angle
            }
        }

        if wanderIdle {
            physicsBody?.velocity = .zero
        } else {
            let speed = effectiveMoveSpeed
            physicsBody?.velocity = CGVector(
                dx: wanderDirection.dx * speed,
                dy: wanderDirection.dy * speed
            )
        }
    }

    // MARK: - Procedural Pixel Creature (Clawd-style, 16×16)

    private static var textureFrameCache: [String: [SKTexture]] = [:]

    /// Generates a unique symmetric pixel-art creature with walk animation frames.
    /// Returns [idle, walkLeft, walkRight] — 3 frames for walk cycle.
    /// 16×16 canvas with big head, stubby body, distinct legs (Clawd-inspired).
    private static func createCreatureTextures(seed: String, baseColor: UIColor) -> [SKTexture] {
        if let cached = textureFrameCache[seed] { return cached }
        let w = 16
        let h = 16
        let halfW = w / 2 // 8
        var rng = PixelRNG(seed: djb2Hash(seed))

        // --- 1. Generate body mask (left half only, mirrored) ---
        // Big-headed Clawd-style proportions: large head, compact body, stubby legs
        let zoneProb: [[Double]] = [
            //  col: 0     1     2     3     4     5     6     7
            /* 0  */ [0.00, 0.00, 0.00, 0.05, 0.20, 0.25, 0.10, 0.00],  // top accent
            /* 1  */ [0.00, 0.00, 0.15, 0.50, 0.75, 0.82, 0.55, 0.12],  // head top
            /* 2  */ [0.00, 0.05, 0.35, 0.78, 0.92, 0.95, 0.82, 0.28],  // head
            /* 3  */ [0.00, 0.10, 0.52, 0.88, 0.96, 0.98, 0.90, 0.38],  // head widest
            /* 4  */ [0.00, 0.10, 0.52, 0.88, 0.96, 0.98, 0.90, 0.38],  // eyes row
            /* 5  */ [0.00, 0.08, 0.45, 0.82, 0.94, 0.96, 0.85, 0.32],  // lower face
            /* 6  */ [0.00, 0.05, 0.30, 0.68, 0.85, 0.90, 0.75, 0.22],  // chin
            /* 7  */ [0.00, 0.00, 0.15, 0.45, 0.68, 0.75, 0.58, 0.12],  // neck
            /* 8  */ [0.00, 0.10, 0.38, 0.65, 0.88, 0.92, 0.85, 0.38],  // shoulders
            /* 9  */ [0.05, 0.22, 0.52, 0.75, 0.92, 0.96, 0.92, 0.48],  // body + arms
            /* 10 */ [0.05, 0.20, 0.50, 0.72, 0.92, 0.96, 0.90, 0.45],  // body
            /* 11 */ [0.00, 0.12, 0.38, 0.58, 0.82, 0.88, 0.78, 0.32],  // waist
            /* 12 */ [0.00, 0.00, 0.20, 0.42, 0.62, 0.55, 0.50, 0.18],  // hips
            /* 13 */ [0.00, 0.00, 0.12, 0.35, 0.55, 0.28, 0.48, 0.12],  // upper legs (gap)
            /* 14 */ [0.00, 0.00, 0.08, 0.28, 0.48, 0.20, 0.42, 0.08],  // lower legs
            /* 15 */ [0.00, 0.00, 0.00, 0.22, 0.42, 0.15, 0.35, 0.00],  // feet
        ]

        var half = [[Bool]](repeating: [Bool](repeating: false, count: halfW), count: h)
        for row in 0..<h {
            for col in 0..<halfW {
                let rand = Double(rng.next() % 10000) / 10000.0
                half[row][col] = rand < zoneProb[row][col]
            }
        }

        // Mirror to full width
        var body = [[Bool]](repeating: [Bool](repeating: false, count: w), count: h)
        for row in 0..<h {
            for col in 0..<halfW {
                body[row][col] = half[row][col]
                body[row][w - 1 - col] = half[row][col]
            }
        }

        // Ensure minimum body mass
        let mass = body.flatMap { $0 }.filter { $0 }.count
        if mass < 36 {
            for row in 2...10 {
                for col in 4...11 { body[row][col] = true }
            }
        }

        // --- 2. Color palette ---
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        baseColor.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let bodyC    = baseColor
        let lightC   = UIColor(red: min(1, br + 0.18), green: min(1, bg + 0.18), blue: min(1, bb + 0.18), alpha: 1)
        let darkC    = UIColor(red: max(0, br - 0.18), green: max(0, bg - 0.18), blue: max(0, bb - 0.18), alpha: 1)
        let outlineC = UIColor(red: max(0, br - 0.40), green: max(0, bg - 0.40), blue: max(0, bb - 0.40), alpha: 1)

        // --- 3. Eye placement ---
        var eyeRow = 4
        for testRow in 1..<(h - 4) {
            let centerFilled = (5...10).contains { body[testRow][$0] }
            if centerFilled {
                eyeRow = min(testRow + 1, h - 4)
                break
            }
        }
        let leftEyeCol = 5
        let rightEyeCol = w - 1 - leftEyeCol  // 10

        // --- 4. Pre-compute pixel color map (consistent across frames) ---
        var colorMap = [[UIColor?]](repeating: [UIColor?](repeating: nil, count: w), count: h)
        for row in 0..<h {
            for col in 0..<w {
                guard body[row][col] else { continue }
                let v = Int(rng.next() % 100)
                if v < 18      { colorMap[row][col] = lightC }
                else if v < 32 { colorMap[row][col] = darkC }
                else           { colorMap[row][col] = bodyC }
            }
        }

        // --- 5. Render function ---
        func renderFrame(mask: [[Bool]]) -> SKTexture {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: w, height: h), format: format
            )
            let image = renderer.image { ctx in
                let gc = ctx.cgContext
                gc.clear(CGRect(x: 0, y: 0, width: w, height: h))

                // Outline (1px dark border around body pixels)
                gc.setFillColor(outlineC.cgColor)
                for row in 0..<h {
                    for col in 0..<w {
                        guard !mask[row][col] else { continue }
                        let adj = [(row-1, col), (row+1, col), (row, col-1), (row, col+1)]
                        let touchesBody = adj.contains { r, c in
                            r >= 0 && r < h && c >= 0 && c < w && mask[r][c]
                        }
                        if touchesBody {
                            gc.fill(CGRect(x: col, y: row, width: 1, height: 1))
                        }
                    }
                }

                // Body pixels — use pre-computed colors for base body,
                // fall back to bodyC for walk-shifted pixels
                for row in 0..<h {
                    for col in 0..<w {
                        guard mask[row][col] else { continue }
                        let color = colorMap[row][col] ?? bodyC
                        gc.setFillColor(color.cgColor)
                        gc.fill(CGRect(x: col, y: row, width: 1, height: 1))
                    }
                }

                // Eyes: 2×2 white + 1×1 dark pupil
                if mask[eyeRow][leftEyeCol] && mask[eyeRow][rightEyeCol] {
                    gc.setFillColor(UIColor.white.cgColor)
                    gc.fill(CGRect(x: leftEyeCol, y: eyeRow, width: 2, height: 2))
                    gc.fill(CGRect(x: rightEyeCol - 1, y: eyeRow, width: 2, height: 2))
                    gc.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
                    gc.fill(CGRect(x: leftEyeCol + 1, y: eyeRow + 1, width: 1, height: 1))
                    gc.fill(CGRect(x: rightEyeCol - 1, y: eyeRow + 1, width: 1, height: 1))
                }
            }
            let tex = SKTexture(image: image)
            tex.filteringMode = .nearest
            return tex
        }

        // --- 6. Idle frame ---
        let idleFrame = renderFrame(mask: body)

        // --- 7. Walk frames: shift leg-zone pixels ---
        let legStart = 12

        // Walk-left: left legs shift down 1px, right legs shift up 1px
        var walkL = body
        for row in stride(from: h - 1, to: legStart, by: -1) {
            for col in 0..<halfW {
                walkL[row][col] = body[row - 1][col]
            }
        }
        for col in 0..<halfW { walkL[legStart][col] = false }
        for row in legStart..<(h - 1) {
            for col in halfW..<w {
                walkL[row][col] = body[row + 1][col]
            }
        }
        for col in halfW..<w { walkL[h - 1][col] = false }

        // Walk-right: right legs shift down 1px, left legs shift up 1px
        var walkR = body
        for row in stride(from: h - 1, to: legStart, by: -1) {
            for col in halfW..<w {
                walkR[row][col] = body[row - 1][col]
            }
        }
        for col in halfW..<w { walkR[legStart][col] = false }
        for row in legStart..<(h - 1) {
            for col in 0..<halfW {
                walkR[row][col] = body[row + 1][col]
            }
        }
        for col in 0..<halfW { walkR[h - 1][col] = false }

        let walkLFrame = renderFrame(mask: walkL)
        let walkRFrame = renderFrame(mask: walkR)

        let frames = [idleFrame, walkLFrame, walkRFrame]
        textureFrameCache[seed] = frames
        return frames
    }

    // Simple deterministic RNG for creature generation
    private struct PixelRNG {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 1 : seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state >> 33
        }
    }

    private static func djb2Hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return hash
    }

    private func restorePhysicsBody() {
        if physicsBody == nil {
            setupPhysicsBody()
            return
        }
        physicsBody?.categoryBitMask    = PhysicsCategory.agent
        physicsBody?.contactTestBitMask = PhysicsCategory.projectile | PhysicsCategory.melee | PhysicsCategory.trap
        physicsBody?.collisionBitMask   = PhysicsCategory.structure
    }

    private func applyDeadStateForRestore() {
        restorePhysicsBody()
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        alpha = 0.3
        targetPosition = nil
        currentAction = .idle
        if respawnTimer <= 0 {
            respawnTimer = EconomyConfig.shared.respawnTime
        }
        // Stop brain for restored dead agents too
        brain?.stop()
    }

    private func appendChatMessage(_ speaker: ChatSpeakerRole, text: String) {
        chatMessages.append(
            ChatMessageEntry(
                speaker: speaker,
                text: text,
                timestamp: Date().timeIntervalSince1970
            )
        )

        if chatMessages.count > 40 {
            chatMessages.removeFirst(chatMessages.count - 40)
        }
    }

    private func persistMutation(
        reason: String,
        category: WorldEventCategory,
        title: String,
        message: String
    ) {
        IncrementalArchiveStore.shared.recordAgent(self, reason: reason)
        WorldEventLogStore.shared.append(
            category: category,
            entityID: entityID,
            title: title,
            message: message,
            metadata: [
                "agent": displayName,
                "modelConfigID": representedModelConfigID.uuidString,
            ]
        )
    }

    var respawnRemaining: TimeInterval {
        respawnTimer
    }
}
