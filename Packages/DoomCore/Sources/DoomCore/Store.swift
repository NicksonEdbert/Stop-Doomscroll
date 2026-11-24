import Foundation

/// Everything the app saves.
public struct AppData: Codable, Equatable, Sendable {
    public var plan: BudgetPlan
    public var ledger: Ledger
    public var onboardingDone: Bool

    public init(plan: BudgetPlan, ledger: Ledger = Ledger(), onboardingDone: Bool = false) {
        self.plan = plan
        self.ledger = ledger
        self.onboardingDone = onboardingDone
    }

    /// A new install: the step-down plan starts today.
    public static func fresh(now: Date, calendar: Calendar) -> AppData {
        AppData(plan: BudgetPlan(planStart: now, calendar: calendar))
    }
}

/// Saves `AppData` as a JSON file.
public struct FileStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Returns nil if nothing has been saved yet.
    public func load() throws -> AppData? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppData.self, from: data)
    }

    public func save(_ appData: AppData) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(appData)
        try data.write(to: url, options: .atomic)
    }
}
