//
//  CameraController.swift
//  Stars
//

import SpriteKit

final class CameraController {
    let cameraNode: SKCameraNode
    private(set) var currentScale: CGFloat = 1.35

    static let minScale: CGFloat = 0.95
    static let maxScale: CGFloat = 1.85

    init() {
        cameraNode = SKCameraNode()
        cameraNode.setScale(currentScale)
    }

    var position: CGPoint {
        cameraNode.position
    }

    func handlePan(translation: CGPoint) {
        cameraNode.position.x -= translation.x * currentScale
        cameraNode.position.y += translation.y * currentScale
    }

    func handlePinch(gestureScale: CGFloat) {
        let newScale = currentScale / gestureScale
        currentScale = max(Self.minScale, min(newScale, Self.maxScale))
        cameraNode.setScale(currentScale)
    }

    func restore(position: CGPoint, scale: CGFloat) {
        cameraNode.position = position
        currentScale = max(Self.minScale, min(scale, Self.maxScale))
        cameraNode.setScale(currentScale)
    }

    var chunkX: Int {
        Int(floor(cameraNode.position.x / Chunk.worldSize))
    }

    var chunkY: Int {
        Int(floor(cameraNode.position.y / Chunk.worldSize))
    }
}
