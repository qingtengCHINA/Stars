//
//  AppDelegate.swift
//  Stars
//
//  Created by QingTeng on 2026/3/19.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Seed built-in agent from .env on first launch
        BuiltInAgent.seedIfNeeded()

        // Authenticate Game Center
        GameCenterManager.shared.authenticate()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        configuration.storyboard = UIStoryboard(name: "Main", bundle: nil)
        return configuration
    }

    func applicationWillTerminate(_ application: UIApplication) {
        NotificationCenter.default.post(name: .starsPersistWorldState, object: nil)
    }
}
