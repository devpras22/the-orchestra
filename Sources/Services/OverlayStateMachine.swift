import Foundation

/// Runs the canvas animation state machine using the inputs + conditions model.
/// External code calls `setInput()` to change named values; the engine evaluates
/// all outgoing edges from the current node whenever any input changes.
@MainActor
@Observable
final class OverlayStateMachine {

    enum Phase {
        case idle          // No video playing
        case looping       // Loop video at current node
        case transitioning // Transition video playing to another node
    }

    // MARK: - Public state

    private(set) var phase: Phase = .idle
    private(set) var currentNodeId: String
    private(set) var currentVideoURL: URL?
    private(set) var isLoopVideo = true

    let config: MaskoAnimationConfig

    // MARK: - Inputs

    /// Current values of all inputs (system + custom).
    /// No SwiftUI view reads this directly — excluded from observation to avoid needless invalidation.
    @ObservationIgnored
    private(set) var inputs: [String: ConditionValue] = [:]

    // MARK: - Debug state

    private(set) var lastInputChange: String?
    private(set) var lastInputTime: Date?
    private(set) var lastMatchResult: String?

    /// Human-readable name for the current node
    var currentNodeName: String {
        config.nodes.first(where: { $0.id == currentNodeId })?.name ?? currentNodeId
    }

    /// Available transition edges from the current node (for debug display)
    var availableEdges: [String] {
        config.edges.compactMap { edge in
            guard edge.source == currentNodeId, !edge.isLoop else { return nil }
            let label: String
            if let conditions = edge.conditions, !conditions.isEmpty {
                label = conditions.map { c in
                    "\(c.input) \(c.op) \(conditionValueStr(c.value))"
                }.joined(separator: " & ")
            } else {
                label = "no condition"
            }
            let targetName = config.nodes.first(where: { $0.id == edge.target })?.name ?? edge.target
            return "\(label) → \(targetName)"
        }
    }

    // MARK: - Private state

    private var pendingEdge: MaskoAnimationEdge?
    private var loopCount = 0
    private var nodeArrivalTime: Date?
    private var nodeTimeTimer: Timer?
    private var nodeTimeGeneration: Int = 0

    // MARK: - Init

    init(config: MaskoAnimationConfig) {
        self.config = config
        self.currentNodeId = config.initialNode
        initializeInputs()
    }

    /// Agent state input names (generic prefix).
    /// Old mascot JSONs use "claudeCode::" - both prefixes are kept in sync.
    static let agentPrefix = "agent::"
    /// Legacy prefix for backward compatibility with existing mascot JSON files
    static let legacyPrefix = "claudeCode::"

    /// The 5 persistent agent state inputs (not auto-reset triggers)
    private static let agentStateInputs: Set<String> = [
        "isWorking", "isIdle", "isAlert", "isCompacting", "sessionCount",
    ]

    private func initializeInputs() {
        // Node-local inputs (reset on arrival)
        inputs["clicked"] = .bool(false)
        inputs["mouseOver"] = .bool(false)
        inputs["loopCount"] = .number(0)
        inputs["nodeTime"] = .number(0)

        // Agent state inputs - set both "agent::" and "claudeCode::" so old JSONs work
        setAgentStateInput("isWorking", .bool(false))
        setAgentStateInput("isIdle", .bool(true))
        setAgentStateInput("isAlert", .bool(false))
        setAgentStateInput("isCompacting", .bool(false))
        setAgentStateInput("sessionCount", .number(0))

        // Custom inputs from config
        if let configInputs = config.inputs {
            for input in configInputs {
                inputs[input.name] = input.defaultValue
            }
        }
    }

    /// Set an agent state input under both "agent::" and "claudeCode::" prefixes.
    /// This ensures old mascot JSONs referencing "claudeCode::isWorking" keep working.
    func setAgentStateInput(_ name: String, _ value: ConditionValue) {
        inputs[Self.agentPrefix + name] = value
        inputs[Self.legacyPrefix + name] = value
    }

    /// Set an agent event trigger under both prefixes.
    func setAgentEventTrigger(_ eventName: String) {
        setInput(Self.agentPrefix + eventName, .bool(true))
        // Also set legacy prefix so old JSONs with "claudeCode::PreToolUse" conditions work
        inputs[Self.legacyPrefix + eventName] = .bool(true)
    }

    // MARK: - Public API

    /// Start the state machine: play the initial node's loop video
    func start() {
        print("[masko-desktop] State machine starting — initial node: \(currentNodeName) (\(currentNodeId))")
        print("[masko-desktop]   Config: \(config.nodes.count) nodes, \(config.edges.count) edges")

        let conditionlessCount = config.edges.filter { !$0.isLoop && ($0.conditions == nil || $0.conditions!.isEmpty) }.count
        if conditionlessCount > 0 {
            print("[masko-desktop] WARNING: \(conditionlessCount) transition edges have NO CONDITIONS")
        }

        arriveAtNode(currentNodeId)
    }

    /// Set an input value and evaluate conditions on all outgoing edges.
    func setInput(_ name: String, _ value: ConditionValue) {
        // Skip evaluation if value didn't change (check BEFORE writing to avoid needless observation)
        let oldValue = inputs[name]
        if let old = oldValue, conditionValuesEqual(old, value) { return }

        inputs[name] = value

        // Only update debug state when debug HUD is visible
        if UserDefaults.standard.bool(forKey: "overlay_show_debug") {
            lastInputChange = "\(name) = \(conditionValueStr(value))"
            lastInputTime = Date()
        }

        print("[masko-desktop] Input: \(name) = \(conditionValueStr(value))")

        evaluateAndFire(changedInput: name)
    }

    /// Called by the view on tap
    func handleClick() {
        setInput("clicked", .bool(true))
    }

    /// Called by the view on hover
    func handleMouseOver(_ isOver: Bool) {
        setInput("mouseOver", .bool(isOver))
    }

    /// Called by the view when a loop video completes one cycle
    func handleLoopCycleCompleted() {
        guard phase == .looping else { return }
        loopCount += 1
        setInput("loopCount", .number(Double(loopCount)))
    }

    /// Called by the view when a non-looping (transition) video finishes
    func handleVideoEnded() {
        guard phase == .transitioning, let edge = pendingEdge else { return }

        let targetName = config.nodes.first(where: { $0.id == edge.target })?.name ?? edge.target
        print("[masko-desktop] Transition video ended — arriving at \(targetName)")

        pendingEdge = nil
        arriveAtNode(edge.target)
    }

    // MARK: - Condition Evaluation

    private func evaluateAndFire(changedInput: String) {
        guard phase == .looping || phase == .idle else {
            lastMatchResult = "Ignored (phase=\(phase))"
            return
        }

        // Lazily refresh nodeTime when other inputs change, so compound conditions
        // (e.g. nodeTime >= 5000 AND isWorking == true) use a fresh value
        if changedInput != "nodeTime", let arrival = nodeArrivalTime {
            let hasNodeTimeEdge = config.edges.contains { edge in
                edge.source == currentNodeId && !edge.isLoop &&
                edge.conditions?.contains(where: { $0.input == "nodeTime" }) == true
            }
            if hasNodeTimeEdge {
                let elapsed = Date().timeIntervalSince(arrival) * 1000
                inputs["nodeTime"] = .number(elapsed)
            }
        }

        // Check all non-loop edges from current node — first match wins
        for edge in config.edges where edge.source == currentNodeId && !edge.isLoop {
            if evaluateConditions(edge.conditions) {
                let targetName = config.nodes.first(where: { $0.id == edge.target })?.name ?? edge.target
                lastMatchResult = "Matched → \(targetName)"
                print("[masko-desktop] Conditions met → \(targetName)")

                // Reset trigger-type inputs after firing
                resetTriggerInput(changedInput)

                playTransition(edge)
                return
            }
        }

        lastMatchResult = "No match from \(currentNodeName)"
    }

    /// All conditions must be true (AND logic). Empty conditions = never fires.
    private func evaluateConditions(_ conditions: [MaskoAnimationCondition]?) -> Bool {
        guard let conditions, !conditions.isEmpty else { return false }
        return conditions.allSatisfy { condition in
            guard let inputValue = inputs[condition.input] else { return false }
            return compare(inputValue, condition.op, condition.value)
        }
    }

    private func compare(_ lhs: ConditionValue, _ op: String, _ rhs: ConditionValue) -> Bool {
        let left = lhs.doubleValue
        let right = rhs.doubleValue
        switch op {
        case "==": return left == right
        case "!=": return left != right
        case ">":  return left > right
        case "<":  return left < right
        case ">=": return left >= right
        case "<=": return left <= right
        default:   return false
        }
    }

    private func resetTriggerInput(_ name: String) {
        // Built-in trigger: clicked always resets
        if name == "clicked" {
            inputs["clicked"] = .bool(false)
        }
        // Agent event triggers (agent::* and claudeCode::*) always reset,
        // but persistent state inputs (isWorking, isIdle, etc.) do not.
        for prefix in [Self.agentPrefix, Self.legacyPrefix] {
            if name.hasPrefix(prefix) {
                let suffix = String(name.dropFirst(prefix.count))
                if !Self.agentStateInputs.contains(suffix) {
                    // Reset both prefixes for this trigger
                    inputs[Self.agentPrefix + suffix] = .bool(false)
                    inputs[Self.legacyPrefix + suffix] = .bool(false)
                }
                break
            }
        }
        // Custom trigger-type inputs reset after firing
        if let configInputs = config.inputs,
           let def = configInputs.first(where: { $0.name == name }),
           def.type == "trigger" {
            inputs[name] = .bool(false)
        }
    }

    // MARK: - Node Arrival

    private func arriveAtNode(_ nodeId: String) {
        cancelNodeTimeTimer()
        loopCount = 0
        currentNodeId = nodeId

        // Reset node-local inputs
        inputs["loopCount"] = .number(0)
        inputs["nodeTime"] = .number(0)
        inputs["clicked"] = .bool(false)

        let nodeName = config.nodes.first(where: { $0.id == nodeId })?.name ?? nodeId

        // Find loop edge for this node
        let loopEdge = config.edges.first { $0.source == nodeId && $0.target == nodeId && $0.isLoop }

        if let loopEdge, let hevc = loopEdge.videos.hevc, let url = URL(string: hevc) {
            currentVideoURL = VideoCache.shared.resolve(url)
            isLoopVideo = true
            phase = .looping
            print("[masko-desktop] Arrived at \(nodeName) — looping")
        } else {
            phase = .idle
            print("[masko-desktop] Arrived at \(nodeName) — idle (no loop video)")
        }

        if !availableEdges.isEmpty {
            print("[masko-desktop]   Edges: \(availableEdges.joined(separator: ", "))")
        }

        // Start nodeTime timer if any edge uses it
        startNodeTimeTimer()

        // Immediately evaluate — session inputs may already match an edge
        evaluateAndFire(changedInput: "nodeArrival")
    }

    // MARK: - nodeTime Timer

    private func startNodeTimeTimer() {
        nodeArrivalTime = Date()
        nodeTimeGeneration += 1
        let generation = nodeTimeGeneration

        // Collect all nodeTime thresholds from outgoing edges
        let thresholds: [Double] = config.edges.compactMap { edge in
            guard edge.source == currentNodeId, !edge.isLoop else { return nil }
            guard let conditions = edge.conditions else { return nil }
            return conditions.first(where: { $0.input == "nodeTime" })?.value.doubleValue
        }
        guard !thresholds.isEmpty else { return }

        // Schedule a one-shot check at each unique threshold instead of polling every 100ms
        for threshold in Set(thresholds).sorted() {
            let delaySec = threshold / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delaySec) { [weak self] in
                guard let self, self.nodeTimeGeneration == generation,
                      let arrival = self.nodeArrivalTime else { return }
                let elapsed = Date().timeIntervalSince(arrival) * 1000
                self.setInput("nodeTime", .number(elapsed))
            }
        }
    }

    private func cancelNodeTimeTimer() {
        nodeTimeGeneration += 1 // Invalidates all pending closures
        nodeTimeTimer?.invalidate()
        nodeTimeTimer = nil
    }

    // MARK: - Transition Playback

    private func playTransition(_ edge: MaskoAnimationEdge) {
        guard phase == .looping || phase == .idle else { return }
        guard let hevc = edge.videos.hevc, let url = URL(string: hevc) else {
            let targetName = config.nodes.first(where: { $0.id == edge.target })?.name ?? edge.target
            print("[masko-desktop] No transition video — jumping directly to \(targetName)")
            arriveAtNode(edge.target)
            return
        }

        let sourceName = config.nodes.first(where: { $0.id == edge.source })?.name ?? edge.source
        let targetName = config.nodes.first(where: { $0.id == edge.target })?.name ?? edge.target
        print("[masko-desktop] Playing transition: \(sourceName) → \(targetName)")

        cancelNodeTimeTimer()
        pendingEdge = edge
        currentVideoURL = VideoCache.shared.resolve(url)
        isLoopVideo = false
        phase = .transitioning
    }

    // MARK: - Helpers

    private func conditionValueStr(_ value: ConditionValue) -> String {
        switch value {
        case .bool(let b): b ? "true" : "false"
        case .number(let n): n == n.rounded() ? "\(Int(n))" : "\(n)"
        }
    }

    private func conditionValuesEqual(_ a: ConditionValue, _ b: ConditionValue) -> Bool {
        a.doubleValue == b.doubleValue
    }
}
