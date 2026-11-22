import ActivityKit
import Foundation

/// The Live Activity for a run in progress. Shared by the app and the widget extension.
/// Everything here is local: the app starts and updates it, no push server.
struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var index: Int        // stops done so far
        var total: Int
        var nextName: String
        var nextKind: String  // "Stunt jumps", "CLOSING", ...
        var firstName: String
        var lastName: String

        var fraction: Double { total == 0 ? 0 : Double(index) / Double(total) }
        var left: Int { max(0, total - index) }
    }

    var title: String
}
