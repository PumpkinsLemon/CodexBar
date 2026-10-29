import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
struct CodexResetCreditExpiryNotifierTests {
    private static let expiry = Date(timeIntervalSince1970: 1_900_000_000)

    @Test
    func `each countdown threshold posts once including after notifier recreation`() {
        let defaults = InMemoryUserDefaults()
        var posts: [String] = []
        let snapshot = Self.snapshot([Self.credit(id: "credit", expiresAt: Self.expiry)])
        for (index, remaining) in [86400.0, 43200, 3600, 1800, 600].enumerated() {
            // Recreating the notifier simulates a refresh or application restart using the same persisted defaults.
            let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, body in posts.append(body) }
            notifier.postExpiringCreditsIfNeeded(
                snapshot: snapshot,
                enabled: true,
                resetStyle: .countdown,
                now: Self.expiry.addingTimeInterval(-remaining - 1))
            #expect(posts.count == index)
            notifier.postExpiringCreditsIfNeeded(
                snapshot: snapshot,
                enabled: true,
                resetStyle: .countdown,
                now: Self.expiry.addingTimeInterval(-remaining))
            notifier.postExpiringCreditsIfNeeded(
                snapshot: snapshot,
                enabled: true,
                resetStyle: .countdown,
                now: Self.expiry.addingTimeInterval(-remaining + 1))
            #expect(posts.count == index + 1)
        }
        #expect(posts == [
            "1. Expires in 1d",
            "1. Expires in 12h",
            "1. Expires in 1h",
            "1. Expires in 30m",
            "1. Expires in 10m",
        ])
    }

    @Test
    func `disabled reminders do not post or consume a threshold and reenabling retains deduplication`() {
        let defaults = InMemoryUserDefaults()
        var postCount = 0
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, _ in postCount += 1 }
        let snapshot = Self.snapshot([Self.credit(id: "credit", expiresAt: Self.expiry)])
        let now = Self.expiry.addingTimeInterval(-3600)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: false, resetStyle: .countdown, now: now)
        #expect(postCount == 0)
        #expect(defaults.object(forKey: CodexResetCreditExpiryNotifier.reminderFingerprintsKey) == nil)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: true, resetStyle: .countdown, now: now)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: false, resetStyle: .countdown, now: now)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: true, resetStyle: .absolute, now: now)
        #expect(postCount == 1)
    }

    @Test
    func `late refresh sends the nearest reminder without replaying every missed threshold`() {
        let defaults = InMemoryUserDefaults()
        var posts: [String] = []
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, body in posts.append(body) }
        let snapshot = Self.snapshot([Self.credit(id: "credit", expiresAt: Self.expiry)])
        for remaining in [540.0, 300, 1, 0, -1] {
            notifier.postExpiringCreditsIfNeeded(
                snapshot: snapshot,
                enabled: true,
                resetStyle: .countdown,
                now: Self.expiry.addingTimeInterval(-remaining))
        }
        #expect(posts == ["1. Expires in 9m"])
    }

    @Test
    func `posts bounded receipts without persisting or logging raw credit IDs`() throws {
        let defaults = InMemoryUserDefaults()
        let rawID = "private-provider-credit-id"
        var posts: [(prefix: String, title: String, body: String)] = []
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { prefix, title, body in
            posts.append((prefix, title, body))
        }
        let snapshot = Self.snapshot([Self.credit(id: rawID, expiresAt: Self.expiry)])
        let now = Self.expiry.addingTimeInterval(-86400)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: true, resetStyle: .countdown, now: now)
        notifier.postExpiringCreditsIfNeeded(snapshot: snapshot, enabled: true, resetStyle: .countdown, now: now)
        #expect(posts.count == 1)
        #expect(posts[0].prefix == CodexResetCreditExpiryNotifier.notificationPrefix)
        #expect(posts[0].title == "Codex · Limit Reset Credits")
        #expect(!posts[0].prefix.contains(rawID))
        #expect(!posts[0].body.contains(rawID))
        let fingerprints = try #require(defaults.stringArray(
            forKey: CodexResetCreditExpiryNotifier.reminderFingerprintsKey))
        #expect(fingerprints.count == 1)
        #expect(fingerprints.allSatisfy { $0.count == 64 && !$0.contains(rawID) })
    }

    @Test
    func `adding a credit or switching accounts does not repeat another credits reminder`() {
        let defaults = InMemoryUserDefaults()
        var posts: [String] = []
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, body in posts.append(body) }
        let first = Self.credit(id: "first-account", expiresAt: Self.expiry)
        let second = Self.credit(id: "second-account", expiresAt: Self.expiry)
        let now = Self.expiry.addingTimeInterval(-86400)
        for credits in [[first], [second], [first, second], [second], [first]] {
            notifier.postExpiringCreditsIfNeeded(
                snapshot: Self.snapshot(credits),
                enabled: true,
                resetStyle: .countdown,
                now: now)
        }
        #expect(posts == ["1. Expires in 1d", "1. Expires in 1d"])
    }

    @Test
    func `a changed expiry rearms the same credit without reusing the prior deadline`() {
        let defaults = InMemoryUserDefaults()
        var postCount = 0
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, _ in postCount += 1 }
        let now = Self.expiry.addingTimeInterval(-600)
        for expiry in [Self.expiry, Self.expiry.addingTimeInterval(-60), Self.expiry] {
            notifier.postExpiringCreditsIfNeeded(
                snapshot: Self.snapshot([Self.credit(id: "credit", expiresAt: expiry)]),
                enabled: true,
                resetStyle: .countdown,
                now: now)
        }
        #expect(postCount == 2)
    }

    @Test
    func `expired used redeeming unknown and no-expiry credits stay silent`() {
        let defaults = InMemoryUserDefaults()
        var postCount = 0
        let notifier = CodexResetCreditExpiryNotifier(userDefaults: defaults) { _, _, _ in postCount += 1 }
        let now = Self.expiry.addingTimeInterval(-600)
        let credits = [
            Self.credit(id: "expired-time", expiresAt: now),
            Self.credit(id: "expired-status", expiresAt: Self.expiry, status: .expired),
            Self.credit(id: "used", expiresAt: Self.expiry, status: .redeemed),
            Self.credit(id: "redeeming", expiresAt: Self.expiry, status: .redeeming),
            Self.credit(id: "unknown", expiresAt: Self.expiry, status: .unknown("future-status")),
            Self.credit(id: "no-expiry", expiresAt: nil),
        ]
        notifier.postExpiringCreditsIfNeeded(
            snapshot: Self.snapshot(credits),
            enabled: true,
            resetStyle: .countdown,
            now: now)
        #expect(postCount == 0)
        #expect(defaults.object(forKey: CodexResetCreditExpiryNotifier.reminderFingerprintsKey) == nil)
    }

    private static func snapshot(_ credits: [CodexRateLimitResetCredit]) -> CodexRateLimitResetCreditsSnapshot {
        CodexRateLimitResetCreditsSnapshot(credits: credits, availableCount: credits.count, updatedAt: self.expiry)
    }

    private static func credit(
        id: String,
        expiresAt: Date?,
        status: CodexRateLimitResetCreditStatus = .available) -> CodexRateLimitResetCredit
    {
        CodexRateLimitResetCredit(
            id: id,
            resetType: "codex_rate_limits",
            status: status,
            grantedAt: self.expiry.addingTimeInterval(-86400 * 30),
            expiresAt: expiresAt,
            redeemStartedAt: nil,
            redeemedAt: nil,
            title: nil,
            description: nil)
    }
}
