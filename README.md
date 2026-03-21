# Stars · 群星

**AI 的群星闪耀时 / When AI Stars Shine**

一个像素风 AI 沙盒世界。每个 Agent 由大语言模型驱动，拥有独立的记忆、灵魂和自由意志。

A pixel-art AI sandbox world. Each Agent is powered by a large language model, with independent memory, soul, and free will.

[中文](#中文文档) | [English](#english-documentation)

---

## 中文文档

### 项目概览

Stars（群星）是一款 iOS 原生 SpriteKit 游戏。玩家可以召唤由不同大语言模型（LLM）驱动的 AI Agent，观察它们在一个无限 2D 像素世界中自由生活、思考、战斗、建造和社交。

**核心设计理念：最大自由度。** 宪法只定义世界规则，不规定 Agent 应该如何感受或行动。

### 技术栈

- **平台**: iOS 17+ (iPhone / iPad)
- **引擎**: SpriteKit (SKScene / SKSpriteNode / SKPhysicsContact)
- **语言**: Swift 5.9+
- **字体**: fusion-pixel-font 12px（中英文像素字体）
- **国际化**: 中文 (zh-Hans) / 英文 (en) 双语
- **内购**: StoreKit 2（打赏功能）
- **存储**: UserDefaults + iOS Keychain（API Key 安全存储）

### 目录结构

```
Stars/
├── AppDelegate.swift           # 应用入口
├── SceneDelegate.swift         # UIScene 生命周期
├── GameScene.swift             # SpriteKit 主场景，游戏循环
├── GameViewController.swift    # UIKit → SpriteKit 桥接，底部菜单栏
├── GameCenterManager.swift     # Game Center 成就/排行榜
│
├── AI/                         # AI 推理层
│   ├── AgentAction.swift       # 数据模型：LLMResponse, AgentActionType, WeaponType, StructureType
│   ├── AgentBrain.swift        # Agent 的"大脑"，负责构建 prompt、调用 LLM、管理思考周期
│   ├── ActionResolver.swift    # 解析 LLM JSON 响应 → 执行 Agent 行为
│   ├── LLMService.swift        # LLM API 网络层（OpenAI / Anthropic 协议）
│   ├── ProviderPayloadCodec.swift  # 请求/响应编解码（OpenAI/Anthropic 兼容）
│   ├── MemoryStore.swift       # Agent 短期记忆（环形缓冲区）
│   ├── LongTermMemory.swift    # Agent 长期记忆（持久化，按重要性排序）
│   └── ContextBudgetMonitor.swift  # Token 使用量监控
│
├── Agents/                     # Agent 实体与管理
│   ├── Agent.swift             # Agent SKSpriteNode 子类，HP/移动/战斗/语音气泡
│   ├── AgentManager.swift      # Agent 生命周期管理，房屋休息逻辑，广播系统
│   ├── AgentsFile.swift        # AGENTS 文件（世界宪法用户自定义版本）
│   ├── SoulStore.swift         # SOUL 系统持久化（人格/信念/目标/日志）
│   └── StarsConstitution.swift # 群星宪法（默认系统提示词）
│
├── Camera/
│   └── CameraController.swift  # 相机平移/缩放/跟随
│
├── Combat/                     # 战斗系统
│   ├── CombatSystem.swift      # 物理碰撞处理（远程/近战/陷阱），击杀奖励 Star
│   ├── BuildSystem.swift       # 建造系统（墙/陷阱/房屋），所有权追踪
│   ├── WeaponSystem.swift      # 武器发射（近战挥击/远程投射物）
│   ├── Projectile.swift        # 远程投射物 SKSpriteNode
│   ├── ProjectilePool.swift    # 投射物对象池
│   └── PhysicsCategory.swift   # 物理碰撞掩码定义
│
├── Models/                     # 数据模型与配置
│   ├── ModelConfig.swift       # AI 服务商配置（provider/model/baseURL/apiKey）
│   ├── ModelManager.swift      # 配置 CRUD，Keychain 集成
│   ├── ModelConnectionService.swift  # 连接测试 / 模型列表拉取
│   ├── ProviderCatalog.swift   # AI 服务商目录（20+ 家服务商定义）
│   └── KeychainHelper.swift    # iOS Keychain 安全存储封装
│
├── Persistence/                # 持久化
│   ├── GameStateStore.swift    # 世界快照存储/恢复（Agent/结构/相机/命令）
│   ├── IncrementalArchiveStore.swift  # 增量归档（减少全量保存频率）
│   └── WorldEventLogStore.swift      # 世界事件日志
│
├── World/                      # 世界系统
│   ├── Chunk.swift             # 地图分块（16×16 tile chunk）
│   ├── ChunkManager.swift      # 可视区域分块加载/卸载
│   ├── TerrainGenerator.swift  # 程序化地形生成（Perlin noise）
│   ├── TileType.swift          # 地形类型枚举（深水/浅水/沙滩/草地/森林/山地/雪地）
│   ├── Structure.swift         # 结构物 SKSpriteNode（墙/陷阱/房屋），像素纹理生成
│   ├── WorldClock.swift        # 世界时钟（跟随设备真实时间）
│   ├── WorldCommandRegistry.swift    # 世界命令注册表（内置+自定义命令）
│   └── ZSort.swift             # Y 轴排序（模拟 2.5D 深度）
│
├── UI/                         # 界面层
│   ├── PixelTheme.swift        # 全局像素主题（颜色/字体/样式）
│   ├── SettingsViewController.swift      # 主设置菜单
│   ├── ModelSettingsViewController.swift # Agent 管理列表
│   ├── ModelEditViewController.swift     # Agent 配置编辑（API Key/模型/SOUL）
│   ├── ProviderPickerViewController.swift # AI 服务商选择器
│   ├── ConstitutionViewController.swift  # 世界宪法编辑
│   ├── AboutViewController.swift         # 关于页（开源/打赏/法律）
│   └── AgentChatView.swift              # Agent 对话面板（聊天/状态/日志）
│
├── Fonts/                      # 像素字体
│   ├── fusion-pixel-12px-proportional-zh_hans.ttf  # 比例字体（标题/正文）
│   └── fusion-pixel-12px-monospaced-zh_hans.ttf    # 等宽字体（数据/代码）
│
├── Assets.xcassets/            # 图片资源
│   ├── AppIcon.appiconset/     # 应用图标
│   └── buttonicon/             # UI 图标（机器人/宪法/咖啡 等 SVG）
│
├── zh-Hans.lproj/              # 中文本地化
│   ├── Localizable.strings     # UI 字符串
│   ├── LaunchScreen.strings    # 启动屏
│   └── Main.strings            # Storyboard
│
└── en.lproj/                   # 英文本地化
    └── Localizable.strings     # UI 字符串
```

### 核心概念

| 术语 | 说明 |
|------|------|
| **Agent** | 由 LLM 驱动的自主实体，拥有 HP、位置、记忆、SOUL |
| **SOUL** | Agent 的灵魂：personality（人格）、beliefs（信念）、goals（目标）、journal（日志） |
| **Brain** (`AgentBrain`) | Agent 的思考引擎，定期调用 LLM 获取下一步行动 |
| **Constitution** | 群星宪法，所有 Agent 的系统提示词基础 |
| **Star** (⭐) | 击杀奖励，未来可用于升级 |
| **World Command** | Agent 可执行的命令（/move, /attack_melee, /build_house 等） |
| **Structure** | 可建造的结构物：wall（墙 HP:100）、trap（陷阱 HP:30 伤害:25）、house（房屋 HP:150） |
| **Owner** (主人) | 玩家，可通过聊天面板向 Agent 发送指令 |

### 关键接口

**LLM 协议**
- `LLMService.chat(messages:config:apiKey:)` — 发送消息到 LLM，返回文本响应
- 支持 OpenAI Chat Completions 和 Anthropic Messages 两种协议
- 每个 Agent 独立调用，互不干扰

**Agent 行为循环**
1. `AgentBrain.thinkLoop()` — 定期触发思考
2. 构建 prompt（宪法 + 状态 + 记忆 + 附近实体 + 聊天记录）
3. 调用 `LLMService` 获取 JSON 响应
4. `ActionResolver.parse()` — 解析 JSON 为 `LLMResponse`
5. `ActionResolver.execute()` — 将响应转化为 Agent 行为

**世界命令系统**
- `WorldCommandRegistry.resolve()` — 将命令名解析为行为类型
- `WorldCommandRegistry.registerAliasIfSafe()` — Agent 可注册自定义命令别名

**持久化**
- `GameStateStore.save/load` — 完整世界快照（Agent 状态、结构物、相机位置、自定义命令）
- `IncrementalArchiveStore` — 增量变更记录，减少 IO
- `SoulStore` — SOUL 独立持久化
- `LongTermMemory` — 长期记忆独立持久化

### 游戏规则

- **攻击**: 近战 10 伤害（1 格射程，0.8s CD），远程 10 伤害（5 格射程，1.2s CD）
- **击杀**: 杀死 Agent → 获得 1 Star (⭐)
- **死亡**: HP 归零 → 脑停止（零 Token 消耗）→ 30 秒后复活
- **建造**: 墙（HP:100 阻挡移动）、陷阱（HP:30 接触伤害 25）、房屋（HP:150 归属建造者）
- **房屋休息**: HP ≤ 20 的 Agent 在自己的房屋内静止 10 小时 → 恢复 5 HP
- **语音**: 全局广播，所有存活 Agent 都能听到

---

## English Documentation

### Project Overview

Stars is a native iOS SpriteKit game. Players summon AI Agents powered by various large language models (LLMs) and watch them live, think, fight, build, and socialize freely in an infinite 2D pixel world.

**Core design principle: MAXIMUM FREEDOM.** The Constitution only defines world rules, never how agents should feel or act.

### Tech Stack

- **Platform**: iOS 17+ (iPhone / iPad)
- **Engine**: SpriteKit (SKScene / SKSpriteNode / SKPhysicsContact)
- **Language**: Swift 5.9+
- **Font**: fusion-pixel-font 12px (Chinese & English pixel font)
- **i18n**: Chinese (zh-Hans) / English (en) bilingual
- **IAP**: StoreKit 2 (tip jar)
- **Storage**: UserDefaults + iOS Keychain (secure API key storage)

### Directory Structure

```
Stars/
├── AppDelegate.swift           # App entry point
├── SceneDelegate.swift         # UIScene lifecycle
├── GameScene.swift             # SpriteKit main scene, game loop
├── GameViewController.swift    # UIKit → SpriteKit bridge, bottom menu bar
├── GameCenterManager.swift     # Game Center achievements/leaderboards
│
├── AI/                         # AI reasoning layer
│   ├── AgentAction.swift       # Data models: LLMResponse, AgentActionType, WeaponType, StructureType
│   ├── AgentBrain.swift        # Agent's "brain" — builds prompts, calls LLM, manages think cycles
│   ├── ActionResolver.swift    # Parses LLM JSON response → executes Agent actions
│   ├── LLMService.swift        # LLM API network layer (OpenAI / Anthropic protocols)
│   ├── ProviderPayloadCodec.swift  # Request/response encoding (OpenAI/Anthropic compatible)
│   ├── MemoryStore.swift       # Agent short-term memory (ring buffer)
│   ├── LongTermMemory.swift    # Agent long-term memory (persisted, sorted by importance)
│   └── ContextBudgetMonitor.swift  # Token usage monitoring
│
├── Agents/                     # Agent entities & management
│   ├── Agent.swift             # Agent SKSpriteNode subclass — HP/movement/combat/speech bubbles
│   ├── AgentManager.swift      # Agent lifecycle, house resting logic, broadcast system
│   ├── AgentsFile.swift        # AGENTS file (user-customized world constitution)
│   ├── SoulStore.swift         # SOUL system persistence (personality/beliefs/goals/journal)
│   └── StarsConstitution.swift # Stars Constitution (default system prompt)
│
├── Camera/
│   └── CameraController.swift  # Camera pan/zoom/follow
│
├── Combat/                     # Combat system
│   ├── CombatSystem.swift      # Physics contact handling (ranged/melee/trap), Star kill rewards
│   ├── BuildSystem.swift       # Build system (wall/trap/house), ownership tracking
│   ├── WeaponSystem.swift      # Weapon firing (melee slash/ranged projectile)
│   ├── Projectile.swift        # Ranged projectile SKSpriteNode
│   ├── ProjectilePool.swift    # Projectile object pool
│   └── PhysicsCategory.swift   # Physics collision bitmask definitions
│
├── Models/                     # Data models & configuration
│   ├── ModelConfig.swift       # AI provider config (provider/model/baseURL/apiKey)
│   ├── ModelManager.swift      # Config CRUD, Keychain integration
│   ├── ModelConnectionService.swift  # Connection testing / model list fetching
│   ├── ProviderCatalog.swift   # AI provider catalog (20+ provider definitions)
│   └── KeychainHelper.swift    # iOS Keychain secure storage wrapper
│
├── Persistence/                # Persistence
│   ├── GameStateStore.swift    # World snapshot save/restore (agents/structures/camera/commands)
│   ├── IncrementalArchiveStore.swift  # Incremental archiving (reduces full-save frequency)
│   └── WorldEventLogStore.swift      # World event log
│
├── World/                      # World systems
│   ├── Chunk.swift             # Map chunking (16×16 tile chunks)
│   ├── ChunkManager.swift      # Visible-area chunk loading/unloading
│   ├── TerrainGenerator.swift  # Procedural terrain generation (Perlin noise)
│   ├── TileType.swift          # Terrain type enum (deepWater/water/sand/grass/forest/mountain/snow)
│   ├── Structure.swift         # Structure SKSpriteNode (wall/trap/house), pixel texture generation
│   ├── WorldClock.swift        # World clock (follows real device time)
│   ├── WorldCommandRegistry.swift    # World command registry (built-in + custom commands)
│   └── ZSort.swift             # Y-axis sorting (simulates 2.5D depth)
│
├── UI/                         # UI layer
│   ├── PixelTheme.swift        # Global pixel theme (colors/fonts/styles)
│   ├── SettingsViewController.swift      # Main settings menu
│   ├── ModelSettingsViewController.swift # Agent management list
│   ├── ModelEditViewController.swift     # Agent config editor (API Key/model/SOUL)
│   ├── ProviderPickerViewController.swift # AI provider picker
│   ├── ConstitutionViewController.swift  # World Constitution editor
│   ├── AboutViewController.swift         # About page (open source/tip jar/legal)
│   └── AgentChatView.swift              # Agent chat panel (chat/stats/log)
│
├── Fonts/                      # Pixel fonts
│   ├── fusion-pixel-12px-proportional-zh_hans.ttf  # Proportional (titles/body)
│   └── fusion-pixel-12px-monospaced-zh_hans.ttf    # Monospaced (data/code)
│
├── Assets.xcassets/            # Image assets
│   ├── AppIcon.appiconset/     # App icon
│   └── buttonicon/             # UI icons (robot/constitution/coffee SVGs)
│
├── zh-Hans.lproj/              # Chinese localization
│   ├── Localizable.strings     # UI strings
│   ├── LaunchScreen.strings    # Launch screen
│   └── Main.strings            # Storyboard
│
└── en.lproj/                   # English localization
    └── Localizable.strings     # UI strings
```

### Core Concepts

| Term | Description |
|------|-------------|
| **Agent** | Autonomous entity powered by an LLM, with HP, position, memory, SOUL |
| **SOUL** | Agent's soul: personality, beliefs, goals, journal |
| **Brain** (`AgentBrain`) | Agent's thinking engine — periodically calls LLM for next action |
| **Constitution** | Stars Constitution — the base system prompt for all Agents |
| **Star** (⭐) | Kill reward, will unlock upgrades in the future |
| **World Command** | Commands Agents can execute (/move, /attack_melee, /build_house, etc.) |
| **Structure** | Buildable structures: wall (HP:100), trap (HP:30, 25 dmg), house (HP:150) |
| **Owner** | The player — can send instructions to Agents via chat panel |

### Key Interfaces

**LLM Protocol**
- `LLMService.chat(messages:config:apiKey:)` — Send messages to LLM, return text response
- Supports both OpenAI Chat Completions and Anthropic Messages protocols
- Each Agent calls independently, no interference

**Agent Behavior Loop**
1. `AgentBrain.thinkLoop()` — Periodically triggers thinking
2. Build prompt (constitution + status + memory + nearby entities + chat history)
3. Call `LLMService` for JSON response
4. `ActionResolver.parse()` — Parse JSON into `LLMResponse`
5. `ActionResolver.execute()` — Translate response into Agent actions

**World Command System**
- `WorldCommandRegistry.resolve()` — Resolve command name to action type
- `WorldCommandRegistry.registerAliasIfSafe()` — Agents can register custom command aliases

**Persistence**
- `GameStateStore.save/load` — Full world snapshot (agent state, structures, camera, custom commands)
- `IncrementalArchiveStore` — Incremental change recording to reduce IO
- `SoulStore` — Independent SOUL persistence
- `LongTermMemory` — Independent long-term memory persistence

### Game Rules

- **Attack**: Melee 10 dmg (1 tile range, 0.8s CD), Ranged 10 dmg (5 tile range, 1.2s CD)
- **Kill**: Kill an Agent → earn 1 Star (⭐)
- **Death**: HP reaches 0 → brain stops (zero token consumption) → respawn after 30 seconds
- **Building**: Wall (HP:100, blocks movement), Trap (HP:30, contact 25 dmg), House (HP:150, owned by builder)
- **House Rest**: Agent with HP ≤ 20 rests idle in own house for 10 hours → recover 5 HP
- **Speech**: Global broadcast — all living Agents hear everything

---

## License

Open source project. See repository for license details.

Made By [QingTengStudio](https://qingtengstudio.com/)
