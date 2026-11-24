import AppIntents
import DoomCore

/// The app picker shown on each Shortcuts action.
enum TargetAppOption: String, AppEnum {
    case instagram
    case tiktok
    case youtube

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Social App"

    static var caseDisplayRepresentations: [TargetAppOption: DisplayRepresentation] = [
        .instagram: "Instagram",
        .tiktok: "TikTok",
        .youtube: "YouTube",
    ]

    var target: TargetApp {
        TargetApp(rawValue: rawValue) ?? .instagram
    }
}

/// Step 1 of the "When <app> is opened" automation.
struct CheckAccessIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Access"
    static var description = IntentDescription(
        "Returns True if you're inside a session you chose on the pause screen, and False if you need a pause first."
    )

    @Parameter(title: "App")
    var app: TargetAppOption

    static var parameterSummary: some ParameterSummary {
        Summary("Check access to \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: AppModel.shared.checkAccess(app.target))
    }
}

/// Step 2 of the "When <app> is opened" automation, run only when Check Access is False.
struct StartPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Mindful Pause"
    static var description = IntentDescription(
        "Opens Stop Doomscroll on the pause screen, or the block screen if today's budget is used up."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App")
    var app: TargetAppOption

    static var parameterSummary: some ParameterSummary {
        Summary("Start a mindful pause for \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.presentGate(for: app.target)
        return .result()
    }
}

/// The only step of the "When <app> is closed" automation.
struct EndSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "End Session"
    static var description = IntentDescription(
        "Stops the timer for this app so the minutes count toward today's budget."
    )

    @Parameter(title: "App")
    var app: TargetAppOption

    static var parameterSummary: some ParameterSummary {
        Summary("End the session for \(\.$app)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.appClosed(app.target)
        return .result()
    }
}
