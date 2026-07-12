/// Tracks one recoverable degradation without clearing a different failure
/// that happens to use the same `ModuleState.degraded` case.
public struct RecoverableFailureHealth: Sendable {
    private var failureReason: String?

    public init() {}

    public mutating func failed(reason: String) -> ModuleState {
        failureReason = reason
        return .degraded(reason: reason)
    }

    public mutating func recovered(current state: ModuleState) -> ModuleState {
        guard let failureReason else { return state }
        self.failureReason = nil
        if case .degraded(let currentReason) = state, currentReason == failureReason {
            return .running
        }
        return state
    }
}
