//
//  ModelManager.swift
//  Stars
//

import Foundation

extension Notification.Name {
    static let modelConfigsDidChange = Notification.Name("stars.modelConfigsDidChange")
}

final class ModelManager {
    static let shared = ModelManager()

    private(set) var configs: [ModelConfig] = []

    private let storageKey = "stars.model.configs"
    private let apiKeyPrefix = "stars.apikey."

    private init() {
        load()
    }

    // MARK: - CRUD

    func addConfig(_ config: ModelConfig, apiKey: String) {
        configs.append(config)
        KeychainHelper.shared.save(apiKey, for: keychainKey(config.id))
        save()
        WorldEventLogStore.shared.append(
            category: .model,
            entityID: config.id.uuidString,
            title: "新增模型配置",
            message: "已添加 \(config.alias)（\(config.provider.displayName) / \(config.modelName)）。"
        )
        notifyConfigsChanged()
    }

    func updateConfig(_ config: ModelConfig, apiKey: String? = nil) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[index] = config
        if let apiKey, !apiKey.isEmpty {
            KeychainHelper.shared.save(apiKey, for: keychainKey(config.id))
        }
        save()
        WorldEventLogStore.shared.append(
            category: .model,
            entityID: config.id.uuidString,
            title: "更新模型配置",
            message: "已更新 \(config.alias)（\(config.provider.displayName) / \(config.modelName)）。"
        )
        notifyConfigsChanged()
    }

    func updateConnectionState(id: UUID, status: ModelConnectionStatus, message: String?) {
        guard let index = configs.firstIndex(where: { $0.id == id }) else { return }
        guard configs[index].connectionStatus != status || configs[index].connectionMessage != message else { return }
        configs[index].connectionStatus = status
        configs[index].connectionMessage = message
        save()
        WorldEventLogStore.shared.append(
            category: .model,
            entityID: id.uuidString,
            title: "连接状态变更",
            message: "模型连接状态已更新为 \(status.displayText)。\(message ?? "")"
        )
        notifyConfigsChanged()
    }

    func deleteConfig(id: UUID) {
        let removed = configs.first { $0.id == id }
        configs.removeAll { $0.id == id }
        KeychainHelper.shared.delete(for: keychainKey(id))
        save()
        WorldEventLogStore.shared.append(
            category: .model,
            entityID: id.uuidString,
            title: "删除模型配置",
            message: "已删除 \(removed?.alias ?? "未知模型")。"
        )
        notifyConfigsChanged()
    }

    func apiKey(for configID: UUID) -> String? {
        // Official providers: always use bundled config (fresh keys survive app updates)
        if let config = config(for: configID), config.provider.isOfficialProvider {
            let key = OfficialProviderConfig.apiKey(for: config.provider)
            return key.isEmpty ? nil : key
        }
        return KeychainHelper.shared.read(for: keychainKey(configID))
    }

    func config(for id: UUID) -> ModelConfig? {
        configs.first { $0.id == id }
    }

    // MARK: - Persistence (non-sensitive data in UserDefaults)

    private func save() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([ModelConfig].self, from: data)
        else { return }
        configs = loaded
    }

    private func keychainKey(_ id: UUID) -> String {
        apiKeyPrefix + id.uuidString
    }

    private func notifyConfigsChanged() {
        NotificationCenter.default.post(name: .modelConfigsDidChange, object: nil)
    }
}
