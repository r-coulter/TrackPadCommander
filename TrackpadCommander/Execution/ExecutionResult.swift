import Foundation

struct ExecutionResult: Codable, Identifiable, Hashable {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date
    var exitStatus: Int32?
    var stdoutTail: String
    var stderrTail: String
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        finishedAt: Date,
        exitStatus: Int32?,
        stdoutTail: String = "",
        stderrTail: String = "",
        errorDescription: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitStatus = exitStatus
        self.stdoutTail = stdoutTail
        self.stderrTail = stderrTail
        self.errorDescription = errorDescription
    }

    var succeeded: Bool {
        errorDescription == nil && (exitStatus ?? 0) == 0
    }
}
