import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct SessionUsagePresentationTests {
    @Test
    func `search finds a named conversation case insensitively without changing accounting`() {
        let session = Self.session(id: "thread-alpha", title: "Fix cache accounting")
        let original = session
        let matches = SessionUsagePresentation.sessions([session], matching: "  CACHE  ", hidePersonalInfo: false)
        #expect(matches == [original])
        #expect(session == original)
    }

    @Test
    func `search keeps IDs available but cannot reveal hidden conversation names`() {
        let session = Self.session(id: "thread-alpha", title: "Confidential customer incident")
        #expect(SessionUsagePresentation.sessions(
            [session], matching: "customer", hidePersonalInfo: true).isEmpty)
        #expect(SessionUsagePresentation.sessions(
            [session], matching: "ALPHA", hidePersonalInfo: true) == [session])
    }

    @Test
    func `search considers all retained conversations before ordering`() {
        let sessions = (0..<120).map { Self.session(id: "thread-\($0)", title: "Conversation \($0)") }
        #expect(SessionUsagePresentation.sessions(sessions, matching: "", hidePersonalInfo: false).count == 120)
        #expect(SessionUsagePresentation.sessions(
            sessions, matching: "Conversation 119", hidePersonalInfo: false).map(\.sessionID) == ["thread-119"])
    }

    @Test
    func `conversations are ordered by recency with a stable tie break`() {
        let oldest = Self.session(id: "old", activity: 1)
        let latestB = Self.session(id: "b", activity: 2)
        let latestA = Self.session(id: "a", activity: 2)
        #expect(SessionUsagePresentation.sessions(
            [oldest, latestB, latestA], matching: "", hidePersonalInfo: false).map(\.sessionID) == ["a", "b", "old"])
    }

    @Test
    func `uncached input excludes cache hits and does not add reasoning again`() {
        let session = Self.session(id: "example")
        #expect(SessionUsagePresentation.uncachedInput(session) == 30)
        #expect(session.inputTokens == 120)
        #expect(session.cachedInputTokens == 90)
        #expect(session.outputTokens == 20)
        #expect(session.reasoningTokens == 10)
        #expect(session.totalTokens == 140)
    }

    @Test
    func `unknown or inconsistent cached input stays unavailable instead of becoming zero`() {
        #expect(SessionUsagePresentation.uncachedInput(Self.session(id: "missing", cached: nil)) == nil)
        #expect(SessionUsagePresentation.uncachedInput(Self.session(id: "invalid", cached: 121)) == nil)
        #expect(SessionUsagePresentation.uncachedInput(Self.session(id: "all-cached", cached: 120)) == 0)
    }

    @Test
    func `cost conversion preserves unknown zero and source currency semantics`() {
        #expect(SessionUsagePresentation.convertedCost(nil, multiplier: 2) == nil)
        #expect(SessionUsagePresentation.convertedCost(0, multiplier: 2) == 0)
        #expect(SessionUsagePresentation.convertedCost(3, multiplier: 2) == 6)
        #expect(SessionUsagePresentation.convertedCost(.infinity, multiplier: 1) == nil)
        #expect(SessionUsagePresentation.convertedCost(3, multiplier: .infinity) == nil)
    }

    private static func session(
        id: String,
        title: String? = nil,
        activity: TimeInterval = 1,
        cached: Int? = 90) -> CostUsageSessionBreakdown
    {
        CostUsageSessionBreakdown(
            sessionID: id,
            lastActivity: Date(timeIntervalSince1970: activity),
            inputTokens: 120,
            cachedInputTokens: cached,
            outputTokens: 20,
            reasoningTokens: 10,
            totalTokens: 140,
            requestCount: 2,
            costUSD: 0.02,
            modelBreakdowns: [],
            title: title)
    }
}
