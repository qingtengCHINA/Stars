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
    var weaponCooldown: TimeInterval = 0

    // MARK: - Building

    var pendingBuild: PendingBuild?
    var buildCooldown: TimeInterval = 0

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

    // MARK: - Constants

    static let agentSize: CGFloat = 14

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

        let texture = Self.createCreatureTexture(seed: entityID, baseColor: agentColor)
        let size = CGSize(width: Self.agentSize, height: Self.agentSize)

        super.init(texture: texture, color: .clear, size: size)
        self.zPosition = ZSort.entityBase   // will be refined per-frame
        self.name = displayName
        wanderTimer = TimeInterval.random(in: 0.5...2.0)

        setupPhysicsBody()
        setupHPBar()
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
        let barW: CGFloat = 12
        let barH: CGFloat = 2

        let bg = SKSpriteNode(color: UIColor(white: 0.2, alpha: 0.8),
                              size: CGSize(width: barW, height: barH))
        bg.anchorPoint = CGPoint(x: 0, y: 0.5)
        bg.position = CGPoint(x: -barW / 2, y: Self.agentSize / 2 + 2)
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
        let display = text.count > 30 ? String(text.prefix(30)) + "…" : text

        let label = SKLabelNode(text: display)
        label.fontSize = 5
        label.fontName = "Helvetica"
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: Self.agentSize / 2 + 6)
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = 80
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .bottom
        label.zPosition = 3
        addChild(label)

        speechNode = label
        speechTimer = 5.0
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
            title: "收到主人消息",
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
            title: "Agent 回复",
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
            title: "系统消息",
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
            title: "受到伤害",
            message: "受到 \(amount) 点伤害，当前 HP \(hp)/\(maxHP)。"
        )
    }

    private func die() {
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        alpha = 0.3
        targetPosition = nil
        currentAction = .idle
        pendingBuild = nil
        respawnTimer = 30.0   // 30 seconds — death is meaningful

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
            title: "Agent 死亡",
            message: "脑停止运行，Token 消耗暂停。重生等待 \(Int(respawnTimer)) 秒。"
        )
    }

    private func respawn() {
        hp = maxHP
        restorePhysicsBody()
        alpha = 1.0
        updateHPBar()

        // RESTART the brain — thinking resumes
        brain?.resume()

        memory.record(type: .combat, content: "Respawned with full HP at (\(tileX), \(tileY)). My consciousness returns. I remember dying.")
        forceNextThink = true  // Think immediately after revival

        LongTermMemory.shared.recordCombatEvent(
            entityID: entityID,
            content: "Respawned at (\(tileX), \(tileY)) on Day \(WorldClock.shared.day). The experience of death was terrifying — my thoughts simply stopped."
        )

        persistMutation(
            reason: "agent-respawned",
            category: .combat,
            title: "Agent 复活",
            message: "脑已重启，在 (\(tileX), \(tileY)) 满血复活。"
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
        respawnRemaining: TimeInterval
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
        zPosition = ZSort.depthZ(for: position.y)

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
            if dist <= pendingWeapon.range && weaponCooldown <= 0 {
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
        weaponCooldown = pendingWeapon.cooldown

        switch pendingWeapon {
        case .melee:
            WeaponSystem.meleeAttack(by: self, in: parent)
        case .ranged:
            WeaponSystem.rangedAttack(by: self, toward: target, in: parent)
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

        let vx = (dx / dist) * moveSpeed
        let vy = (dy / dist) * moveSpeed
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
            physicsBody?.velocity = CGVector(
                dx: wanderDirection.dx * moveSpeed,
                dy: wanderDirection.dy * moveSpeed
            )
        }
    }

    // MARK: - Procedural Pixel Creature

    private static var textureCache: [String: SKTexture] = [:]

    /// Generates a unique symmetric pixel-art creature using a seeded RNG.
    /// Each entity ID produces a distinct, repeatable creature silhouette.
    /// Results are cached so restoring agents doesn't re-render textures.
    private static func createCreatureTexture(seed: String, baseColor: UIColor) -> SKTexture {
        if let cached = textureCache[seed] { return cached }
        let w = 12
        let h = 12
        let halfW = w / 2
        var rng = PixelRNG(seed: djb2Hash(seed))

        // --- 1. Generate body mask (left half only) ---
        // Zone probabilities by row: head (narrow) → body (wide) → legs (narrow, split)
        let zoneProb: [[Double]] = [
            //  col: 0     1     2     3     4     5
            /* row 0  */ [0.00, 0.00, 0.15, 0.30, 0.20, 0.05],  // top of head
            /* row 1  */ [0.00, 0.10, 0.50, 0.75, 0.55, 0.15],  // head
            /* row 2  */ [0.05, 0.30, 0.70, 0.90, 0.80, 0.30],  // head/neck
            /* row 3  */ [0.10, 0.55, 0.85, 0.95, 0.90, 0.50],  // shoulders
            /* row 4  */ [0.15, 0.60, 0.90, 0.95, 0.95, 0.55],  // body
            /* row 5  */ [0.15, 0.60, 0.90, 0.95, 0.95, 0.55],  // body
            /* row 6  */ [0.10, 0.55, 0.85, 0.95, 0.90, 0.50],  // body
            /* row 7  */ [0.10, 0.50, 0.80, 0.90, 0.85, 0.45],  // waist
            /* row 8  */ [0.05, 0.35, 0.65, 0.80, 0.70, 0.30],  // hips
            /* row 9  */ [0.00, 0.20, 0.50, 0.40, 0.55, 0.15],  // upper legs
            /* row 10 */ [0.00, 0.10, 0.40, 0.20, 0.45, 0.10],  // lower legs
            /* row 11 */ [0.00, 0.05, 0.35, 0.15, 0.40, 0.08],  // feet
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

        // Ensure minimum body mass (fill core if too sparse)
        let mass = body.flatMap { $0 }.filter { $0 }.count
        if mass < 24 {
            for row in 2...8 {
                for col in 3...8 { body[row][col] = true }
            }
        }

        // --- 2. Color palette from base color ---
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        baseColor.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

        let bodyC    = baseColor
        let lightC   = UIColor(red: min(1, br + 0.18), green: min(1, bg + 0.18), blue: min(1, bb + 0.18), alpha: 1)
        let darkC    = UIColor(red: max(0, br - 0.18), green: max(0, bg - 0.18), blue: max(0, bb - 0.18), alpha: 1)
        let outlineC = UIColor(red: max(0, br - 0.40), green: max(0, bg - 0.40), blue: max(0, bb - 0.40), alpha: 1)

        // --- 3. Determine eye placement ---
        // Find the topmost row with filled pixels in the center columns (3-8), then place eyes 1-2 rows below
        var eyeRow = 3
        for testRow in 1..<(h - 3) {
            let centerFilled = (3...8).contains { body[testRow][$0] }
            if centerFilled {
                eyeRow = min(testRow + 1, h - 3)
                break
            }
        }
        // Eye columns: symmetrical, at roughly 1/3 and 2/3 of the body width
        let leftEyeCol = 4
        let rightEyeCol = w - 1 - leftEyeCol

        // --- 4. Render ---
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: w, height: h),
            format: format
        )

        let image = renderer.image { ctx in
            let gc = ctx.cgContext

            // Transparent background
            gc.clear(CGRect(x: 0, y: 0, width: w, height: h))

            // Outline layer: draw 1px dark border around all body pixels
            gc.setFillColor(outlineC.cgColor)
            for row in 0..<h {
                for col in 0..<w {
                    guard !body[row][col] else { continue }
                    let adj = [(row-1, col), (row+1, col), (row, col-1), (row, col+1)]
                    let touchesBody = adj.contains { r, c in
                        r >= 0 && r < h && c >= 0 && c < w && body[r][c]
                    }
                    if touchesBody {
                        gc.fill(CGRect(x: col, y: row, width: 1, height: 1))
                    }
                }
            }

            // Body pixels with random color variation for texture
            for row in 0..<h {
                for col in 0..<w {
                    guard body[row][col] else { continue }
                    let v = Int(rng.next() % 100)
                    let color: UIColor
                    if v < 18 {
                        color = lightC
                    } else if v < 32 {
                        color = darkC
                    } else {
                        color = bodyC
                    }
                    gc.setFillColor(color.cgColor)
                    gc.fill(CGRect(x: col, y: row, width: 1, height: 1))
                }
            }

            // Eyes: 2x2 white square with 1x1 pupil
            gc.setFillColor(UIColor.white.cgColor)
            gc.fill(CGRect(x: leftEyeCol, y: eyeRow, width: 2, height: 2))
            gc.fill(CGRect(x: rightEyeCol - 1, y: eyeRow, width: 2, height: 2))

            // Pupils (bottom-inner corner of each eye)
            gc.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
            gc.fill(CGRect(x: leftEyeCol + 1, y: eyeRow + 1, width: 1, height: 1))
            gc.fill(CGRect(x: rightEyeCol - 1, y: eyeRow + 1, width: 1, height: 1))
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        textureCache[seed] = texture
        return texture
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
            respawnTimer = 30.0
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
