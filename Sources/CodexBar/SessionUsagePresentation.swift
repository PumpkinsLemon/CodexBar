import CodexBarCore
import Foundation

enum SessionUsagePresentation {
    static func sessions(
        _ sessions: [CostUsageSessionBreakdown],
        matching query: String,
        hidePersonalInfo: Bool) -> [CostUsageSessionBreakdown]
    {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions.filter { session in
            guard !query.isEmpty else { return true }
            let identity = CostHistoryIdentity(
                sessionID: session.sessionID,
                title: session.title,
                hidePersonalInfo: hidePersonalInfo)
            // Hidden titles must not be discoverable indirectly through search results.
            return identity.name.localizedStandardContains(query)
                || session.sessionID.localizedStandardContains(query)
        }.sorted {
            if $0.lastActivity != $1.lastActivity { return $0.lastActivity > $1.lastActivity }
            return $0.sessionID < $1.sessionID
        }
    }

    static func uncachedInput(_ session: CostUsageSessionBreakdown) -> Int? {
        guard let input = session.inputTokens, let cached = session.cachedInputTokens,
              input >= 0, cached >= 0, cached <= input
        else { return nil }
        return input - cached
    }

    static func convertedCost(_ cost: Double?, multiplier: Double) -> Double? {
        guard let cost, cost.isFinite, cost >= 0, multiplier.isFinite, multiplier > 0 else { return nil }
        let result = cost * multiplier
        return result.isFinite ? result : nil
    }
}
