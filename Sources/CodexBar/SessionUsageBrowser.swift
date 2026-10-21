import AppKit
import CodexBarCore
import SwiftUI

struct SessionUsageBrowserContext: Sendable {
    let providerName: String
    let windowLabel: String
    let sessions: [CostUsageSessionBreakdown]
    let currencyCode: String
    let costMultiplier: Double
    let timeZone: TimeZone
}

@MainActor
final class SessionUsagePresenter {
    static let shared = SessionUsagePresenter()
    private var windowController: NSWindowController?

    func present(context: SessionUsageBrowserContext, settings: SettingsStore, sessionID: String?) {
        let controller: NSWindowController
        if let existing = self.windowController {
            controller = existing
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 940, height: 660),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.contentMinSize = NSSize(width: 780, height: 520)
            window.center()
            controller = NSWindowController(window: window)
            self.windowController = controller
        }
        controller.window?.title = "\(L("Sessions")) · \(context.providerName)"
        controller.window?.contentViewController = NSHostingController(rootView: SessionUsageBrowser(
            context: context,
            settings: settings,
            selectedSessionID: sessionID).codexBarLocalized())
        NSApp.activate()
        controller.showWindow(nil)
        controller.window?.deminiaturize(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
struct SessionUsageBrowser: View {
    let context: SessionUsageBrowserContext
    @Bindable var settings: SettingsStore
    @State private var query = ""
    @State private var selectedSessionID: String?

    init(context: SessionUsageBrowserContext, settings: SettingsStore, selectedSessionID: String? = nil) {
        self.context = context
        self.settings = settings
        self._selectedSessionID = State(initialValue: selectedSessionID)
    }

    private var sessions: [CostUsageSessionBreakdown] {
        SessionUsagePresentation.sessions(
            self.context.sessions,
            matching: self.query,
            hidePersonalInfo: self.settings.hidePersonalInfo)
    }

    private var selectedSession: CostUsageSessionBreakdown? {
        self.sessions.first { $0.sessionID == self.selectedSessionID } ?? self.sessions.first
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                TextField(L("Search sessions"), text: self.$query)
                    .textFieldStyle(.roundedBorder)
                    .padding(12)
                List(selection: self.$selectedSessionID) {
                    ForEach(self.sessions) { session in
                        self.sessionRow(session)
                            .tag(session.sessionID)
                    }
                }
                .overlay {
                    if self.sessions.isEmpty {
                        ContentUnavailableView(L("No matching sessions"), systemImage: "magnifyingglass")
                    }
                }
            }
            .frame(minWidth: 260, idealWidth: 320, maxWidth: 400)

            Group {
                if let session = self.selectedSession {
                    self.details(session)
                } else {
                    ContentUnavailableView(L("Select a session"), systemImage: "text.bubble")
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if self.selectedSessionID == nil { self.selectedSessionID = self.sessions.first?.sessionID }
        }
        .onChange(of: self.sessions.map(\.sessionID)) { _, ids in
            if !ids.contains(self.selectedSessionID ?? "") { self.selectedSessionID = ids.first }
        }
        .onChange(of: self.settings.hidePersonalInfo) { _, _ in
            self.query = ""
        }
        .environment(\.timeZone, self.context.timeZone)
    }

    private func sessionRow(_ session: CostUsageSessionBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(self.identity(session).name)
                .fontWeight(.medium)
                .lineLimit(1)
                .help(self.identity(session).name)
            HStack {
                Text(self.tokenText(session.totalTokens))
                Spacer(minLength: 6)
                Text(self.costText(session.costUSD))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            Text(self.dateText(session.lastActivity))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private func details(_ session: CostUsageSessionBreakdown) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(self.identity(session).name)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    if !self.settings.hidePersonalInfo {
                        Text(session.sessionID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Text("\(self.context.providerName) · \(L(self.context.windowLabel))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(self.dateText(session.lastActivity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if self.settings.hidePersonalInfo {
                        Label(L("hide_personal_info_title"), systemImage: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 18) {
                    GridRow {
                        self.metric(L("Input"), value: self.tokenText(session.inputTokens))
                        self.metric(L("Cached input"), value: self.tokenText(session.cachedInputTokens))
                    }
                    GridRow {
                        self.metric(L("Uncached input"), value: self.tokenText(
                            SessionUsagePresentation.uncachedInput(session)))
                        self.metric(L("Output"), value: self.tokenText(session.outputTokens))
                    }
                    GridRow {
                        self.metric(L("Reasoning"), value: self.tokenText(session.reasoningTokens))
                        self.metric(L("Requests"), value: self.tokenText(session.requestCount))
                    }
                    GridRow {
                        self.metric(L("Total"), value: self.tokenText(session.totalTokens))
                        self.metric(L("Estimated spend"), value: self.costText(session.costUSD))
                    }
                }

                Text(L("Cached input is included in input; reasoning is included in output."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L("codex_api_estimate_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !session.modelBreakdowns.isEmpty {
                    Divider()
                    Text(L("Models")).font(.headline)
                    ForEach(Array(session.modelBreakdowns.enumerated()), id: \.offset) { _, model in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(UsageFormatter.modelDisplayName(model.modelName))
                                Text(L(
                                    "Input %@ · cached %@ · output %@",
                                    self.tokenText(model.inputTokens),
                                    self.tokenText(model.cacheReadTokens),
                                    self.tokenText(model.outputTokens)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 12)
                            Text(self.costText(model.costUSD)).monospacedDigit()
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit()).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identity(_ session: CostUsageSessionBreakdown) -> CostHistoryIdentity {
        CostHistoryIdentity(
            sessionID: session.sessionID, title: session.title, hidePersonalInfo: self.settings.hidePersonalInfo)
    }

    private func tokenText(_ value: Int?) -> String {
        guard let value, value >= 0 else { return "—" }
        return value.formatted(.number.locale(codexBarLocalizedLocale()))
    }

    private func costText(_ value: Double?) -> String {
        SessionUsagePresentation.convertedCost(value, multiplier: self.context.costMultiplier)
            .map { UsageFormatter.currencyString($0, currencyCode: self.context.currencyCode) } ?? "—"
    }

    private func dateText(_ date: Date) -> String {
        var format = Date.FormatStyle.dateTime.year().month().day().hour().minute()
        format.locale = codexBarLocalizedLocale()
        format.timeZone = self.context.timeZone
        return date.formatted(format)
    }
}
