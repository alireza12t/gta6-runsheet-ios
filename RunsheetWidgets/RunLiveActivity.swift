import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RunsheetWidgetsBundle: WidgetBundle {
    var body: some Widget { RunLiveActivity() }
}

private let accent = Color(red: 1, green: 0.42, blue: 0.10)  // #FF6B1A, the dark-mode accent

/// Flighty-style run tracker: next stop, a progress line with a dot, stops left.
struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { ctx in
            LockScreenRun(title: ctx.attributes.title, s: ctx.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            let s = ctx.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STOP").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        Text("\(min(s.index + 1, s.total))/\(s.total)").font(.system(size: 20, weight: .bold, design: .monospaced))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TO GO").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        Text("\(s.left)").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundStyle(accent)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(ctx.attributes.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        LiveLine(fraction: s.fraction)
                        HStack(alignment: .firstTextBaseline) {
                            Text(s.nextKind.uppercased()).font(.system(size: 10, weight: .bold)).foregroundStyle(accent)
                            Text(s.nextName).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                    Text("\(min(s.index + 1, s.total))/\(s.total)").font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            } compactTrailing: {
                Text(s.nextName.shortName).font(.system(size: 12, weight: .semibold)).lineLimit(1).frame(maxWidth: 70)
            } minimal: {
                ZStack {
                    Circle().stroke(.white.opacity(0.25), lineWidth: 3)
                    Circle().trim(from: 0, to: s.fraction).stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                }
                .padding(2)
            }
            .keylineTint(accent)
        }
    }
}

struct LockScreenRun: View {
    let title: String
    let s: RunActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RUNSHEET").font(.system(size: 11, weight: .heavy)).kerning(1.5).foregroundStyle(accent)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                Spacer()
                Text("STOP \(min(s.index + 1, s.total)) OF \(s.total)").font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            HStack(spacing: 8) {
                Text("\(s.index)").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                LiveLine(fraction: s.fraction)
                Text("\(s.total)").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            }
            HStack {
                Text(s.firstName).lineLimit(1)
                Spacer()
                Text("\(s.left) to go").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                Spacer()
                Text(s.lastName).lineLimit(1)
            }
            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT: \(s.nextKind.uppercased())").font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                Text(s.nextName).font(.system(size: 20, weight: .bold)).foregroundStyle(.white).lineLimit(1)
            }
        }
        .padding(16)
    }
}

struct LiveLine: View {
    let fraction: Double
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22)).frame(height: 4)
                Capsule().fill(accent).frame(width: max(0, w * fraction), height: 4)
                Circle().fill(accent).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.black, lineWidth: 2.5))
                    .offset(x: w * fraction - 6)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 14)
    }
}

private extension String {
    var shortName: String {
        var s = self
        for suffix in [" Stunt Jump", " Stunt"] where s.hasSuffix(suffix) { s.removeLast(suffix.count); break }
        return s
    }
}
