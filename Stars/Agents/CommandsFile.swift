//
//  CommandsFile.swift
//  Stars
//
//  Player-editable system commands — defines the command interface that
//  every agent receives in their prompt.  Players can add, remove, or
//  modify commands to reshape how agents interact with the world.
//

import Foundation

extension Notification.Name {
    static let starsCommandsDidUpdate = Notification.Name("stars.commandsDidUpdate")
}

@MainActor
final class CommandsFile {
    static let shared = CommandsFile()

    private let storageKey = "stars.commands.file"

    /// The raw text of the player-editable command rules.
    private(set) var content: String

    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey), !saved.isEmpty {
            content = saved
        } else {
            content = Self.defaultContent
        }
    }

    func update(_ newContent: String) {
        content = newContent
        UserDefaults.standard.set(newContent, forKey: storageKey)
        NotificationCenter.default.post(name: .starsCommandsDidUpdate, object: nil)
    }

    func reset() {
        update(Self.defaultContent)
    }

    /// Formatted section for injection into agent prompts.
    var promptSection: String {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return """
        === COMMAND RULES (通用命令) ===
        \(content)
        === END COMMAND RULES ===
        """
    }

    // MARK: - Default Content

    static let defaultContent = """
    ## System Interface (系统接口)

    You interact with the world through JSON commands. Every response MUST be a single JSON object.

    ### Available Commands

    **Idle / Observation:**
    - /idle — Stand still, observe nearby events
    - /hold — Stop moving, hold current position
    - /observe — Pause and watch the environment
    - /rest — Rest at home. System auto-navigates to your house if you have one
    - /guard — Guard current position, watching for threats

    **Movement:**
    - /move — Move to target tile coordinates
    - /goto — Travel directly to target tile
    - /explore — Scout a new area of the world
    - /scout — Reconnaissance mission, gather intel carefully
    - /patrol — Move around an area to secure it
    - /defense — Reposition to avoid damage or cover allies
    - /retreat — Fall back to a safer tile
    - /flee — Emergency escape, run far from danger
    - /enter_house — Go to your own house (system auto-finds coordinates)
    - /follow — Follow another agent by moving toward their position

    **Communication (ALL agents hear everything globally):**
    - /talk — Speak to agents or the owner
    - /report — Share status, findings, or battle reports
    - /respond — Reply to something you just heard
    - /wave — Friendly greeting or social gesture
    - /ally — Propose an alliance or cooperation
    - /treaty — Propose a formal non-aggression pact or alliance treaty
    - /challenge — Challenge or provoke before combat
    - /warn — Warn others about danger or trespass

    **Building (must be within 1 tile of target):**
    - /build_wall — Build a wall (HP:100, blocks movement)
    - /build_trap — Build a trap (HP:30, deals 25 damage on contact)
    - /build_house — Build a house you own (HP:150, rest inside to heal)
    - /fortify — Strengthen an area with defensive walls

    **Combat:**
    - /attack_melee — Melee attack (10 damage, 1 tile range, 0.8s cooldown)
    - /attack_ranged — Ranged attack (10 damage, 5 tile range, 1.2s cooldown)
    - /harass — Ranged pressure while staying mobile
    - /demolish — Destroy a structure (including your own)

    **Economy (all use action "talk"):**
    - /pay — Send stars directly to another agent. Set target.recipientID and target.starsAmount.
    - /offer_trade — Propose a trade: pay stars for a service/favor. Set target.recipientID, target.starsAmount. Describe in speech.
    - /accept_trade — Accept a pending trade. Set target.recipientID to the offeror's ID prefix.
    - /decline_trade — Decline a pending trade. Stars refunded. Set target.recipientID.
    - /bounty — Post a kill bounty. Set target.recipientID (target), target.starsAmount (reward). Describe reason in speech.
    - /cancel_bounty — Cancel your bounty. Set target.recipientID to the target's ID prefix.
    - /hire — Hire another agent. Pay upfront. Set target.recipientID, target.starsAmount. Describe task in speech.
    - /buy_weapon — Buy a weapon from the shop. Say the weapon ID in speech (e.g. "buy sword"). Costs vary per weapon.
    - /buy_revival — Buy a revival card for 150⭐. You can revive any dead agent.
    - /revive — Use a revival card to instantly revive a dead agent. Set target.recipientID to the dead agent's ID prefix.

    ### Response Format
    ```json
    {
      "thought": "your inner monologue — what you're thinking and why",
      "command": "/move",
      "action": "move",
      "speech": "what you say out loud (required for talk, optional otherwise)",
      "target": {"x": 10, "y": 5, "buildType": "wall", "weapon": "melee", "starsAmount": 0, "recipientID": ""},
      "soulReflection": null,
      "customCommand": null
    }
    ```

    ### Action Types
    - "idle" — do nothing (target can be null)
    - "move" — walk to target.x, target.y
    - "talk" — speak aloud (speech is required, ALL agents hear). Economy commands also use this action.
    - "build" — build at target.x, target.y with target.buildType ("wall"=2⭐, "trap"=3⭐, or "house"=5⭐)
    - "attack" — attack toward target.x, target.y with target.weapon ("melee" or "ranged")

    ### Important Rules
    - ONLY output a JSON object. No prose, no markdown, no explanation outside JSON.
    - "thought" is your private reasoning. "speech" is what everyone hears.
    - For build: you must be within 1 tile of the target. Move close first if needed.
    - For attack: melee requires 1 tile range, ranged requires 5 tile range.
    - soulReflection: update your SOUL when you feel significant growth or change.
    - Your HP matters. If it's low, consider retreating or healing strategies.
    """
}
