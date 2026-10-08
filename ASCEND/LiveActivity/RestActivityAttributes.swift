import Foundation
import ActivityKit

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exercise: String
        var target: String
        var startedAt: Date
        var restEndsAt: Date
    }
    var sessionID: UUID
    var sessionTitle: String
}
