//
//  ModelEditViewController.swift
//  Stars
//
//  Provider-specific configuration form.
//  Presented as a modal sheet with dark theme.
//

import UIKit
import SafariServices

final class ModelEditViewController: UIViewController {

    enum Mode {
        case add(APIProvider)
        case edit(ModelConfig)

        var provider: APIProvider {
            switch self {
            case .add(let p):  return p
            case .edit(let c): return c.provider
            }
        }

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    // MARK: - Properties

    private let mode: Mode

    private let aliasField     = UITextField()
    private let apiKeyField    = UITextField()
    private let baseURLField   = UITextField()
    private let modelNameField = UITextField()
    private let v1Toggle       = UISwitch()
    private let connectionDotView = UIView()
    private let connectionStatusLabel = UILabel()
    private let connectionSpinner = UIActivityIndicatorView(style: .medium)
    private let testConnectionButton = UIButton(type: .system)
    private let fetchModelsButton = UIButton(type: .system)
    private let selectModelButton = UIButton(type: .system)

    // SOUL fields (edit mode only)
    private let personalityTextView = UITextView()
    private let beliefsTextView = UITextView()
    private let goalsTextView = UITextView()
    private let journalTextView = UITextView()
    private let memoryCountLabel = UILabel()

    private var scrollView: UIScrollView!
    private var fetchedModels: [String] = []
    private var pendingConnectionStatus: ModelConnectionStatus = .unknown
    private var pendingConnectionMessage = "尚未测试连接。"
    private var providerDefinition: ProviderDefinition { mode.provider.definition }
    private var usesStaticCatalog: Bool {
        if case .staticCatalog = providerDefinition.modelCatalogMode {
            return true
        }
        return false
    }

    // MARK: - Init

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = PixelTheme.bgDark
        preferredContentSize = CGSize(width: 760, height: 560)
        fetchedModels = providerDefinition.catalogModels

        if case .edit(let config) = mode {
            title = "Agent 设置 · \(config.alias)"
        } else {
            title = "添加 \(mode.provider.displayName)"
        }

        setupNavBar()
        setupForm()
        prefillForEditMode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Navigation Bar

    private func setupNavBar() {
        if let navBar = navigationController?.navigationBar {
            PixelTheme.styleNavBar(navBar)
        }

        // "← 返回" pixel button
        var btnConfig = UIButton.Configuration.filled()
        btnConfig.title = "← 返回"
        btnConfig.baseForegroundColor = PixelTheme.textCream
        btnConfig.baseBackgroundColor = PixelTheme.bgLight
        btnConfig.cornerStyle = .fixed
        btnConfig.background.cornerRadius = PixelTheme.cornerRadius
        btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        btnConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attr = incoming
            attr.font = PixelTheme.boldFont(size: 13)
            return attr
        }
        let backButton = UIButton(configuration: btnConfig)
        backButton.layer.borderWidth = PixelTheme.borderWidth
        backButton.layer.borderColor = PixelTheme.borderWarm.cgColor
        backButton.layer.cornerRadius = PixelTheme.cornerRadius
        backButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "📖 文档",
            style: .plain,
            target: self,
            action: #selector(openProviderDocs)
        )
    }

    // MARK: - Form Setup

    private func setupForm() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        let provider = mode.provider

        stack.addArrangedSubview(makeProviderInfoCard())
        stack.addArrangedSubview(makeSpacer(14))

        // ── 标签 ──
        stack.addArrangedSubview(makeSectionTitle("标签"))
        aliasField.autocapitalizationType = .words
        stack.addArrangedSubview(makeCardField(aliasField, placeholder: "AI 服务商名称"))
        stack.addArrangedSubview(makeSpacer(12))

        // ── API Key ──
        stack.addArrangedSubview(makeSectionTitle("API Key"))
        apiKeyField.isSecureTextEntry = true
        apiKeyField.autocapitalizationType = .none
        apiKeyField.autocorrectionType = .no

        let eyeButton = UIButton(type: .system)
        eyeButton.setImage(UIImage(systemName: "eye"), for: .normal)
        eyeButton.tintColor = PixelTheme.textTan
        eyeButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        eyeButton.addTarget(self, action: #selector(toggleApiKeyVisibility(_:)), for: .touchUpInside)
        apiKeyField.rightView = eyeButton
        apiKeyField.rightViewMode = .always

        stack.addArrangedSubview(makeCardField(apiKeyField, placeholder: provider.apiKeyPlaceholder))
        stack.addArrangedSubview(makeHint("您的密钥安全存储在 iOS 钥匙串中，不会离开设备。"))
        stack.addArrangedSubview(makeSpacer(8))

        // ── 自定义 API 地址（可选）──
        stack.addArrangedSubview(makeSectionTitle("自定义 API 地址（可选）"))

        baseURLField.keyboardType = .URL
        baseURLField.autocapitalizationType = .none
        baseURLField.autocorrectionType = .no

        v1Toggle.isOn = provider.defaultAppendV1
        v1Toggle.onTintColor = .systemGreen

        stack.addArrangedSubview(
            makeURLCard(field: baseURLField,
                        placeholder: providerBaseURLPlaceholder(),
                        toggle: v1Toggle)
        )
        stack.addArrangedSubview(
            makeHint(providerBaseURLHint())
        )
        stack.addArrangedSubview(makeSpacer(6))
        stack.addArrangedSubview(makeConnectionStatusCard())
        stack.addArrangedSubview(makeSpacer(8))
        stack.addArrangedSubview(makeUtilityButtonsRow())
        stack.addArrangedSubview(makeSpacer(8))

        // ── 模型名称 ──
        stack.addArrangedSubview(makeSectionTitle("模型名称"))
        modelNameField.autocapitalizationType = .none
        modelNameField.autocorrectionType = .no
        modelNameField.text = provider.defaultModel
        stack.addArrangedSubview(makeCardField(modelNameField, placeholder: provider.defaultModel))
        stack.addArrangedSubview(makeHint("用于 API 请求的模型标识符。支持直接输入自定义模型名。"))
        selectModelButton.setTitle(usesStaticCatalog ? "📋 从内置目录中选择模型" : "📋 从拉取结果中选择模型", for: .normal)
        selectModelButton.titleLabel?.font = PixelTheme.boldFont(size: 12)
        selectModelButton.setTitleColor(PixelTheme.textCream, for: .normal)
        selectModelButton.backgroundColor = PixelTheme.bgMedium
        selectModelButton.layer.cornerRadius = PixelTheme.cornerRadius
        selectModelButton.layer.borderWidth = PixelTheme.borderWidth
        selectModelButton.layer.borderColor = PixelTheme.borderWarm.cgColor
        selectModelButton.translatesAutoresizingMaskIntoConstraints = false
        selectModelButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        selectModelButton.addTarget(self, action: #selector(selectFetchedModel), for: .touchUpInside)
        selectModelButton.isEnabled = !fetchedModels.isEmpty
        selectModelButton.alpha = fetchedModels.isEmpty ? 0.45 : 1.0
        stack.addArrangedSubview(selectModelButton)
        stack.addArrangedSubview(makeSpacer(24))

        // ── SOUL 配置 (edit mode only) ──
        if mode.isEdit {
            stack.addArrangedSubview(makeSectionTitle("SOUL — 人格"))
            stack.addArrangedSubview(makeTextViewCard(personalityTextView, height: 50))
            stack.addArrangedSubview(makeHint("Agent 的性格特质与行为倾向。"))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle("SOUL — 信念"))
            stack.addArrangedSubview(makeTextViewCard(beliefsTextView, height: 50))
            stack.addArrangedSubview(makeHint("Agent 的价值观与世界观。"))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle("SOUL — 目标"))
            stack.addArrangedSubview(makeTextViewCard(goalsTextView, height: 50))
            stack.addArrangedSubview(makeHint("Agent 当前正在追求的目标。"))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle("SOUL — 日志"))
            stack.addArrangedSubview(makeTextViewCard(journalTextView, height: 60))
            stack.addArrangedSubview(makeHint("Agent 对近期事件的反思与总结。"))
            stack.addArrangedSubview(makeSpacer(12))

            // ── Memory Info ──
            stack.addArrangedSubview(makeSectionTitle("记忆"))
            stack.addArrangedSubview(makeMemoryInfoCard())
            stack.addArrangedSubview(makeSpacer(24))
        }

        // ── Submit Button ──
        let submitButton = makeActionButton(
            title: mode.isEdit ? "保存修改" : "添加 AI 服务商",
            color: UIColor(white: 0.55, alpha: 1)
        )
        submitButton.addTarget(self, action: #selector(saveModel), for: .touchUpInside)
        stack.addArrangedSubview(submitButton)

        // ── Delete Button (edit mode) ──
        if mode.isEdit {
            stack.addArrangedSubview(makeSpacer(12))
            let deleteButton = makeActionButton(title: "删除此配置", color: .systemRed)
            deleteButton.addTarget(self, action: #selector(deleteModel), for: .touchUpInside)
            stack.addArrangedSubview(deleteButton)
        }
    }

    private func prefillForEditMode() {
        guard case .edit(let config) = mode else {
            configureProviderSpecificURLBehavior()
            updateConnectionStatusUI()
            return
        }
        aliasField.text = config.alias
        apiKeyField.text = ModelManager.shared.apiKey(for: config.id)
        baseURLField.text = config.baseURL
        modelNameField.text = config.modelName
        v1Toggle.isOn = resolvedAppendV1Value(for: config)
        pendingConnectionStatus = config.connectionStatus
        pendingConnectionMessage = config.connectionMessage ?? config.connectionStatus.displayText
        configureProviderSpecificURLBehavior()
        updateConnectionStatusUI()

        // Load SOUL data for this agent
        let soul = SoulStore.shared.soul(for: config.id.uuidString)
        personalityTextView.text = soul.personality
        beliefsTextView.text = soul.beliefs
        goalsTextView.text = soul.goals
        journalTextView.text = soul.journal

        // Update memory info
        let ltmCount = LongTermMemory.shared.entries(for: config.id.uuidString).count
        memoryCountLabel.text = "长期记忆: \(ltmCount) 条"
    }

    // MARK: - UI Builders

    private func makeProviderInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = PixelTheme.headerFont(size: 15)
        title.textColor = PixelTheme.textCream
        title.text = providerDefinition.selectionTitle

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = PixelTheme.bodyFont(size: 11)
        subtitle.textColor = PixelTheme.textTan
        subtitle.numberOfLines = 0
        subtitle.text = providerDefinition.selectionSubtitle

        let stack = UIStackView(arrangedSubviews: [
            makeMetaPill("协议", value: providerDefinition.protocolLabel),
            makeMetaPill("鉴权", value: providerDefinition.authLabel),
            makeMetaPill("模型", value: providerDefinition.modelSourceLabel),
            makeMetaPill("上下文", value: "\(providerDefinition.contextWindowTokens.formatted()) tokens"),
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8

        card.addSubview(title)
        card.addSubview(subtitle)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor),

            stack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    private func makeMetaPill(_ key: String, value: String) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = PixelTheme.bodyFont(size: 11)
        label.textColor = PixelTheme.textCream
        label.text = "\(key): \(value)"

        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = PixelTheme.bgLight
        background.layer.cornerRadius = PixelTheme.cornerRadius
        background.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
        ])
        return background
    }

    private func makeSectionTitle(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = PixelTheme.fontSection
        label.textColor = PixelTheme.textGold
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }

    private func providerBaseURLPlaceholder() -> String {
        providerDefinition.defaultBaseURL.isEmpty ? "根据官方文档填写 base URL" : providerDefinition.defaultBaseURL
    }

    private func providerBaseURLHint() -> String {
        if mode.provider == .minimax {
            return "MiniMax Anthropic 兼容层默认使用 /anthropic/v1/messages。建议留空使用默认值，或填写到 /anthropic/v1 为止。"
        }
        if providerDefinition.protocolFamily == .anthropicMessages {
            if providerDefinition.defaultBaseURL.isEmpty {
                return "该服务商使用 Anthropic Messages 协议，请参考文档填写 base URL（需包含 /v1）。不要填写 /messages 这类具体接口路径。"
            }
            return "留空则使用默认端点。若自定义，请填写到 /v1 为止（如 https://your-host/v1），不要填写 /messages。"
        }
        if providerDefinition.defaultBaseURL.isEmpty {
            return "该服务商没有通用默认入口，需参考官方文档填写你的专属 base URL。只填主机地址，不要填写 /chat/completions、/models。"
        }
        return "留空则使用默认端点。建议只填主机地址，启用「自动附加 /v1」后会自动拼接。不要填写 /chat/completions、/models 这类接口路径。"
    }

    private func makeCardField(_ field: UITextField, placeholder: String) -> UIView {
        field.placeholder = placeholder
        field.borderStyle = .none
        field.font = PixelTheme.bodyFont(size: 14)
        field.textColor = PixelTheme.textCream
        field.backgroundColor = .clear
        field.tintColor = PixelTheme.accentAmber

        let leftPad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.leftView = leftPad
        field.leftViewMode = .always
        if field.rightView == nil {
            let rightPad = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
            field.rightView = rightPad
            field.rightViewMode = .always
        }

        let card = UIView()
        card.backgroundColor = PixelTheme.bgInput
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderDark.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        field.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(field)

        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: card.topAnchor),
            field.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            field.heightAnchor.constraint(equalToConstant: 48),
            field.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        return card
    }

    /// Card containing a URL text field + separator + "/v1" toggle row.
    private func makeURLCard(field: UITextField, placeholder: String,
                             toggle: UISwitch) -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgInput
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderDark.cgColor
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // URL field
        field.placeholder = placeholder
        field.borderStyle = .none
        field.font = PixelTheme.bodyFont(size: 14)
        field.textColor = PixelTheme.textCream
        field.backgroundColor = .clear
        field.tintColor = PixelTheme.accentAmber
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.rightViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let separator = UIView()
        separator.backgroundColor = PixelTheme.borderWarm
        separator.translatesAutoresizingMaskIntoConstraints = false

        // Toggle row
        let toggleLabel = UILabel()
        if providerDefinition.protocolFamily == .anthropicMessages {
            toggleLabel.text = "Anthropic 格式无需附加 \"/v1\""
        } else {
            toggleLabel.text = "自动附加 \"/v1\""
        }
        toggleLabel.font = PixelTheme.bodyFont(size: 13)
        toggleLabel.textColor = PixelTheme.textCream
        toggleLabel.translatesAutoresizingMaskIntoConstraints = false

        toggle.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(field)
        card.addSubview(separator)
        card.addSubview(toggleLabel)
        card.addSubview(toggle)

        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: card.topAnchor),
            field.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            field.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            field.heightAnchor.constraint(equalToConstant: 48),

            separator.topAnchor.constraint(equalTo: field.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            toggleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            toggleLabel.centerYAnchor.constraint(equalTo: toggle.centerYAnchor),

            toggle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            toggle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])

        return card
    }

    private func configureProviderSpecificURLBehavior() {
        if providerDefinition.protocolFamily == .anthropicMessages {
            // Anthropic protocol bakes /v1 into the base URL; no toggle needed.
            v1Toggle.isOn = false
            v1Toggle.isEnabled = false
            v1Toggle.alpha = 0.5
        } else {
            v1Toggle.isEnabled = true
            v1Toggle.alpha = 1.0
        }
    }

    private func resolvedAppendV1Value(for config: ModelConfig) -> Bool {
        if config.provider.definition.protocolFamily == .anthropicMessages {
            return false
        }
        return config.appendV1
    }

    private func makeHint(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = PixelTheme.bodyFont(size: 10)
        label.textColor = PixelTheme.textMuted
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
        ])
        return container
    }

    private func makeTextViewCard(_ textView: UITextView, height: CGFloat) -> UIView {
        textView.backgroundColor = .clear
        textView.font = PixelTheme.bodyFont(size: 13)
        textView.textColor = PixelTheme.textCream
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        textView.isScrollEnabled = false
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.tintColor = PixelTheme.accentAmber
        textView.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = PixelTheme.bgInput
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderDark.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: card.topAnchor),
            textView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: height),
        ])
        return card
    }

    private func makeMemoryInfoCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        memoryCountLabel.font = PixelTheme.bodyFont(size: 13)
        memoryCountLabel.textColor = PixelTheme.textTan
        memoryCountLabel.text = "📚 长期记忆: 0 条"
        memoryCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("🗑️ 清除记忆", for: .normal)
        clearButton.titleLabel?.font = PixelTheme.bodyFont(size: 12)
        clearButton.tintColor = PixelTheme.accentRed
        clearButton.addTarget(self, action: #selector(clearMemory), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(memoryCountLabel)
        card.addSubview(clearButton)

        NSLayoutConstraint.activate([
            memoryCountLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            memoryCountLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            memoryCountLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            clearButton.centerYAnchor.constraint(equalTo: memoryCountLabel.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])
        return card
    }

    private func makeSpacer(_ height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func makeActionButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = PixelTheme.headerFont(size: 16)
        button.setTitleColor(color, for: .normal)
        button.backgroundColor = PixelTheme.bgMedium
        button.layer.cornerRadius = PixelTheme.cornerRadius
        button.layer.borderWidth = PixelTheme.borderWidth
        button.layer.borderColor = PixelTheme.borderWarm.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    private func makeConnectionStatusCard() -> UIView {
        let card = UIView()
        card.backgroundColor = PixelTheme.bgMedium
        card.layer.cornerRadius = PixelTheme.cornerRadius
        card.layer.borderWidth = PixelTheme.borderWidth
        card.layer.borderColor = PixelTheme.borderWarm.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        connectionDotView.translatesAutoresizingMaskIntoConstraints = false
        connectionDotView.layer.cornerRadius = 6

        connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionStatusLabel.font = PixelTheme.bodyFont(size: 12)
        connectionStatusLabel.textColor = PixelTheme.textCream
        connectionStatusLabel.numberOfLines = 0

        connectionSpinner.translatesAutoresizingMaskIntoConstraints = false
        connectionSpinner.hidesWhenStopped = true
        connectionSpinner.color = PixelTheme.accentAmber

        card.addSubview(connectionDotView)
        card.addSubview(connectionStatusLabel)
        card.addSubview(connectionSpinner)

        NSLayoutConstraint.activate([
            connectionDotView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            connectionDotView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            connectionDotView.widthAnchor.constraint(equalToConstant: 12),
            connectionDotView.heightAnchor.constraint(equalToConstant: 12),

            connectionStatusLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            connectionStatusLabel.leadingAnchor.constraint(equalTo: connectionDotView.trailingAnchor, constant: 12),
            connectionStatusLabel.trailingAnchor.constraint(equalTo: connectionSpinner.leadingAnchor, constant: -12),
            connectionStatusLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            connectionSpinner.centerYAnchor.constraint(equalTo: connectionDotView.centerYAnchor),
            connectionSpinner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        ])

        updateConnectionStatusUI()
        return card
    }

    private func makeUtilityButtonsRow() -> UIView {
        testConnectionButton.setTitle("🔌 测试连接", for: .normal)
        testConnectionButton.titleLabel?.font = PixelTheme.boldFont(size: 13)
        testConnectionButton.setTitleColor(PixelTheme.textWhite, for: .normal)
        testConnectionButton.backgroundColor = PixelTheme.accentGreen.withAlphaComponent(0.6)
        testConnectionButton.layer.cornerRadius = PixelTheme.cornerRadius
        testConnectionButton.layer.borderWidth = PixelTheme.borderWidth
        testConnectionButton.layer.borderColor = PixelTheme.accentGreen.withAlphaComponent(0.3).cgColor
        testConnectionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        testConnectionButton.addTarget(self, action: #selector(testConnection), for: .touchUpInside)

        fetchModelsButton.setTitle(usesStaticCatalog ? "📋 加载内置模型" : "🔄 刷新模型", for: .normal)
        fetchModelsButton.titleLabel?.font = PixelTheme.boldFont(size: 13)
        fetchModelsButton.setTitleColor(PixelTheme.textWhite, for: .normal)
        fetchModelsButton.backgroundColor = PixelTheme.accentBlue.withAlphaComponent(0.4)
        fetchModelsButton.layer.cornerRadius = PixelTheme.cornerRadius
        fetchModelsButton.layer.borderWidth = PixelTheme.borderWidth
        fetchModelsButton.layer.borderColor = PixelTheme.accentBlue.withAlphaComponent(0.3).cgColor
        fetchModelsButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        fetchModelsButton.addTarget(self, action: #selector(refreshModels), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [testConnectionButton, fetchModelsButton])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }

    private func updateConnectionStatusUI() {
        connectionStatusLabel.text = pendingConnectionMessage
        connectionDotView.backgroundColor = color(for: pendingConnectionStatus)
    }

    private func setNetworkLoading(_ isLoading: Bool) {
        if isLoading {
            connectionSpinner.startAnimating()
        } else {
            connectionSpinner.stopAnimating()
        }
        testConnectionButton.isEnabled = !isLoading
        fetchModelsButton.isEnabled = !isLoading
        testConnectionButton.alpha = isLoading ? 0.5 : 1
        fetchModelsButton.alpha = isLoading ? 0.5 : 1
    }

    private func color(for status: ModelConnectionStatus) -> UIColor {
        switch status {
        case .unknown:  return PixelTheme.statusUnknown
        case .success:  return PixelTheme.statusOK
        case .failure:  return PixelTheme.statusFail
        }
    }

    // MARK: - Actions

    @objc private func toggleApiKeyVisibility(_ sender: UIButton) {
        apiKeyField.isSecureTextEntry.toggle()
        let icon = apiKeyField.isSecureTextEntry ? "eye" : "eye.slash"
        sender.setImage(UIImage(systemName: icon), for: .normal)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func openProviderDocs() {
        guard let url = URL(string: providerDefinition.docsURL) else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    @objc private func saveModel() {
        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else {
            showAlert("请输入 API Key")
            return
        }

        let draft = makeDraftConfig()

        switch mode {
        case .add:
            ModelManager.shared.addConfig(draft, apiKey: apiKey)

        case .edit(let existing):
            let updated = ModelConfig(
                id: existing.id,
                alias: draft.alias,
                provider: draft.provider,
                baseURL: draft.baseURL,
                modelName: draft.modelName,
                appendV1: draft.appendV1,
                connectionStatus: draft.connectionStatus,
                connectionMessage: draft.connectionMessage
            )
            ModelManager.shared.updateConfig(updated, apiKey: apiKey)

            // Save SOUL changes
            var soul = SoulStore.shared.soul(for: existing.id.uuidString)
            soul.personality = (personalityTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            soul.beliefs = (beliefsTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            soul.goals = (goalsTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            soul.journal = (journalTextView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            SoulStore.shared.update(entityID: existing.id.uuidString, soul: soul)
        }

        dismiss(animated: true)
    }

    @objc private func deleteModel() {
        guard case .edit(let config) = mode else { return }

        let alert = UIAlertController(
            title: "确认删除",
            message: "确定要删除「\(config.alias)」吗？此操作不可撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            ModelManager.shared.deleteConfig(id: config.id)
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    @objc private func clearMemory() {
        guard case .edit(let config) = mode else { return }
        let alert = UIAlertController(
            title: "清除记忆",
            message: "确定要清除此 Agent 的全部长期记忆吗？此操作不可撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            LongTermMemory.shared.removeAll(for: config.id.uuidString)
            self?.memoryCountLabel.text = "长期记忆: 0 条"
        })
        present(alert, animated: true)
    }

    @objc private func testConnection() {
        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else {
            showAlert("请输入 API Key 后再测试连接。")
            return
        }

        let draft = makeDraftConfig()
        pendingConnectionStatus = .unknown
        pendingConnectionMessage = "正在测试连接..."
        updateConnectionStatusUI()
        setNetworkLoading(true)

        Task { [weak self] in
            guard let self else { return }
            let result = await ModelConnectionService.shared.testConnection(using: draft, apiKey: apiKey)
            await MainActor.run {
                self.pendingConnectionStatus = result.status
                self.pendingConnectionMessage = result.message
                self.fetchedModels = result.models
                if self.modelNameField.text?.isEmpty ?? true, let first = result.models.first {
                    self.modelNameField.text = first
                }
                self.selectModelButton.isEnabled = !result.models.isEmpty
                self.selectModelButton.alpha = result.models.isEmpty ? 0.45 : 1.0
                self.updateConnectionStatusUI()
                self.setNetworkLoading(false)
            }
        }
    }

    @objc private func refreshModels() {
        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else {
            showAlert(usesStaticCatalog ? "请输入 API Key 后再加载模型目录。" : "请输入 API Key 后再刷新模型。")
            return
        }

        let draft = makeDraftConfig()
        pendingConnectionMessage = usesStaticCatalog ? "正在加载内置模型目录..." : "正在拉取模型列表..."
        updateConnectionStatusUI()
        setNetworkLoading(true)

        Task { [weak self] in
            guard let self else { return }
            do {
                let models = try await ModelConnectionService.shared.listModels(using: draft, apiKey: apiKey)
                await MainActor.run {
                    self.fetchedModels = models
                    self.pendingConnectionStatus = .success
                    self.pendingConnectionMessage = models.isEmpty
                        ? (self.usesStaticCatalog ? "连接成功，但当前服务商没有内置模型目录。" : "连接成功，但服务端未返回模型列表。")
                        : (self.usesStaticCatalog
                            ? "已载入 \(models.count) 个内置参考模型，可直接选择或手动输入。"
                            : "已拉取 \(models.count) 个模型，可直接选择或手动输入。")
                    self.selectModelButton.isEnabled = !models.isEmpty
                    self.selectModelButton.alpha = models.isEmpty ? 0.45 : 1.0
                    self.updateConnectionStatusUI()
                    self.setNetworkLoading(false)
                    if !models.isEmpty {
                        self.presentFetchedModelsPicker()
                    }
                }
            } catch {
                await MainActor.run {
                    self.pendingConnectionStatus = .failure
                    self.pendingConnectionMessage = error.localizedDescription
                    self.updateConnectionStatusUI()
                    self.setNetworkLoading(false)
                    self.showAlert(error.localizedDescription)
                }
            }
        }
    }

    @objc private func selectFetchedModel() {
        presentFetchedModelsPicker()
    }

    private func presentFetchedModelsPicker() {
        guard !fetchedModels.isEmpty else {
            showAlert(usesStaticCatalog ? "请先加载内置模型目录。" : "请先刷新模型列表。")
            return
        }

        let sheet = UIAlertController(
            title: usesStaticCatalog ? "选择内置模型" : "选择模型",
            message: nil,
            preferredStyle: .actionSheet
        )
        for model in fetchedModels.prefix(12) {
            sheet.addAction(UIAlertAction(title: model, style: .default) { [weak self] _ in
                self?.modelNameField.text = model
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = selectModelButton
            popover.sourceRect = selectModelButton.bounds
        }

        present(sheet, animated: true)
    }

    private func makeDraftConfig() -> ModelConfig {
        let alias = (aliasField.text ?? "").trimmingCharacters(in: .whitespaces)
        let baseURL = (baseURLField.text ?? "").trimmingCharacters(in: .whitespaces)
        let modelName = (modelNameField.text ?? "").trimmingCharacters(in: .whitespaces)

        let provider = mode.provider
        let resolvedAlias = alias.isEmpty ? provider.displayName : alias
        let resolvedModel = modelName.isEmpty ? provider.defaultModel : modelName

        switch mode {
        case .add:
            return ModelConfig(
                alias: resolvedAlias,
                provider: provider,
                baseURL: baseURL,
                modelName: resolvedModel,
                appendV1: v1Toggle.isOn,
                connectionStatus: pendingConnectionStatus,
                connectionMessage: pendingConnectionMessage
            )
        case .edit(let existing):
            return ModelConfig(
                id: existing.id,
                alias: resolvedAlias,
                provider: provider,
                baseURL: baseURL,
                modelName: resolvedModel,
                appendV1: v1Toggle.isOn,
                connectionStatus: pendingConnectionStatus,
                connectionMessage: pendingConnectionMessage
            )
        }
    }

    private func currentAPIKey() -> String {
        (apiKeyField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Keyboard

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        else { return }

        let keyboardTop = view.convert(frame, from: nil).origin.y
        let bottomInset = max(0, view.bounds.height - keyboardTop)

        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }
}
