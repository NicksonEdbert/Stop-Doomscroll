import Foundation

/// The apps Stop Doomscroll puts a pause in front of.
public enum TargetApp: String, Codable, CaseIterable, Identifiable, Sendable {
    case instagram
    case tiktok
    case youtube

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        }
    }

    /// URL schemes to try, in order, when sending you on to the app after a pause.
    public var urlSchemes: [String] {
        switch self {
        case .instagram: return ["instagram://"]
        case .tiktok: return ["tiktok://", "snssdk1233://"]
        case .youtube: return ["youtube://"]
        }
    }
}
