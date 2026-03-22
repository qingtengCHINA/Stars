//
//  WeatherEffectNode.swift
//  Stars
//
//  A SpriteKit node that renders subtle pixel-art weather effects
//  (rain, snow, thunder, fog) as an overlay on the game scene.
//

import SpriteKit

final class WeatherEffectNode: SKNode {

    private var currentEffect: WeatherManager.WeatherEffect = .clear
    private var emitterNodes: [SKEmitterNode] = []
    private var fogNode: SKSpriteNode?
    private var thunderAction: SKAction?

    // MARK: - Public API

    func updateEffect(_ effect: WeatherManager.WeatherEffect, sceneSize: CGSize) {
        guard effect != currentEffect else { return }
        currentEffect = effect
        removeAllEffects()

        switch effect {
        case .clear:
            break
        case .rain:
            addRainEffect(sceneSize: sceneSize, density: 0.4)
        case .heavyRain:
            addRainEffect(sceneSize: sceneSize, density: 0.8)
        case .snow:
            addSnowEffect(sceneSize: sceneSize)
        case .thunderstorm:
            addRainEffect(sceneSize: sceneSize, density: 0.6)
            addThunderEffect(sceneSize: sceneSize)
        case .fog:
            addFogEffect(sceneSize: sceneSize)
        }
    }

    // MARK: - Rain

    private func addRainEffect(sceneSize: CGSize, density: CGFloat) {
        let emitter = SKEmitterNode()

        // Small 2×6 pixel raindrop, blue-tinted white
        let texture = makePixelTexture(
            width: 2, height: 6,
            color: UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        )
        emitter.particleTexture = texture

        // Birth rate scales with density
        emitter.particleBirthRate = density * 200

        // Lifetime
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5

        // Speed — fast downward fall
        emitter.particleSpeed = 400
        emitter.particleSpeedRange = 100

        // Angle — roughly downward with a slight slant (~260°, i.e. slightly left)
        emitter.emissionAngle = .pi * 1.444   // ~260°
        emitter.emissionAngleRange = .pi * 0.03

        // Alpha — subtle
        emitter.particleAlpha = 0.35
        emitter.particleAlphaRange = 0.15

        // Scale
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.2

        // Emitter position — top edge, spanning full width
        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 20)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width + 80, dy: 0)

        // Blend mode
        emitter.particleBlendMode = .alpha

        addChild(emitter)
        emitterNodes.append(emitter)
    }

    // MARK: - Snow

    private func addSnowEffect(sceneSize: CGSize) {
        let emitter = SKEmitterNode()

        // Small 3×3 pixel snowflake
        let texture = makePixelTexture(
            width: 3, height: 3,
            color: UIColor.white
        )
        emitter.particleTexture = texture

        emitter.particleBirthRate = 80

        // Longer lifetime — snow falls slowly
        emitter.particleLifetime = 4.0
        emitter.particleLifetimeRange = 1.0

        // Slower speed
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 50

        // Downward with slight drift
        emitter.emissionAngle = .pi * 1.5  // 270° straight down
        emitter.emissionAngleRange = .pi * 0.15

        // Alpha
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.1

        // Scale
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.4

        // Emitter position — top edge
        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 20)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width + 80, dy: 0)

        // Blend mode
        emitter.particleBlendMode = .alpha

        addChild(emitter)
        emitterNodes.append(emitter)
    }

    // MARK: - Thunder

    private func addThunderEffect(sceneSize: CGSize) {
        let flashNode = SKSpriteNode(color: .white, size: sceneSize)
        flashNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        flashNode.position = .zero
        flashNode.alpha = 0
        flashNode.zPosition = 1  // above rain particles within this node
        addChild(flashNode)

        // Random flash sequence: fade in, hold, fade out, wait random interval
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 0.05),
            SKAction.wait(forDuration: 0.1),
            SKAction.fadeAlpha(to: 0, duration: 0.15),
            SKAction.wait(forDuration: TimeInterval.random(in: 5...15))
        ])
        let repeatFlash = SKAction.repeatForever(flash)
        flashNode.run(repeatFlash, withKey: "thunder")
    }

    // MARK: - Fog

    private func addFogEffect(sceneSize: CGSize) {
        let fog = SKSpriteNode(
            color: UIColor(white: 0.6, alpha: 1.0),
            size: CGSize(width: sceneSize.width + 40, height: sceneSize.height + 40)
        )
        fog.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        fog.position = .zero
        fog.alpha = 0.12
        fog.blendMode = .alpha

        // Subtle horizontal drift
        let drift = SKAction.sequence([
            SKAction.moveBy(x: 15, y: 0, duration: 6),
            SKAction.moveBy(x: -15, y: 0, duration: 6)
        ])
        fog.run(SKAction.repeatForever(drift))

        // Gentle alpha breathing
        let breathe = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 4),
            SKAction.fadeAlpha(to: 0.10, duration: 4)
        ])
        fog.run(SKAction.repeatForever(breathe))

        addChild(fog)
        fogNode = fog
    }

    // MARK: - Cleanup

    private func removeAllEffects() {
        for emitter in emitterNodes {
            emitter.removeFromParent()
        }
        emitterNodes.removeAll()

        fogNode?.removeFromParent()
        fogNode = nil

        // Remove any thunder flash children
        children.filter { $0.action(forKey: "thunder") != nil }.forEach {
            $0.removeFromParent()
        }
    }

    // MARK: - Pixel Texture Helper

    private func makePixelTexture(width: Int, height: Int, color: UIColor) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}
