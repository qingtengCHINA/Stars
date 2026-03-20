//
//  SceneDelegate.swift
//  Stars
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func sceneWillResignActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: .starsPersistWorldState, object: nil)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .starsPersistWorldState, object: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        NotificationCenter.default.post(name: .starsPersistWorldState, object: nil)
    }
}
