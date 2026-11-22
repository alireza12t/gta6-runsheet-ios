import ActivityKit
import Foundation

/// Starts, updates and ends the run Live Activity from local state. No push tokens.

enum LiveRun {
    static func state(for run: RunPlan) -> RunActivityAttributes.ContentState {
        let cur: RunStop? = run.current
        var kind = ""
        if let cur { kind = (cur.kind == .place ? cur.sub : cur.tag) ?? "" }
        let first: String = run.stops.first?.name.shortStop ?? ""
        let last: String = run.stops.last?.name.shortStop ?? ""
        return RunActivityAttributes.ContentState(
            index: min(run.idx, run.total), total: run.total,
            nextName: cur?.name ?? "Run complete", nextKind: kind,
            firstName: first, lastName: last)
    }

    static func sync(_ run: RunPlan?) async {
        let current = Activity<RunActivityAttributes>.activities
        guard let run else {
            for a in current { await a.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let content = ActivityContent(state: state(for: run), staleDate: nil)
        if run.isComplete {
            for a in current { await a.end(content, dismissalPolicy: .after(.now.addingTimeInterval(15 * 60))) }
            return
        }
        if let a = current.first(where: { $0.attributes.title == run.title }) {
            await a.update(content)
            for other in current where other.id != a.id { await other.end(nil, dismissalPolicy: .immediate) }
        } else {
            for a in current { await a.end(nil, dismissalPolicy: .immediate) }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: RunActivityAttributes(title: run.title), content: content, pushType: nil)
        }
    }
}
