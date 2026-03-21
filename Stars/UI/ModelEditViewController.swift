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
    private lazy var pendingConnectionMessage = NSLocalizedString("edit.connection_default", comment: "")
    private var providerDefinition: ProviderDefinition { mode.provider.definition }
    private var usesStaticCatalog: Bool {
        if case .staticCatalog = providerDefinition.modelCatalogMode {
            return true
        }
        return false
    }

    /// True when editing the built-in 星尘 agent — API key and model must be locked.
    private var isBuiltInAgent: Bool {
        if case .edit(let config) = mode {
            return config.id == BuiltInAgent.stableID
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
            title = String(format: NSLocalizedString("edit.title_edit", comment: ""), config.alias)
        } else {
            title = String(format: NSLocalizedString("edit.title_add", comment: ""), mode.provider.displayName)
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

        navigationItem.leftBarButtonItem = PixelTheme.makeIconBarButton(
            iconName: "返回", size: 24,
            target: self, action: #selector(dismissSelf)
        )
        navigationItem.rightBarButtonItem = PixelTheme.makeIconBarButton(
            iconName: "文档", size: 24,
            target: self, action: #selector(openProviderDocs)
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
        stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_alias", comment: "")))
        aliasField.autocapitalizationType = .words
        if isBuiltInAgent { aliasField.isEnabled = false; aliasField.alpha = 0.6 }
        stack.addArrangedSubview(makeCardField(aliasField, placeholder: NSLocalizedString("edit.placeholder_alias", comment: "")))
        stack.addArrangedSubview(makeSpacer(12))

        if !isBuiltInAgent {
            // ── API Key (hidden for built-in agent) ──
            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_apikey", comment: "")))
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
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.apikey_hint", comment: "")))
            stack.addArrangedSubview(makeSpacer(8))

            // ── 自定义 API 地址（可选）──
            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_baseurl", comment: "")))

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
        }

        stack.addArrangedSubview(makeConnectionStatusCard())
        stack.addArrangedSubview(makeSpacer(8))

        if !isBuiltInAgent {
            stack.addArrangedSubview(makeUtilityButtonsRow())
            stack.addArrangedSubview(makeSpacer(8))
        }

        // ── 模型名称 ──
        stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_model", comment: "")))
        modelNameField.autocapitalizationType = .none
        modelNameField.autocorrectionType = .no
        modelNameField.text = provider.defaultModel
        if isBuiltInAgent {
            modelNameField.isEnabled = false
            modelNameField.alpha = 0.6
        }
        stack.addArrangedSubview(makeCardField(modelNameField, placeholder: provider.defaultModel))
        if !isBuiltInAgent {
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.model_hint", comment: "")))
            selectModelButton.setTitle(usesStaticCatalog ? NSLocalizedString("edit.select_builtin", comment: "") : NSLocalizedString("edit.select_fetched", comment: ""), for: .normal)
            selectModelButton.titleLabel?.font = PixelTheme.boldFont(size: 14)
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
        }
        stack.addArrangedSubview(makeSpacer(24))

        // ── SOUL 配置 (edit mode only) ──
        if mode.isEdit {
            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_soul_personality", comment: "")))
            stack.addArrangedSubview(makeTextViewCard(personalityTextView, height: 50))
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.hint_personality", comment: "")))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_soul_beliefs", comment: "")))
            stack.addArrangedSubview(makeTextViewCard(beliefsTextView, height: 50))
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.hint_beliefs", comment: "")))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_soul_goals", comment: "")))
            stack.addArrangedSubview(makeTextViewCard(goalsTextView, height: 50))
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.hint_goals", comment: "")))
            stack.addArrangedSubview(makeSpacer(6))

            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_soul_journal", comment: "")))
            stack.addArrangedSubview(makeTextViewCard(journalTextView, height: 60))
            stack.addArrangedSubview(makeHint(NSLocalizedString("edit.hint_journal", comment: "")))
            stack.addArrangedSubview(makeSpacer(12))

            // ── Memory Info ──
            stack.addArrangedSubview(makeSectionTitle(NSLocalizedString("edit.section_memory", comment: "")))
            stack.addArrangedSubview(makeMemoryInfoCard())
            stack.addArrangedSubview(makeSpacer(24))
        }

        // ── Submit Button ──
        let submitButton = makeActionButton(
            title: mode.isEdit ? NSLocalizedString("edit.save", comment: "") : NSLocalizedString("edit.add_provider", comment: ""),
            color: UIColor(white: 0.55, alpha: 1)
        )
        submitButton.addTarget(self, action: #selector(saveModel), for: .touchUpInside)
        stack.addArrangedSubview(submitButton)

        // ── Delete Button (edit mode, not for built-in agent) ──
        if mode.isEdit && !isBuiltInAgent {
            stack.addArrangedSubview(makeSpacer(12))
            let deleteButton = makeActionButton(title: NSLocalizedString("edit.delete_config", comment: ""), color: .systemRed)
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
        memoryCountLabel.text = String(format: NSLocalizedString("edit.ltm_count", comment: ""), ltmCount)
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
        title.font = PixelTheme.headerFont(size: 18)
        title.textColor = PixelTheme.textCream
        title.text = providerDefinition.selectionTitle

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.font = PixelTheme.bodyFont(size: 14)
        subtitle.textColor = PixelTheme.textTan
        subtitle.numberOfLines = 0
        subtitle.text = providerDefinition.selectionSubtitle

        let stack = UIStackView(arrangedSubviews: [
            makeMetaPill(NSLocalizedString("meta.protocol", comment: ""), value: providerDefinition.protocolLabel),
            makeMetaPill(NSLocalizedString("meta.auth", comment: ""), value: providerDefinition.authLabel),
            makeMetaPill(NSLocalizedString("meta.model", comment: ""), value: providerDefinition.modelSourceLabel),
            makeMetaPill(NSLocalizedString("meta.context", comment: ""), value: "\(providerDefinition.contextWindowTokens.formatted()) tokens"),
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
        label.font = PixelTheme.bodyFont(size: 14)
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
        providerDefinition.defaultBaseURL.isEmpty ? NSLocalizedString("edit.url_hint_docs", comment: "") : providerDefinition.defaultBaseURL
    }

    private func providerBaseURLHint() -> String {
        if mode.provider == .minimax {
            return NSLocalizedString("edit.url_hint_minimax", comment: "")
        }
        if providerDefinition.protocolFamily == .anthropicMessages {
            if providerDefinition.defaultBaseURL.isEmpty {
                return NSLocalizedString("edit.url_hint_anthropic", comment: "")
            }
            return NSLocalizedString("edit.url_hint_anthropic_default", comment: "")
        }
        if providerDefinition.defaultBaseURL.isEmpty {
            return NSLocalizedString("edit.url_hint_custom", comment: "")
        }
        return NSLocalizedString("edit.url_hint_openai_default", comment: "")
    }

    private func makeCardField(_ field: UITextField, placeholder: String) -> UIView {
        field.placeholder = placeholder
        field.borderStyle = .none
        field.font = PixelTheme.bodyFont(size: 16)
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
        field.font = PixelTheme.bodyFont(size: 16)
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
            toggleLabel.text = NSLocalizedString("edit.append_v1_anthropic", comment: "")
        } else {
            toggleLabel.text = NSLocalizedString("edit.append_v1", comment: "")
        }
        toggleLabel.font = PixelTheme.bodyFont(size: 16)
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
        label.font = PixelTheme.bodyFont(size: 12)
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
        textView.font = PixelTheme.bodyFont(size: 16)
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

        memoryCountLabel.font = PixelTheme.bodyFont(size: 16)
        memoryCountLabel.textColor = PixelTheme.textTan
        memoryCountLabel.text = NSLocalizedString("edit.ltm_label", comment: "")
        memoryCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let clearButton = UIButton(type: .system)
        clearButton.setTitle(NSLocalizedString("edit.clear_memory", comment: ""), for: .normal)
        clearButton.titleLabel?.font = PixelTheme.bodyFont(size: 14)
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
        button.titleLabel?.font = PixelTheme.headerFont(size: 18)
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
        connectionStatusLabel.font = PixelTheme.bodyFont(size: 14)
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
        testConnectionButton.setTitle(NSLocalizedString("edit.test_connection", comment: ""), for: .normal)
        testConnectionButton.titleLabel?.font = PixelTheme.boldFont(size: 16)
        testConnectionButton.setTitleColor(PixelTheme.textWhite, for: .normal)
        testConnectionButton.backgroundColor = PixelTheme.accentGreen.withAlphaComponent(0.6)
        testConnectionButton.layer.cornerRadius = PixelTheme.cornerRadius
        testConnectionButton.layer.borderWidth = PixelTheme.borderWidth
        testConnectionButton.layer.borderColor = PixelTheme.accentGreen.withAlphaComponent(0.3).cgColor
        testConnectionButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        testConnectionButton.addTarget(self, action: #selector(testConnection), for: .touchUpInside)

        fetchModelsButton.setTitle(usesStaticCatalog ? NSLocalizedString("edit.load_builtin_models", comment: "") : NSLocalizedString("edit.refresh_models", comment: ""), for: .normal)
        fetchModelsButton.titleLabel?.font = PixelTheme.boldFont(size: 16)
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

        // Built-in agent: skip API key validation, keep existing key
        if !isBuiltInAgent {
            guard !apiKey.isEmpty else {
                showAlert(NSLocalizedString("edit.enter_apikey", comment: ""))
                return
            }
        }

        let draft = makeDraftConfig()

        switch mode {
        case .add:
            ModelManager.shared.addConfig(draft, apiKey: apiKey)

        case .edit(let existing):
            let updated = ModelConfig(
                id: existing.id,
                alias: isBuiltInAgent ? existing.alias : draft.alias,
                provider: existing.provider,
                baseURL: isBuiltInAgent ? existing.baseURL : draft.baseURL,
                modelName: isBuiltInAgent ? existing.modelName : draft.modelName,
                appendV1: isBuiltInAgent ? existing.appendV1 : draft.appendV1,
                connectionStatus: draft.connectionStatus,
                connectionMessage: draft.connectionMessage
            )
            let resolvedKey = isBuiltInAgent ? (ModelManager.shared.apiKey(for: existing.id) ?? "") : apiKey
            ModelManager.shared.updateConfig(updated, apiKey: resolvedKey)

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
            title: NSLocalizedString("edit.delete_confirm_title", comment: ""),
            message: String(format: NSLocalizedString("edit.delete_confirm_msg", comment: ""), config.alias),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.delete", comment: ""), style: .destructive) { [weak self] _ in
            ModelManager.shared.deleteConfig(id: config.id)
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: NSLocalizedString("edit.alert_title", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.alert_confirm", comment: ""), style: .default))
        present(alert, animated: true)
    }

    @objc private func clearMemory() {
        guard case .edit(let config) = mode else { return }
        let alert = UIAlertController(
            title: NSLocalizedString("edit.clear_memory_title", comment: ""),
            message: NSLocalizedString("edit.clear_memory_msg", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("edit.clear", comment: ""), style: .destructive) { [weak self] _ in
            LongTermMemory.shared.removeAll(for: config.id.uuidString)
            self?.memoryCountLabel.text = String(format: NSLocalizedString("edit.ltm_count", comment: ""), 0)
        })
        present(alert, animated: true)
    }

    @objc private func testConnection() {
        let apiKey = currentAPIKey()
        guard !apiKey.isEmpty else {
            showAlert(NSLocalizedString("edit.test_need_key", comment: ""))
            return
        }

        let draft = makeDraftConfig()
        pendingConnectionStatus = .unknown
        pendingConnectionMessage = NSLocalizedString("edit.testing", comment: "")
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
            showAlert(usesStaticCatalog ? NSLocalizedString("edit.fetch_need_key_catalog", comment: "") : NSLocalizedString("edit.fetch_need_key_api", comment: ""))
            return
        }

        let draft = makeDraftConfig()
        pendingConnectionMessage = usesStaticCatalog ? NSLocalizedString("edit.loading_catalog", comment: "") : NSLocalizedString("edit.loading_api", comment: "")
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
                        ? (self.usesStaticCatalog ? NSLocalizedString("edit.success_no_catalog", comment: "") : NSLocalizedString("edit.success_no_api", comment: ""))
                        : (self.usesStaticCatalog
                            ? String(format: NSLocalizedString("edit.loaded_catalog", comment: ""), models.count)
                            : String(format: NSLocalizedString("edit.loaded_api", comment: ""), models.count))
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
            showAlert(usesStaticCatalog ? NSLocalizedString("edit.select_need_catalog", comment: "") : NSLocalizedString("edit.select_need_api", comment: ""))
            return
        }

        let title = usesStaticCatalog
            ? NSLocalizedString("edit.select_catalog_title", comment: "")
            : NSLocalizedString("edit.select_api_title", comment: "")
        let picker = PixelModelPickerViewController(
            title: title,
            models: Array(fetchedModels.prefix(20))
        ) { [weak self] model in
            self?.modelNameField.text = model
        }
        picker.modalPresentationStyle = .overCurrentContext
        picker.modalTransitionStyle = .crossDissolve
        present(picker, animated: true)
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

// MARK: - Pixel Model Picker

/// A game-themed model picker that replaces the system UIAlertController.
private final class PixelModelPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let titleText: String
    private let models: [String]
    private let onSelect: (String) -> Void

    private let panelView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init(title: String, models: [String], onSelect: @escaping (String) -> Void) {
        self.titleText = title
        self.models = models
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Tap dimmed area to dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPicker))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // Panel
        panelView.backgroundColor = PixelTheme.bgDark
        panelView.layer.borderWidth = PixelTheme.thickBorder
        panelView.layer.borderColor = PixelTheme.borderWarm.cgColor
        panelView.layer.cornerRadius = PixelTheme.cornerRadius
        panelView.clipsToBounds = true
        panelView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panelView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = PixelTheme.headerFont(size: 18)
        titleLabel.textColor = PixelTheme.textGold
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(titleLabel)

        // Divider
        let divider = PixelTheme.makeDivider()
        panelView.addSubview(divider)

        // Table
        tableView.backgroundColor = .clear
        tableView.separatorColor = PixelTheme.borderWarm.withAlphaComponent(0.3)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "modelCell")
        tableView.rowHeight = 44
        tableView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(tableView)

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(NSLocalizedString("edit.cancel", comment: ""), for: .normal)
        cancelButton.titleLabel?.font = PixelTheme.boldFont(size: 16)
        cancelButton.setTitleColor(PixelTheme.textTan, for: .normal)
        cancelButton.backgroundColor = PixelTheme.bgMedium
        cancelButton.layer.cornerRadius = PixelTheme.cornerRadius
        cancelButton.layer.borderWidth = PixelTheme.borderWidth
        cancelButton.layer.borderColor = PixelTheme.borderWarm.cgColor
        cancelButton.addTarget(self, action: #selector(dismissPicker), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(cancelButton)

        let maxTableHeight: CGFloat = min(CGFloat(models.count) * 44, 320)

        NSLayoutConstraint.activate([
            panelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panelView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.7),
            panelView.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),

            titleLabel.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 12),
            divider.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -12),

            tableView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            tableView.heightAnchor.constraint(equalToConstant: maxTableHeight),

            cancelButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.bottomAnchor.constraint(equalTo: panelView.bottomAnchor, constant: -14),
        ])
    }

    @objc private func dismissPicker() {
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "modelCell", for: indexPath)
        cell.textLabel?.text = models[indexPath.row]
        cell.textLabel?.font = PixelTheme.bodyFont(size: 16)
        cell.textLabel?.textColor = PixelTheme.textCream
        cell.backgroundColor = .clear
        cell.selectionStyle = .none

        let bg = UIView()
        bg.backgroundColor = PixelTheme.bgLight
        cell.selectedBackgroundView = bg
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = models[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSelect(model)
        }
    }

    // Dismiss when tapping outside the panel
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if !panelView.frame.contains(touch.location(in: view)) {
            dismissPicker()
        }
    }
}
