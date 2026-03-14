import CoreGraphics
import Foundation

struct TouchContact: Hashable, Sendable {
    var identifier: Int
    var normalizedPosition: CGPoint
    var normalizedVelocity: CGVector
}

struct TouchFrame: Hashable, Sendable {
    var deviceID: String
    var timestamp: TimeInterval
    var contacts: [TouchContact]
}
