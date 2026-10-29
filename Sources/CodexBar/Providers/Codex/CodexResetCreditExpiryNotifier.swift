import CodexBarCore
import CryptoKit
import Foundation

@MainActor
struct CodexResetCreditExpiryNotifier {
    static let reminderThresholds: [TimeInterval] = [86400, 43200, 3600, 1800, 600]
    static let notificationPrefix = "codex-reset-credit-expiry"
    static let reminderFingerprintsKey = "codexResetCreditExpiryReminderFingerprints"
    static let maximumRememberedReminders = 320

    var userDefaults: UserDefaults = .standard
    var notificationPoster: (String, String, String) -> Void = { prefix, title, body in
        AppNotifications.shared.post(idPrefix: prefix, title: title, body: body)
    }

    func postExpiringCreditsIfNeeded(
        snapshot: CodexRateLimitResetCreditsSnapshot,
        enabled: Bool,
        resetStyle: ResetTimeDisplayStyle,
        now: Date = Date())
    {
        guard enabled else { return }
        var notifiedFingerprints = self.userDefaults.stringArray(forKey: Self.reminderFingerprintsKey) ?? []
        let expiringCredits = snapshot.availableInventory(at: now).credits.filter { credit in
            guard let expiresAt = credit.expiresAt,
                  let threshold = Self.reminderThresholds.last(where: { expiresAt.timeIntervalSince(now) <= $0 })
            else { return false }
            // On a late refresh, announce only the closest threshold, rather than replaying missed reminders.
            let material = "\(credit.id)\u{1f}\(expiresAt.timeIntervalSince1970)\u{1f}\(threshold)"
            let fingerprint = SHA256.hash(data: Data(material.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
            guard !notifiedFingerprints.contains(fingerprint) else { return false }
            notifiedFingerprints.append(fingerprint)
            return true
        }
        guard !expiringCredits.isEmpty else { return }

        // Keep the existing bounded history, allowing five receipts for each of 64 recently observed credits.
        if notifiedFingerprints.count > Self.maximumRememberedReminders {
            notifiedFingerprints.removeFirst(notifiedFingerprints.count - Self.maximumRememberedReminders)
        }
        self.userDefaults.set(notifiedFingerprints, forKey: Self.reminderFingerprintsKey)

        let expiringSnapshot = CodexRateLimitResetCreditsSnapshot(
            credits: expiringCredits,
            availableCount: expiringCredits.count,
            updatedAt: now)
        guard let presentation = LimitResetCreditsPresentation.make(
            snapshot: expiringSnapshot,
            resetStyle: resetStyle,
            now: now)
        else {
            return
        }
        self.notificationPoster(
            Self.notificationPrefix,
            "Codex · \(L("Limit Reset Credits"))",
            presentation.helpText)
    }
}
